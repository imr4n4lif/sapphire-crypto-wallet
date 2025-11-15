import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:provider/provider.dart';
import '../models/wallet_model.dart';
import '../providers/wallet_provider.dart';

class ReceivePage extends StatefulWidget {
  const ReceivePage({super.key});

  @override
  State<ReceivePage> createState() => _ReceivePageState();
}

class _ReceivePageState extends State<ReceivePage> {
  String _selectedCoin = 'BTC';

  CryptoCoin _getCurrentCoin(List<CryptoCoin> coins) {
    try {
      return coins.firstWhere((coin) => coin.symbol == _selectedCoin);
    } catch (e) {
      return coins.isNotEmpty ? coins.first : _getDefaultCoin();
    }
  }

  CryptoCoin _getDefaultCoin() {
    return CryptoCoin(
      symbol: 'BTC',
      name: 'Bitcoin',
      balance: 0,
      price: 0,
      address: 'bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh',
      icon: '₿',
      priceHistory: [],
    );
  }

  @override
  Widget build(BuildContext context) {
    final walletProvider = Provider.of<WalletProvider>(context);
    final coins = walletProvider.currentWallet?.coins ?? [];
    final currentCoin = _getCurrentCoin(coins);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Receive Crypto'),
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
                });
              },
              decoration: const InputDecoration(
                labelText: 'Select Coin',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 40),

            // QR Code
            Card(
              child: Container(
                width: 200,
                height: 200,
                padding: const EdgeInsets.all(16),
                child: QrImageView(
                  data: currentCoin.address,
                  version: QrVersions.auto,
                  size: 200,
                  backgroundColor: Colors.white,
                ),
              ),
            ),

            const SizedBox(height: 30),

            // Address
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      'Your $_selectedCoin Address',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SelectableText(
                      currentCoin.address,
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      onPressed: () {
                        // Copy to clipboard
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Address copied to clipboard')),
                        );
                      },
                      icon: const Icon(Icons.copy),
                      label: const Text('Copy Address'),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Warning
            Card(
              color: Colors.orange[50],
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const Icon(Icons.warning, color: Colors.orange),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Only send $_selectedCoin to this address. Sending other assets may result in permanent loss.',
                        style: const TextStyle(color: Colors.orange),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}