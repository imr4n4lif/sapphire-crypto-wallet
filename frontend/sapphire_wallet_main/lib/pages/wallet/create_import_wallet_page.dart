// lib/pages/wallet/create_import_wallet_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:bip39/bip39.dart' as bip39;
import '../../providers/wallet_provider.dart';
import '../home_page.dart';

class CreateImportWalletPage extends StatefulWidget {
  const CreateImportWalletPage({super.key});

  @override
  State<CreateImportWalletPage> createState() => _CreateImportWalletPageState();
}

class _CreateImportWalletPageState extends State<CreateImportWalletPage> {
  final _nameController = TextEditingController();
  final _mnemonicController = TextEditingController();
  bool _isCreating = false;
  bool _isImporting = false;
  String? _generatedMnemonic;

  Future<void> _createWallet() async {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a wallet name')),
      );
      return;
    }

    setState(() {
      _isCreating = true;
    });

    try {
      final provider = Provider.of<WalletProvider>(context, listen: false);
      _generatedMnemonic = bip39.generateMnemonic();

      // Show seed phrase first
      await _showSeedPhraseDialog();

      await provider.createWallet(_nameController.text);

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const HomePage()),
              (route) => false,
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() {
        _isCreating = false;
      });
    }
  }

  Future<void> _importWallet() async {
    if (_nameController.text.isEmpty || _mnemonicController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    final mnemonic = _mnemonicController.text.trim();
    if (!bip39.validateMnemonic(mnemonic)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid seed phrase')),
      );
      return;
    }

    setState(() {
      _isImporting = true;
    });

    try {
      final provider = Provider.of<WalletProvider>(context, listen: false);
      await provider.importWallet(_nameController.text, mnemonic);

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const HomePage()),
              (route) => false,
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() {
        _isImporting = false;
      });
    }
  }

  Future<void> _showSeedPhraseDialog() async {
    final words = _generatedMnemonic!.split(' ');

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Your Recovery Phrase'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Write these words down in order and store them safely!',
                  style: TextStyle(color: Colors.red.shade700),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 16),
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
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${index + 1}',
                          style: const TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                        Text(
                          words[index],
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('I have saved it'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Wallet Setup'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Create New'),
              Tab(text: 'Import Existing'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Create Tab
            _buildCreateTab(),
            // Import Tab
            _buildImportTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Wallet Name',
              border: OutlineInputBorder(),
              hintText: 'My Wallet',
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade700),
                    const SizedBox(width: 12),
                    Text(
                      'Security Information',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text('• A 12-word recovery phrase will be generated'),
                const Text('• Write it down and store it securely offline'),
                const Text('• Never share it with anyone'),
                const Text('• This is the only way to recover your wallet'),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isCreating ? null : _createWallet,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isCreating
                  ? const CircularProgressIndicator()
                  : const Text('Create Wallet'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImportTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Wallet Name',
              border: OutlineInputBorder(),
              hintText: 'Imported Wallet',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _mnemonicController,
            decoration: const InputDecoration(
              labelText: 'Recovery Phrase',
              border: OutlineInputBorder(),
              hintText: 'Enter your 12-word recovery phrase',
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.orange.shade700),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Make sure you are in a private place. Never enter your phrase on shared devices.',
                    style: TextStyle(color: Colors.orange.shade700),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isImporting ? null : _importWallet,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isImporting
                  ? const CircularProgressIndicator()
                  : const Text('Import Wallet'),
            ),
          ),
        ],
      ),
    );
  }
}