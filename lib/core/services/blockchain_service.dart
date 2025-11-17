import 'package:http/http.dart' as http;
import 'package:web3dart/web3dart.dart' as web3dart;
import 'dart:convert';
import '../../models/wallet.dart' as models;
import '../constants/app_constants.dart';

class BlockchainService {
  static final BlockchainService _instance = BlockchainService._internal();
  factory BlockchainService() => _instance;
  BlockchainService._internal();

  late web3dart.Web3Client _ethClient;
  bool _isMainnet = true;

  void initialize(bool isMainnet) {
    _isMainnet = isMainnet;
    final rpcUrl = isMainnet ? AppConstants.ethMainnetRpc : AppConstants.ethTestnetRpc;
    _ethClient = web3dart.Web3Client(rpcUrl, http.Client());
  }

  // Get Bitcoin balance
  Future<double> getBitcoinBalance(String address) async {
    try {
      final url = _isMainnet
          ? '${AppConstants.btcMainnetApi}/addrs/$address/balance'
          : '${AppConstants.btcTestnetApi}/addrs/$address/balance';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final balanceSatoshis = data['final_balance'] ?? 0;
        return balanceSatoshis / 100000000;
      }
      return 0.0;
    } catch (e) {
      print('Error fetching Bitcoin balance: $e');
      return 0.0;
    }
  }

  // Get Ethereum balance
  Future<double> getEthereumBalance(String address) async {
    try {
      final ethAddress = web3dart.EthereumAddress.fromHex(address);
      final balance = await _ethClient.getBalance(ethAddress);
      return balance.getValueInUnit(web3dart.EtherUnit.ether);
    } catch (e) {
      print('Error fetching Ethereum balance: $e');
      return 0.0;
    }
  }

  // Get Filecoin balance
  Future<double> getFilecoinBalance(String address) async {
    try {
      final url = _isMainnet ? AppConstants.filMainnetRpc : AppConstants.filTestnetRpc;

      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'jsonrpc': '2.0',
          'method': 'Filecoin.WalletBalance',
          'params': [address],
          'id': 1,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['result'] != null) {
          final balanceStr = data['result'].toString().replaceAll('"', '');
          final balanceAttoFil = BigInt.parse(balanceStr);
          return balanceAttoFil / BigInt.from(10).pow(18);
        }
      }
      return 0.0;
    } catch (e) {
      print('Error fetching Filecoin balance: $e');
      return 0.0;
    }
  }

  // Get Bitcoin transactions
  Future<List<models.Transaction>> getBitcoinTransactions(String address) async {
    try {
      final url = _isMainnet
          ? '${AppConstants.btcMainnetApi}/addrs/$address/full?limit=50'
          : '${AppConstants.btcTestnetApi}/addrs/$address/full?limit=50';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final txs = data['txs'] as List? ?? [];
        return txs.map((tx) => models.Transaction.fromJson(tx, CoinType.btc, address)).toList();
      }
      return <models.Transaction>[];
    } catch (e) {
      print('Error fetching Bitcoin transactions: $e');
      return <models.Transaction>[];
    }
  }

  // Get Ethereum transactions using Infura
  Future<List<models.Transaction>> getEthereumTransactions(String address) async {
    try {
      // Get recent block number
      final blockNumber = await _ethClient.getBlockNumber();
      final fromBlock = blockNumber > 1000 ? blockNumber - 1000 : 0;

      // This is simplified - in production use Etherscan API
      // For now, return empty list to avoid errors
      return <models.Transaction>[];
    } catch (e) {
      print('Error fetching Ethereum transactions: $e');
      return <models.Transaction>[];
    }
  }

  // Send Bitcoin
  Future<String> sendBitcoin({
    required String fromAddress,
    required String toAddress,
    required String privateKey,
    required double amount,
  }) async {
    try {
      throw UnimplementedError(
          'Bitcoin sending requires signing library. Use testnet faucet to receive, '
              'or implement with bitcoin_base package for production.'
      );
    } catch (e) {
      throw Exception('Failed to send Bitcoin: $e');
    }
  }

  // Send Ethereum (FIXED - proper gas estimation)
  Future<String> sendEthereum({
    required String toAddress,
    required String privateKey,
    required double amount,
  }) async {
    try {
      final credentials = web3dart.EthPrivateKey.fromHex(privateKey);
      final sender = await credentials.address;
      final recipient = web3dart.EthereumAddress.fromHex(toAddress);

      // Convert amount to wei
      final amountInWei = web3dart.EtherAmount.fromBase10String(
        web3dart.EtherUnit.ether,
        amount.toString(),
      );

      // Get gas price
      final gasPrice = await _ethClient.getGasPrice();

      // Estimate gas limit
      final gasLimit = await _ethClient.estimateGas(
        sender: sender,
        to: recipient,
        value: amountInWei,
      );

      // Add 20% buffer to gas limit
      final gasLimitWithBuffer = (gasLimit.toDouble() * 1.2).round();

      print('Gas Price: ${gasPrice.getInWei}');
      print('Gas Limit: $gasLimitWithBuffer');
      print('Total Gas Cost: ${(gasPrice.getInWei * BigInt.from(gasLimitWithBuffer))}');

      final txData = web3dart.Transaction(
        to: recipient,
        value: amountInWei,
        gasPrice: gasPrice,
        maxGas: gasLimitWithBuffer,
      );

      final txHash = await _ethClient.sendTransaction(
        credentials,
        txData,
        chainId: _isMainnet ? 1 : 11155111, // Mainnet : Sepolia
      );

      return txHash;
    } catch (e) {
      print('Ethereum send error: $e');
      throw Exception('Failed to send Ethereum: ${e.toString()}');
    }
  }

  // Get gas price for Ethereum
  Future<web3dart.EtherAmount> getGasPrice() async {
    try {
      return await _ethClient.getGasPrice();
    } catch (e) {
      return web3dart.EtherAmount.fromUnitAndValue(web3dart.EtherUnit.gwei, 20);
    }
  }

  // Estimate gas for Ethereum transaction
  Future<BigInt> estimateGas({
    required String fromAddress,
    required String toAddress,
    required double amount,
  }) async {
    try {
      final from = web3dart.EthereumAddress.fromHex(fromAddress);
      final to = web3dart.EthereumAddress.fromHex(toAddress);
      final value = web3dart.EtherAmount.fromBase10String(
        web3dart.EtherUnit.ether,
        amount.toString(),
      );

      return await _ethClient.estimateGas(
        sender: from,
        to: to,
        value: value,
      );
    } catch (e) {
      return BigInt.from(21000); // Default gas limit for ETH transfer
    }
  }

  void dispose() {
    _ethClient.dispose();
  }
}