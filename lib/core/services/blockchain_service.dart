import 'package:http/http.dart' as http;
import 'package:web3dart/web3dart.dart' as web3dart;
import 'dart:convert';
import 'dart:async';
import '../../models/wallet.dart';
import '../constants/app_constants.dart';
import 'package:bitcoin_base/bitcoin_base.dart';

class BlockchainService {
  static final BlockchainService _instance = BlockchainService._internal();
  factory BlockchainService() => _instance;
  BlockchainService._internal();

  late web3dart.Web3Client _ethClient;
  bool _isMainnet = true;

  // Optimized rate limiting
  DateTime? _lastBtcApiCall;
  DateTime? _lastEthApiCall;
  DateTime? _lastTrxApiCall;
  Duration _apiCallDelay = const Duration(milliseconds: 500);
  static const int _maxRetries = 3;

  // Enhanced caching
  final Map<String, _CachedData> _cache = {};
  static const Duration _balanceCacheTTL = Duration(minutes: 2);
  static const Duration _txCacheTTL = Duration(minutes: 3);
  static const Duration _feeCacheTTL = Duration(minutes: 1);

  final http.Client _httpClient = http.Client();

  void initialize(bool isMainnet) {
    _isMainnet = isMainnet;
    final rpcUrl = isMainnet ? AppConstants.ethMainnetRpc : AppConstants.ethTestnetRpc;

    if (AppConstants.infuraProjectId.isEmpty) {
      print('⚠️ Warning: Infura Project ID not configured');
    }

    _ethClient = web3dart.Web3Client(rpcUrl, _httpClient);
    print('🔗 Blockchain service initialized (${isMainnet ? "Mainnet" : "Testnet"})');
  }

  // BITCOIN
  Future<double> getBitcoinBalance(String address) async {
    try {
      final cacheKey = 'btc_balance_$address';
      if (_isCacheValid(cacheKey, _balanceCacheTTL)) {
        return _cache[cacheKey]!.data as double;
      }

      await _respectRateLimit(_lastBtcApiCall);
      _lastBtcApiCall = DateTime.now();

      final url = _isMainnet
          ? '${AppConstants.btcMainnetApi}/address/$address'
          : '${AppConstants.btcTestnetApi}/address/$address';

      final response = await _makeHttpRequest(url);

      if (response != null && response.statusCode == 200) {
        final data = json.decode(response.body);
        final chainStats = data['chain_stats'] ?? {};
        final mempoolStats = data['mempool_stats'] ?? {};

        final totalFunded = (chainStats['funded_txo_sum'] ?? 0) + (mempoolStats['funded_txo_sum'] ?? 0);
        final totalSpent = (chainStats['spent_txo_sum'] ?? 0) + (mempoolStats['spent_txo_sum'] ?? 0);
        final balance = (totalFunded - totalSpent) / 100000000.0;

        _cache[cacheKey] = _CachedData(balance, DateTime.now());
        print('✅ BTC Balance: $balance');
        return balance;
      }

      return _cache[cacheKey]?.data as double? ?? 0.0;
    } catch (e) {
      print('❌ BTC balance error: $e');
      return _cache['btc_balance_$address']?.data as double? ?? 0.0;
    }
  }

  Future<List<Transaction>> getBitcoinTransactions(String address) async {
    try {
      final cacheKey = 'btc_tx_$address';
      if (_isCacheValid(cacheKey, _txCacheTTL)) {
        return _cache[cacheKey]!.data as List<Transaction>;
      }

      await _respectRateLimit(_lastBtcApiCall);
      _lastBtcApiCall = DateTime.now();

      final url = _isMainnet
          ? '${AppConstants.btcMainnetApi}/address/$address/txs'
          : '${AppConstants.btcTestnetApi}/address/$address/txs';

      final response = await _makeHttpRequest(url);

      if (response != null && response.statusCode == 200) {
        final txs = json.decode(response.body) as List;
        final transactions = txs.take(20).map((tx) {
          try {
            return Transaction.fromBlockstreamBitcoin(tx, address);
          } catch (e) {
            print('⚠️ Error parsing BTC tx: $e');
            return null;
          }
        }).whereType<Transaction>().toList();

        _cache[cacheKey] = _CachedData(transactions, DateTime.now());
        print('✅ Fetched ${transactions.length} BTC transactions');
        return transactions;
      }

      return _cache[cacheKey]?.data as List<Transaction>? ?? [];
    } catch (e) {
      print('❌ BTC transactions error: $e');
      return _cache['btc_tx_$address']?.data as List<Transaction>? ?? [];
    }
  }

