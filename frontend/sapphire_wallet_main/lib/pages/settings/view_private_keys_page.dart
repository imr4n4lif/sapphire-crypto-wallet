
// lib/pages/settings/view_private_keys_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/wallet_provider.dart';
import '../../services/security/biometric_service.dart';

class ViewPrivateKeysPage extends StatefulWidget {
  const ViewPrivateKeysPage({super.key});

  @override
  State<ViewPrivateKeysPage> createState() => _ViewPrivateKeysPageState();
}

class _ViewPrivateKeysPageState extends State<ViewPrivateKeysPage> {
  bool _isAuthenticated = false;
  final _biometricService = BiometricService();
  final Map<String, bool> _revealed = {};

  @override
  void initState() {
    super.initState();
    _authenticate();
  }

  Future<void> _authenticate() async {
    final authenticated = await _biometricService.authenticate(
      reason: 'Authenticate to view private keys',
    );

    setState(() {
      _isAuthenticated = authenticated;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Private Keys'),
      ),
      body: _isAuthenticated
          ? Consumer<WalletProvider>(
        builder: (context, provider, child) {
          if (provider.currentWallet == null) {
            return const Center(child: Text('No wallet found'));
          }

          final coins = provider.currentWallet!.coins;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.red.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Never share your private keys. Anyone with these keys can access your funds.',
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              ...coins.map((coin) => _buildPrivateKeyCard(coin)),
            ],
          );
        },
      )
          : Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('Authentication Required'),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _authenticate,
              child: const Text('Authenticate'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrivateKeyCard(coin) {
    final isRevealed = _revealed[coin.symbol] ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  child: Text(coin.icon),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      coin.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      coin.symbol,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: isRevealed
                  ? SelectableText(
                coin.privateKey,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              )
                  : const Text(
                '••••••••••••••••••••••••••••••••',
                style: TextStyle(fontSize: 18),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _revealed[coin.symbol] = !isRevealed;
                      });
                    },
                    icon: Icon(isRevealed ? Icons.visibility_off : Icons.visibility),
                    label: Text(isRevealed ? 'Hide' : 'Reveal'),
                  ),
                ),
                if (isRevealed) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: coin.privateKey));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${coin.symbol} private key copied'),
                          ),
                        );
                      },
                      icon: const Icon(Icons.copy),
                      label: const Text('Copy'),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}