import '../core/constants/app_constants.dart';

class AddressBookEntry {
  final String id;
  final String name;
  final String address;
  final CoinType coinType;
  final DateTime createdAt;

  AddressBookEntry({
    required this.id,
    required this.name,
    required this.address,
    required this.coinType,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'coinType': coinType.name,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory AddressBookEntry.fromJson(Map<String, dynamic> json) {
    return AddressBookEntry(
      id: json['id'] as String,
      name: json['name'] as String,
      address: json['address'] as String,
      coinType: CoinType.values.firstWhere(
            (e) => e.name == json['coinType'],
        orElse: () => CoinType.btc,
      ),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  AddressBookEntry copyWith({
    String? id,
    String? name,
    String? address,
    CoinType? coinType,
    DateTime? createdAt,
  }) {
    return AddressBookEntry(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      coinType: coinType ?? this.coinType,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}