  Future<String> sendBitcoin({
    required String fromAddress,
    required String toAddress,
    required String privateKeyHex,
    required double amount,
    required double feeRate,
  }) async {
    try {
      print('📤 Preparing Bitcoin transaction...');

      if (!_validateBitcoinAddress(toAddress)) {
        throw Exception('Invalid recipient Bitcoin address');
      }

      final utxos = await _getBitcoinUtxos(fromAddress, privateKeyHex);
      if (utxos.isEmpty) {
        throw Exception('No UTXOs available');
      }

      final amountSatoshis = (amount * 100000000).toInt();
      final totalAvailable = utxos.fold<BigInt>(BigInt.zero, (sum, utxo) => sum + utxo.utxo.value);

      if (totalAvailable < BigInt.from(amountSatoshis)) {
        throw Exception('Insufficient funds');
      }

      final privateKey = ECPrivate.fromHex(privateKeyHex);
      final network = _isMainnet ? BitcoinNetwork.mainnet : BitcoinNetwork.testnet;
      final feeSatoshis = (feeRate * 250).toInt();

      final txb = BitcoinTransactionBuilder(
        utxos: utxos,
        outPuts: [
          BitcoinOutput(
            address: P2pkhAddress.fromAddress(address: toAddress, network: network),
            value: BigInt.from(amountSatoshis),
          ),
        ],
        fee: BigInt.from(feeSatoshis),
        network: network,
        enableRBF: true,
      );

      final transaction = txb.buildTransaction((trDigest, utxo, publicKey, sighash) {
        return privateKey.signInput(trDigest, sigHash: sighash);
      });

      final txHex = transaction.serialize();
      final txHash = await _broadcastBitcoinTransaction(txHex);

      _clearCacheForAddress(fromAddress, CoinType.btc);
      return txHash;
    } catch (e) {
      throw Exception('Failed to send Bitcoin: ${_sanitizeErrorMessage(e.toString())}');
    }
  }

  Future<List<UtxoWithAddress>> _getBitcoinUtxos(String address, String privateKeyHex) async {
    final url = _isMainnet
        ? '${AppConstants.btcMainnetApi}/address/$address/utxo'
        : '${AppConstants.btcTestnetApi}/address/$address/utxo';

    final response = await _makeHttpRequest(url);

    if (response != null && response.statusCode == 200) {
      final utxos = json.decode(response.body) as List;
      if (utxos.isEmpty) return [];

      final privateKey = ECPrivate.fromHex(privateKeyHex);
      final publicKey = privateKey.getPublic();
      final network = _isMainnet ? BitcoinNetwork.mainnet : BitcoinNetwork.testnet;
      final p2pkhAddress = P2pkhAddress.fromAddress(address: address, network: network);

      return utxos.map((u) {
        return UtxoWithAddress(
          utxo: BitcoinUtxo(
            txHash: u['txid'],
            value: BigInt.from(u['value'] ?? 0),
            vout: u['vout'] ?? 0,
            scriptType: p2pkhAddress.type,
          ),
          ownerDetails: UtxoAddressDetails(
            publicKey: publicKey.toHex(),
            address: p2pkhAddress,
          ),
        );
      }).toList();
    }
    return [];
  }

