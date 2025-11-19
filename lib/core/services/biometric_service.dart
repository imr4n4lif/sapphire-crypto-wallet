import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';

class BiometricService {
  static final BiometricService _instance = BiometricService._internal();
  factory BiometricService() => _instance;
  BiometricService._internal();

  final LocalAuthentication _localAuth = LocalAuthentication();

  // Check if device supports biometric authentication
  Future<bool> canCheckBiometrics() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      print('🔐 canCheckBiometrics: $canCheck');
      return canCheck;
    } on PlatformException catch (e) {
      print('❌ canCheckBiometrics error: $e');
      return false;
    }
  }

  // Check if device has biometrics enrolled
  Future<bool> isDeviceSupported() async {
    try {
      final isSupported = await _localAuth.isDeviceSupported();
      print('🔐 isDeviceSupported: $isSupported');
      return isSupported;
    } on PlatformException catch (e) {
      print('❌ isDeviceSupported error: $e');
      return false;
    }
  }

  // Get available biometrics
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      final biometrics = await _localAuth.getAvailableBiometrics();
      print('🔐 Available biometrics: $biometrics');
      return biometrics;
    } on PlatformException catch (e) {
      print('❌ getAvailableBiometrics error: $e');
      return <BiometricType>[];
    }
  }

  // Authenticate with biometrics - IMPROVED
  Future<bool> authenticate({
    String reason = 'Please authenticate to access your wallet',
  }) async {
    try {
      print('🔐 Starting biometric authentication...');

      final bool canAuthenticateWithBiometrics = await canCheckBiometrics();
      final bool canAuthenticate = canAuthenticateWithBiometrics || await _localAuth.isDeviceSupported();

      print('🔐 Can authenticate: $canAuthenticate');

      if (!canAuthenticate) {
        print('⚠️ Device cannot authenticate with biometrics');
        return false;
      }

      final availableBiometrics = await getAvailableBiometrics();
      print('🔐 Available biometric types: $availableBiometrics');

      if (availableBiometrics.isEmpty) {
        print('⚠️ No biometrics enrolled on device');
        return false;
      }

      print('🔐 Calling authenticate() with reason: $reason');
      final result = await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true, // Changed to true for better security
          useErrorDialogs: true,
          sensitiveTransaction: true,
        ),
      );

      print('🔐 Authentication result: $result');
      return result;
    } on PlatformException catch (e) {
      print('❌ Biometric authentication error: ${e.code} - ${e.message}');

      if (e.code == 'NotAvailable') {
        print('ℹ️ Biometric authentication not available');
      } else if (e.code == 'NotEnrolled') {
        print('ℹ️ No biometrics enrolled');
      } else if (e.code == 'LockedOut') {
        print('ℹ️ Biometric authentication locked out');
      } else if (e.code == 'PermanentlyLockedOut') {
        print('ℹ️ Biometric authentication permanently locked out');
      } else if (e.code == 'UserCancel' || e.code == 'auth_in_progress') {
        print('ℹ️ User cancelled authentication');
      } else if (e.code == 'PasscodeNotSet') {
        print('ℹ️ Device passcode not set');
      } else {
        print('ℹ️ Other error: ${e.code}');
      }

      return false;
    } catch (e) {
      print('❌ Unexpected biometric error: $e');
      return false;
    }
  }

  // Stop authentication
  Future<void> stopAuthentication() async {
    try {
      await _localAuth.stopAuthentication();
    } on PlatformException catch (e) {
      print('⚠️ Stop authentication error: $e');
    }
  }

  // Get biometric type string for display
  Future<String> getBiometricTypeString() async {
    final biometrics = await getAvailableBiometrics();
    if (biometrics.contains(BiometricType.face)) {
      return 'Face ID';
    } else if (biometrics.contains(BiometricType.fingerprint)) {
      return 'Fingerprint';
    } else if (biometrics.contains(BiometricType.strong) ||
        biometrics.contains(BiometricType.weak)) {
      return 'Biometric';
    }
    return 'Biometric Authentication';
  }
}