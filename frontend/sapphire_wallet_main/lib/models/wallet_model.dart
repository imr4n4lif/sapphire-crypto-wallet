// lib/models/wallet_model.dart
import 'package:equatable/equatable.dart';
import 'crypto_coin_model.dart';

class WalletModel extends Equatable {
  final String id;
  final String name;
  final String mnemonic;
  final DateTime createdAt;
  final List<CryptoCoinModel> coins;

  const WalletModel({
    required this.id,
    required this.name,
    required this.mnemonic,
    required this.createdAt,
    required this.coins,
  });

  WalletModel copyWith({
    String? id,
    String? name,
    String? mnemonic,
    DateTime? createdAt,
    List<CryptoCoinModel>? coins,
  }) {
    return WalletModel(
      id: id ?? this.id,
      name: name ?? this.name,
      mnemonic: mnemonic ?? this.mnemonic,
      createdAt: createdAt ?? this.createdAt,
      coins: coins ?? this.coins,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'mnemonic': mnemonic,
      'createdAt': createdAt.toIso8601String(),
      'coins': coins.map((c) => c.toJson()).toList(),
    };
  }

  factory WalletModel.fromJson(Map<String, dynamic> json) {
    return WalletModel(
      id: json['id'],
      name: json['name'],
      mnemonic: json['mnemonic'],
      createdAt: DateTime.parse(json['createdAt']),
      coins: (json['coins'] as List)
          .map((c) => CryptoCoinModel.fromJson(c))
          .toList(),
    );
  }

  @override
  List<Object?> get props => [id, name, mnemonic, createdAt, coins];
}