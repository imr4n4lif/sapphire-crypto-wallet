import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';

class BiometricService {
  static final BiometricService _instance = BiometricService._internal();
  factory BiometricService() => _instance;
  BiometricService._internal();

  final LocalAuthentication _localAuth = LocalAuthentication();
  bool _isAuthenticating = false;

  Future<bool> canCheckBiometrics() async {
    try {
      return await _localAuth.canCheckBiometrics;
    } on PlatformException catch (e) {
      print('❌ canCheckBiometrics error: $e');
      return false;
    }
  }

  Future<bool> isDeviceSupported() async {
    try {
      return await _localAuth.isDeviceSupported();
    } on PlatformException catch (e) {
      print('❌ isDeviceSupported error: $e');
      return false;
    }
  }

  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } on PlatformException catch (e) {
      print('❌ getAvailableBiometrics error: $e');
      return <BiometricType>[];
    }
  }

  Future<bool> authenticate({
    String reason = 'Please authenticate to access your wallet',
  }) async {
    // Prevent multiple simultaneous authentication attempts
    if (_isAuthenticating) {
      print('⚠️ Authentication already in progress');
      return false;
    }

    try {
      _isAuthenticating = true;
      print('🔐 Starting biometric authentication...');

      final canAuthenticate = await canCheckBiometrics() || await isDeviceSupported();

      if (!canAuthenticate) {
        print('⚠️ Device cannot authenticate');
        return false;
      }

      final availableBiometrics = await getAvailableBiometrics();
      if (availableBiometrics.isEmpty) {
        print('⚠️ No biometrics enrolled');
        return false;
      }

      print('🔐 Available biometrics: $availableBiometrics');

      final result = await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,  // Allow fallback to PIN/pattern
          useErrorDialogs: true,
          sensitiveTransaction: true,
        ),
      );

      print('🔐 Authentication result: $result');
      return result;
    } on PlatformException catch (e) {
      print('❌ Biometric authentication error: ${e.code}');

      // Handle specific error codes
      switch (e.code) {
        case 'NotAvailable':
        case 'NotEnrolled':
        case 'PasscodeNotSet':
          print('ℹ️ Biometric not available: ${e.message}');
          break;
        case 'LockedOut':
        case 'PermanentlyLockedOut':
          print('🔒 Biometric locked out: ${e.message}');
          break;
        case 'UserCancel':
        case 'auth_in_progress':
          print('ℹ️ User cancelled or already authenticating');
          break;
        default:
          print('ℹ️ Other biometric error: ${e.code} - ${e.message}');
      }

      return false;
    } catch (e) {
      print('❌ Unexpected biometric error: $e');
      return false;
    } finally {
      _isAuthenticating = false;
    }
  }

  Future<void> stopAuthentication() async {
    try {
      await _localAuth.stopAuthentication();
      _isAuthenticating = false;
    } on PlatformException catch (e) {
      print('⚠️ Stop authentication error: $e');
    }
  }

  Future<String> getBiometricTypeString() async {
    final biometrics = await getAvailableBiometrics();
    if (biometrics.contains(BiometricType.face)) {
      return 'Face ID';
    } else if (biometrics.contains(BiometricType.fingerprint)) {
      return 'Fingerprint';
    } else if (biometrics.contains(BiometricType.strong)) {
      return 'Biometric Authentication';
    } else if (biometrics.contains(BiometricType.weak)) {
      return 'Device Credentials';
    }
    return 'Biometric Authentication';
  }

  bool get isAuthenticating => _isAuthenticating;
}