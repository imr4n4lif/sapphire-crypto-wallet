import 'package:http/http.dart' as http;
import 'package:web3dart/web3dart.dart' as web3dart;
import 'dart:convert';
import '../../models/wallet.dart';
import '../constants/app_constants.dart';
import 'package:bitcoin_base/bitcoin_base.dart';

class BlockchainService {
  static final BlockchainService _instance = BlockchainService._internal();
  factory BlockchainService() => _instance;
  BlockchainService._internal();

  late web3dart.Web3Client _ethClient;
  bool _isMainnet = true;

  // Enhanced rate limiting
  DateTime? _lastBtcApiCall;
  DateTime? _lastEthApiCall;
  DateTime? _lastFilApiCall;
  final Duration _apiCallDelay = const Duration(milliseconds: 800);

  // Enhanced caching with timestamps
  Map<String, _CachedData> _cache = {};

  void initialize(bool isMainnet) {
    _isMainnet = isMainnet;
    final rpcUrl = isMainnet ? AppConstants.ethMainnetRpc : AppConstants.ethTestnetRpc;
    _ethClient = web3dart.Web3Client(rpcUrl, http.Client());
    print('🔗 Blockchain service initialized (${isMainnet ? "Mainnet" : "Testnet"})');
  }

  // ====================
  // BITCOIN IMPLEMENTATION
  // ====================

  Future<double> getBitcoinBalance(String address) async {
    try {
      final cacheKey = 'btc_balance_$address';
      if (_isCacheValid(cacheKey, Duration(minutes: 2))) {
        return _cache[cacheKey]!.data as double;
      }

      await _respectRateLimit(_lastBtcApiCall);
      _lastBtcApiCall = DateTime.now();

      final url = _isMainnet
          ? '${AppConstants.btcMainnetApi}/address/$address'
          : '${AppConstants.btcTestnetApi}/address/$address';

      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Request timeout'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final funded = data['chain_stats']['funded_txo_sum'] ?? 0;
        final spent = data['chain_stats']['spent_txo_sum'] ?? 0;
        final balanceSatoshis = funded - spent;
        final balance = balanceSatoshis / 100000000.0;

        _cache[cacheKey] = _CachedData(balance, DateTime.now());
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
      if (_isCacheValid(cacheKey, Duration(minutes: 2))) {
        return _cache[cacheKey]!.data as List<Transaction>;
      }

      await _respectRateLimit(_lastBtcApiCall);
      _lastBtcApiCall = DateTime.now();

      final url = _isMainnet
          ? '${AppConstants.btcMainnetApi}/address/$address/txs'
          : '${AppConstants.btcTestnetApi}/address/$address/txs';

      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode == 200) {
        final txs = json.decode(response.body) as List;
        final transactions = txs.take(20).map((tx) {
          return Transaction.fromMempoolBitcoin(tx, address);
        }).whereType<Transaction>().toList();

        _cache[cacheKey] = _CachedData(transactions, DateTime.now());
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
      // Get UTXOs
      final utxos = await _getBitcoinUtxos(fromAddress, privateKeyHex);
      if (utxos.isEmpty) {
        throw Exception('No UTXOs available');
      }

      // Convert amount to satoshis
      final amountSatoshis = (amount * 100000000).toInt();

      // Create Bitcoin private key
      final privateKey = ECPrivate.fromHex(privateKeyHex);

      // Build transaction
      final txb = BitcoinTransactionBuilder(
        utxos: utxos,
        outPuts: [
          BitcoinOutput(
            address: P2pkhAddress.fromAddress(
              address: toAddress,
              network: _isMainnet ? BitcoinNetwork.mainnet : BitcoinNetwork.testnet,
            ),
            value: BigInt.from(amountSatoshis),
          ),
        ],
        fee: BigInt.from((feeRate * 250).toInt()),
        network: _isMainnet ? BitcoinNetwork.mainnet : BitcoinNetwork.testnet,
        enableRBF: false,
      );

      // Sign transaction
      final transaction = txb.buildTransaction((trDigest, utxo, publicKey, sighash) {
        final signature = privateKey.signInput(trDigest, sigHash: sighash);
        return signature;
      });

      // Broadcast
      final txHex = transaction.serialize();
      final txHash = await _broadcastBitcoinTransaction(txHex);

      return txHash;
    } catch (e) {
      print('❌ Send Bitcoin error: $e');
      throw Exception('Failed to send Bitcoin: $e');
    }
  }

