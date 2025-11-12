import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../providers/wallet_provider.dart';
import 'home_page.dart';
import 'seed_phrase_page.dart';

class CreateImportWalletPage extends StatefulWidget {
  const CreateImportWalletPage({super.key});

  @override
  State<CreateImportWalletPage> createState() => _CreateImportWalletPageState();
}

class _CreateImportWalletPageState extends State<CreateImportWalletPage> {
  final PageController _pageController = PageController();
  final TextEditingController _nameController = TextEditingController();
  final List<TextEditingController> _seedControllers = List.generate(12, (index) => TextEditingController());
  bool _isImporting = false;

  // Mock seed phrase
  final String _mockSeedPhrase = "abandon ability able about above absent absorb abstract absurd abuse access accident";

  void _proceedToSeedPhrase() {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a wallet name')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SeedPhrasePage(
          walletName: _nameController.text,
          seedPhrase: _mockSeedPhrase,
        ),
      ),
    );
  }

  void _importWallet() {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a wallet name')),
      );
      return;
    }

    // Validate that all seed fields are filled
    for (int i = 0; i < _seedControllers.length; i++) {
      if (_seedControllers[i].text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please enter word ${i + 1}')),
        );
        return;
      }
    }

    // Combine all words into a seed phrase
    final seedPhrase = _seedControllers.map((controller) => controller.text.trim()).join(' ');

    if (seedPhrase.split(' ').length != 12) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter exactly 12 words')),
      );
      return;
    }

    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    walletProvider.importWallet(_nameController.text, seedPhrase);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const HomePage()),
    );
  }

  @override
  void dispose() {
    for (final controller in _seedControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create/Import Wallet'),
      ),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          // Welcome Page
          _buildWelcomePage(),
          // Create Wallet Page
          _buildCreateWalletPage(),
          // Import Wallet Page
          _buildImportWalletPage(),
        ],
      ),
    );
  }

  Widget _buildWelcomePage() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Custom SVG Icon
          SvgPicture.asset(
            'assets/svg/sapphire_logo.svg',
            width: 80,
            height: 80,
            color: Colors.blue,
          ),
          const SizedBox(height: 30),
          Text(
            'Welcome to Sapphire Wallet',
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Text(
            'A secure non-custodial wallet for BTC, ETH, and FIL',
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                _isImporting = false;
                _pageController.nextPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeIn,
                );
              },
              child: const Text('Create New Wallet'),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                _isImporting = true;
                // Go directly to import wallet page (page 2)
                _pageController.jumpToPage(2);
              },
              child: const Text('Import Wallet'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateWalletPage() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => _pageController.previousPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeIn,
              ),
            ),
            title: const Text('Create Wallet'),
            backgroundColor: Colors.transparent,
            elevation: 0,
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Wallet Name',
              border: OutlineInputBorder(),
              hintText: 'Enter a name for your wallet',
            ),
          ),
          const SizedBox(height: 30),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Security Information',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  SizedBox(height: 10),
                  Text('• You will be shown a 12-word seed phrase'),
                  SizedBox(height: 5),
                  Text('• Write it down and store it securely'),
                  SizedBox(height: 5),
                  Text('• Never share your seed phrase with anyone'),
                  SizedBox(height: 5),
                  Text('• This is the only way to recover your wallet'),
                ],
              ),
            ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _proceedToSeedPhrase,
              child: const Text('Generate Seed Phrase'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImportWalletPage() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => _pageController.jumpToPage(0), // Go back to welcome page
            ),
            title: const Text('Import Wallet'),
            backgroundColor: Colors.transparent,
            elevation: 0,
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Wallet Name',
              border: OutlineInputBorder(),
              hintText: 'Enter a name for your imported wallet',
            ),
          ),
          const SizedBox(height: 20),

          // Seed phrase input grid
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Text(
                    'Enter Your 12-Word Seed Phrase',
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
                      childAspectRatio: 2.5,
                    ),
                    itemCount: 12,
                    itemBuilder: (context, index) {
                      return Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: TextField(
                          controller: _seedControllers[index],
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            labelText: '${index + 1}',
                            border: InputBorder.none,
                            floatingLabelBehavior: FloatingLabelBehavior.always,
                          ),
                          textCapitalization: TextCapitalization.none,
                          onChanged: (value) {
                            // Auto-focus to next field
                            if (value.length > 3 && index < 11) {
                              FocusScope.of(context).nextFocus();
                            }
                          },
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),

                  // Alternative: Single text field for quick paste
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Quick Import',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text('Paste your entire seed phrase here:'),
                          const SizedBox(height: 10),
                          TextField(
                            maxLines: 2,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              hintText: 'Paste 12 words separated by spaces',
                            ),
                            onChanged: (value) {
                              if (value.split(' ').length == 12) {
                                final words = value.split(' ');
                                for (int i = 0; i < 12; i++) {
                                  _seedControllers[i].text = words[i];
                                }
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),
          const Card(
            color: Colors.orangeAccent,
            child: Padding(
              padding: EdgeInsets.all(12.0),
              child: Row(
                children: [
                  Icon(Icons.warning, color: Colors.white),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Make sure you are in a private space. Never enter your seed phrase on shared devices.',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _importWallet,
              child: const Text('Import Wallet'),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}