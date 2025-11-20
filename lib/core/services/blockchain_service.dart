import 'package:http/http.dart' as http;
import 'package:web3dart/web3dart.dart' as web3dart;
import 'dart:convert';
import '../../models/wallet.dart';
import '../constants/app_constants.dart';

class BlockchainService {
  static final BlockchainService _instance = BlockchainService._internal();
  factory BlockchainService() => _instance;
  BlockchainService._internal();

  late web3dart.Web3Client _ethClient;
  bool _isMainnet = true;

  // Rate limiting
  DateTime? _lastBtcApiCall;
  DateTime? _lastEthApiCall;
  DateTime? _lastFilApiCall;
  final Duration _apiCallDelay = const Duration(seconds: 2);

  // Cache for API responses
  Map<String, dynamic> _btcBalanceCache = {};
  Map<String, dynamic> _ethTxCache = {};
  DateTime? _lastCacheUpdate;

  void initialize(bool isMainnet) {
    _isMainnet = isMainnet;
    final rpcUrl = isMainnet ? AppConstants.ethMainnetRpc : AppConstants.ethTestnetRpc;
    _ethClient = web3dart.Web3Client(rpcUrl, http.Client());
    print('🔗 Blockchain service initialized (${isMainnet ? "Mainnet" : "Testnet"})');
  }

  // Check if we should wait before making API call
  Future<void> _respectRateLimit(DateTime? lastCall) async {
    if (lastCall != null) {
      final timeSinceLastCall = DateTime.now().difference(lastCall);
      if (timeSinceLastCall < _apiCallDelay) {
        final waitTime = _apiCallDelay - timeSinceLastCall;
        print('⏱️ Rate limiting: waiting ${waitTime.inMilliseconds}ms');
        await Future.delayed(waitTime);
      }
    }
  }

  // Get Bitcoin balance with rate limiting (Using mempool.space API for testnet4)
  Future<double> getBitcoinBalance(String address) async {
    try {
      // Check cache first (valid for 1 minute)
      if (_btcBalanceCache['address'] == address &&
          _lastCacheUpdate != null &&
          DateTime.now().difference(_lastCacheUpdate!).inMinutes < 1) {
        print('📦 Using cached BTC balance');
        return _btcBalanceCache['balance'] ?? 0.0;
      }

      await _respectRateLimit(_lastBtcApiCall);
      _lastBtcApiCall = DateTime.now();

      final url = _isMainnet
          ? '${AppConstants.btcMainnetApi}/address/$address'
          : '${AppConstants.btcTestnetApi}/address/$address';

      print('📡 Fetching BTC balance for: $address');

      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw Exception('Request timeout'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final balanceSatoshis = data['chain_stats']['funded_txo_sum'] - data['chain_stats']['spent_txo_sum'];
        final balance = balanceSatoshis / 100000000;

        // Update cache
        _btcBalanceCache = {'address': address, 'balance': balance};
        _lastCacheUpdate = DateTime.now();

        print('✅ BTC Balance: $balance');
        return balance;
      } else if (response.statusCode == 429) {
        print('⚠️ BTC API rate limited (429). Using cached data or returning 0');
        return _btcBalanceCache['balance'] ?? 0.0;
      } else {
        print('⚠️ Failed to fetch BTC balance: ${response.statusCode}');
        return _btcBalanceCache['balance'] ?? 0.0;
      }
    } catch (e) {
      print('❌ Error fetching Bitcoin balance: $e');
      return _btcBalanceCache['balance'] ?? 0.0;
    }
  }

  // Get Ethereum balance
  Future<double> getEthereumBalance(String address) async {
    try {
      print('📡 Fetching ETH balance for: $address');
      final ethAddress = web3dart.EthereumAddress.fromHex(address);
      final balance = await _ethClient.getBalance(ethAddress);
      final balanceEth = balance.getValueInUnit(web3dart.EtherUnit.ether);
      print('✅ ETH Balance: $balanceEth');
      return balanceEth;
    } catch (e) {
      print('❌ Error fetching Ethereum balance: $e');
      return 0.0;
    }
  }