  Future<String> _broadcastBitcoinTransaction(String txHex) async {
    final url = _isMainnet
        ? '${AppConstants.btcMainnetApi}/tx'
        : '${AppConstants.btcTestnetApi}/tx';

    final response = await _httpClient.post(
      Uri.parse(url),
      headers: {'Content-Type': 'text/plain'},
      body: txHex,
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      return response.body.trim();
    }
    throw Exception('Broadcast failed: ${response.body}');
  }

  bool _validateBitcoinAddress(String address) {
    if (_isMainnet) {
      return address.startsWith('1') || address.startsWith('3') || address.startsWith('bc1');
    } else {
      return address.startsWith('m') || address.startsWith('n') ||
          address.startsWith('2') || address.startsWith('tb1');
    }
  }

  // ETHEREUM
  Future<double> getEthereumBalance(String address) async {
    try {
      final cacheKey = 'eth_balance_$address';
      if (_isCacheValid(cacheKey, _balanceCacheTTL)) {
        return _cache[cacheKey]!.data as double;
      }

      final ethAddress = web3dart.EthereumAddress.fromHex(address);
      final balance = await _ethClient.getBalance(ethAddress);
      final balanceEth = balance.getValueInUnit(web3dart.EtherUnit.ether);

      _cache[cacheKey] = _CachedData(balanceEth, DateTime.now());
      print('✅ ETH Balance: $balanceEth');
      return balanceEth;
    } catch (e) {
      print('❌ ETH balance error: $e');
      return _cache['eth_balance_$address']?.data as double? ?? 0.0;
    }
  }

