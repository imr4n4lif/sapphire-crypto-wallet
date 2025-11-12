class CryptoCoin {
  final String symbol;
  final String name;
  double balance;
  double price;
  final String address;
  final String icon;
  final List<PricePoint> priceHistory;

  CryptoCoin({
    required this.symbol,
    required this.name,
    required this.balance,
    required this.price,
    required this.address,
    required this.icon,
    required this.priceHistory,
  });

  double get valueInUSD => balance * price;
}

class PricePoint {
  final DateTime time;
  final double price;

  PricePoint({required this.time, required this.price});
}

class Transaction {
  final String id;
  final String coinSymbol;
  final String type; // send, receive
  final double amount;
  final String address;
  final DateTime date;
  final String status;
  final double fee;

  Transaction({
    required this.id,
    required this.coinSymbol,
    required this.type,
    required this.amount,
    required this.address,
    required this.date,
    required this.status,
    required this.fee,
  });
}

class Wallet {
  final String id;
  final String name;
  final String seedPhrase;
  final DateTime createdAt;
  List<CryptoCoin> coins;

  Wallet({
    required this.id,
    required this.name,
    required this.seedPhrase,
    required this.createdAt,
    required this.coins,
  });
}