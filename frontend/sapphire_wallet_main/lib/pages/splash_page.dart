import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../providers/wallet_provider.dart';
import 'create_import_wallet_page.dart';
import 'home_page.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    _navigateToNext();
  }

  void _navigateToNext() async {
    await Future.delayed(const Duration(seconds: 2));

    final walletProvider = Provider.of<WalletProvider>(context, listen: false);

    if (walletProvider.isWalletCreated) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomePage()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const CreateImportWalletPage()),
      );
    }
  }

  Widget _buildSapphireLogo() {
    try {
      return SvgPicture.asset(
        'assets/svg/sapphire_logo.svg',
        width: 100,
        height: 100,
        color: Colors.white,
      );
    } catch (e) {
      // Fallback to diamond icon if SVG fails to load
      return const Icon(
        Icons.diamond,
        size: 80,
        color: Colors.white,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildSapphireLogo(),
            const SizedBox(height: 20),
            Text(
              'Sapphire Wallet',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}