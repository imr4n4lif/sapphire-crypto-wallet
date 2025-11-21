import '../core/constants/app_constants.dart';
import 'dart:typed_data';
import 'package:bs58check/bs58check.dart' as bs58check;
class WalletData {
  final String mnemonic;
  final String btcAddress;
  final String btcPrivateKey;
  final String ethAddress;
  final String ethPrivateKey;
  final String trxAddress;
  final String trxPrivateKey;
  final String? name;

  WalletData({
    required this.mnemonic,
    required this.btcAddress,
    required this.btcPrivateKey,
    required this.ethAddress,
    required this.ethPrivateKey,
    required this.trxAddress,
    required this.trxPrivateKey,
    this.name,
  });

  WalletData copyWith({String? name}) {
    return WalletData(
      mnemonic: mnemonic,
      btcAddress: btcAddress,
      btcPrivateKey: btcPrivateKey,
      ethAddress: ethAddress,
      ethPrivateKey: ethPrivateKey,
      trxAddress: trxAddress,
      trxPrivateKey: trxPrivateKey,
      name: name ?? this.name,
    );
  }
}

class CoinBalance {
  final CoinType coinType;
  final double balance;
  final double usdValue;
  final double pricePerCoin;
  final double change24h;
  final List<PricePoint> priceHistory;

  CoinBalance({
    required this.coinType,
    required this.balance,
    required this.usdValue,
    required this.pricePerCoin,
    required this.change24h,
    this.priceHistory = const [],
  });

  CoinBalance copyWith({
    CoinType? coinType,
    double? balance,
    double? usdValue,
    double? pricePerCoin,
    double? change24h,
    List<PricePoint>? priceHistory,
  }) {
    return CoinBalance(
      coinType: coinType ?? this.coinType,
      balance: balance ?? this.balance,
      usdValue: usdValue ?? this.usdValue,
      pricePerCoin: pricePerCoin ?? this.pricePerCoin,
      change24h: change24h ?? this.change24h,
      priceHistory: priceHistory ?? this.priceHistory,
    );
  }
}

class Transaction {
  final String hash;
  final CoinType coinType;
  final String from;
  final String to;
  final double amount;
  final DateTime timestamp;
  final int confirmations;
  final double fee;
  final TransactionStatus status;
  final bool isIncoming;
  final String? blockHash;
  final int? blockHeight;

  Transaction({
    required this.hash,
    required this.coinType,
    required this.from,
    required this.to,
    required this.amount,
    required this.timestamp,
    required this.confirmations,
    required this.fee,
    required this.status,
    required this.isIncoming,
    this.blockHash,
    this.blockHeight,
  });

  // FIXED: Bitcoin transaction parser with proper perspective
  factory Transaction.fromBlockstreamBitcoin(Map<String, dynamic> json, String myAddress) {
    try {
      final txid = json['txid'] ?? '';
      final vin = json['vin'] as List? ?? [];
      final vout = json['vout'] as List? ?? [];

      print('🔍 Parsing BTC TX: ${txid.substring(0, 10)}... for MY address: $myAddress');

      // Check if this is incoming or outgoing from MY perspective
      bool isIncoming = false;
      double myAmount = 0.0;
      String fromAddress = '';
      String toAddress = '';

      // Get sender address
      if (vin.isNotEmpty && vin[0]['prevout'] != null) {
        fromAddress = vin[0]['prevout']['scriptpubkey_address'] ?? '';
      }

      // Check outputs to see if I'm receiving
      for (var output in vout) {
        final addr = output['scriptpubkey_address'] ?? '';
        final value = (output['value'] ?? 0) / 100000000.0;

        if (addr.toLowerCase() == myAddress.toLowerCase()) {
          isIncoming = true;
          myAmount += value;
          toAddress = addr;
        } else if (toAddress.isEmpty) {
          toAddress = addr; // Set as default recipient
        }
      }

      // If not incoming, I'm sending - calculate amount sent
      if (!isIncoming) {
        // Calculate total sent from my outputs
        for (var input in vin) {
          if (input['prevout'] != null) {
            final addr = input['prevout']['scriptpubkey_address'] ?? '';
            if (addr.toLowerCase() == myAddress.toLowerCase()) {
              final value = (input['prevout']['value'] ?? 0) / 100000000.0;
              myAmount += value;
            }
          }
        }

        // Subtract change returned to me
        for (var output in vout) {
          final addr = output['scriptpubkey_address'] ?? '';
          if (addr.toLowerCase() == myAddress.toLowerCase()) {
            final value = (output['value'] ?? 0) / 100000000.0;
            myAmount -= value;
          }
        }
      }

      final fee = (json['fee'] ?? 0) / 100000000.0;
      final confirmed = json['status']?['confirmed'] ?? false;
      final blockHeight = json['status']?['block_height'];
      final blockHash = json['status']?['block_hash'];
      final blockTime = json['status']?['block_time'];

      final timestamp = blockTime != null
          ? DateTime.fromMillisecondsSinceEpoch(blockTime * 1000)
          : DateTime.now();

      print('   ✅ BTC TX: ${isIncoming ? "INCOMING ✅" : "OUTGOING ❌"} ${myAmount.toStringAsFixed(8)} BTC');

      return Transaction(
        hash: txid,
        coinType: CoinType.btc,
        from: fromAddress,
        to: toAddress,
        amount: myAmount.abs(), // Use absolute value
        timestamp: timestamp,
        confirmations: confirmed ? 6 : 0,
        fee: fee,
        status: confirmed ? TransactionStatus.confirmed : TransactionStatus.pending,
        isIncoming: isIncoming,
        blockHash: blockHash,
        blockHeight: blockHeight,
      );
    } catch (e) {
      print('❌ Error parsing Bitcoin transaction: $e');
      rethrow;
    }
  }

