// lib/pages/settings/view_seed_phrase_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/wallet_provider.dart';
import '../../services/security/biometric_service.dart';

class ViewSeedPhrasePage extends StatefulWidget {
  const ViewSeedPhrasePage({super.key});

  @override
  State<ViewSeedPhrasePage> createState() => _ViewSeedPhrasePageState();
}

class _ViewSeedPhrasePageState extends State<ViewSeedPhrasePage> {
  bool _isAuthenticated = false;
  final _biometricService = BiometricService();

  @override
  void initState() {
    super.initState();
    _authenticate();
  }

  Future<void> _authenticate() async {
    final authenticated = await _biometricService.authenticate(
      reason: 'Authenticate to view seed phrase',
    );

    setState(() {
      _isAuthenticated = authenticated;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recovery Phrase'),
      ),
      body: _isAuthenticated
          ? Consumer<WalletProvider>(
        builder: (context, provider, child) {
          if (provider.currentWallet == null) {
            return const Center(child: Text('No wallet found'));
          }

          final words = provider.currentWallet!.mnemonic.split(' ');

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                          'Never share your seed phrase with anyone. Store it securely offline.',
                          style: TextStyle(color: Colors.red.shade700),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 2,
                  ),
                  itemCount: words.length,
                  itemBuilder: (context, index) {
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${index + 1}',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            words[index],
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(
                        ClipboardData(text: provider.currentWallet!.mnemonic),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Seed phrase copied to clipboard'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy to Clipboard'),
                  ),
                ),
              ],
            ),
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
}