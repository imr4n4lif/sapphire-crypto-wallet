// lib/services/blockchain/ethereum_service.dart
import 'dart:convert';
import 'package:web3dart/web3dart.dart';
import 'package:http/http.dart' as http;
import 'package:bip39/bip39.dart' as bip39;
import 'package:bip32/bip32.dart' as bip32;
import 'package:hex/hex.dart';
import '../../models/transaction_model.dart';

class EthereumService {
  static const String mainnetRpc = 'https://eth.llamarpc.com';
  static const String testnetRpc = 'https://rpc.sepolia.org';
  static const String etherscanApi = 'https://api.etherscan.io/api';
  static const String sepoliaApi = 'https://api-sepolia.etherscan.io/api';

  final bool isTestnet;
  late Web3Client client;

  EthereumService({this.isTestnet = false}) {
    final rpcUrl = isTestnet ? testnetRpc : mainnetRpc;
    client = Web3Client(rpcUrl, http.Client());
  }

  String get explorerApi => isTestnet ? sepoliaApi : etherscanApi;

  // Generate ETH address from mnemonic
  String getAddress(String mnemonic, {int index = 0}) {
    try {
      final seed = bip39.mnemonicToSeed(mnemonic);
      final root = bip32.BIP32.fromSeed(seed);
      final child = root.derivePath("m/44'/60'/0'/0/$index");

      final privateKey = HEX.encode(child.privateKey!);
      final credentials = EthPrivateKey.fromHex(privateKey);
      return credentials.address.hex;
    } catch (e) {
      print('Error generating ETH address: $e');
      return '0x0000000000000000000000000000000000000000';
    }
  }

  // Get private key
  String getPrivateKey(String mnemonic, {int index = 0}) {
    try {
      final seed = bip39.mnemonicToSeed(mnemonic);
      final root = bip32.BIP32.fromSeed(seed);
      final child = root.derivePath("m/44'/60'/0'/0/$index");
      return HEX.encode(child.privateKey!);
    } catch (e) {
      print('Error getting ETH private key: $e');
      return '';
    }
  }

  // Get balance
  Future<double> getBalance(String address) async {
    try {
      final ethAddress = EthereumAddress.fromHex(address);
      final balance = await client.getBalance(ethAddress);
      return balance.getValueInUnit(EtherUnit.ether).toDouble();
    } catch (e) {
      print('Error getting ETH balance: $e');
      return 0.0;
    }
  }

  // Get transactions
  Future<List<TransactionModel>> getTransactions(String address) async {
    try {
      // Using free API without key (limited requests)
      final url = Uri.parse(
          '$explorerApi?module=account&action=txlist&address=$address&sort=desc&page=1&offset=20'
      );
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == '1' && data['result'] is List) {
          final List<dynamic> txs = data['result'];
          return txs.map((tx) => _parseTransaction(tx, address)).toList();
        }
      }
    } catch (e) {
      print('Error getting ETH transactions: $e');
    }
    return [];
  }

  TransactionModel _parseTransaction(Map<String, dynamic> tx, String myAddress) {
    try {
      final isSend = (tx['from'] ?? '').toLowerCase() == myAddress.toLowerCase();
      final value = BigInt.tryParse(tx['value'] ?? '0') ?? BigInt.zero;
      final amount = value / BigInt.from(10).pow(18);

      final gasUsed = BigInt.tryParse(tx['gasUsed'] ?? '0') ?? BigInt.zero;
      final gasPrice = BigInt.tryParse(tx['gasPrice'] ?? '0') ?? BigInt.zero;
      final fee = (gasUsed * gasPrice) / BigInt.from(10).pow(18);

      return TransactionModel(
        id: tx['hash'] ?? '',
        coinSymbol: 'ETH',
        type: isSend ? 'send' : 'receive',
        amount: amount.toDouble(),
        address: isSend ? (tx['to'] ?? '') : (tx['from'] ?? ''),
        date: DateTime.fromMillisecondsSinceEpoch(
            (int.tryParse(tx['timeStamp'] ?? '0') ?? 0) * 1000
        ),
        status: (tx['txreceipt_status'] ?? '1') == '1' ? 'confirmed' : 'failed',
        fee: fee.toDouble(),
        confirmations: int.tryParse(tx['confirmations']?.toString() ?? '0') ?? 0,
      );
    } catch (e) {
      print('Error parsing ETH transaction: $e');
      return TransactionModel(
        id: tx['hash'] ?? '',
        coinSymbol: 'ETH',
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

  // Send transaction
  Future<String> sendTransaction({
    required String mnemonic,
    required String toAddress,
    required double amount,
    int index = 0,
  }) async {
    try {
      final privateKey = getPrivateKey(mnemonic, index: index);
      final credentials = EthPrivateKey.fromHex(privateKey);

      final transaction = Transaction(
        to: EthereumAddress.fromHex(toAddress),
        value: EtherAmount.fromUnitAndValue(
          EtherUnit.ether,
          (amount * 1e18).toInt(),
        ),
      );

      final txHash = await client.sendTransaction(
        credentials,
        transaction,
        chainId: isTestnet ? 11155111 : 1, // Sepolia or Mainnet
      );

      return txHash;
    } catch (e) {
      throw Exception('Error sending ETH: $e');
    }
  }

  // Estimate gas
  Future<double> estimateGas({
    required String from,
    required String to,
    required double amount,
  }) async {
    try {
      final gasPrice = await client.getGasPrice();
      const estimatedGasLimit = 21000; // Standard ETH transfer

      final fee = gasPrice.getInWei * BigInt.from(estimatedGasLimit);
      return (fee / BigInt.from(10).pow(18)).toDouble();
    } catch (e) {
      print('Error estimating ETH gas: $e');
      return 0.001; // Default estimate
    }
  }

  void dispose() {
    client.dispose();
  }
}

