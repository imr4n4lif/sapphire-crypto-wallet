import 'package:crypto_wallet/core/constants/app_constants.dart';

class WalletData {
  final String mnemonic;
  final String btcAddress;
  final String btcPrivateKey;
  final String ethAddress;
  final String ethPrivateKey;
  final String filAddress;
  final String filPrivateKey;
  final String? name;

  WalletData({
    required this.mnemonic,
    required this.btcAddress,
    required this.btcPrivateKey,
    required this.ethAddress,
    required this.ethPrivateKey,
    required this.filAddress,
    required this.filPrivateKey,
    this.name,
  });

  WalletData copyWith({String? name}) {
    return WalletData(
      mnemonic: mnemonic,
      btcAddress: btcAddress,
      btcPrivateKey: btcPrivateKey,
      ethAddress: ethAddress,
      ethPrivateKey: ethPrivateKey,
      filAddress: filAddress,
      filPrivateKey: filPrivateKey,
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
  });

  // Bitcoin transaction parsing
  factory Transaction.fromJson(Map<String, dynamic> json, CoinType coinType, String myAddress) {
    try {
      if (coinType == CoinType.btc) {
        final inputs = json['inputs'] as List? ?? [];
        final outputs = json['outputs'] as List? ?? [];

        String fromAddress = '';
        if (inputs.isNotEmpty && inputs[0]['addresses'] != null) {
          final addresses = inputs[0]['addresses'] as List;
          if (addresses.isNotEmpty) {
            fromAddress = addresses[0].toString();
          }
        }

        String toAddress = '';
        double amount = 0.0;

        for (var output in outputs) {
          final addresses = output['addresses'] as List? ?? [];
          if (addresses.isNotEmpty) {
            final addr = addresses[0].toString();
            if (addr != fromAddress) {
              toAddress = addr;
              final value = output['value'] ?? 0;
              amount = value / 100000000.0;
              break;
            }
          }
        }

        if (toAddress.isEmpty && outputs.isNotEmpty) {
          final addresses = outputs[0]['addresses'] as List? ?? [];
          if (addresses.isNotEmpty) {
            toAddress = addresses[0].toString();
            final value = outputs[0]['value'] ?? 0;
            amount = value / 100000000.0;
          }
        }

        return Transaction(
          hash: json['hash'] ?? json['txid'] ?? '',
          coinType: coinType,
          from: fromAddress,
          to: toAddress,
          amount: amount,
          timestamp: _parseTimestamp(json),
          confirmations: json['confirmations'] ?? 0,
          fee: _parseFee(json, coinType),
          status: _getStatus(json['confirmations'] ?? 0, coinType),
          isIncoming: toAddress.toLowerCase() == myAddress.toLowerCase(),
        );
      }

      throw Exception('Unsupported coin type for this parser');
    } catch (e) {
      print('❌ Error parsing transaction: $e');
      rethrow;
    }
  }

