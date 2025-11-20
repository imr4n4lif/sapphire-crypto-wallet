import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';

class BiometricService {
  static final BiometricService _instance = BiometricService._internal();
  factory BiometricService() => _instance;
  BiometricService._internal();

  final LocalAuthentication _localAuth = LocalAuthentication();
  bool _isAuthenticating = false;
  DateTime? _lastAuthAttempt;
  int _failedAttempts = 0;
  static const int _maxAttempts = 3;
  static const Duration _lockoutDuration = Duration(minutes: 1);

  // Check if biometrics can be used
  Future<bool> canCheckBiometrics() async {
    try {
      return await _localAuth.canCheckBiometrics;
    } on PlatformException catch (e) {
      print('❌ canCheckBiometrics error: $e');
      return false;
    }
  }

  // Check if device supports biometrics
  Future<bool> isDeviceSupported() async {
    try {
      return await _localAuth.isDeviceSupported();
    } on PlatformException catch (e) {
      print('❌ isDeviceSupported error: $e');
      return false;
    }
  }

  // Get available biometric types
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      final biometrics = await _localAuth.getAvailableBiometrics();
      print('📱 Available biometrics: $biometrics');
      return biometrics;
    } on PlatformException catch (e) {
      print('❌ getAvailableBiometrics error: $e');
      return <BiometricType>[];
    }
  }

  // Check if currently locked out
  bool _isLockedOut() {
    if (_lastAuthAttempt == null) return false;
    if (_failedAttempts < _maxAttempts) return false;

    final timeSinceLastAttempt = DateTime.now().difference(_lastAuthAttempt!);
    if (timeSinceLastAttempt < _lockoutDuration) {
      print('🔒 Biometric locked out for ${_lockoutDuration.inSeconds - timeSinceLastAttempt.inSeconds} seconds');
      return true;
    }

    // Reset after lockout period
    _failedAttempts = 0;
    return false;
  }

  // Main authentication method with enhanced error handling
  Future<BiometricAuthResult> authenticate({
    String reason = 'Please authenticate to access your wallet',
    bool stickyAuth = true,
  }) async {
    // Check for ongoing authentication
    if (_isAuthenticating) {
      print('⚠️ Authentication already in progress');
      return BiometricAuthResult(
        success: false,
        error: BiometricError.authInProgress,
        message: 'Authentication already in progress',
      );
    }

    // Check for lockout
    if (_isLockedOut()) {
      final remainingTime = _lockoutDuration - DateTime.now().difference(_lastAuthAttempt!);
      return BiometricAuthResult(
        success: false,
        error: BiometricError.lockedOut,
        message: 'Too many failed attempts. Try again in ${remainingTime.inSeconds} seconds',
      );
    }

    try {
      _isAuthenticating = true;
      _lastAuthAttempt = DateTime.now();
      print('🔐 Starting biometric authentication...');

      // Check if biometrics are available
      final canAuthenticate = await canCheckBiometrics() || await isDeviceSupported();
      if (!canAuthenticate) {
        print('⚠️ Device cannot authenticate');
        return BiometricAuthResult(
          success: false,
          error: BiometricError.notAvailable,
          message: 'Biometric authentication not available',
        );
      }

      // Check enrolled biometrics
      final availableBiometrics = await getAvailableBiometrics();
      if (availableBiometrics.isEmpty) {
        print('⚠️ No biometrics enrolled');
        return BiometricAuthResult(
          success: false,
          error: BiometricError.notEnrolled,
          message: 'No biometrics enrolled on device',
        );
      }

      print('🔐 Available biometrics: $availableBiometrics');

      // Attempt authentication
      final result = await _localAuth.authenticate(
        localizedReason: reason,
        options: AuthenticationOptions(
          stickyAuth: stickyAuth,
          biometricOnly: false, // Allow PIN/pattern fallback
          useErrorDialogs: true,
          sensitiveTransaction: true,
        ),
      );

      print('🔐 Authentication result: $result');

      if (result) {
        _failedAttempts = 0;
        return BiometricAuthResult(
          success: true,
          error: BiometricError.none,
          message: 'Authentication successful',
        );
      } else {
        _failedAttempts++;
        return BiometricAuthResult(
          success: false,
          error: BiometricError.failed,
          message: 'Authentication failed',
        );
      }
    } on PlatformException catch (e) {
      print('❌ Biometric authentication error: ${e.code}');
      _failedAttempts++;

      // Map platform errors to BiometricError enum
      BiometricError error;
      String message;

      switch (e.code) {
        case 'no_fragment_activity':
          error = BiometricError.noFragmentActivity;
          message = 'Activity configuration error. Please contact support.';
          break;
        case 'NotAvailable':
          error = BiometricError.notAvailable;
          message = 'Biometric authentication not available';
          break;
        case 'NotEnrolled':
          error = BiometricError.notEnrolled;
          message = 'No biometrics enrolled. Please set up biometrics in device settings.';
          break;
        case 'PasscodeNotSet':
          error = BiometricError.passcodeNotSet;
          message = 'Device passcode not set. Please set up a passcode first.';
          break;
        case 'LockedOut':
          error = BiometricError.lockedOut;
          message = 'Biometric locked due to too many failed attempts';
          break;
        case 'PermanentlyLockedOut':
          error = BiometricError.permanentlyLockedOut;
          message = 'Biometric permanently locked. Use passcode to unlock.';
          break;
        case 'UserCancel':
          error = BiometricError.userCanceled;
          message = 'Authentication cancelled by user';
          _failedAttempts--; // Don't count cancellation as failed attempt
          break;
        case 'auth_in_progress':
          error = BiometricError.authInProgress;
          message = 'Another authentication in progress';
          _failedAttempts--;
          break;
        default:
          error = BiometricError.unknown;
          message = e.message ?? 'Unknown error occurred';
      }

      return BiometricAuthResult(
        success: false,
        error: error,
        message: message,
        platformError: e.code,
      );
    } catch (e) {
      print('❌ Unexpected biometric error: $e');
      _failedAttempts++;
      return BiometricAuthResult(
        success: false,
        error: BiometricError.unknown,
        message: 'Unexpected error occurred',
      );
    } finally {
      _isAuthenticating = false;
    }
  }

  // Stop ongoing authentication
  Future<void> stopAuthentication() async {
    try {
      await _localAuth.stopAuthentication();
      _isAuthenticating = false;
      print('✅ Authentication stopped');
    } on PlatformException catch (e) {
      print('⚠️ Stop authentication error: $e');
    }
  }

  // Get biometric type as user-friendly string
  Future<String> getBiometricTypeString() async {
    try {
      final biometrics = await getAvailableBiometrics();

      if (biometrics.contains(BiometricType.face)) {
        return 'Face ID';
      } else if (biometrics.contains(BiometricType.fingerprint)) {
        return 'Fingerprint';
      } else if (biometrics.contains(BiometricType.iris)) {
        return 'Iris Scan';
      } else if (biometrics.contains(BiometricType.strong)) {
        return 'Biometric Authentication';
      } else if (biometrics.contains(BiometricType.weak)) {
        return 'Device Credentials';
      }

      return 'Biometric Authentication';
    } catch (e) {
      return 'Biometric Authentication';
    }
  }

  // Check if biometric hardware exists
  Future<bool> hasBiometricHardware() async {
    try {
      final isSupported = await isDeviceSupported();
      final canCheck = await canCheckBiometrics();
      return isSupported || canCheck;
    } catch (e) {
      return false;
    }
  }

  // Check if biometrics are enrolled
  Future<bool> hasBiometricsEnrolled() async {
    try {
      final biometrics = await getAvailableBiometrics();
      return biometrics.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // Reset failed attempts (call after successful PIN entry)
  void resetFailedAttempts() {
    _failedAttempts = 0;
    _lastAuthAttempt = null;
  }

  // Get remaining lockout time
  Duration? getRemainingLockoutTime() {
    if (!_isLockedOut()) return null;
    if (_lastAuthAttempt == null) return null;

    final elapsed = DateTime.now().difference(_lastAuthAttempt!);
    final remaining = _lockoutDuration - elapsed;

    return remaining.isNegative ? null : remaining;
  }

  // Getters
  bool get isAuthenticating => _isAuthenticating;
  int get failedAttempts => _failedAttempts;
  int get maxAttempts => _maxAttempts;
}

// Result class for better error handling
class BiometricAuthResult {
  final bool success;
  final BiometricError error;
  final String message;
  final String? platformError;

  BiometricAuthResult({
    required this.success,
    required this.error,
    required this.message,
    this.platformError,
  });

  bool get isSuccess => success;
  bool get isCanceled => error == BiometricError.userCanceled;
  bool get isLockedOut => error == BiometricError.lockedOut ||
      error == BiometricError.permanentlyLockedOut;
  bool get requiresSetup => error == BiometricError.notEnrolled ||
      error == BiometricError.passcodeNotSet;
}

// Error types enum
enum BiometricError {
  none,
  notAvailable,
  notEnrolled,
  passcodeNotSet,
  lockedOut,
  permanentlyLockedOut,
  userCanceled,
  failed,
  authInProgress,
  noFragmentActivity,
  unknown,
}

// Extension for error messages
extension BiometricErrorExtension on BiometricError {
  String get userFriendlyMessage {
    switch (this) {
      case BiometricError.none:
        return 'Success';
      case BiometricError.notAvailable:
        return 'Biometric authentication is not available on this device';
      case BiometricError.notEnrolled:
        return 'Please enroll biometrics in your device settings';
      case BiometricError.passcodeNotSet:
        return 'Please set up a device passcode first';
      case BiometricError.lockedOut:
        return 'Too many failed attempts. Please try again later';
      case BiometricError.permanentlyLockedOut:
        return 'Biometric is locked. Please use your device passcode';
      case BiometricError.userCanceled:
        return 'Authentication cancelled';
      case BiometricError.failed:
        return 'Authentication failed. Please try again';
      case BiometricError.authInProgress:
        return 'Another authentication is in progress';
      case BiometricError.noFragmentActivity:
        return 'Configuration error. Please contact support';
      case BiometricError.unknown:
        return 'An unknown error occurred';
    }
  }

  bool get isRecoverable {
    switch (this) {
      case BiometricError.failed:
      case BiometricError.userCanceled:
      case BiometricError.authInProgress:
        return true;
      default:
        return false;
    }
  }
}