  Future<List<UtxoWithAddress>> _getBitcoinUtxos(String address, String privateKeyHex) async {
    final url = _isMainnet
        ? '${AppConstants.btcMainnetApi}/address/$address/utxo'
        : '${AppConstants.btcTestnetApi}/address/$address/utxo';

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final utxos = json.decode(response.body) as List;
      final privateKey = ECPrivate.fromHex(privateKeyHex);
      final publicKey = privateKey.getPublic();

      final network = _isMainnet ? BitcoinNetwork.mainnet : BitcoinNetwork.testnet;
      final p2pkhAddress = P2pkhAddress.fromAddress(address: address, network: network);

      return utxos.map((u) {
        return UtxoWithAddress(
          utxo: BitcoinUtxo(
            txHash: u['txid'],
            value: BigInt.from(u['value']),
            vout: u['vout'],
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

    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'text/plain'},
      body: txHex,
    );

    if (response.statusCode == 200) {
      return response.body;
    }

    throw Exception('Failed to broadcast: ${response.body}');
  }

  // ====================
  // ETHEREUM IMPLEMENTATION
  // ====================

  Future<double> getEthereumBalance(String address) async {
    try {
      final cacheKey = 'eth_balance_$address';
      if (_isCacheValid(cacheKey, Duration(minutes: 1))) {
        return _cache[cacheKey]!.data as double;
      }

      final ethAddress = web3dart.EthereumAddress.fromHex(address);
      final balance = await _ethClient.getBalance(ethAddress);
      final balanceEth = balance.getValueInUnit(web3dart.EtherUnit.ether);

      _cache[cacheKey] = _CachedData(balanceEth, DateTime.now());
      return balanceEth;
    } catch (e) {
      print('❌ ETH balance error: $e');
      return _cache['eth_balance_$address']?.data as double? ?? 0.0;
    }
  }

  Future<List<Transaction>> getEthereumTransactions(String address) async {
    try {
      final cacheKey = 'eth_tx_$address';
      if (_isCacheValid(cacheKey, Duration(minutes: 2))) {
        return _cache[cacheKey]!.data as List<Transaction>;
      }

      await _respectRateLimit(_lastEthApiCall);
      _lastEthApiCall = DateTime.now();

      final apiKey = AppConstants.etherscanApiKey;
      if (apiKey.isEmpty) return [];

      final chainId = _isMainnet ? 1 : 11155111;
      final baseUrl = 'https://api.etherscan.io/v2/api';

      final url = '$baseUrl?chainid=$chainId&module=account&action=txlist&address=$address&startblock=0&endblock=99999999&page=1&offset=20&sort=desc&apikey=$apiKey';

      final response = await http.get(Uri.parse(url)).timeout(Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == '1' && data['result'] is List) {
          final transactions = (data['result'] as List)
              .map((tx) => Transaction.fromEtherscanV2(tx, address))
              .whereType<Transaction>()
              .toList();

          _cache[cacheKey] = _CachedData(transactions, DateTime.now());
          return transactions;
        }
      }

      return _cache[cacheKey]?.data as List<Transaction>? ?? [];
    } catch (e) {
      print('❌ ETH transactions error: $e');
      return _cache['eth_tx_$address']?.data as List<Transaction>? ?? [];
    }
  }

  Future<String> sendEthereum({
    required String toAddress,
    required String privateKey,
    required double amount,
  }) async {
    try {
      final credentials = web3dart.EthPrivateKey.fromHex(privateKey);
      final sender = await credentials.address;
      final recipient = web3dart.EthereumAddress.fromHex(toAddress);

      final amountWei = BigInt.from((amount * 1e18).round());
      final amountInWei = web3dart.EtherAmount.inWei(amountWei);

      final gasPrice = await _ethClient.getGasPrice();
      BigInt gasLimit = BigInt.from(21000);

      try {
        gasLimit = await _ethClient.estimateGas(
          sender: sender,
          to: recipient,
          value: amountInWei,
        );
      } catch (_) {}

      final txData = web3dart.Transaction(
        to: recipient,
        value: amountInWei,
        gasPrice: gasPrice,
        maxGas: (gasLimit.toDouble() * 1.2).round(),
      );

      final txHash = await _ethClient.sendTransaction(
        credentials,
        txData,
        chainId: _isMainnet ? 1 : 11155111,
      );

      return txHash;
    } catch (e) {
      print('❌ Send Ethereum error: $e');
      rethrow;
    }
  }

  // ====================
  // FILECOIN IMPLEMENTATION
  // ====================

  Future<double> getFilecoinBalance(String address) async {
    try {
      if (address.endsWith('unavailable')) return 0.0;

      final cacheKey = 'fil_balance_$address';
      if (_isCacheValid(cacheKey, Duration(minutes: 2))) {
        return _cache[cacheKey]!.data as double;
      }

      await _respectRateLimit(_lastFilApiCall);
      _lastFilApiCall = DateTime.now();

      final url = _isMainnet ? AppConstants.filMainnetRpc : AppConstants.filTestnetRpc;

      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'jsonrpc': '2.0',
          'method': 'Filecoin.WalletBalance',
          'params': [address],
          'id': 1,
        }),
      ).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['error'] != null) {
          return 0.0;
        }

        if (data['result'] != null) {
          final balanceStr = data['result'].toString().replaceAll('"', '');
          if (balanceStr.isNotEmpty && balanceStr != 'null') {
            final balanceAttoFil = BigInt.parse(balanceStr);
            final balance = balanceAttoFil / BigInt.from(10).pow(18);

            _cache[cacheKey] = _CachedData(balance, DateTime.now());
            return balance;
          }
        }
      }

      return 0.0;
    } catch (e) {
      print('❌ FIL balance error: $e');
      return _cache['fil_balance_$address']?.data as double? ?? 0.0;
    }
  }

  Future<List<Transaction>> getFilecoinTransactions(String address) async {
    try {
      if (address.endsWith('unavailable')) return [];

      final cacheKey = 'fil_tx_$address';
      if (_isCacheValid(cacheKey, Duration(minutes: 3))) {
        return _cache[cacheKey]!.data as List<Transaction>;
      }

      await _respectRateLimit(_lastFilApiCall);
      _lastFilApiCall = DateTime.now();

      final url = _isMainnet ? AppConstants.filMainnetRpc : AppConstants.filTestnetRpc;

      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'jsonrpc': '2.0',
          'method': 'Filecoin.StateListMessages',
          'params': [{'To': address}, null, 0],
          'id': 1,
        }),
      ).timeout(Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['error'] == null && data['result'] is List) {
          final transactions = (data['result'] as List)
              .take(20)
              .map((tx) => Transaction.fromFilecoin(tx, address))
              .whereType<Transaction>()
              .toList();

          _cache[cacheKey] = _CachedData(transactions, DateTime.now());
          return transactions;
        }
      }

      return [];
    } catch (e) {
      print('❌ FIL transactions error: $e');
      return _cache['fil_tx_$address']?.data as List<Transaction>? ?? [];
    }
  }

  Future<GasFeeEstimate> estimateEthereumGasFee({
    required String fromAddress,
    required String toAddress,
    required double amount,
  }) async {
    try {
      final from = web3dart.EthereumAddress.fromHex(fromAddress);
      final to = web3dart.EthereumAddress.fromHex(toAddress);
      final value = web3dart.EtherAmount.inWei(BigInt.from((amount * 1e18).round()));

      final gasPrice = await _ethClient.getGasPrice();
      BigInt gasLimit = BigInt.from(21000);

      try {
        gasLimit = await _ethClient.estimateGas(sender: from, to: to, value: value);
      } catch (_) {}

      final gasFee = gasPrice.getInWei * gasLimit;
      final gasFeeEth = web3dart.EtherAmount.inWei(gasFee).getValueInUnit(web3dart.EtherUnit.ether);

      return GasFeeEstimate(
        gasLimit: gasLimit.toInt(),
        gasPrice: gasPrice.getValueInUnit(web3dart.EtherUnit.gwei),
        totalFee: gasFeeEth,
      );
    } catch (e) {
      return GasFeeEstimate(gasLimit: 21000, gasPrice: 20.0, totalFee: 0.00042);
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

  void clearCache() {
    _cache.clear();
    print('🗑️ Cache cleared');
  }

  void dispose() {
    _ethClient.dispose();
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