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

  bool get isAuthenticated => _isAuthenticated;
  bool get biometricEnabled => _biometricEnabled;
  bool get biometricAvailable => _biometricAvailable;
  String get biometricType => _biometricType;

  Future<void> initialize() async {
    print('🔐 Initializing AuthProvider...');

    // Check if biometric is available
    final canCheck = await _biometric.canCheckBiometrics();
    final isSupported = await _biometric.isDeviceSupported();
    _biometricAvailable = canCheck && isSupported;

    print('🔐 Biometric available: $_biometricAvailable (canCheck: $canCheck, isSupported: $isSupported)');

    // Check if biometric is enabled in settings
    _biometricEnabled = await _storage.readBool(AppConstants.keyBiometricEnabled);
    print('🔐 Biometric enabled in settings: $_biometricEnabled');

    if (_biometricAvailable) {
      _biometricType = await _biometric.getBiometricTypeString();
      print('🔐 Biometric type: $_biometricType');

      // List available biometrics for debugging
      final available = await _biometric.getAvailableBiometrics();
      print('🔐 Available biometric types: $available');
    } else {
      print('⚠️ Biometric not available on this device');
    }

    notifyListeners();
  }

  Future<bool> hasPin() async {
    final pin = await _storage.readSecure('pin_hash');
    final hasPin = pin != null;
    print('🔐 Has PIN: $hasPin');
    return hasPin;
  }

  Future<void> setPin(String pin) async {
    print('🔐 Setting new PIN...');
    await _storage.savePin(pin);
    notifyListeners();
  }

  Future<bool> verifyPin(String pin) async {
    print('🔐 Verifying PIN...');
    final isValid = await _storage.verifyPin(pin);
    print('🔐 PIN valid: $isValid');

    if (isValid) {
      _isAuthenticated = true;
      notifyListeners();
    }
    return isValid;
  }

  Future<bool> authenticateWithBiometric() async {
    print('🔐 authenticateWithBiometric called');
    print('🔐 - Available: $_biometricAvailable');
    print('🔐 - Enabled: $_biometricEnabled');

    if (!_biometricAvailable) {
      print('⚠️ Biometric not available, cannot authenticate');
      return false;
    }

    if (!_biometricEnabled) {
      print('⚠️ Biometric not enabled in settings, cannot authenticate');
      return false;
    }

    print('🔐 Calling BiometricService.authenticate()...');
    final authenticated = await _biometric.authenticate(
        reason: 'Please authenticate to access your wallet'
    );

    print('🔐 Biometric authentication result: $authenticated');

    if (authenticated) {
      _isAuthenticated = true;
      notifyListeners();
    }
    return authenticated;
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    print('🔐 Setting biometric enabled: $enabled');
    _biometricEnabled = enabled;
    await _storage.saveBool(AppConstants.keyBiometricEnabled, enabled);
    notifyListeners();
  }

  void logout() {
    print('🔐 Logging out...');
    _isAuthenticated = false;
    notifyListeners();
  }

  Future<void> changePin(String oldPin, String newPin) async {
    print('🔐 Changing PIN...');
    final isValid = await _storage.verifyPin(oldPin);
    if (!isValid) {
      throw Exception('Invalid current PIN');
    }
    await _storage.savePin(newPin);
    print('✅ PIN changed successfully');
  }
}