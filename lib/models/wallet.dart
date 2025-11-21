import '../core/constants/app_constants.dart';

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

  // Bitcoin transaction parser (Blockstream API)
  factory Transaction.fromBlockstreamBitcoin(Map<String, dynamic> json, String myAddress) {
    try {
      final txid = json['txid'] ?? '';
      final vin = json['vin'] as List? ?? [];
      final vout = json['vout'] as List? ?? [];

      String fromAddress = '';
      if (vin.isNotEmpty && vin[0]['prevout'] != null) {
        fromAddress = vin[0]['prevout']['scriptpubkey_address'] ?? '';
      }

      String toAddress = '';
      double amount = 0.0;

      for (var output in vout) {
        final addr = output['scriptpubkey_address'] ?? '';
        if (addr.isNotEmpty && addr != fromAddress) {
          toAddress = addr;
          amount = (output['value'] ?? 0) / 100000000.0;
          break;
        }
      }

      if (toAddress.isEmpty && vout.isNotEmpty) {
        toAddress = vout[0]['scriptpubkey_address'] ?? '';
        amount = (vout[0]['value'] ?? 0) / 100000000.0;
      }

      final fee = (json['fee'] ?? 0) / 100000000.0;
      final confirmed = json['status']?['confirmed'] ?? false;
      final blockHeight = json['status']?['block_height'];
      final blockHash = json['status']?['block_hash'];
      final blockTime = json['status']?['block_time'];

      final timestamp = blockTime != null
          ? DateTime.fromMillisecondsSinceEpoch(blockTime * 1000)
          : DateTime.now();

      return Transaction(
        hash: txid,
        coinType: CoinType.btc,
        from: fromAddress,
        to: toAddress,
        amount: amount,
        timestamp: timestamp,
        confirmations: confirmed ? 6 : 0,
        fee: fee,
        status: confirmed ? TransactionStatus.confirmed : TransactionStatus.pending,
        isIncoming: toAddress.toLowerCase() == myAddress.toLowerCase(),
        blockHash: blockHash,
        blockHeight: blockHeight,
      );
    } catch (e) {
      print('❌ Error parsing Bitcoin transaction: $e');
      rethrow;
    }
  }

  // Etherscan V2 API Parser
  factory Transaction.fromEtherscanV2(Map<String, dynamic> json, String myAddress) {
    try {
      final hash = json['hash']?.toString() ?? '';
      final from = json['from']?.toString() ?? '';
      final to = json['to']?.toString() ?? '';

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
        print('⚠️ Error calculating fee: $e');
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
        blockHash: json['blockHash']?.toString(),
        blockHeight: blockNumber,
      );
    } catch (e) {
      print('❌ Error parsing Etherscan V2 transaction: $e');
      rethrow;
    }
  }

  // Tron transaction parsing (TronGrid API)
  factory Transaction.fromTronGrid(Map<String, dynamic> json, String myAddress) {
    try {
      final txID = json['txID']?.toString() ?? '';
      final blockTimestamp = json['block_timestamp'] ?? 0;
      final timestamp = DateTime.fromMillisecondsSinceEpoch(blockTimestamp);

      final rawData = json['raw_data'] ?? {};
      final contract = (rawData['contract'] as List?)?.first ?? {};
      final value = contract['parameter']?['value'] ?? {};

      final from = value['owner_address']?.toString() ?? '';
      final to = value['to_address']?.toString() ?? '';
      final amountSun = value['amount'] ?? 0;
      final amount = amountSun / 1000000.0; // Convert SUN to TRX

      final ret = (json['ret'] as List?)?.first ?? {};
      final contractRet = ret['contractRet']?.toString() ?? 'SUCCESS';
      final fee = (ret['fee'] ?? 0) / 1000000.0;

      final isIncoming = to.toLowerCase() == myAddress.toLowerCase();

      return Transaction(
        hash: txID,
        coinType: CoinType.trx,
        from: from,
        to: to,
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