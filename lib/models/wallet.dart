import '../core/constants/app_constants.dart';

class WalletData {
  final String mnemonic;
  final String btcAddress;
  final String btcPrivateKey;
  final String ethAddress;
  final String ethPrivateKey;
  final String filAddress;
  final String filPrivateKey;

  WalletData({
    required this.mnemonic,
    required this.btcAddress,
    required this.btcPrivateKey,
    required this.ethAddress,
    required this.ethPrivateKey,
    required this.filAddress,
    required this.filPrivateKey,
  });
}

class CoinBalance {
  final CoinType coinType;
  final double balance;
  final double usdValue;
  final double pricePerCoin;
  final double change24h;

  CoinBalance({
    required this.coinType,
    required this.balance,
    required this.usdValue,
    required this.pricePerCoin,
    required this.change24h,
  });

  CoinBalance copyWith({
    CoinType? coinType,
    double? balance,
    double? usdValue,
    double? pricePerCoin,
    double? change24h,
  }) {
    return CoinBalance(
      coinType: coinType ?? this.coinType,
      balance: balance ?? this.balance,
      usdValue: usdValue ?? this.usdValue,
      pricePerCoin: pricePerCoin ?? this.pricePerCoin,
      change24h: change24h ?? this.change24h,
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

  factory Transaction.fromJson(Map<String, dynamic> json, CoinType coinType, String myAddress) {
    return Transaction(
      hash: json['hash'] ?? json['txid'] ?? '',
      coinType: coinType,
      from: json['from'] ?? json['inputs']?[0]?['addresses']?[0] ?? '',
      to: json['to'] ?? json['outputs']?[0]?['addresses']?[0] ?? '',
      amount: _parseAmount(json, coinType),
      timestamp: _parseTimestamp(json),
      confirmations: json['confirmations'] ?? 0,
      fee: _parseFee(json, coinType),
      status: _getStatus(json['confirmations'] ?? 0, coinType),
      isIncoming: _isIncoming(json, myAddress),
    );
  }

  static double _parseAmount(Map<String, dynamic> json, CoinType coinType) {
    if (coinType == CoinType.btc) {
      int satoshis = json['total'] ?? json['value'] ?? 0;
      return satoshis / 100000000;
    } else if (coinType == CoinType.eth) {
      String wei = json['value'] ?? '0';
      return double.parse(wei) / 1e18;
    } else {
      String attoFil = json['value'] ?? '0';
      return double.parse(attoFil) / 1e18;
    }
  }

  static DateTime _parseTimestamp(Map<String, dynamic> json) {
    if (json['received'] != null) {
      return DateTime.parse(json['received']);
    } else if (json['timestamp'] != null) {
      return DateTime.fromMillisecondsSinceEpoch(json['timestamp'] * 1000);
    }
    return DateTime.now();
  }

  static double _parseFee(Map<String, dynamic> json, CoinType coinType) {
    if (coinType == CoinType.btc) {
      int satoshis = json['fees'] ?? 0;
      return satoshis / 100000000;
    } else if (coinType == CoinType.eth) {
      String wei = json['gasUsed'] ?? '0';
      return double.parse(wei) / 1e18;
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

  static bool _isIncoming(Map<String, dynamic> json, String myAddress) {
    String to = json['to'] ?? json['outputs']?[0]?['addresses']?[0] ?? '';
    return to.toLowerCase() == myAddress.toLowerCase();
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