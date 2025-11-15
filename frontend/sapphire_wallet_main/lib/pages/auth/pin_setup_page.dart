// lib/pages/auth/pin_setup_page.dart
import 'package:flutter/material.dart';
import '../../services/security/secure_storage_service.dart';
import 'pin_login_page.dart';

class PinSetupPage extends StatefulWidget {
  const PinSetupPage({super.key});

  @override
  State<PinSetupPage> createState() => _PinSetupPageState();
}

class _PinSetupPageState extends State<PinSetupPage> {
  String _pin = '';
  String _confirmPin = '';
  bool _isConfirming = false;
  final _storage = SecureStorageService();

  void _onNumberTap(String number) {
    setState(() {
      if (_isConfirming) {
        if (_confirmPin.length < 6) {
          _confirmPin += number;
          if (_confirmPin.length == 6) {
            _verifyPin();
          }
        }
      } else {
        if (_pin.length < 6) {
          _pin += number;
          if (_pin.length == 6) {
            _isConfirming = true;
          }
        }
      }
    });
  }

  void _onDeleteTap() {
    setState(() {
      if (_isConfirming) {
        if (_confirmPin.isNotEmpty) {
          _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1);
        }
      } else {
        if (_pin.isNotEmpty) {
          _pin = _pin.substring(0, _pin.length - 1);
        }
      }
    });
  }

  Future<void> _verifyPin() async {
    if (_pin == _confirmPin) {
      await _storage.setPin(_pin);
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const PinLoginPage()),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PINs do not match. Try again.')),
      );
      setState(() {
        _pin = '';
        _confirmPin = '';
        _isConfirming = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentPin = _isConfirming ? _confirmPin : _pin;

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
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 32),
              Text(
                _isConfirming ? 'Confirm Your PIN' : 'Create a PIN',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _isConfirming
                    ? 'Enter your PIN again to confirm'
                    : 'Create a 6-digit PIN to secure your wallet',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(6, (index) {
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: index < currentPin.length
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey.shade300,
                    ),
                  );
                }),
              ),
              const Spacer(),
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