  // Etherscan V2 API Parser - FULLY UPDATED
  factory Transaction.fromEtherscanV2(Map<String, dynamic> json, String myAddress) {
    try {
      final hash = json['hash']?.toString() ?? '';
      final from = json['from']?.toString() ?? '';
      final to = json['to']?.toString() ?? '';

      // Parse value (in wei)
      final valueStr = json['value']?.toString() ?? '0';
      final valueBigInt = BigInt.tryParse(valueStr) ?? BigInt.zero;
      final amount = valueBigInt / BigInt.from(10).pow(18);

      // Parse timestamp
      final timeStampStr = json['timeStamp']?.toString() ?? '0';
      final ts = int.tryParse(timeStampStr) ?? 0;
      final timestamp = DateTime.fromMillisecondsSinceEpoch(ts * 1000);

      // Parse confirmations
      final blockNumber = int.tryParse(json['blockNumber']?.toString() ?? '0') ?? 0;
      final confirmations = blockNumber > 0 ? 15 : 0;

      // Calculate gas fee
      double fee = 0.0;
      try {
        final gasUsedStr = json['gasUsed']?.toString() ?? '0';
        final gasPriceStr = json['gasPrice']?.toString() ?? '0';

        final gasUsed = BigInt.tryParse(gasUsedStr) ?? BigInt.zero;
        final gasPrice = BigInt.tryParse(gasPriceStr) ?? BigInt.zero;

        final feeBigInt = gasUsed * gasPrice;
        fee = feeBigInt / BigInt.from(10).pow(18);
      } catch (e) {
        print('⚠️ Error calculating fee: $e');
      }

      // Check transaction status
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

      final isIncoming = to.toLowerCase() == myAddress.toLowerCase();

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
      );
    } catch (e) {
      print('❌ Error parsing Etherscan V2 transaction: $e');
      rethrow;
    }
  }

  // Filecoin transaction parsing - NEW
  factory Transaction.fromFilecoin(Map<String, dynamic> json, String myAddress) {
    try {
      final message = json['Message'] ?? json;

      // Parse CID
      String hash = '';
      if (json['Cid'] != null) {
        hash = json['Cid'] is Map ? (json['Cid']['/'] ?? '') : json['Cid'].toString();
      } else if (json['CID'] != null) {
        hash = json['CID'] is Map ? (json['CID']['/'] ?? '') : json['CID'].toString();
      }

      // Parse value (from attoFIL to FIL)
      double amount = 0.0;
      try {
        final valueStr = message['Value']?.toString() ?? '0';
        final valueBigInt = BigInt.tryParse(valueStr) ?? BigInt.zero;
        amount = (valueBigInt / BigInt.from(10).pow(18)).toDouble();
      } catch (e) {
        print('⚠️ Error parsing Filecoin amount: $e');
      }

      // Parse addresses
      final from = message['From']?.toString() ?? '';
      final to = message['To']?.toString() ?? '';

      // Parse height for timestamp approximation (10 blocks per 5 minutes)
      int height = 0;
      if (json['Height'] != null) {
        height = int.tryParse(json['Height'].toString()) ?? 0;
      }

      // Approximate timestamp (Filecoin epoch time)
      final timestamp = height > 0
          ? DateTime.now().subtract(Duration(minutes: (height * 30) ~/ 60))
          : DateTime.now();

      return Transaction(
        hash: hash,
        coinType: CoinType.fil,
        from: from,
        to: to,
        amount: amount,
        timestamp: timestamp,
        confirmations: AppConstants.filConfirmations,
        fee: 0.0,
        status: TransactionStatus.confirmed,
        isIncoming: to.toLowerCase() == myAddress.toLowerCase(),
      );
    } catch (e) {
      print('❌ Error parsing Filecoin transaction: $e');
      rethrow;
    }
  }

  static DateTime _parseTimestamp(Map<String, dynamic> json) {
    try {
      if (json['received'] != null) {
        return DateTime.parse(json['received']);
      } else if (json['confirmed'] != null) {
        return DateTime.parse(json['confirmed']);
      } else if (json['timestamp'] != null) {
        final timestamp = json['timestamp'];
        if (timestamp is int) {
          return DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
        } else if (timestamp is String) {
          return DateTime.parse(timestamp);
        }
      } else if (json['timeStamp'] != null) {
        final ts = int.tryParse(json['timeStamp'].toString()) ?? 0;
        return DateTime.fromMillisecondsSinceEpoch(ts * 1000);
      }
    } catch (e) {
      print('⚠️ Error parsing timestamp: $e');
    }
    return DateTime.now();
  }

  static double _parseFee(Map<String, dynamic> json, CoinType coinType) {
    try {
      if (coinType == CoinType.btc) {
        int satoshis = json['fees'] ?? 0;
        return satoshis / 100000000.0;
      } else if (coinType == CoinType.eth) {
        final gasUsed = json['gasUsed']?.toString() ?? '0';
        final gasPrice = json['gasPrice']?.toString() ?? '0';
        final fee = (double.tryParse(gasUsed) ?? 0.0) * (double.tryParse(gasPrice) ?? 0.0);
        return fee / 1e18;
      }
    } catch (e) {
      print('⚠️ Error parsing fee: $e');
    }
    return 0.0;
  }

  static TransactionStatus _getStatus(int confirmations, CoinType coinType) {
    int required = coinType == CoinType.btc ? AppConstants.btcConfirmations :
    coinType == CoinType.eth ? AppConstants.ethConfirmations :
    AppConstants.filConfirmations;

    if (confirmations == 0) return TransactionStatus.pending;
    if (confirmations >= required) return TransactionStatus.confirmed;
    return TransactionStatus.confirming;
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