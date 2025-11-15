// lib/models/transaction_model.dart
import 'package:equatable/equatable.dart';

class TransactionModel extends Equatable {
  final String id;
  final String coinSymbol;
  final String type; // send, receive
  final double amount;
  final String address;
  final DateTime date;
  final String status; // pending, confirmed, failed
  final double fee;
  final int confirmations;

  const TransactionModel({
    required this.id,
    required this.coinSymbol,
    required this.type,
    required this.amount,
    required this.address,
    required this.date,
    required this.status,
    required this.fee,
    this.confirmations = 0,
  });

  TransactionModel copyWith({
    String? id,
    String? coinSymbol,
    String? type,
    double? amount,
    String? address,
    DateTime? date,
    String? status,
    double? fee,
    int? confirmations,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      coinSymbol: coinSymbol ?? this.coinSymbol,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      address: address ?? this.address,
      date: date ?? this.date,
      status: status ?? this.status,
      fee: fee ?? this.fee,
      confirmations: confirmations ?? this.confirmations,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'coinSymbol': coinSymbol,
      'type': type,
      'amount': amount,
      'address': address,
      'date': date.toIso8601String(),
      'status': status,
      'fee': fee,
      'confirmations': confirmations,
    };
  }

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id'],
      coinSymbol: json['coinSymbol'],
      type: json['type'],
      amount: json['amount'],
      address: json['address'],
      date: DateTime.parse(json['date']),
      status: json['status'],
      fee: json['fee'],
      confirmations: json['confirmations'] ?? 0,
    );
  }

  @override
  List<Object?> get props => [
    id, coinSymbol, type, amount, address,
    date, status, fee, confirmations
  ];
}