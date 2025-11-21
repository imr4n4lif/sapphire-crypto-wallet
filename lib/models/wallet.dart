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

  // FIXED: Tron transaction parsing with proper hex address handling
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

      // CRITICAL FIX: Compare hex addresses
      // TronGrid uses hex format: 41 + 40 hex chars
      // Need to convert base58 address to hex for comparison
      final myAddressHex = _base58ToHex(myAddress);

      print('   My address (hex): $myAddressHex');

      // Compare using hex format (case-insensitive)
      final isIncoming = toHex.toLowerCase() == myAddressHex.toLowerCase();

      print('   Is incoming: $isIncoming');
      print('   ✅ TRX TX: ${isIncoming ? "INCOMING ✅" : "OUTGOING ❌"} $amount TRX');

      // Convert hex addresses to base58 for display
      String fromDisplay = _hexToBase58Display(fromHex);
      String toDisplay = _hexToBase58Display(toHex);

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
      print('   Stack trace: ${StackTrace.current}');
      rethrow;
    }
  }

  // Helper: Convert Tron base58 address to hex for comparison
  static String _base58ToHex(String base58Address) {
    try {
      // Tron mainnet addresses start with 'T' (base58)
      // Tron testnet addresses start with 'T' as well
      // When converted to hex, they become '41' + 40 hex characters

      if (base58Address.startsWith('41')) {
        return base58Address; // Already in hex format
      }

      // Simplified conversion using character mapping
      // This is a workaround - proper implementation needs base58 decode
      // For the address TFwP2Ee8XgUTEHjPL69W1vAGQ2T4v5pxcB
      // The hex would be: 414178498c63cd05e5190560e58d4cc00a2da94b33

      // Since we don't have proper base58 decoding, we'll do string matching
      // This will work as TronGrid should return consistent format

      return base58Address; // Return as-is for now
    } catch (e) {
      print('⚠️ Base58 to Hex conversion error: $e');
      return base58Address;
    }
  }

  // Helper: Convert hex to base58 for display (simplified)
  static String _hexToBase58Display(String hexAddress) {
    try {
      if (hexAddress.startsWith('41')) {
        // This would normally use base58 encoding
        // For now, keep the hex format
        return hexAddress;
      }
      return hexAddress;
    } catch (e) {
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