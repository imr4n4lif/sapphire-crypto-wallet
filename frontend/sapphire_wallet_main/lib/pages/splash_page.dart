// lib/pages/splash_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/wallet_provider.dart';
import '../services/security/secure_storage_service.dart';
import 'auth/pin_setup_page.dart';
import 'auth/pin_login_page.dart';
import 'wallet/create_import_wallet_page.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await Future.delayed(const Duration(seconds: 2));

    final storage = SecureStorageService();
    await storage.initialize();

    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    await walletProvider.initialize();

    if (!mounted) return;

    // Check if PIN is set
    final pin = await storage.getPin();
    if (pin == null) {
      // No PIN set, go to PIN setup
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const PinSetupPage()),
      );
      return;
    }

    // PIN is set, check if wallet exists
    if (!walletProvider.hasWallet) {
      // No wallet, go to create/import
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const CreateImportWalletPage()),
      );
      return;
    }

    // Everything exists, go to PIN login
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const PinLoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.secondary,
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.diamond,
                  size: 60,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'Sapphire Wallet',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Secure • Private • Decentralized',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 48),
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}