  // Get Filecoin balance with IMPROVED error handling
  Future<double> getFilecoinBalance(String address) async {
    try {
      // Skip if address is placeholder/unavailable
      if (address.endsWith('unavailable')) {
        print('⚠️ Filecoin address unavailable, skipping balance check');
        return 0.0;
      }

      final url = _isMainnet ? AppConstants.filMainnetRpc : AppConstants.filTestnetRpc;

      print('📡 Fetching FIL balance for: $address');

      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'jsonrpc': '2.0',
          'method': 'Filecoin.WalletBalance',
          'params': [address],
          'id': 1,
        }),
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          print('⚠️ FIL RPC request timeout');
          throw Exception('Request timeout');
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Check for RPC error
        if (data['error'] != null) {
          final errorMsg = data['error']['message'] ?? 'Unknown error';
          print('⚠️ FIL RPC Error: $errorMsg');

          // Don't spam logs if it's a known address format issue
          if (errorMsg.contains('invalid address')) {
            print('ℹ️ Filecoin address format may need adjustment');
          }
          return 0.0;
        }

        if (data['result'] != null) {
          final balanceStr = data['result'].toString().replaceAll('"', '');

          // Handle empty or invalid balance strings
          if (balanceStr.isEmpty || balanceStr == 'null') {
            print('ℹ️ FIL balance is empty/null');
            return 0.0;
          }

          try {
            final balanceAttoFil = BigInt.parse(balanceStr);
            final balance = balanceAttoFil / BigInt.from(10).pow(18);
            print('✅ FIL Balance: $balance');
            return balance;
          } catch (e) {
            print('⚠️ Failed to parse FIL balance: $balanceStr');
            return 0.0;
          }
        }
      } else if (response.statusCode == 500) {
        print('⚠️ FIL RPC server error (500) - Node may be unavailable');
        return 0.0;
      } else {
        print('⚠️ Failed to fetch FIL balance: ${response.statusCode}');
        return 0.0;
      }
    } catch (e) {
      if (e.toString().contains('timeout')) {
        print('⚠️ FIL balance check timed out');
      } else {
        print('❌ Error fetching Filecoin balance: $e');
      }
      return 0.0;
    }
    return 0.0;
  }

  // Get Bitcoin transactions (Using mempool.space API)
  Future<List<Transaction>> getBitcoinTransactions(String address) async {
    try {
      await _respectRateLimit(_lastBtcApiCall);
      _lastBtcApiCall = DateTime.now();

      final url = _isMainnet
          ? '${AppConstants.btcMainnetApi}/address/$address/txs'
          : '${AppConstants.btcTestnetApi}/address/$address/txs';

      print('📡 Fetching BTC transactions for: $address');

      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw Exception('Request timeout'),
      );

      if (response.statusCode == 200) {
        final txs = json.decode(response.body) as List;
        print('✅ Found ${txs.length} BTC transactions');

        return txs.take(20).map((tx) {
          try {
            return Transaction.fromMempoolBitcoin(tx, address);
          } catch (e) {
            print('⚠️ Error parsing BTC transaction: $e');
            return null;
          }
        }).whereType<Transaction>().toList();
      } else if (response.statusCode == 429) {
        print('⚠️ BTC transactions API rate limited (429)');
        return <Transaction>[];
      } else {
        print('⚠️ Failed to fetch BTC transactions: ${response.statusCode}');
        return <Transaction>[];
      }
    } catch (e) {
      if (e.toString().contains('timeout')) {
        print('⚠️ BTC transaction fetch timed out');
      } else {
        print('❌ Error fetching Bitcoin transactions: $e');
      }
      return <Transaction>[];
    }
  }

  // Get Ethereum transactions using Etherscan V2 API
  Future<List<Transaction>> getEthereumTransactions(String address) async {
    try {
      final apiKey = AppConstants.etherscanApiKey;

      if (apiKey.isEmpty) {
        print('⚠️ Etherscan API key not found in .env file');
        return <Transaction>[];
      }

      await _respectRateLimit(_lastEthApiCall);
      _lastEthApiCall = DateTime.now();

      final chainId = _isMainnet ? 1 : 11155111;
      final baseUrl = 'https://api.etherscan.io/v2/api';

      final url = '$baseUrl?chainid=$chainId&module=account&action=txlist&address=$address&startblock=0&endblock=99999999&page=1&offset=20&sort=desc&apikey=$apiKey';

      print('📡 Fetching ETH transactions for: $address');

      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 20),
        onTimeout: () => throw Exception('Request timeout'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data is! Map<String, dynamic>) {
          return <Transaction>[];
        }

        final status = data['status']?.toString() ?? '0';
        final message = data['message']?.toString() ?? '';
        final result = data['result'];

        if (status == '0') {
          if (message.toLowerCase().contains('no transactions found')) {
            print('ℹ️ No ETH transactions found');
            return <Transaction>[];
          }
          print('⚠️ Etherscan API Error: $message');
          return <Transaction>[];
        }

        if (status == '1' && result != null && result is List) {
          final txs = result as List;
          print('✅ Found ${txs.length} ETH transactions');

          return txs.take(20).map((tx) {
            try {
              return Transaction.fromEtherscanV2(tx, address);
            } catch (e) {
              print('⚠️ Error parsing ETH transaction: $e');
              return null;
            }
          }).whereType<Transaction>().toList();
        }

        return <Transaction>[];
      } else {
        print('⚠️ Failed to fetch ETH transactions: ${response.statusCode}');
        return <Transaction>[];
      }
    } catch (e) {
      print('❌ Error fetching Ethereum transactions: $e');
      return <Transaction>[];
    }
  }

  // Get Filecoin transactions with improved error handling
  Future<List<Transaction>> getFilecoinTransactions(String address) async {
    try {
      // Skip if address is placeholder/unavailable
      if (address.endsWith('unavailable')) {
        print('⚠️ Filecoin address unavailable, skipping transaction check');
        return <Transaction>[];
      }

      await _respectRateLimit(_lastFilApiCall);
      _lastFilApiCall = DateTime.now();

      final url = _isMainnet ? AppConstants.filMainnetRpc : AppConstants.filTestnetRpc;

      print('📡 Fetching FIL transactions for: $address');

      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'jsonrpc': '2.0',
          'method': 'Filecoin.StateListMessages',
          'params': [{'To': address}, null, 0],
          'id': 1,
        }),
      ).timeout(
        const Duration(seconds: 20),
        onTimeout: () => throw Exception('Request timeout'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['error'] != null) {
          print('⚠️ FIL RPC Error: ${data['error']['message']}');
          return <Transaction>[];
        }

        final result = data['result'];
        if (result != null && result is List) {
          print('✅ Found ${result.length} FIL transactions');

          return result.take(20).map((tx) {
            try {
              return Transaction.fromFilecoin(tx, address);
            } catch (e) {
              print('⚠️ Error parsing FIL transaction: $e');
              return null;
            }
          }).whereType<Transaction>().toList();
        }

        print('ℹ️ No FIL transactions found');
        return <Transaction>[];
      }

      return <Transaction>[];
    } catch (e) {
      if (e.toString().contains('timeout')) {
        print('⚠️ FIL transaction fetch timed out');
      } else {
        print('❌ Error fetching Filecoin transactions: $e');
      }
      return <Transaction>[];
    }
  }

  // Estimate gas fee for Ethereum
  Future<GasFeeEstimate> estimateEthereumGasFee({
    required String fromAddress,
    required String toAddress,
    required double amount,
  }) async {
    try {
      final from = web3dart.EthereumAddress.fromHex(fromAddress);
      final to = web3dart.EthereumAddress.fromHex(toAddress);

      final amountStr = amount.toStringAsFixed(18);
      final parts = amountStr.split('.');
      final integerPart = BigInt.parse(parts[0]);
      final fractionalPart = parts.length > 1 ? parts[1] : '0';
      final integerWei = integerPart * BigInt.from(10).pow(18);
      final fractionalWei = BigInt.parse(fractionalPart.padRight(18, '0'));
      final value = web3dart.EtherAmount.inWei(integerWei + fractionalWei);

      // Get gas price
      final gasPrice = await _ethClient.getGasPrice();

      // Estimate gas limit
      BigInt gasLimit;
      try {
        gasLimit = await _ethClient.estimateGas(
          sender: from,
          to: to,
          value: value,
        );
      } catch (e) {
        gasLimit = BigInt.from(21000);
      }

      final gasFee = gasPrice.getInWei * gasLimit;
      final gasFeeEth = web3dart.EtherAmount.inWei(gasFee).getValueInUnit(web3dart.EtherUnit.ether);

      return GasFeeEstimate(
        gasLimit: gasLimit.toInt(),
        gasPrice: gasPrice.getValueInUnit(web3dart.EtherUnit.gwei),
        totalFee: gasFeeEth,
      );
    } catch (e) {
      print('❌ Error estimating gas fee: $e');
      return GasFeeEstimate(
        gasLimit: 21000,
        gasPrice: 20.0,
        totalFee: 0.00042,
      );
    }
  }

  // Send Bitcoin
  Future<String> sendBitcoin({
    required String fromAddress,
    required String toAddress,
    required String privateKey,
    required double amount,
  }) async {
    try {
      throw UnimplementedError(
          'Bitcoin sending requires signing library. Use testnet faucet to receive:\n'
              '• Testnet4: https://mempool.space/testnet4/faucet\n'
              '• Testnet4: https://coinfaucet.eu/en/btc-testnet4/\n\n'
              'For implementation: Use bitcoin_base package'
      );
    } catch (e) {
      throw Exception('Failed to send Bitcoin: $e');
    }
  }

  // Send Ethereum
  Future<String> sendEthereum({
    required String toAddress,
    required String privateKey,
    required double amount,
  }) async {
    try {
      print('📤 Preparing ETH transaction...');

      final credentials = web3dart.EthPrivateKey.fromHex(privateKey);
      final sender = await credentials.address;
      final recipient = web3dart.EthereumAddress.fromHex(toAddress);

      final amountStr = amount.toStringAsFixed(18);
      final parts = amountStr.split('.');
      final integerPart = BigInt.parse(parts[0]);
      final fractionalPart = parts.length > 1 ? parts[1] : '0';
      final integerWei = integerPart * BigInt.from(10).pow(18);
      final fractionalWei = BigInt.parse(fractionalPart.padRight(18, '0'));
      final amountInWei = web3dart.EtherAmount.inWei(integerWei + fractionalWei);

      final balance = await _ethClient.getBalance(sender);
      final gasPrice = await _ethClient.getGasPrice();

      BigInt gasLimit;
      try {
        gasLimit = await _ethClient.estimateGas(
          sender: sender,
          to: recipient,
          value: amountInWei,
        );
      } catch (e) {
        gasLimit = BigInt.from(21000);
      }

      final gasLimitWithBuffer = (gasLimit.toDouble() * 1.2).round();
      final gasCost = gasPrice.getInWei * BigInt.from(gasLimitWithBuffer);
      final totalRequired = amountInWei.getInWei + gasCost;

      if (balance.getInWei < totalRequired) {
        final shortage = totalRequired - balance.getInWei;
        final shortageEth = web3dart.EtherAmount.inWei(shortage).getValueInUnit(web3dart.EtherUnit.ether);
        throw Exception(
            'Insufficient funds!\n'
                'Need: ${web3dart.EtherAmount.inWei(totalRequired).getValueInUnit(web3dart.EtherUnit.ether)} ETH\n'
                'Have: ${balance.getValueInUnit(web3dart.EtherUnit.ether)} ETH\n'
                'Short: $shortageEth ETH'
        );
      }

      final txData = web3dart.Transaction(
        to: recipient,
        value: amountInWei,
        gasPrice: gasPrice,
        maxGas: gasLimitWithBuffer,
      );

      final txHash = await _ethClient.sendTransaction(
        credentials,
        txData,
        chainId: _isMainnet ? 1 : 11155111,
      );

      print('✅ Transaction sent! Hash: $txHash');
      return txHash;
    } catch (e) {
      print('❌ Ethereum send error: $e');
      rethrow;
    }
  }

  // Send Filecoin
  Future<String> sendFilecoin({
    required String fromAddress,
    required String toAddress,
    required String privateKey,
    required double amount,
  }) async {
    throw UnimplementedError(
        'Filecoin sending requires filecoin signing library.\n'
            'For testnet: https://faucet.calibration.fildev.network/'
    );
  }

  void clearCache() {
    _btcBalanceCache.clear();
    _ethTxCache.clear();
    _lastCacheUpdate = null;
    print('🗑️ API cache cleared');
  }

  void dispose() {
    _ethClient.dispose();
  }
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