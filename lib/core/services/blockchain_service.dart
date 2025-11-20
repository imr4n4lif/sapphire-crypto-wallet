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

  // Enhanced rate limiting with exponential backoff
  DateTime? _lastBtcApiCall;
  DateTime? _lastEthApiCall;
  DateTime? _lastFilApiCall;
  Duration _apiCallDelay = const Duration(milliseconds: 800);
  static const int _maxRetries = 3;

  // Enhanced caching with timestamps and TTL
  final Map<String, _CachedData> _cache = {};
  static const Duration _balanceCacheTTL = Duration(minutes: 2);
  static const Duration _txCacheTTL = Duration(minutes: 3);
  static const Duration _feeCacheTTL = Duration(minutes: 1);

  // Connection pooling for better performance
  final http.Client _httpClient = http.Client();

  void initialize(bool isMainnet) {
    _isMainnet = isMainnet;
    final rpcUrl = isMainnet ? AppConstants.ethMainnetRpc : AppConstants.ethTestnetRpc;

    // Check if Infura key exists
    if (AppConstants.infuraProjectId.isEmpty) {
      print('⚠️ Warning: Infura Project ID not configured');
    }

    _ethClient = web3dart.Web3Client(rpcUrl, _httpClient);
    print('🔗 Blockchain service initialized (${isMainnet ? "Mainnet" : "Testnet"})');
  }

  // ====================
  // BITCOIN IMPLEMENTATION
  // ====================

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

        // Calculate balance from UTXOs
        final chainStats = data['chain_stats'] ?? {};
        final mempoolStats = data['mempool_stats'] ?? {};

        final chainFunded = chainStats['funded_txo_sum'] ?? 0;
        final chainSpent = chainStats['spent_txo_sum'] ?? 0;
        final mempoolFunded = mempoolStats['funded_txo_sum'] ?? 0;
        final mempoolSpent = mempoolStats['spent_txo_sum'] ?? 0;

        final totalFunded = chainFunded + mempoolFunded;
        final totalSpent = chainSpent + mempoolSpent;
        final balanceSatoshis = totalFunded - totalSpent;
        final balance = balanceSatoshis / 100000000.0;

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
            return Transaction.fromMempoolBitcoin(tx, address);
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

      // Validate addresses
      if (!_validateBitcoinAddress(toAddress)) {
        throw Exception('Invalid recipient Bitcoin address');
      }

      // Get UTXOs
      final utxos = await _getBitcoinUtxos(fromAddress, privateKeyHex);
      if (utxos.isEmpty) {
        throw Exception('No UTXOs available. Please wait for confirmations.');
      }

      // Convert amount to satoshis
      final amountSatoshis = (amount * 100000000).toInt();

      // Calculate total available
      final totalAvailable = utxos.fold<BigInt>(
          BigInt.zero,
              (sum, utxo) => sum + utxo.utxo.value
      );

      if (totalAvailable < BigInt.from(amountSatoshis)) {
        throw Exception('Insufficient funds (have: ${totalAvailable / BigInt.from(100000000)} BTC)');
      }

      // Create Bitcoin private key
      final privateKey = ECPrivate.fromHex(privateKeyHex);

      // Determine network
      final network = _isMainnet ? BitcoinNetwork.mainnet : BitcoinNetwork.testnet;

      // Build transaction with dynamic fee
      final estimatedSize = 250; // bytes (typical for 1 input, 2 outputs)
      final feeSatoshis = (feeRate * estimatedSize).toInt();

      final txb = BitcoinTransactionBuilder(
        utxos: utxos,
        outPuts: [
          BitcoinOutput(
            address: P2pkhAddress.fromAddress(
              address: toAddress,
              network: network,
            ),
            value: BigInt.from(amountSatoshis),
          ),
        ],
        fee: BigInt.from(feeSatoshis),
        network: network,
        enableRBF: true, // Enable Replace-By-Fee
      );

      // Sign transaction
      final transaction = txb.buildTransaction((trDigest, utxo, publicKey, sighash) {
        final signature = privateKey.signInput(trDigest, sigHash: sighash);
        return signature;
      });

      // Serialize and broadcast
      final txHex = transaction.serialize();
      print('📋 Transaction hex length: ${txHex.length}');

      final txHash = await _broadcastBitcoinTransaction(txHex);
      print('✅ Bitcoin transaction sent: $txHash');

      // Clear balance cache to force refresh
      _clearCacheForAddress(fromAddress, CoinType.btc);

      return txHash;
    } catch (e) {
      print('❌ Send Bitcoin error: $e');
      throw Exception('Failed to send Bitcoin: ${_sanitizeErrorMessage(e.toString())}');
    }
  }

  Future<List<UtxoWithAddress>> _getBitcoinUtxos(String address, String privateKeyHex) async {
    try {
      final url = _isMainnet
          ? '${AppConstants.btcMainnetApi}/address/$address/utxo'
          : '${AppConstants.btcTestnetApi}/address/$address/utxo';

      final response = await _makeHttpRequest(url);

      if (response != null && response.statusCode == 200) {
        final utxos = json.decode(response.body) as List;

        if (utxos.isEmpty) {
          return [];
        }

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
    } catch (e) {
      print('❌ Error fetching UTXOs: $e');
      return [];
    }
  }

  Future<String> _broadcastBitcoinTransaction(String txHex) async {
    final url = _isMainnet
        ? '${AppConstants.btcMainnetApi}/tx'
        : '${AppConstants.btcTestnetApi}/tx';

    try {
      final response = await _httpClient.post(
        Uri.parse(url),
        headers: {'Content-Type': 'text/plain'},
        body: txHex,
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return response.body.trim();
      }

      throw Exception('Failed to broadcast: ${response.body}');
    } catch (e) {
      throw Exception('Broadcast failed: ${_sanitizeErrorMessage(e.toString())}');
    }
  }

  bool _validateBitcoinAddress(String address) {
    try {
      if (_isMainnet) {
        return address.startsWith('1') || // P2PKH
            address.startsWith('3') || // P2SH
            address.startsWith('bc1'); // Bech32
      } else {
        return address.startsWith('m') || // P2PKH testnet
            address.startsWith('n') || // P2PKH testnet
            address.startsWith('2') || // P2SH testnet
            address.startsWith('tb1'); // Bech32 testnet
      }
    } catch (e) {
      return false;
    }
  }

  // ====================
  // ETHEREUM IMPLEMENTATION
  // ====================

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
              print('⚠️ Error parsing ETH tx: $e');
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
      print('📤 Preparing Ethereum transaction...');

      // Validate address
      if (!toAddress.startsWith('0x') || toAddress.length != 42) {
        throw Exception('Invalid Ethereum address format');
      }

      final credentials = web3dart.EthPrivateKey.fromHex(privateKey);
      final sender = await credentials.address;
      final recipient = web3dart.EthereumAddress.fromHex(toAddress);

      // Check balance
      final currentBalance = await getEthereumBalance(sender.hex);
      if (currentBalance < amount) {
        throw Exception('Insufficient ETH balance (have: $currentBalance ETH)');
      }

      // Convert amount to Wei
      final amountWei = BigInt.from((amount * 1e18).round());
      final amountInWei = web3dart.EtherAmount.inWei(amountWei);

      // Get gas price (with fallback)
      web3dart.EtherAmount gasPrice;
      try {
        gasPrice = await _ethClient.getGasPrice();
      } catch (e) {
        print('⚠️ Using fallback gas price');
        gasPrice = web3dart.EtherAmount.inWei(BigInt.from(20 * 1e9)); // 20 Gwei fallback
      }

      // Estimate gas limit
      BigInt gasLimit = BigInt.from(21000); // Default for simple transfer
      try {
        gasLimit = await _ethClient.estimateGas(
          sender: sender,
          to: recipient,
          value: amountInWei,
        );
        // Add 10% buffer
        gasLimit = (gasLimit * BigInt.from(110)) ~/ BigInt.from(100);
      } catch (e) {
        print('⚠️ Using default gas limit: $e');
      }

      // Calculate total cost
      final totalCost = amountInWei.getInWei + (gasPrice.getInWei * gasLimit);
      final totalCostEth = web3dart.EtherAmount.inWei(totalCost)
          .getValueInUnit(web3dart.EtherUnit.ether);

      if (currentBalance < totalCostEth) {
        throw Exception('Insufficient balance for transaction + gas '
            '(need: ${totalCostEth.toStringAsFixed(6)} ETH)');
      }

      // Create transaction
      final txData = web3dart.Transaction(
        to: recipient,
        value: amountInWei,
        gasPrice: gasPrice,
        maxGas: gasLimit.toInt(),
      );

      // Send transaction
      final txHash = await _ethClient.sendTransaction(
        credentials,
        txData,
        chainId: _isMainnet ? 1 : 11155111,
      );

      print('✅ Ethereum transaction sent: $txHash');

      // Clear balance cache
      _clearCacheForAddress(sender.hex, CoinType.eth);

      return txHash;
    } catch (e) {
      print('❌ Send Ethereum error: $e');
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

      // Get gas price
      web3dart.EtherAmount gasPrice;
      try {
        gasPrice = await _ethClient.getGasPrice();
      } catch (e) {
        gasPrice = web3dart.EtherAmount.inWei(BigInt.from(20 * 1e9)); // 20 Gwei
      }

      // Estimate gas limit
      BigInt gasLimit = BigInt.from(21000);
      try {
        gasLimit = await _ethClient.estimateGas(
            sender: from,
            to: to,
            value: value
        );
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
      print('❌ Gas estimation error: $e');
      return GasFeeEstimate(gasLimit: 21000, gasPrice: 20.0, totalFee: 0.00042);
    }
  }

  // ====================
  // FILECOIN IMPLEMENTATION
  // ====================

  Future<double> getFilecoinBalance(String address) async {
    try {
      if (address.endsWith('unavailable')) return 0.0;

      final cacheKey = 'fil_balance_$address';
      if (_isCacheValid(cacheKey, _balanceCacheTTL)) {
        return _cache[cacheKey]!.data as double;
      }

      await _respectRateLimit(_lastFilApiCall);
      _lastFilApiCall = DateTime.now();

      final url = _isMainnet ? AppConstants.filMainnetRpc : AppConstants.filTestnetRpc;

      final response = await _httpClient.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'jsonrpc': '2.0',
          'method': 'Filecoin.WalletBalance',
          'params': [address],
          'id': 1,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['error'] != null) {
          print('⚠️ Filecoin API error: ${data['error']}');
          return 0.0;
        }

        if (data['result'] != null) {
          final balanceStr = data['result'].toString().replaceAll('"', '');
          if (balanceStr.isNotEmpty && balanceStr != 'null') {
            final balanceAttoFil = BigInt.tryParse(balanceStr) ?? BigInt.zero;
            final balance = balanceAttoFil / BigInt.from(10).pow(18);

            _cache[cacheKey] = _CachedData(balance, DateTime.now());
            print('✅ FIL Balance: $balance');
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
      if (_isCacheValid(cacheKey, _txCacheTTL)) {
        return _cache[cacheKey]!.data as List<Transaction>;
      }

      // Note: Filecoin transaction history is complex and may require
      // additional implementation or third-party services
      return [];
    } catch (e) {
      print('❌ FIL transactions error: $e');
      return [];
    }
  }

  // ====================
  // HELPER METHODS
  // ====================

  Future<http.Response?> _makeHttpRequest(String url, {int attempt = 1}) async {
    try {
      final response = await _httpClient.get(Uri.parse(url)).timeout(
        Duration(seconds: 10 + (attempt * 5)), // Increase timeout on retries
      );

      if (response.statusCode == 429) {
        // Rate limited - exponential backoff
        if (attempt <= _maxRetries) {
          final delay = Duration(seconds: attempt * 2);
          print('⚠️ Rate limited, retrying in ${delay.inSeconds}s...');
          await Future.delayed(delay);
          return _makeHttpRequest(url, attempt: attempt + 1);
        }
      }

      return response;
    } catch (e) {
      if (attempt <= _maxRetries) {
        print('⚠️ Request failed (attempt $attempt), retrying...');
        await Future.delayed(Duration(seconds: attempt));
        return _makeHttpRequest(url, attempt: attempt + 1);
      }
      print('❌ Request failed after $attempt attempts: $e');
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
    final prefix = coinType.name;
    _cache.removeWhere((key, value) =>
    key.contains(address) && key.startsWith(prefix)
    );
  }

  String _sanitizeErrorMessage(String error) {
    // Remove sensitive information from error messages
    if (error.contains('private')) {
      return 'Authentication error';
    }
    if (error.contains('Invalid JSON')) {
      return 'Network error';
    }
    // Truncate long errors
    if (error.length > 100) {
      return error.substring(0, 100) + '...';
    }
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

// Cache data wrapper
class _CachedData {
  final dynamic data;
  final DateTime timestamp;
  _CachedData(this.data, this.timestamp);
}

// Gas fee estimate model
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