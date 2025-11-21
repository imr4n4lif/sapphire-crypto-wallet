// COMPLETE REPLACEMENT FOR lib/core/services/blockchain_service.dart
// DELETE THE ENTIRE OLD FILE AND REPLACE WITH THIS

import 'package:http/http.dart' as http;
import 'package:web3dart/web3dart.dart' as web3dart;
import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';
import '../../models/wallet.dart';
import '../constants/app_constants.dart';
import 'package:bitcoin_base/bitcoin_base.dart';
import 'package:crypto/crypto.dart';
import 'package:pointycastle/ecc/curves/secp256k1.dart';
import 'package:pointycastle/ecc/api.dart';
import 'package:pointycastle/api.dart';
import 'package:pointycastle/digests/sha256.dart';
import 'package:pointycastle/macs/hmac.dart';
import 'package:pointycastle/signers/ecdsa_signer.dart';
import 'package:bs58check/bs58check.dart' as bs58;

class BlockchainService {
  static final BlockchainService _instance = BlockchainService._internal();
  factory BlockchainService() => _instance;
  BlockchainService._internal();

  late web3dart.Web3Client _ethClient;
  bool _isMainnet = true;

  DateTime? _lastBtcApiCall;
  DateTime? _lastEthApiCall;
  DateTime? _lastTrxApiCall;
  Duration _apiCallDelay = const Duration(milliseconds: 500);
  static const int _maxRetries = 3;

  final Map<String, _CachedData> _cache = {};
  static const Duration _balanceCacheTTL = Duration(minutes: 2);
  static const Duration _txCacheTTL = Duration(minutes: 3);
  static const Duration _feeCacheTTL = Duration(seconds: 45);

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

