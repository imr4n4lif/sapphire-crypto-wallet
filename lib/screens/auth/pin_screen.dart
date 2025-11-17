import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../home/home_screen.dart';
import '../../providers/auth_provider.dart';

enum PinScreenMode { create, verify, change }

class PinScreen extends StatefulWidget {
  final PinScreenMode mode;
  final VoidCallback? onSuccess;

  const PinScreen({
    super.key,
    required this.mode,
    this.onSuccess,
  });

  @override
  State<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen> {
  String _pin = '';
  String _confirmPin = '';
  bool _isConfirming = false;
  String _error = '';

  String get _title {
    if (widget.mode == PinScreenMode.create) {
      return _isConfirming ? 'Confirm PIN' : 'Create PIN';
    } else if (widget.mode == PinScreenMode.change) {
      return 'Enter New PIN';
    }
    return 'Enter PIN';
  }

  void _onNumberTap(String number) {
    if (_error.isNotEmpty) {
      setState(() => _error = '');
    }

    setState(() {
      if (widget.mode == PinScreenMode.create && !_isConfirming) {
        if (_pin.length < 6) {
          _pin += number;
          if (_pin.length == 6) {
            _isConfirming = true;
          }
        }
      } else if (widget.mode == PinScreenMode.create && _isConfirming) {
        if (_confirmPin.length < 6) {
          _confirmPin += number;
          if (_confirmPin.length == 6) {
            _validateAndCreatePin();
          }
        }
      } else {
        if (_pin.length < 6) {
          _pin += number;
          if (_pin.length == 6) {
            _verifyPin();
          }
        }
      }
    });
  }

  void _onBackspace() {
    setState(() {
      if (widget.mode == PinScreenMode.create && _isConfirming && _confirmPin.isNotEmpty) {
        _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1);
      } else if (_pin.isNotEmpty) {
        _pin = _pin.substring(0, _pin.length - 1);
      }
      _error = '';
    });
  }

  Future<void> _validateAndCreatePin() async {
    if (_pin == _confirmPin) {
      final authProvider = context.read<AuthProvider>();
      await authProvider.setPin(_pin);

      if (widget.onSuccess != null) {
        widget.onSuccess!();
      } else {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        }
      }
    } else {
      setState(() {
        _error = 'PINs do not match';
        _pin = '';
        _confirmPin = '';
        _isConfirming = false;
      });
    }
  }

  Future<void> _verifyPin() async {
    final authProvider = context.read<AuthProvider>();
    final isValid = await authProvider.verifyPin(_pin);

    if (isValid) {
      if (widget.onSuccess != null) {
        widget.onSuccess!();
      } else {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        }
      }
    } else {
      setState(() {
        _error = 'Invalid PIN';
        _pin = '';
      });
    }
  }

  Future<void> _useBiometric() async {
    final authProvider = context.read<AuthProvider>();
    final authenticated = await authProvider.authenticateWithBiometric();

    if (authenticated) {
      if (widget.onSuccess != null) {
        widget.onSuccess!();
      } else {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final currentPin = _isConfirming ? _confirmPin : _pin;

    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            if (_error.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  _error,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(6, (index) {
                final isFilled = index < currentPin.length;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isFilled
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.primary.withOpacity(0.2),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary,
                      width: 2,
                    ),
                  ),
                );
              }),
            ),
            const Spacer(),
            _buildNumberPad(),
            if (widget.mode == PinScreenMode.verify &&
                authProvider.biometricEnabled &&
                authProvider.biometricAvailable)
              Padding(
                padding: const EdgeInsets.only(bottom: 30),
                child: TextButton.icon(
                  onPressed: _useBiometric,
                  icon: const Icon(Icons.fingerprint),
                  label: Text('Use ${authProvider.biometricType}'),
                ),
              )
            else
              const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildNumberPad() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        children: [
          _buildNumberRow(['1', '2', '3']),
          _buildNumberRow(['4', '5', '6']),
          _buildNumberRow(['7', '8', '9']),
          _buildNumberRow(['', '0', 'back']),
        ],
      ),
    );
  }

  Widget _buildNumberRow(List<String> numbers) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: numbers.map((number) {
          if (number.isEmpty) {
            return const SizedBox(width: 70, height: 70);
          }
          if (number == 'back') {
            return _buildNumberButton(
              onTap: _onBackspace,
              child: const Icon(Icons.backspace_outlined, size: 28),
            );
          }
          return _buildNumberButton(
            onTap: () => _onNumberTap(number),
            child: Text(
              number,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w500),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildNumberButton({
    required VoidCallback onTap,
    required Widget child,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(35),
      child: Container(
        width: 70,
        height: 70,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: child,
      ),
    );
  }
}