  // FIXED: Etherscan V2 API Parser with proper perspective
  factory Transaction.fromEtherscanV2(Map<String, dynamic> json, String myAddress) {
    try {
      final hash = json['hash']?.toString() ?? '';
      final from = json['from']?.toString().toLowerCase() ?? '';
      final to = json['to']?.toString().toLowerCase() ?? '';
      final myAddr = myAddress.toLowerCase();

      print('🔍 Parsing ETH TX: ${hash.substring(0, 10)}... for MY address: $myAddr');

      final valueStr = json['value']?.toString() ?? '0';
      final valueBigInt = BigInt.tryParse(valueStr) ?? BigInt.zero;
      final amount = valueBigInt / BigInt.from(10).pow(18);

      final timeStampStr = json['timeStamp']?.toString() ?? '0';
      final ts = int.tryParse(timeStampStr) ?? 0;
      final timestamp = DateTime.fromMillisecondsSinceEpoch(ts * 1000);

      final blockNumber = int.tryParse(json['blockNumber']?.toString() ?? '0') ?? 0;
      final confirmations = blockNumber > 0 ? 15 : 0;

      double fee = 0.0;
      try {
        final gasUsedStr = json['gasUsed']?.toString() ?? '0';
        final gasPriceStr = json['gasPrice']?.toString() ?? '0';

        final gasUsed = BigInt.tryParse(gasUsedStr) ?? BigInt.zero;
        final gasPrice = BigInt.tryParse(gasPriceStr) ?? BigInt.zero;

        final feeBigInt = gasUsed * gasPrice;
        fee = feeBigInt / BigInt.from(10).pow(18);
      } catch (e) {
        print('   ⚠️ Error calculating fee: $e');
      }

      final isError = json['isError']?.toString() == '1';
      final txReceiptStatus = json['txreceipt_status']?.toString() ?? '1';

      TransactionStatus status;
      if (isError || txReceiptStatus == '0') {
        status = TransactionStatus.failed;
      } else if (confirmations == 0) {
        status = TransactionStatus.pending;
      } else if (confirmations < AppConstants.ethConfirmations) {
        status = TransactionStatus.confirming;
      } else {
        status = TransactionStatus.confirmed;
      }

      final isIncoming = to == myAddr;

      print('   ✅ ETH TX: ${isIncoming ? "INCOMING ✅" : "OUTGOING ❌"} ${amount.toDouble().toStringAsFixed(6)} ETH');

      return Transaction(
        hash: hash,
        coinType: CoinType.eth,
        from: from,
        to: to,
        amount: amount.toDouble(),
        timestamp: timestamp,
        confirmations: confirmations,
        fee: fee,
        status: status,
        isIncoming: isIncoming,
        blockHash: json['blockHash']?.toString(),
        blockHeight: blockNumber,
      );
    } catch (e) {
      print('❌ Error parsing Etherscan V2 transaction: $e');
      rethrow;
    }
  }

