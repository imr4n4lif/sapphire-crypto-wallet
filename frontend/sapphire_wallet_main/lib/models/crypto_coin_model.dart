// lib/models/crypto_coin_model.dart
import 'package:equatable/equatable.dart';

class CryptoCoinModel extends Equatable {
  final String symbol;
  final String name;
  final double balance;
  final double price;
  final String address;
  final String privateKey;
  final String icon;
  final List<PricePoint> priceHistory;
  final double change24h;

  const CryptoCoinModel({
    required this.symbol,
    required this.name,
    required this.balance,
    required this.price,
    required this.address,
    required this.privateKey,
    required this.icon,
    required this.priceHistory,
    this.change24h = 0.0,
  });

  double get valueInUSD => balance * price;

  CryptoCoinModel copyWith({
    String? symbol,
    String? name,
    double? balance,
    double? price,
    String? address,
    String? privateKey,
    String? icon,
    List<PricePoint>? priceHistory,
    double? change24h,
  }) {
    return CryptoCoinModel(
      symbol: symbol ?? this.symbol,
      name: name ?? this.name,
      balance: balance ?? this.balance,
      price: price ?? this.price,
      address: address ?? this.address,
      privateKey: privateKey ?? this.privateKey,
      icon: icon ?? this.icon,
      priceHistory: priceHistory ?? this.priceHistory,
      change24h: change24h ?? this.change24h,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'symbol': symbol,
      'name': name,
      'balance': balance,
      'price': price,
      'address': address,
      'privateKey': privateKey,
      'icon': icon,
      'change24h': change24h,
    };
  }

  factory CryptoCoinModel.fromJson(Map<String, dynamic> json) {
    return CryptoCoinModel(
      symbol: json['symbol'],
      name: json['name'],
      balance: json['balance'],
      price: json['price'] ?? 0.0,
      address: json['address'],
      privateKey: json['privateKey'],
      icon: json['icon'],
      priceHistory: [],
      change24h: json['change24h'] ?? 0.0,
    );
  }

  @override
  List<Object?> get props => [
    symbol, name, balance, price, address,
    privateKey, icon, priceHistory, change24h
  ];
}

class PricePoint extends Equatable {
  final DateTime time;
  final double price;

  const PricePoint({required this.time, required this.price});

  @override
  List<Object?> get props => [time, price];
}