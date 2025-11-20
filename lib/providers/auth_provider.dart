import 'package:flutter/material.dart';
import '../core/services/secure_storage_service.dart';
import '../core/services/biometric_service.dart';
import '../core/constants/app_constants.dart';

class AuthProvider with ChangeNotifier {
  final SecureStorageService _storage = SecureStorageService();
  final BiometricService _biometric = BiometricService();

  bool _isAuthenticated = false;
  bool _biometricEnabled = false;
  bool _biometricAvailable = false;
  String _biometricType = 'Biometric';
  BiometricAuthResult? _lastBiometricResult;

  bool get isAuthenticated => _isAuthenticated;
  bool get biometricEnabled => _biometricEnabled;
  bool get biometricAvailable => _biometricAvailable;
  String get biometricType => _biometricType;
  BiometricAuthResult? get lastBiometricResult => _lastBiometricResult;

  Future<void> initialize() async {
    print('🔐 Initializing AuthProvider...');

    try {
      // Check biometric hardware availability
      _biometricAvailable = await _biometric.hasBiometricHardware();
      print('🔐 Biometric hardware available: $_biometricAvailable');

      // Get biometric enabled setting
      _biometricEnabled = await _storage.readBool(AppConstants.keyBiometricEnabled);
      print('🔐 Biometric enabled in settings: $_biometricEnabled');

      // Check if biometrics are enrolled
      if (_biometricAvailable) {
        final enrolled = await _biometric.hasBiometricsEnrolled();
        if (!enrolled) {
          _biometricAvailable = false;
          _biometricEnabled = false;
          await _storage.saveBool(AppConstants.keyBiometricEnabled, false);
          print('⚠️ No biometrics enrolled, disabling biometric auth');
        } else {
          _biometricType = await _biometric.getBiometricTypeString();
          print('🔐 Biometric type: $_biometricType');
        }
      }

      // If biometric was enabled but now not available, disable it
      if (_biometricEnabled && !_biometricAvailable) {
        _biometricEnabled = false;
        await _storage.saveBool(AppConstants.keyBiometricEnabled, false);
      }

      notifyListeners();
    } catch (e) {
      print('❌ Error initializing auth: $e');
      _biometricAvailable = false;
      _biometricEnabled = false;
      notifyListeners();
    }
  }

  Future<bool> hasPin() async {
    try {
      final pin = await _storage.readSecure('pin_hash');
      final hasPin = pin != null && pin.isNotEmpty;
      print('🔐 Has PIN: $hasPin');
      return hasPin;
    } catch (e) {
      print('❌ Error checking PIN: $e');
      return false;
    }
  }

  Future<void> setPin(String pin) async {
    if (pin.length != 6 || !RegExp(r'^\d{6}$').hasMatch(pin)) {
      throw Exception('PIN must be exactly 6 digits');
    }

    print('🔐 Setting new PIN...');
    try {
      await _storage.savePin(pin);
      _isAuthenticated = true;
      notifyListeners();
      print('✅ PIN set successfully');
    } catch (e) {
      print('❌ Error setting PIN: $e');
      throw Exception('Failed to set PIN');
    }
  }

  Future<bool> verifyPin(String pin) async {
    print('🔐 Verifying PIN...');
    try {
      final isValid = await _storage.verifyPin(pin);
      print('🔐 PIN valid: $isValid');

      if (isValid) {
        _isAuthenticated = true;
        _biometric.resetFailedAttempts(); // Reset biometric lockout on successful PIN
        notifyListeners();
      }
      return isValid;
    } catch (e) {
      print('❌ Error verifying PIN: $e');
      return false;
    }
  }

