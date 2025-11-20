import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../home/home_screen.dart';
import '../../providers/auth_provider.dart';
import '../../core/services/biometric_service.dart';

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

class _PinScreenState extends State<PinScreen> with SingleTickerProviderStateMixin {
  String _pin = '';
  String _confirmPin = '';
  bool _isConfirming = false;
  String _error = '';
  bool _hasTriedBiometric = false;
  bool _isBiometricInProgress = false;

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();

    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _shakeAnimation = Tween<double>(
      begin: 0,
      end: 10,
    ).animate(CurvedAnimation(
      parent: _shakeController,
      curve: Curves.elasticIn,
    ));

    // Trigger biometric auth only in verify mode
    if (widget.mode == PinScreenMode.verify) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          _tryBiometricAuth();
        }
      });
    }
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  String get _title {
    if (widget.mode == PinScreenMode.create) {
      return _isConfirming ? 'Confirm Your PIN' : 'Create a PIN';
    } else if (widget.mode == PinScreenMode.change) {
      return 'Enter New PIN';
    }
    return 'Enter Your PIN';
  }

  String get _subtitle {
    if (widget.mode == PinScreenMode.create) {
      return _isConfirming
          ? 'Re-enter your PIN to confirm'
          : 'Choose a 6-digit PIN to secure your wallet';
    } else if (widget.mode == PinScreenMode.change) {
      return 'Create a new 6-digit PIN';
    }
    return 'Enter your PIN to unlock';
  }

  Future<void> _tryBiometricAuth() async {
    if (_hasTriedBiometric || _isBiometricInProgress) {
      return;
    }

    final authProvider = context.read<AuthProvider>();

    if (!authProvider.biometricEnabled || !authProvider.biometricAvailable) {
      return;
    }

    if (!mounted) return;

    setState(() {
      _hasTriedBiometric = true;
      _isBiometricInProgress = true;
    });

    try {
      print('🔐 Attempting biometric authentication...');
      final result = await authProvider.authenticateWithBiometric(
        reason: 'Authenticate to unlock your wallet',
      );

      if (mounted) {
        setState(() => _isBiometricInProgress = false);

        if (result.success) {
          print('✅ Biometric authentication successful');
          _onAuthenticationSuccess();
        } else if (result.isCanceled) {
          print('ℹ️ Biometric authentication canceled');
        } else if (result.isLockedOut) {
          _showError('Too many attempts. Use PIN to unlock.');
        } else {
          print('❌ Biometric authentication failed: ${result.message}');
        }
      }
    } catch (e) {
      print('❌ Biometric authentication error: $e');
      if (mounted) {
        setState(() => _isBiometricInProgress = false);
      }
    }
  }

  void _onAuthenticationSuccess() {
    // Add haptic feedback
    HapticFeedback.lightImpact();

    if (widget.onSuccess != null) {
      widget.onSuccess!();
    } else {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const HomeScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
        ),
      );
    }
  }

  void _onNumberTap(String number) {
    if (_error.isNotEmpty) {
      setState(() => _error = '');
    }

    HapticFeedback.selectionClick();

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
    HapticFeedback.selectionClick();

    setState(() {
      if (widget.mode == PinScreenMode.create && _isConfirming && _confirmPin.isNotEmpty) {
        _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1);
      } else if (_pin.isNotEmpty) {
        _pin = _pin.substring(0, _pin.length - 1);
      }
      _error = '';
    });
  }

  void _showError(String message) {
    setState(() => _error = message);
    _shakeController.forward().then((_) {
      _shakeController.reset();
    });
    HapticFeedback.vibrate();
  }

  Future<void> _validateAndCreatePin() async {
    if (_pin == _confirmPin) {
      try {
        final authProvider = context.read<AuthProvider>();
        await authProvider.setPin(_pin);
        _onAuthenticationSuccess();
      } catch (e) {
        _showError('Failed to create PIN');
        setState(() {
          _pin = '';
          _confirmPin = '';
          _isConfirming = false;
        });
      }
    } else {
      _showError('PINs do not match');
      setState(() {
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
      _onAuthenticationSuccess();
    } else {
      _showError('Incorrect PIN');
      setState(() => _pin = '');
    }
  }

  Future<void> _useBiometric() async {
    if (_isBiometricInProgress) return;

    setState(() => _isBiometricInProgress = true);

    final authProvider = context.read<AuthProvider>();
    final result = await authProvider.authenticateWithBiometric();

    if (mounted) {
      setState(() => _isBiometricInProgress = false);

      if (result.success) {
        _onAuthenticationSuccess();
      } else if (result.isLockedOut) {
        _showError('Too many attempts. Enter PIN to unlock.');
      } else if (!result.isCanceled) {
        _showError(result.error.userFriendlyMessage);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final currentPin = _isConfirming ? _confirmPin : _pin;
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Expanded(
              flex: 2,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Icon
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      widget.mode == PinScreenMode.create
                          ? Icons.lock_outline
                          : Icons.lock_open,
                      size: 40,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _title,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 48),
                    child: Text(
                      _subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.textTheme.bodySmall?.color,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  if (_error.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    AnimatedBuilder(
                      animation: _shakeAnimation,
                      builder: (context, child) {
                        return Transform.translate(
                          offset: Offset(_shakeAnimation.value, 0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.error.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _error,
                              style: TextStyle(
                                color: theme.colorScheme.error,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),

            // PIN Dots
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(6, (index) {
                  final isFilled = index < currentPin.length;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    width: isFilled ? 20 : 16,
                    height: isFilled ? 20 : 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isFilled
                          ? theme.colorScheme.primary
                          : theme.colorScheme.primary.withOpacity(0.2),
                      border: Border.all(
                        color: theme.colorScheme.primary,
                        width: 2,
                      ),
                    ),
                  );
                }),
              ),
            ),

            const SizedBox(height: 48),

            // Number Pad
            Expanded(
              flex: 3,
              child: _buildNumberPad(),
            ),

            // Biometric Button
            if (widget.mode == PinScreenMode.verify &&
                authProvider.biometricEnabled &&
                authProvider.biometricAvailable)
              Padding(
                padding: const EdgeInsets.only(bottom: 32),
                child: _isBiometricInProgress
                    ? const CircularProgressIndicator()
                    : TextButton.icon(
                  onPressed: _useBiometric,
                  icon: Icon(
                    Icons.fingerprint,
                    size: 28,
                    color: theme.colorScheme.primary,
                  ),
                  label: Text(
                    'Use ${authProvider.biometricType}',
                    style: TextStyle(
                      fontSize: 16,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
              )
            else
              const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildNumberPad() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: numbers.map((number) {
        if (number.isEmpty) {
          return const SizedBox(width: 75, height: 75);
        }
        if (number == 'back') {
          return _buildNumberButton(
            onTap: _onBackspace,
            child: Icon(
              Icons.backspace_outlined,
              size: 28,
              color: Theme.of(context).colorScheme.primary,
            ),
          );
        }
        return _buildNumberButton(
          onTap: () => _onNumberTap(number),
          child: Text(
            number,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildNumberButton({
    required VoidCallback onTap,
    required Widget child,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(40),
        splashColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
        highlightColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
        child: Container(
          width: 75,
          height: 75,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
              width: 2,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}