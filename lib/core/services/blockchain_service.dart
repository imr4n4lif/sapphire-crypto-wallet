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

  // Get Bitcoin balance with rate limiting
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
          ? '${AppConstants.btcMainnetApi}/addrs/$address/balance'
          : '${AppConstants.btcTestnetApi}/addrs/$address/balance';

      print('📡 Fetching BTC balance for: $address');

      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Request timeout'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final balanceSatoshis = data['final_balance'] ?? 0;
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

  // Get Filecoin balance with better error handling
  Future<double> getFilecoinBalance(String address) async {
    try {
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
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Request timeout'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Check for RPC error
        if (data['error'] != null) {
          print('⚠️ FIL RPC Error: ${data['error']['message']}');
          return 0.0;
        }

        if (data['result'] != null) {
          final balanceStr = data['result'].toString().replaceAll('"', '');
          final balanceAttoFil = BigInt.parse(balanceStr);
          final balance = balanceAttoFil / BigInt.from(10).pow(18);
          print('✅ FIL Balance: $balance');
          return balance;
        }
      } else if (response.statusCode == 500) {
        print('⚠️ FIL RPC server error (500)');
        return 0.0;
      } else {
        print('⚠️ Failed to fetch FIL balance: ${response.statusCode}');
        return 0.0;
      }
    } catch (e) {
      print('❌ Error fetching Filecoin balance: $e');
      return 0.0;
    }
    return 0.0;
  }

  // Get Bitcoin transactions with rate limiting
  Future<List<Transaction>> getBitcoinTransactions(String address) async {
    try {
      await _respectRateLimit(_lastBtcApiCall);
      _lastBtcApiCall = DateTime.now();

      final url = _isMainnet
          ? '${AppConstants.btcMainnetApi}/addrs/$address/full?limit=20'
          : '${AppConstants.btcTestnetApi}/addrs/$address/full?limit=20';

      print('📡 Fetching BTC transactions for: $address');

      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Request timeout'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final txs = data['txs'] as List? ?? [];
        print('✅ Found ${txs.length} BTC transactions');

        return txs.map((tx) {
          try {
            return Transaction.fromJson(tx, CoinType.btc, address);
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
      print('❌ Error fetching Bitcoin transactions: $e');
      return <Transaction>[];
    }
  }

  // Get Ethereum transactions using Etherscan V2 API - FULLY FIXED
  Future<List<Transaction>> getEthereumTransactions(String address) async {
    try {
      final apiKey = AppConstants.etherscanApiKey;

      if (apiKey.isEmpty) {
        print('⚠️ Etherscan API key not found in .env file');
        print('ℹ️ Add ETHERSCAN_API_KEY=your_key to .env file');
        print('ℹ️ Get free API key from: https://etherscan.io/apis');
        return <Transaction>[];
      }

      await _respectRateLimit(_lastEthApiCall);
      _lastEthApiCall = DateTime.now();

      // Etherscan V2 API endpoint with chainid parameter
      final chainId = _isMainnet ? 1 : 11155111; // Mainnet: 1, Sepolia: 11155111
      final baseUrl = 'https://api.etherscan.io/v2/api';

      final url = '$baseUrl?chainid=$chainId&module=account&action=txlist&address=$address&startblock=0&endblock=99999999&page=1&offset=20&sort=desc&apikey=$apiKey';

      print('📡 Fetching ETH transactions for: $address (Etherscan V2 API)');

      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw Exception('Request timeout'),
      );

      print('🔍 ETH API Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data is! Map<String, dynamic>) {
          print('⚠️ Unexpected response format: not a JSON object');
          return <Transaction>[];
        }

        final status = data['status']?.toString() ?? '0';
        final message = data['message']?.toString() ?? '';
        final result = data['result'];

        print('🔍 Etherscan Status: $status, Message: $message');

        if (status == '0') {
          if (message.toLowerCase().contains('no transactions found') ||
              message.toLowerCase().contains('no records found')) {
            print('ℹ️ No ETH transactions found for this address');
            return <Transaction>[];
          }

          if (result is String) {
            final resultLower = result.toLowerCase();
            if (resultLower.contains('invalid api key') ||
                resultLower.contains('missing') ||
                resultLower.contains('wrong api key')) {
              print('❌ Invalid or missing Etherscan API key');
              print('ℹ️ Get free key at: https://etherscan.io/apis');
              return <Transaction>[];
            }
          }

          if (message.toLowerCase().contains('rate limit')) {
            print('⚠️ Etherscan API rate limited');
            return <Transaction>[];
          }

          print('⚠️ Etherscan API Error: $message');
          return <Transaction>[];
        }

        // Success - parse transactions from V2 API
        if (status == '1' && result != null) {
          if (result is! List) {
            print('⚠️ Result is not a list: ${result.runtimeType}');
            return <Transaction>[];
          }

          final txs = result as List;
          print('✅ Found ${txs.length} ETH transactions');

          if (txs.isEmpty) {
            print('ℹ️ No ETH transactions found for this address');
            return <Transaction>[];
          }

          return txs.take(20).map((tx) {
            try {
              if (tx is! Map<String, dynamic>) {
                print('⚠️ Transaction is not a map: ${tx.runtimeType}');
                return null;
              }
              return Transaction.fromEtherscanV2(tx, address);
            } catch (e) {
              print('⚠️ Error parsing ETH transaction: $e');
              return null;
            }
          }).whereType<Transaction>().toList();
        }

        print('⚠️ Unexpected Etherscan V2 response format');
        return <Transaction>[];
      } else if (response.statusCode == 404) {
        print('⚠️ API endpoint not found (404)');
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

  // Get Filecoin transactions
  Future<List<Transaction>> getFilecoinTransactions(String address) async {
    try {
      await _respectRateLimit(_lastFilApiCall);
      _lastFilApiCall = DateTime.now();

      final url = _isMainnet ? AppConstants.filMainnetRpc : AppConstants.filTestnetRpc;

      print('📡 Fetching FIL transactions for: $address');

      // Query recent messages involving this address
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'jsonrpc': '2.0',
          'method': 'Filecoin.StateListMessages',
          'params': [{
            'To': address,
          }, null, 0],
          'id': 1,
        }),
      ).timeout(
        const Duration(seconds: 15),
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
      print('❌ Error fetching Filecoin transactions: $e');
      return <Transaction>[];
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
          'Bitcoin sending requires signing library. Use testnet faucet to receive, '
              'or implement with bitcoin_base package for production.'
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
      print('To: $toAddress');
      print('Amount: $amount ETH');

      final credentials = web3dart.EthPrivateKey.fromHex(privateKey);
      final sender = await credentials.address;
      final recipient = web3dart.EthereumAddress.fromHex(toAddress);

      // Convert amount to BigInt wei properly
      final amountStr = amount.toStringAsFixed(18);
      final parts = amountStr.split('.');
      final integerPart = BigInt.parse(parts[0]);
      final fractionalPart = parts.length > 1 ? parts[1] : '0';

      final integerWei = integerPart * BigInt.from(10).pow(18);
      final fractionalWei = BigInt.parse(fractionalPart.padRight(18, '0'));
      final amountInWei = web3dart.EtherAmount.inWei(integerWei + fractionalWei);

      print('Amount in Wei: ${amountInWei.getInWei}');

      // Get current balance
      final balance = await _ethClient.getBalance(sender);
      print('Current Balance: ${balance.getInWei} wei (${balance.getValueInUnit(web3dart.EtherUnit.ether)} ETH)');

      // Get gas price
      final gasPrice = await _ethClient.getGasPrice();
      print('Gas Price: ${gasPrice.getInWei} wei (${gasPrice.getValueInUnit(web3dart.EtherUnit.gwei)} Gwei)');

      // Estimate gas limit
      BigInt gasLimit;
      try {
        gasLimit = await _ethClient.estimateGas(
          sender: sender,
          to: recipient,
          value: amountInWei,
        );
        print('Estimated Gas Limit: $gasLimit');
      } catch (e) {
        print('⚠️ Gas estimation failed, using default: $e');
        gasLimit = BigInt.from(21000);
      }

      // Add 20% buffer
      final gasLimitWithBuffer = (gasLimit.toDouble() * 1.2).round();
      print('Gas Limit with Buffer: $gasLimitWithBuffer');

      // Calculate gas cost
      final gasCost = gasPrice.getInWei * BigInt.from(gasLimitWithBuffer);
      print('Total Gas Cost: $gasCost wei (${web3dart.EtherAmount.inWei(gasCost).getValueInUnit(web3dart.EtherUnit.ether)} ETH)');

      // Check balance
      final totalRequired = amountInWei.getInWei + gasCost;
      print('Total Required: $totalRequired wei (${web3dart.EtherAmount.inWei(totalRequired).getValueInUnit(web3dart.EtherUnit.ether)} ETH)');

      if (balance.getInWei < totalRequired) {
        final shortage = totalRequired - balance.getInWei;
        final shortageEth = web3dart.EtherAmount.inWei(shortage).getValueInUnit(web3dart.EtherUnit.ether);
        throw Exception(
            'Insufficient funds!\n'
                'Need: ${web3dart.EtherAmount.inWei(totalRequired).getValueInUnit(web3dart.EtherUnit.ether)} ETH\n'
                'Have: ${balance.getValueInUnit(web3dart.EtherUnit.ether)} ETH\n'
                'Short: $shortageEth ETH\n\n'
                'Breakdown:\n'
                '• Amount: $amount ETH\n'
                '• Gas: ${web3dart.EtherAmount.inWei(gasCost).getValueInUnit(web3dart.EtherUnit.ether)} ETH'
        );
      }

      // Create and send transaction
      final txData = web3dart.Transaction(
        to: recipient,
        value: amountInWei,
        gasPrice: gasPrice,
        maxGas: gasLimitWithBuffer,
      );

      print('🚀 Sending transaction...');
      final txHash = await _ethClient.sendTransaction(
        credentials,
        txData,
        chainId: _isMainnet ? 1 : 11155111,
      );

      print('✅ Transaction sent! Hash: $txHash');
      return txHash;
    } catch (e) {
      print('❌ Ethereum send error: $e');

      String errorMsg = e.toString();
      if (errorMsg.contains('Could not parse BigInt')) {
        errorMsg = 'Invalid amount format. Please enter a valid number.';
      } else if (errorMsg.contains('insufficient funds')) {
        rethrow;
      }

      throw Exception(errorMsg);
    }
  }

  // Send Filecoin
  Future<String> sendFilecoin({
    required String fromAddress,
    required String toAddress,
    required String privateKey,
    required double amount,
  }) async {
    try {
      final url = _isMainnet ? AppConstants.filMainnetRpc : AppConstants.filTestnetRpc;

      print('📤 Preparing Filecoin transaction...');

      // Convert FIL to attoFIL
      final amountAttoFil = (amount * BigInt.from(10).pow(18).toDouble()).toInt().toString();

      // Get nonce
      final nonceResponse = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'jsonrpc': '2.0',
          'method': 'Filecoin.MpoolGetNonce',
          'params': [fromAddress],
          'id': 1,
        }),
      );

      int nonce = 0;
      if (nonceResponse.statusCode == 200) {
        final nonceData = json.decode(nonceResponse.body);
        nonce = nonceData['result'] ?? 0;
      }

      print('Nonce: $nonce');

      // For production, this requires proper Filecoin message signing
      throw UnimplementedError(
          'Filecoin sending requires filecoin signing library.\n'
              'For testnet: https://faucet.calibration.fildev.network/\n'
              'For implementation: https://github.com/textileio/dart-filecoin\n\n'
              'Message details:\n'
              'From: $fromAddress\n'
              'To: $toAddress\n'
              'Amount: $amount FIL\n'
              'Nonce: $nonce'
      );
    } catch (e) {
      print('❌ Filecoin send error: $e');
      rethrow;
    }
  }

  // Get gas price
  Future<web3dart.EtherAmount> getGasPrice() async {
    try {
      return await _ethClient.getGasPrice();
    } catch (e) {
      print('⚠️ Failed to get gas price, using default');
      return web3dart.EtherAmount.fromUnitAndValue(web3dart.EtherUnit.gwei, 20);
    }
  }

  // Estimate gas
  Future<BigInt> estimateGas({
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

      return await _ethClient.estimateGas(
        sender: from,
        to: to,
        value: value,
      );
    } catch (e) {
      print('⚠️ Gas estimation failed: $e');
      return BigInt.from(21000);
    }
  }

  // Clear cache
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