  Future<BiometricAuthResult> authenticateWithBiometric({
    String? reason,
  }) async {
    print('🔐 authenticateWithBiometric called');

    if (!_biometricAvailable) {
      print('⚠️ Biometric not available');
      return BiometricAuthResult(
        success: false,
        error: BiometricError.notAvailable,
        message: 'Biometric authentication not available',
      );
    }

    if (!_biometricEnabled) {
      print('⚠️ Biometric not enabled');
      return BiometricAuthResult(
        success: false,
        error: BiometricError.notAvailable,
        message: 'Biometric authentication not enabled',
      );
    }

    print('🔐 Calling BiometricService.authenticate()...');
    final result = await _biometric.authenticate(
      reason: reason ?? 'Please authenticate to access your wallet',
    );

    _lastBiometricResult = result;
    print('🔐 Biometric authentication result: ${result.success}');

    if (result.success) {
      _isAuthenticated = true;
      notifyListeners();
    }

    return result;
  }

  Future<bool> setBiometricEnabled(bool enabled) async {
    print('🔐 Setting biometric enabled: $enabled');

    // Check prerequisites
    if (!_biometricAvailable) {
      print('⚠️ Cannot enable - biometric not available');
      return false;
    }

    // If enabling, confirm with biometric first
    if (enabled) {
      // Check if biometrics are enrolled
      final enrolled = await _biometric.hasBiometricsEnrolled();
      if (!enrolled) {
        print('⚠️ No biometrics enrolled');
        throw Exception('Please enroll biometrics in your device settings first');
      }

      print('🔐 Confirming with biometric before enabling...');
      final result = await _biometric.authenticate(
        reason: 'Authenticate to enable $_biometricType',
      );

      if (!result.success) {
        print('⚠️ Biometric confirmation failed: ${result.message}');

        // Throw specific errors for better UI handling
        if (result.requiresSetup) {
          throw Exception(result.message);
        }
        return false;
      }
    }

    _biometricEnabled = enabled;
    await _storage.saveBool(AppConstants.keyBiometricEnabled, enabled);
    notifyListeners();

    print('✅ Biometric ${enabled ? "enabled" : "disabled"} successfully');
    return true;
  }

  void logout() {
    print('🔐 Logging out...');
    _isAuthenticated = false;
    _lastBiometricResult = null;
    notifyListeners();
  }

  Future<void> changePin(String oldPin, String newPin) async {
    print('🔐 Changing PIN...');

    // Validate new PIN format
    if (newPin.length != 6 || !RegExp(r'^\d{6}$').hasMatch(newPin)) {
      throw Exception('New PIN must be exactly 6 digits');
    }

    // Verify old PIN
    final isValid = await _storage.verifyPin(oldPin);
    if (!isValid) {
      throw Exception('Current PIN is incorrect');
    }

    // Set new PIN
    await _storage.savePin(newPin);
    print('✅ PIN changed successfully');

    notifyListeners();
  }

  // Check if should prompt for biometric on app launch
  Future<bool> shouldPromptBiometric() async {
    if (!_biometricEnabled || !_biometricAvailable) {
      return false;
    }

    // Check if biometrics are still enrolled
    final enrolled = await _biometric.hasBiometricsEnrolled();
    if (!enrolled) {
      // Disable biometric if no longer enrolled
      await setBiometricEnabled(false);
      return false;
    }

    return true;
  }

  // Force re-authentication (useful for sensitive operations)
  Future<bool> requireAuthentication({
    bool allowBiometric = true,
    String? reason,
  }) async {
    if (!_isAuthenticated) {
      return false;
    }

    // Try biometric first if allowed and available
    if (allowBiometric && _biometricEnabled && _biometricAvailable) {
      final result = await authenticateWithBiometric(reason: reason);
      if (result.success) {
        return true;
      }
    }

    // Fall back to PIN or return false
    return false;
  }

  // Get lockout status
  Duration? getBiometricLockoutTime() {
    return _biometric.getRemainingLockoutTime();
  }

  // Check if biometric is locked out
  bool get isBiometricLockedOut {
    final lockoutTime = getBiometricLockoutTime();
    return lockoutTime != null && lockoutTime.inSeconds > 0;
  }

  // Reset authentication state (for testing)
  @visibleForTesting
  void resetAuthState() {
    _isAuthenticated = false;
    _lastBiometricResult = null;
    notifyListeners();
  }
}