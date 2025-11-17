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
    try {
      // Bitcoin transaction parsing
      if (coinType == CoinType.btc) {
        final inputs = json['inputs'] as List? ?? [];
        final outputs = json['outputs'] as List? ?? [];

        // Get sender address (from first input)
        String fromAddress = '';
        if (inputs.isNotEmpty && inputs[0]['addresses'] != null) {
          final addresses = inputs[0]['addresses'] as List;
          if (addresses.isNotEmpty) {
            fromAddress = addresses[0].toString();
          }
        }

        // Get recipient address and amount
        String toAddress = '';
        double amount = 0.0;

        for (var output in outputs) {
          final addresses = output['addresses'] as List? ?? [];
          if (addresses.isNotEmpty) {
            final addr = addresses[0].toString();
            // Find the output that's not a change address
            if (addr != fromAddress) {
              toAddress = addr;
              final value = output['value'] ?? 0;
              amount = value / 100000000.0; // Convert satoshis to BTC
              break;
            }
          }
        }

        // If we couldn't determine recipient, use first output
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

      // Ethereum transaction parsing (if implemented with Etherscan API)
      return Transaction(
        hash: json['hash'] ?? json['txid'] ?? '',
        coinType: coinType,
        from: json['from'] ?? '',
        to: json['to'] ?? '',
        amount: _parseAmount(json, coinType),
        timestamp: _parseTimestamp(json),
        confirmations: json['confirmations'] ?? 0,
        fee: _parseFee(json, coinType),
        status: _getStatus(json['confirmations'] ?? 0, coinType),
        isIncoming: _isIncoming(json, myAddress),
      );
    } catch (e) {
      print('❌ Error parsing transaction: $e');
      rethrow;
    }
  }

  static double _parseAmount(Map<String, dynamic> json, CoinType coinType) {
    try {
      if (coinType == CoinType.btc) {
        // For Bitcoin, sum all outputs (simplified)
        final outputs = json['outputs'] as List? ?? [];
        int totalSatoshis = 0;
        for (var output in outputs) {
          totalSatoshis += (output['value'] ?? 0) as int;
        }
        return totalSatoshis / 100000000.0;
      } else if (coinType == CoinType.eth) {
        String wei = json['value']?.toString() ?? '0';
        return double.parse(wei) / 1e18;
      } else {
        String attoFil = json['value']?.toString() ?? '0';
        return double.parse(attoFil) / 1e18;
      }
    } catch (e) {
      print('⚠️ Error parsing amount: $e');
      return 0.0;
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

  static bool _isIncoming(Map<String, dynamic> json, String myAddress) {
    try {
      String to = json['to']?.toString() ?? '';

      // Check outputs for Bitcoin
      if (json['outputs'] != null) {
        final outputs = json['outputs'] as List;
        for (var output in outputs) {
          final addresses = output['addresses'] as List? ?? [];
          for (var addr in addresses) {
            if (addr.toString().toLowerCase() == myAddress.toLowerCase()) {
              return true;
            }
          }
        }
        return false;
      }

      return to.toLowerCase() == myAddress.toLowerCase();
    } catch (e) {
      print('⚠️ Error checking if incoming: $e');
      return false;
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