  // FIXED: Tron transaction parsing with PROPER address conversion
  factory Transaction.fromTronGrid(Map<String, dynamic> json, String myAddress) {
    try {
      final txID = json['txID']?.toString() ?? '';
      final blockTimestamp = json['block_timestamp'] ?? 0;
      final timestamp = DateTime.fromMillisecondsSinceEpoch(blockTimestamp);

      print('🔍 Parsing TRX TX: ${txID.substring(0, 10)}...');
      print('   MY Address (base58): $myAddress');

      final rawData = json['raw_data'] ?? {};
      final contract = (rawData['contract'] as List?)?.first ?? {};
      final value = contract['parameter']?['value'] ?? {};

      // TronGrid returns addresses in HEX format (41xxx...)
      String fromHex = value['owner_address']?.toString() ?? '';
      String toHex = value['to_address']?.toString() ?? '';
      final amountSun = value['amount'] ?? 0;
      final amount = amountSun / 1000000.0;

      print('   From (hex): $fromHex');
      print('   To (hex): $toHex');
      print('   Amount: $amount TRX');

      final ret = (json['ret'] as List?)?.first ?? {};
      final contractRet = ret['contractRet']?.toString() ?? 'SUCCESS';
      final fee = (ret['fee'] ?? 0) / 1000000.0;

      // CRITICAL FIX: Use proper base58 to hex conversion
      // Import: import '../core/utils/tron_address_converter.dart';
      final myAddressHex = _base58ToHex(myAddress);

      print('   My address (hex): $myAddressHex');

      // Compare using hex format (case-insensitive)
      final isIncoming = toHex.toLowerCase() == myAddressHex.toLowerCase();

      print('   Comparison: toHex($toHex) == myHex($myAddressHex)');
      print('   ✅ TRX TX: ${isIncoming ? "INCOMING ✅" : "OUTGOING ❌"} $amount TRX');

      // Convert hex addresses to base58 for display
      String fromDisplay = _hexToBase58(fromHex);
      String toDisplay = _hexToBase58(toHex);

      return Transaction(
        hash: txID,
        coinType: CoinType.trx,
        from: fromDisplay,
        to: toDisplay,
        amount: amount,
        timestamp: timestamp,
        confirmations: AppConstants.trxConfirmations,
        fee: fee,
        status: contractRet == 'SUCCESS'
            ? TransactionStatus.confirmed
            : TransactionStatus.failed,
        isIncoming: isIncoming,
        blockHeight: json['blockNumber'],
      );
    } catch (e) {
      print('❌ Error parsing Tron transaction: $e');
      rethrow;
    }
  }

  // Helper: Convert Tron base58 address to hex using bs58check
  static String _base58ToHex(String base58Address) {
    try {
      if (base58Address.startsWith('41')) {
        return base58Address.toLowerCase();
      }

      // Use bs58check to decode
      final decoded = bs58check.decode(base58Address);
      final hexString = decoded.map((b) => b.toRadixString(16).padLeft(2, '0')).join('');

      print('   🔄 Converted: $base58Address -> $hexString');
      return hexString.toLowerCase();
    } catch (e) {
      print('   ⚠️ Base58 decode failed: $e, using fallback');
      return base58Address.toLowerCase();
    }
  }

  // Helper: Convert hex to base58 using bs58check
  static String _hexToBase58(String hexAddress) {
    try {
      if (!hexAddress.startsWith('41')) {
        return hexAddress;
      }

      final bytes = <int>[];
      for (int i = 0; i < hexAddress.length; i += 2) {
        bytes.add(int.parse(hexAddress.substring(i, i + 2), radix: 16));
      }

      final base58 = bs58check.encode(Uint8List.fromList(bytes));
      return base58;
    } catch (e) {
      print('   ⚠️ Base58 encode failed: $e');
      return hexAddress;
    }
  }
}

enum TransactionStatus {
  pending,
  confirming,
  confirmed,
  failed,
}

class PriceData {
  final double price;
  final double change24h;
  final List<PricePoint> history;

  PriceData({
    required this.price,
    required this.change24h,
    required this.history,
  });

  factory PriceData.fromJson(Map<String, dynamic> json) {
    return PriceData(
      price: (json['current_price'] ?? 0.0).toDouble(),
      change24h: (json['price_change_percentage_24h'] ?? 0.0).toDouble(),
      history: [],
    );
  }
}

class PricePoint {
  final DateTime timestamp;
  final double price;

  PricePoint({required this.timestamp, required this.price});
}