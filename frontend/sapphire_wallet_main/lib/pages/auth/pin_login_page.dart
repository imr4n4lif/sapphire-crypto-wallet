// lib/pages/auth/pin_login_page.dart
import 'package:flutter/material.dart';
import '../../services/security/secure_storage_service.dart';
import '../../services/security/biometric_service.dart';
import '../home_page.dart';

class PinLoginPage extends StatefulWidget {
  const PinLoginPage({super.key});

  @override
  State<PinLoginPage> createState() => _PinLoginPageState();
}

class _PinLoginPageState extends State<PinLoginPage> {
  String _pin = '';
  bool _isError = false;
  final _storage = SecureStorageService();
  final _biometric = BiometricService();
  bool _biometricAvailable = false;

  @override
  void initState() {
    super.initState();
    _checkBiometric();
  }

  Future<void> _checkBiometric() async {
    final canCheck = await _biometric.canCheckBiometrics();
    final enabled = await _storage.isBiometricEnabled();
    setState(() {
      _biometricAvailable = canCheck && enabled;
    });
    if (_biometricAvailable) {
      _authenticateWithBiometric();
    }
  }

  Future<void> _authenticateWithBiometric() async {
    final authenticated = await _biometric.authenticate(
      reason: 'Authenticate to access your wallet',
    );
    if (authenticated && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomePage()),
      );
    }
  }

  void _onNumberTap(String number) {
    if (_pin.length < 6) {
      setState(() {
        _pin += number;
        _isError = false;
        if (_pin.length == 6) {
          _verifyPin();
        }
      });
    }
  }

  void _onDeleteTap() {
    if (_pin.isNotEmpty) {
      setState(() {
        _pin = _pin.substring(0, _pin.length - 1);
        _isError = false;
      });
    }
  }

  Future<void> _verifyPin() async {
    final isValid = await _storage.verifyPin(_pin);
    if (isValid && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomePage()),
      );
    } else {
      setState(() {
        _isError = true;
        _pin = '';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Incorrect PIN')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const SizedBox(height: 40),
              Icon(
                Icons.lock_outline,
                size: 80,
                color: _isError ? Colors.red : Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 32),
              Text(
                'Enter Your PIN',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter your 6-digit PIN to unlock',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 48),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(6, (index) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: index < _pin.length
                          ? (_isError ? Colors.red : Theme.of(context).colorScheme.primary)
                          : Colors.grey.shade300,
                    ),
                  );
                }),
              ),
              const Spacer(),
              if (_biometricAvailable)
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: IconButton(
                    onPressed: _authenticateWithBiometric,
                    icon: const Icon(Icons.fingerprint),
                    iconSize: 48,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              _buildNumberPad(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNumberPad() {
    return Column(
      children: [
        _buildNumberRow(['1', '2', '3']),
        const SizedBox(height: 16),
        _buildNumberRow(['4', '5', '6']),
        const SizedBox(height: 16),
        _buildNumberRow(['7', '8', '9']),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            const SizedBox(width: 80),
            _buildNumberButton('0'),
            SizedBox(
              width: 80,
              child: IconButton(
                onPressed: _onDeleteTap,
                icon: const Icon(Icons.backspace_outlined),
                iconSize: 28,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNumberRow(List<String> numbers) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: numbers.map((n) => _buildNumberButton(n)).toList(),
    );
  }

  Widget _buildNumberButton(String number) {
    return SizedBox(
      width: 80,
      height: 80,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _onNumberTap(number),
          borderRadius: BorderRadius.circular(40),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w500),
              ),
            ),
          ),
        ),
      ),
    );
  }
}