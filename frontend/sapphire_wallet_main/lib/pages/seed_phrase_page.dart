import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/wallet_provider.dart';
import 'home_page.dart';

class SeedPhrasePage extends StatefulWidget {
  final String walletName;
  final String seedPhrase;

  const SeedPhrasePage({
    super.key,
    required this.walletName,
    required this.seedPhrase,
  });

  @override
  State<SeedPhrasePage> createState() => _SeedPhrasePageState();
}

class _SeedPhrasePageState extends State<SeedPhrasePage> {
  bool _hasConfirmedBackup = false;
  bool _isCopied = false;
  final List<String> _selectedWords = [];

  List<String> get _words => widget.seedPhrase.split(' ');

  void _createWallet() {
    if (!_hasConfirmedBackup) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please confirm that you have backed up your seed phrase')),
      );
      return;
    }

    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    walletProvider.createWallet(widget.walletName, widget.seedPhrase);

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const HomePage()),
          (route) => false,
    );
  }

  void _copyToClipboard() {
    setState(() {
      _isCopied = true;
    });

    // In a real app, you would use Clipboard.setData
    // Clipboard.setData(ClipboardData(text: widget.seedPhrase));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Seed phrase copied to clipboard')),
    );

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isCopied = false;
        });
      }
    });
  }

  void _toggleWordSelection(int index) {
    setState(() {
      if (_selectedWords.contains(_words[index])) {
        _selectedWords.remove(_words[index]);
      } else {
        _selectedWords.add(_words[index]);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Seed Phrase'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            _showBackDialog();
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Warning Header
            Card(
              color: Colors.red[50],
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber, color: Colors.red),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Write these words down in the correct order and store them in a secure location.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.red[800],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Security Tips
            const Text(
              'Security Tips:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text('• Never share your seed phrase with anyone'),
            const Text('• Store it in multiple secure locations'),
            const Text('• Never store it digitally (screenshots, cloud, etc.)'),
            const Text('• This is the ONLY way to recover your wallet'),

            const SizedBox(height: 24),

            // Seed Phrase Grid
            Text(
              'Your 12-Word Seed Phrase:',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
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
                childAspectRatio: 1.8,
              ),
              itemCount: _words.length,
              itemBuilder: (context, index) {
                final word = _words[index];
                final isSelected = _selectedWords.contains(word);

                return Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isSelected ? Colors.blue : Colors.grey.shade300,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    color: isSelected ? Colors.blue.withOpacity(0.1) : Colors.grey[50],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _toggleWordSelection(index),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${index + 1}',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              word,
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 20),

            // Copy Button
            OutlinedButton.icon(
              onPressed: _copyToClipboard,
              icon: Icon(_isCopied ? Icons.check : Icons.copy),
              label: Text(_isCopied ? 'Copied!' : 'Copy to Clipboard'),
            ),

            const SizedBox(height: 30),

            // Warning about digital storage
            Card(
              color: Colors.amber[50],
              child: const Padding(
                padding: EdgeInsets.all(12.0),
                child: Text(
                  '⚠️ Never store your seed phrase digitally (no screenshots, photos, cloud storage, etc.)',
                  style: TextStyle(color: Colors.amber),
                  textAlign: TextAlign.center,
                ),
              ),
            ),

            const SizedBox(height: 30),

            // Confirmation Checkbox
            Row(
              children: [
                Checkbox(
                  value: _hasConfirmedBackup,
                  onChanged: (value) {
                    setState(() {
                      _hasConfirmedBackup = value ?? false;
                    });
                  },
                ),
                const Expanded(
                  child: Text(
                    'I have written down my seed phrase and stored it securely. I understand that losing this phrase means losing access to my funds forever.',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Create Wallet Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _hasConfirmedBackup ? _createWallet : null,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: _hasConfirmedBackup ? Colors.green : Colors.grey,
                ),
                child: const Text(
                  'Create Wallet',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showBackDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Go Back?'),
        content: const Text(
          'You have not completed the wallet creation process. '
              'Your seed phrase will be lost if you go back now.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Go back
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Go Back'),
          ),
        ],
      ),
    );
  }
}