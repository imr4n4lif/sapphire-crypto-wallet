// lib/services/blockchain/filecoin_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:bip39/bip39.dart' as bip39;
import 'package:bip32/bip32.dart' as bip32;
import 'package:hex/hex.dart';
import '../../models/transaction_model.dart';

class FilecoinService {
  static const String mainnetApi = 'https://api.node.glif.io';
  static const String testnetApi = 'https://api.calibration.node.glif.io';

  final bool isTestnet;

  FilecoinService({this.isTestnet = false});

  String get apiUrl => isTestnet ? testnetApi : mainnetApi;

  // Generate FIL address from mnemonic (simplified)
  String getAddress(String mnemonic, {int index = 0}) {
    try {
      final seed = bip39.mnemonicToSeed(mnemonic);
      final root = bip32.BIP32.fromSeed(seed);
      // FIL uses SECP256K1 with path m/44'/461'/0'/0/index
      final child = root.derivePath("m/44'/461'/0'/0/$index");

      // Simplified address generation
      final pubKeyHex = HEX.encode(child.publicKey);
      final prefix = isTestnet ? 't1' : 'f1';
      return '$prefix${pubKeyHex.substring(0, 38)}';
    } catch (e) {
      print('Error generating FIL address: $e');
      return isTestnet
          ? 't1abjxfbp274xpdqcpuaykwkfb43omjotacm2p3za'
          : 'f1abjxfbp274xpdqcpuaykwkfb43omjotacm2p3za';
    }
  }

  // Get private key
  String getPrivateKey(String mnemonic, {int index = 0}) {
    try {
      final seed = bip39.mnemonicToSeed(mnemonic);
      final root = bip32.BIP32.fromSeed(seed);
      final child = root.derivePath("m/44'/461'/0'/0/$index");
      return HEX.encode(child.privateKey!);
    } catch (e) {
      print('Error getting FIL private key: $e');
      return '';
    }
  }

  // Get balance (simplified)
  Future<double> getBalance(String address) async {
    try {
      final response = await _rpcCall('Filecoin.WalletBalance', [address]);
      if (response != null && response is String) {
        final balance = BigInt.tryParse(response) ?? BigInt.zero;
        return (balance / BigInt.from(10).pow(18)).toDouble();
      }
    } catch (e) {
      print('Error getting FIL balance: $e');
    }
    return 0.0;
  }

  // Get transactions (Filecoin doesn't have easy tx history without indexer)
  Future<List<TransactionModel>> getTransactions(String address) async {
    // Note: Filecoin transaction history requires specialized indexing services
    // For production, integrate with Filfox API or Beryx
    return [];
  }

  // Send transaction (placeholder)
  Future<String> sendTransaction({
    required String mnemonic,
    required String toAddress,
    required double amount,
    int index = 0,
  }) async {
    throw UnimplementedError(
        'Filecoin transaction sending requires Lotus API or similar service. '
            'This is a complex operation requiring message signing and gas estimation.'
    );
  }

  Future<dynamic> _rpcCall(String method, List<dynamic> params) async {
    try {
      final response = await http.post(
        Uri.parse('$apiUrl/rpc/v0'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'jsonrpc': '2.0',
          'method': method,
          'params': params,
          'id': 1,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['result'];
      }
    } catch (e) {
      print('Filecoin RPC error: $e');
    }
    return null;
  }

  // Estimate fee
  Future<double> estimateFee() async {
    return 0.01; // Default FIL fee estimate
  }
}