  Future<List<Transaction>> getEthereumTransactions(String address) async {
    try {
      final cacheKey = 'eth_tx_$address';
      if (_isCacheValid(cacheKey, _txCacheTTL)) {
        return _cache[cacheKey]!.data as List<Transaction>;
      }

      await _respectRateLimit(_lastEthApiCall);
      _lastEthApiCall = DateTime.now();

      final apiKey = AppConstants.etherscanApiKey;
      if (apiKey.isEmpty) {
        print('⚠️ Etherscan API key not configured');
        return [];
      }

      final baseUrl = _isMainnet
          ? AppConstants.ethMainnetEtherscanV2
          : AppConstants.ethTestnetEtherscanV2;

      final url = '$baseUrl?module=account&action=txlist'
          '&address=$address&startblock=0&endblock=99999999'
          '&page=1&offset=20&sort=desc&apikey=$apiKey';

      final response = await _makeHttpRequest(url);

      if (response != null && response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == '1' && data['result'] is List) {
          final transactions = (data['result'] as List)
              .map((tx) {
            try {
              return Transaction.fromEtherscanV2(tx, address);
            } catch (e) {
              return null;
            }
          })
              .whereType<Transaction>()
              .toList();

          _cache[cacheKey] = _CachedData(transactions, DateTime.now());
          print('✅ Fetched ${transactions.length} ETH transactions');
          return transactions;
        }
      }

      return [];
    } catch (e) {
      print('❌ ETH transactions error: $e');
      return [];
    }
  }

  Future<String> sendEthereum({
    required String toAddress,
    required String privateKey,
    required double amount,
  }) async {
    try {
      print('📤 Preparing Ethereum transaction...');

      if (!toAddress.startsWith('0x') || toAddress.length != 42) {
        throw Exception('Invalid Ethereum address format');
      }

      final credentials = web3dart.EthPrivateKey.fromHex(privateKey);
      final sender = await credentials.address;
      final recipient = web3dart.EthereumAddress.fromHex(toAddress);

      final currentBalance = await getEthereumBalance(sender.hex);
      if (currentBalance < amount) {
        throw Exception('Insufficient ETH balance');
      }

      final amountWei = BigInt.from((amount * 1e18).round());
      final amountInWei = web3dart.EtherAmount.inWei(amountWei);

      web3dart.EtherAmount gasPrice;
      try {
        gasPrice = await _ethClient.getGasPrice();
      } catch (e) {
        gasPrice = web3dart.EtherAmount.inWei(BigInt.from(20 * 1e9));
      }

      BigInt gasLimit = BigInt.from(21000);
      try {
        gasLimit = await _ethClient.estimateGas(
          sender: sender,
          to: recipient,
          value: amountInWei,
        );
        gasLimit = (gasLimit * BigInt.from(110)) ~/ BigInt.from(100);
      } catch (e) {
        print('⚠️ Using default gas limit');
      }

      final totalCost = amountInWei.getInWei + (gasPrice.getInWei * gasLimit);
      final totalCostEth = web3dart.EtherAmount.inWei(totalCost)
          .getValueInUnit(web3dart.EtherUnit.ether);

      if (currentBalance < totalCostEth) {
        throw Exception('Insufficient balance for transaction + gas');
      }

      final txData = web3dart.Transaction(
        to: recipient,
        value: amountInWei,
        gasPrice: gasPrice,
        maxGas: gasLimit.toInt(),
      );

      final txHash = await _ethClient.sendTransaction(
        credentials,
        txData,
        chainId: _isMainnet ? 1 : 11155111,
      );

      _clearCacheForAddress(sender.hex, CoinType.eth);
      return txHash;
    } catch (e) {
      throw Exception('Failed to send Ethereum: ${_sanitizeErrorMessage(e.toString())}');
    }
  }

  Future<GasFeeEstimate> estimateEthereumGasFee({
    required String fromAddress,
    required String toAddress,
    required double amount,
  }) async {
    try {
      final cacheKey = 'gas_fee_${fromAddress}_${toAddress}_$amount';
      if (_isCacheValid(cacheKey, _feeCacheTTL)) {
        return _cache[cacheKey]!.data as GasFeeEstimate;
      }

      final from = web3dart.EthereumAddress.fromHex(fromAddress);
      final to = web3dart.EthereumAddress.fromHex(toAddress);
      final value = web3dart.EtherAmount.inWei(BigInt.from((amount * 1e18).round()));

      web3dart.EtherAmount gasPrice;
      try {
        gasPrice = await _ethClient.getGasPrice();
      } catch (e) {
        gasPrice = web3dart.EtherAmount.inWei(BigInt.from(20 * 1e9));
      }

      BigInt gasLimit = BigInt.from(21000);
      try {
        gasLimit = await _ethClient.estimateGas(sender: from, to: to, value: value);
      } catch (e) {
        print('⚠️ Using default gas limit');
      }

      final gasFee = gasPrice.getInWei * gasLimit;
      final gasFeeEth = web3dart.EtherAmount.inWei(gasFee)
          .getValueInUnit(web3dart.EtherUnit.ether);

      final estimate = GasFeeEstimate(
        gasLimit: gasLimit.toInt(),
        gasPrice: gasPrice.getValueInUnit(web3dart.EtherUnit.gwei),
        totalFee: gasFeeEth,
      );

      _cache[cacheKey] = _CachedData(estimate, DateTime.now());
      return estimate;
    } catch (e) {
      return GasFeeEstimate(gasLimit: 21000, gasPrice: 20.0, totalFee: 0.00042);
    }
  }

  // TRON
  Future<double> getTronBalance(String address) async {
    try {
      final cacheKey = 'trx_balance_$address';
      if (_isCacheValid(cacheKey, _balanceCacheTTL)) {
        return _cache[cacheKey]!.data as double;
      }

      await _respectRateLimit(_lastTrxApiCall);
      _lastTrxApiCall = DateTime.now();

      final baseUrl = _isMainnet ? AppConstants.trxMainnetApi : AppConstants.trxTestnetApi;
      final url = '$baseUrl/v1/accounts/$address';

      final headers = <String, String>{'Content-Type': 'application/json'};
      if (AppConstants.tronGridApiKey.isNotEmpty) {
        headers['TRON-PRO-API-KEY'] = AppConstants.tronGridApiKey;
      }

      final response = await _httpClient.get(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['data'] != null && (data['data'] as List).isNotEmpty) {
          final balanceSun = data['data'][0]['balance'] ?? 0;
          final balance = balanceSun / 1000000.0;

          _cache[cacheKey] = _CachedData(balance, DateTime.now());
          print('✅ TRX Balance: $balance');
          return balance;
        }
      }

      return 0.0;
    } catch (e) {
      print('❌ TRX balance error: $e');
      return _cache['trx_balance_$address']?.data as double? ?? 0.0;
    }
  }

  Future<List<Transaction>> getTronTransactions(String address) async {
    try {
      final cacheKey = 'trx_tx_$address';
      if (_isCacheValid(cacheKey, _txCacheTTL)) {
        return _cache[cacheKey]!.data as List<Transaction>;
      }

      await _respectRateLimit(_lastTrxApiCall);
      _lastTrxApiCall = DateTime.now();

      final baseUrl = _isMainnet ? AppConstants.trxMainnetApi : AppConstants.trxTestnetApi;
      final url = '$baseUrl/v1/accounts/$address/transactions?limit=20';

      final headers = <String, String>{'Content-Type': 'application/json'};
      if (AppConstants.tronGridApiKey.isNotEmpty) {
        headers['TRON-PRO-API-KEY'] = AppConstants.tronGridApiKey;
      }

      final response = await _httpClient.get(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['data'] != null) {
          final transactions = (data['data'] as List)
              .map((tx) {
            try {
              return Transaction.fromTronGrid(tx, address);
            } catch (e) {
              return null;
            }
          })
              .whereType<Transaction>()
              .toList();

          _cache[cacheKey] = _CachedData(transactions, DateTime.now());
          print('✅ Fetched ${transactions.length} TRX transactions');
          return transactions;
        }
      }

      return [];
    } catch (e) {
      print('❌ TRX transactions error: $e');
      return [];
    }
  }

  Future<String> sendTron({
    required String toAddress,
    required String privateKey,
    required double amount,
  }) async {
    throw UnimplementedError(
        'Tron sending requires tronweb library. '
            'Use TronWeb SDK or tron_dart package for full implementation.'
    );
  }

  // HELPERS
  Future<http.Response?> _makeHttpRequest(String url, {int attempt = 1}) async {
    try {
      final response = await _httpClient.get(Uri.parse(url))
          .timeout(Duration(seconds: 10 + (attempt * 5)));

      if (response.statusCode == 429 && attempt <= _maxRetries) {
        await Future.delayed(Duration(seconds: attempt * 2));
        return _makeHttpRequest(url, attempt: attempt + 1);
      }

      return response;
    } catch (e) {
      if (attempt <= _maxRetries) {
        await Future.delayed(Duration(seconds: attempt));
        return _makeHttpRequest(url, attempt: attempt + 1);
      }
      return null;
    }
  }

  Future<void> _respectRateLimit(DateTime? lastCall) async {
    if (lastCall != null) {
      final timeSince = DateTime.now().difference(lastCall);
      if (timeSince < _apiCallDelay) {
        await Future.delayed(_apiCallDelay - timeSince);
      }
    }
  }

  bool _isCacheValid(String key, Duration maxAge) {
    final cached = _cache[key];
    if (cached == null) return false;
    return DateTime.now().difference(cached.timestamp) < maxAge;
  }

  void _clearCacheForAddress(String address, CoinType coinType) {
    _cache.removeWhere((key, value) =>
    key.contains(address) && key.startsWith(coinType.name));
  }

  String _sanitizeErrorMessage(String error) {
    if (error.contains('private')) return 'Authentication error';
    if (error.length > 100) return error.substring(0, 100) + '...';
    return error;
  }

  void clearCache() {
    _cache.clear();
    print('🗑️ Cache cleared');
  }

  void dispose() {
    _ethClient.dispose();
    _httpClient.close();
  }
}

class _CachedData {
  final dynamic data;
  final DateTime timestamp;
  _CachedData(this.data, this.timestamp);
}

class GasFeeEstimate {
  final int gasLimit;
  final double gasPrice;
  final double totalFee;

  GasFeeEstimate({
    required this.gasLimit,
    required this.gasPrice,
    required this.totalFee,
  });
}