  // ============ BITCOIN METHODS ============
  Future<double> getBitcoinBalance(String address) async {
    try {
      final cacheKey = 'btc_balance_$address';
      if (_isCacheValid(cacheKey, _balanceCacheTTL)) {
        return _cache[cacheKey]!.data as double;
      }

      await _respectRateLimit(_lastBtcApiCall);
      _lastBtcApiCall = DateTime.now();

      final url = _isMainnet
          ? 'https://mempool.space/api/address/$address'
          : 'https://mempool.space/testnet4/api/address/$address';

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
          ? 'https://mempool.space/api/address/$address/txs'
          : 'https://mempool.space/testnet4/api/address/$address/txs';

      final response = await _makeHttpRequest(url);

      if (response != null && response.statusCode == 200) {
        final txs = json.decode(response.body) as List;
        final transactions = txs.take(20).map((tx) {
          try {
            return Transaction.fromBlockstreamBitcoin(tx, address);
          } catch (e) {
            return null;
          }
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
        ? 'https://mempool.space/api/address/$address/utxo'
        : 'https://mempool.space/testnet4/api/address/$address/utxo';

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
        ? 'https://mempool.space/api/tx'
        : 'https://mempool.space/testnet4/api/tx';

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

  // ============ ETHEREUM METHODS ============
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
      if (apiKey.isEmpty) return [];

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
          final txList = data['result'] as List;
          final transactions = txList.map((tx) {
            try {
              return Transaction.fromEtherscanV2(tx, address);
            } catch (e) {
              return null;
            }
          }).whereType<Transaction>().toList();

          _cache[cacheKey] = _CachedData(transactions, DateTime.now());
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

  // ============ TRON METHODS ============
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
          final txList = data['data'] as List;
          final transactions = <Transaction>[];

          for (var tx in txList) {
            try {
              final rawData = tx['raw_data'] ?? {};
              final contracts = rawData['contract'] as List? ?? [];

              if (contracts.isEmpty) continue;

              final contract = contracts.first;
              final contractType = contract['type']?.toString() ?? '';

              if (contractType == 'TransferContract') {
                final parsedTx = Transaction.fromTronGrid(tx, address);
                transactions.add(parsedTx);
              }
            } catch (e) {
              continue;
            }
          }

          _cache[cacheKey] = _CachedData(transactions, DateTime.now());
          return transactions;
        }
      }

      return [];
    } catch (e) {
      print('❌ TRX transactions error: $e');
      return _cache['trx_tx_$address']?.data as List<Transaction>? ?? [];
    }
  }

  // ============ FIXED TRON SEND TRANSACTION ============
  Future<String> sendTron({
    required String toAddress,
    required String privateKey,
    required double amount,
  }) async {
    try {
      print('📤 Preparing Tron transaction...');

      if (!toAddress.startsWith('T') || toAddress.length < 30) {
        throw Exception('Invalid Tron address format');
      }

      final amountSun = (amount * 1000000).toInt();
      final baseUrl = _isMainnet ? AppConstants.trxMainnetApi : AppConstants.trxTestnetApi;

      // Get from address from private key
      final privateKeyBytes = _hexToBytes(privateKey);
      final fromAddress = _getTronAddressFromPrivateKey(privateKeyBytes);

      print('From address: $fromAddress');
      print('To address: $toAddress');
      print('Amount: $amountSun SUN');

      // Create transaction
      final createTxUrl = '$baseUrl/wallet/createtransaction';
      final createTxBody = json.encode({
        'to_address': toAddress,
        'owner_address': fromAddress,
        'amount': amountSun,
        'visible': true,
      });

      final headers = <String, String>{'Content-Type': 'application/json'};
      if (AppConstants.tronGridApiKey.isNotEmpty) {
        headers['TRON-PRO-API-KEY'] = AppConstants.tronGridApiKey;
      }

      print('Creating transaction...');
      final createResponse = await _httpClient.post(
        Uri.parse(createTxUrl),
        headers: headers,
        body: createTxBody,
      ).timeout(const Duration(seconds: 15));

      print('Create response: ${createResponse.statusCode}');
      print('Create body: ${createResponse.body}');

      if (createResponse.statusCode != 200) {
        throw Exception('Failed to create transaction: ${createResponse.body}');
      }

      final txData = json.decode(createResponse.body);

      if (txData['Error'] != null) {
        throw Exception('Transaction error: ${txData['Error']}');
      }

      print('✅ Transaction created, signing...');

      // Sign transaction
      final signedTx = _signTronTransaction(txData, privateKeyBytes);

      // Broadcast
      final broadcastUrl = '$baseUrl/wallet/broadcasttransaction';
      print('Broadcasting...');

      final broadcastResponse = await _httpClient.post(
        Uri.parse(broadcastUrl),
        headers: headers,
        body: json.encode(signedTx),
      ).timeout(const Duration(seconds: 15));

      print('Broadcast status: ${broadcastResponse.statusCode}');
      print('Broadcast body: ${broadcastResponse.body}');

      if (broadcastResponse.statusCode == 200) {
        final result = json.decode(broadcastResponse.body);

        if (result['result'] == true) {
          final txHash = result['txid'] ?? signedTx['txID'];
          print('✅ Transaction sent: $txHash');
          _clearCacheForAddress(fromAddress, CoinType.trx);
          return txHash;
        } else {
          final errorMsg = result['message'] ?? result['code'] ?? 'Unknown error';
          throw Exception('Broadcast failed: $errorMsg');
        }
      }

      throw Exception('Broadcast failed: ${broadcastResponse.statusCode}');
    } catch (e) {
      print('❌ Tron error: $e');
      throw Exception('Failed to send Tron: ${_sanitizeErrorMessage(e.toString())}');
    }
  }

  // ============ TRON HELPER METHODS ============
  String _getTronAddressFromPrivateKey(Uint8List privateKeyBytes) {
    try {
      final secp256k1 = ECCurve_secp256k1();
      final G = secp256k1.G;

      final privateKeyBigInt = _bytesToBigInt(privateKeyBytes);
      final publicKeyPoint = (G * privateKeyBigInt)!;

      final publicKeyBytes = publicKeyPoint.getEncoded(false);
      final keyBytes = publicKeyBytes.sublist(1);

      final hash = SHA256Digest().process(keyBytes);
      final addressBytes = hash.sublist(hash.length - 20);
      final addressWithPrefix = Uint8List.fromList([0x41, ...addressBytes]);

      final address = bs58.encode(addressWithPrefix);
      print('✅ Derived address: $address');
      return address;
    } catch (e) {
      print('❌ Error deriving address: $e');
      throw Exception('Failed to derive Tron address');
    }
  }

  Map<String, dynamic> _signTronTransaction(Map<String, dynamic> txData, Uint8List privateKey) {
    try {
      final rawDataHex = txData['raw_data_hex'] as String?;
      if (rawDataHex == null || rawDataHex.isEmpty) {
        throw Exception('No raw_data_hex');
      }

      final txBytes = _hexToBytes(rawDataHex);
      final hash = SHA256Digest().process(txBytes);
      final signature = _ecdsaSign(hash, privateKey);

      final signedTx = Map<String, dynamic>.from(txData);
      signedTx['signature'] = [_bytesToHex(signature)];

      return signedTx;
    } catch (e) {
      print('❌ Signing error: $e');
      throw Exception('Failed to sign: $e');
    }
  }

  Uint8List _ecdsaSign(Uint8List messageHash, Uint8List privateKey) {
    try {
      final secp256k1 = ECCurve_secp256k1();
      final n = secp256k1.n;
      final G = secp256k1.G;

      final signer = ECDSASigner(null, HMac(SHA256Digest(), 64));
      final privateKeyBigInt = _bytesToBigInt(privateKey);
      final domainParams = ECDomainParameters('secp256k1');
      final privKey = ECPrivateKey(privateKeyBigInt, domainParams);

      signer.init(true, PrivateKeyParameter(privKey));
      final sig = signer.generateSignature(messageHash) as ECSignature;

      final rBytes = _bigIntToBytes(sig.r, 32);
      final sBytes = _bigIntToBytes(sig.s, 32);

      // Calculate recovery ID
      int v = 0;
      final publicKeyPoint = (G * privateKeyBigInt)!;

      for (int i = 0; i < 4; i++) {
        try {
          final recovered = _recoverPublicKey(messageHash, sig.r, sig.s, i, secp256k1);
          if (recovered != null &&
              _bytesToHex(recovered.getEncoded(false)) == _bytesToHex(publicKeyPoint.getEncoded(false))) {
            v = i;
            break;
          }
        } catch (e) {
          continue;
        }
      }

      return Uint8List.fromList([...rBytes, ...sBytes, v]);
    } catch (e) {
      print('❌ ECDSA error: $e');
      throw Exception('ECDSA failed: $e');
    }
  }

  ECPoint? _recoverPublicKey(Uint8List hash, BigInt r, BigInt s, int recoveryId, ECCurve_secp256k1 params) {
    try {
      final n = params.n;
      final G = params.G;

      final i = BigInt.from(recoveryId ~/ 2);
      final x = r + (i * n);

      // Get the prime from secp256k1
      final prime = BigInt.parse(
          'FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F',
          radix: 16
      );

      if (x.compareTo(prime) >= 0) return null;

      // Decompress point
      final yTilde = recoveryId & 1;
      final R = _decompressPoint(x, yTilde == 1, prime);
      if (R == null) return null;

      // Check if R * n is infinity
      final nR = R * n;
      if (nR == null || !nR.isInfinity) return null;

      final e = _bytesToBigInt(hash);
      final eInv = (-e) % n;
      final rInv = r.modInverse(n);
      final srInv = (rInv * s) % n;
      final eInvrInv = (rInv * eInv) % n;

      final q = (G * eInvrInv)! + (R * srInv)!;
      return q;
    } catch (e) {
      return null;
    }
  }

  ECPoint? _decompressPoint(BigInt x, bool yBit, BigInt prime) {
    try {
      final secp256k1 = ECCurve_secp256k1();

      // y^2 = x^3 + 7 (mod p) for secp256k1
      final a = BigInt.from(0);
      final b = BigInt.from(7);

      final x3 = (x * x * x) % prime;
      final ax = (a * x) % prime;
      final ySquared = (x3 + ax + b) % prime;

      // Calculate y using modular square root
      var y = _modSqrt(ySquared, prime);
      if (y == null) return null;

      // Check if y matches the desired bit
      final yIsOdd = (y & BigInt.one) == BigInt.one;
      if (yIsOdd != yBit) {
        y = prime - y;
      }

      // Create the point
      return secp256k1.curve.createPoint(x, y);
    } catch (e) {
      return null;
    }
  }

  // Modular square root using Tonelli-Shanks algorithm
  BigInt? _modSqrt(BigInt a, BigInt p) {
    if (a == BigInt.zero) return BigInt.zero;
    if (p == BigInt.two) return a;

    // Check if a is a quadratic residue
    if (a.modPow((p - BigInt.one) ~/ BigInt.two, p) != BigInt.one) {
      return null;
    }

    // For secp256k1, p ≡ 3 (mod 4), so we can use the simple formula
    if ((p % BigInt.from(4)) == BigInt.from(3)) {
      return a.modPow((p + BigInt.one) ~/ BigInt.from(4), p);
    }

    // General Tonelli-Shanks algorithm (not needed for secp256k1)
    return null;
  }

  // ============ UTILITY METHODS ============
  BigInt _bytesToBigInt(Uint8List bytes) {
    BigInt result = BigInt.zero;
    for (int i = 0; i < bytes.length; i++) {
      result = (result << 8) | BigInt.from(bytes[i]);
    }
    return result;
  }

  Uint8List _bigIntToBytes(BigInt number, int length) {
    final bytes = <int>[];
    var num = number;

    while (num > BigInt.zero) {
      bytes.insert(0, (num & BigInt.from(0xff)).toInt());
      num = num >> 8;
    }

    while (bytes.length < length) {
      bytes.insert(0, 0);
    }

    return Uint8List.fromList(bytes);
  }

  Uint8List _hexToBytes(String hex) {
    if (hex.startsWith('0x')) hex = hex.substring(2);
    return Uint8List.fromList(
        List.generate(hex.length ~/ 2, (i) =>
            int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16))
    );
  }

  String _bytesToHex(Uint8List bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join('');
  }

  Future<http.Response?> _makeHttpRequest(String url, {int attempt = 1}) async {
    try {
      final response = await _httpClient.get(Uri.parse(url))
          .timeout(Duration(seconds: 8 + (attempt * 2)));

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