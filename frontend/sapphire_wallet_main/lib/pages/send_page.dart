import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/wallet_provider.dart';

class SendPage extends StatefulWidget {
  const SendPage({super.key});

  @override
  State<SendPage> createState() => _SendPageState();
}

class _SendPageState extends State<SendPage> {
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  String _selectedCoin = 'BTC';
  double _fee = 0.0001;

  void _sendTransaction() {
    if (_addressController.text.isEmpty || _amountController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    // Show confirmation dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Transaction'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Send: $amount $_selectedCoin'),
            Text('To: ${_addressController.text}'),
            Text('Fee: $_fee $_selectedCoin'),
            Text('Total: ${amount + _fee} $_selectedCoin'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _processTransaction();
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  void _processTransaction() {
    // In a real app, this would broadcast the transaction to the network
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Transaction sent!')),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final walletProvider = Provider.of<WalletProvider>(context);
    final coins = walletProvider.currentWallet?.coins ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Send Crypto'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // Coin Selection
            DropdownButtonFormField<String>(
              value: _selectedCoin,
              items: coins.map((coin) {
                return DropdownMenuItem(
                  value: coin.symbol,
                  child: Row(
                    children: [
                      CircleAvatar(child: Text(coin.icon)),
                      const SizedBox(width: 10),
                      Text(coin.symbol),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedCoin = value!;
                  // Update fee based on coin
                  _fee = _selectedCoin == 'BTC' ? 0.0001 :
                  _selectedCoin == 'ETH' ? 0.001 : 0.01;
                });
              },
              decoration: const InputDecoration(
                labelText: 'Select Coin',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 20),

            // Recipient Address
            TextField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'Recipient Address',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 20),

            // Amount
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Amount',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 20),

            // Fee Information
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Network Fee:'),
                    Text('$_fee $_selectedCoin'),
                  ],
                ),
              ),
            ),

            const Spacer(),

            // Send Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _sendTransaction,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Send Transaction'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}