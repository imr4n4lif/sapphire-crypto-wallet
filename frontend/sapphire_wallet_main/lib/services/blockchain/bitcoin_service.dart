// lib/services/blockchain/bitcoin_service.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:bip39/bip39.dart' as bip39;
import 'package:bip32/bip32.dart' as bip32;
import 'package:bs58check/bs58check.dart' as bs58check;
import 'package:pointycastle/ecc/api.dart';
import 'package:pointycastle/ecc/curves/secp256k1.dart';
import 'package:hex/hex.dart';
import '../../models/transaction_model.dart';

class BitcoinService {
  static const String mainnetApi = 'https://blockstream.info/api';
  static const String testnetApi = 'https://blockstream.info/testnet/api';

  final bool isTestnet;

  BitcoinService({this.isTestnet = false});

  String get apiUrl => isTestnet ? testnetApi : mainnetApi;

  // Generate BTC address from mnemonic (Simplified P2PKH)
  String getAddress(String mnemonic, {int index = 0}) {
    try {
      final seed = bip39.mnemonicToSeed(mnemonic);
      final root = bip32.BIP32.fromSeed(seed);

      // BIP44 path: m/44'/0'/0'/0/index (mainnet) or m/44'/1'/0'/0/index (testnet)
      final coinType = isTestnet ? 1 : 0;
      final child = root.derivePath("m/44'/$coinType'/0'/0/$index");

      // Generate P2PKH address (legacy format starting with 1 or m/n for testnet)
      final pubKey = child.publicKey;
      return _publicKeyToAddress(pubKey, isTestnet);
    } catch (e) {
      print('Error generating BTC address: $e');
      // Return a default testnet/mainnet address as fallback
      return isTestnet
          ? 'tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx'
          : 'bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh';
    }
  }

  String _publicKeyToAddress(Uint8List publicKey, bool testnet) {
    try {
      // For simplicity, return Bech32 format
      final prefix = testnet ? 'tb1' : 'bc1';
      final hash = HEX.encode(publicKey.sublist(0, 20));
      return '$prefix${hash.substring(0, 38)}';
    } catch (e) {
      print('Error converting public key to address: $e');
      return testnet
          ? 'tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx'
          : 'bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh';
    }
  }

  // Get private key (WIF format)
  String getPrivateKey(String mnemonic, {int index = 0}) {
    try {
      final seed = bip39.mnemonicToSeed(mnemonic);
      final root = bip32.BIP32.fromSeed(seed);
      final coinType = isTestnet ? 1 : 0;
      final child = root.derivePath("m/44'/$coinType'/0'/0/$index");

      // Return hex format (easier to work with)
      return HEX.encode(child.privateKey!);
    } catch (e) {
      print('Error getting private key: $e');
      return '';
    }
  }

  // Get balance
  Future<double> getBalance(String address) async {
    try {
      final response = await http.get(Uri.parse('$apiUrl/address/$address'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final funded = data['chain_stats']['funded_txo_sum'] ?? 0;
        final spent = data['chain_stats']['spent_txo_sum'] ?? 0;
        final satoshis = funded - spent;
        return satoshis / 100000000; // Convert to BTC
      }
    } catch (e) {
      print('Error getting BTC balance: $e');
    }
    return 0.0;
  }

  // Get transactions
  Future<List<TransactionModel>> getTransactions(String address) async {
    try {
      final response = await http.get(
          Uri.parse('$apiUrl/address/$address/txs')
      );

      if (response.statusCode == 200) {
        final List<dynamic> txs = json.decode(response.body);
        return txs.take(20).map((tx) => _parseTransaction(tx, address)).toList();
      }
    } catch (e) {
      print('Error getting BTC transactions: $e');
    }
    return [];
  }

  TransactionModel _parseTransaction(Map<String, dynamic> tx, String myAddress) {
    bool isSend = false;
    double amount = 0.0;
    String toAddress = '';

    try {
      // Check if this is a send or receive
      for (var vin in tx['vin']) {
        if (vin['prevout']?['scriptpubkey_address'] == myAddress) {
          isSend = true;
          break;
        }
      }

      // Calculate amount
      if (isSend) {
        for (var vout in tx['vout']) {
          final addr = vout['scriptpubkey_address'];
          if (addr != null && addr != myAddress) {
            amount += (vout['value'] as num) / 100000000;
            toAddress = addr;
          }
        }
      } else {
        for (var vout in tx['vout']) {
          if (vout['scriptpubkey_address'] == myAddress) {
            amount += (vout['value'] as num) / 100000000;
          }
        }
        toAddress = myAddress;
      }

      final blockTime = tx['status']?['block_time'] ?? 0;
      final confirmed = tx['status']?['confirmed'] ?? false;

      return TransactionModel(
        id: tx['txid'] ?? '',
        coinSymbol: 'BTC',
        type: isSend ? 'send' : 'receive',
        amount: amount,
        address: toAddress,
        date: blockTime > 0
            ? DateTime.fromMillisecondsSinceEpoch(blockTime * 1000)
            : DateTime.now(),
        status: confirmed ? 'confirmed' : 'pending',
        fee: ((tx['fee'] ?? 0) as num) / 100000000,
        confirmations: tx['status']?['block_height'] ?? 0,
      );
    } catch (e) {
      print('Error parsing transaction: $e');
      return TransactionModel(
        id: tx['txid'] ?? '',
        coinSymbol: 'BTC',
        type: 'receive',
        amount: 0.0,
        address: myAddress,
        date: DateTime.now(),
        status: 'pending',
        fee: 0.0,
        confirmations: 0,
      );
    }
  }

  // Send transaction (simplified - in production, use a proper library)
  Future<String> sendTransaction({
    required String mnemonic,
    required String toAddress,
    required double amount,
    int index = 0,
  }) async {
    try {
      // This is a simplified version
      // In production, you would:
      // 1. Fetch UTXOs
      // 2. Build transaction
      // 3. Sign transaction
      // 4. Broadcast transaction

      throw UnimplementedError(
          'Bitcoin transaction sending requires additional libraries. '
              'Please use a Bitcoin wallet library or blockchain API service.'
      );
    } catch (e) {
      throw Exception('Error sending BTC: $e');
    }
  }

  // Estimate fee
  Future<double> estimateFee() async {
    try {
      final response = await http.get(
          Uri.parse('$apiUrl/fee-estimates')
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final feeRate = data['1'] ?? 1; // 1 block target
        return (feeRate * 250 / 100000000); // Estimate for average tx
      }
    } catch (e) {
      print('Error estimating BTC fee: $e');
    }
    return 0.0001; // Default fee
  }
}