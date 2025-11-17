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
    _biometricAvailable = await _biometric.canCheckBiometrics() &&
        await _biometric.isDeviceSupported();
    _biometricEnabled = await _storage.readBool(AppConstants.keyBiometricEnabled);

    if (_biometricAvailable) {
      _biometricType = await _biometric.getBiometricTypeString();
    }

    notifyListeners();
  }

  Future<bool> hasPin() async {
    final pin = await _storage.readSecure('pin_hash');
    return pin != null;
  }

  Future<void> setPin(String pin) async {
    await _storage.savePin(pin);
    notifyListeners();
  }

  Future<bool> verifyPin(String pin) async {
    final isValid = await _storage.verifyPin(pin);
    if (isValid) {
      _isAuthenticated = true;
      notifyListeners();
    }
    return isValid;
  }

  Future<bool> authenticateWithBiometric() async {
    if (!_biometricAvailable || !_biometricEnabled) {
      return false;
    }

    final authenticated = await _biometric.authenticate();
    if (authenticated) {
      _isAuthenticated = true;
      notifyListeners();
    }
    return authenticated;
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    _biometricEnabled = enabled;
    await _storage.saveBool(AppConstants.keyBiometricEnabled, enabled);
    notifyListeners();
  }

  void logout() {
    _isAuthenticated = false;
    notifyListeners();
  }

  Future<void> changePin(String oldPin, String newPin) async {
    final isValid = await _storage.verifyPin(oldPin);
    if (!isValid) {
      throw Exception('Invalid current PIN');
    }
    await _storage.savePin(newPin);
  }
}