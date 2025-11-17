import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class SecureStorageService {
  static final SecureStorageService _instance = SecureStorageService._internal();
  factory SecureStorageService() => _instance;
  SecureStorageService._internal();

  final _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );

  // Save data securely
  Future<void> saveSecure(String key, String value) async {
    await _secureStorage.write(key: key, value: value);
  }

  // Read secure data
  Future<String?> readSecure(String key) async {
    return await _secureStorage.read(key: key);
  }

  // Delete secure data
  Future<void> deleteSecure(String key) async {
    await _secureStorage.delete(key: key);
  }

  // Delete all secure data
  Future<void> deleteAll() async {
    await _secureStorage.deleteAll();
  }

  // Save boolean preference
  Future<void> saveBool(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  // Read boolean preference
  Future<bool> readBool(String key, {bool defaultValue = false}) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(key) ?? defaultValue;
  }

  // Save string preference
  Future<void> saveString(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  // Read string preference
  Future<String?> readString(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }

  // Hash PIN for secure storage
  String hashPin(String pin) {
    final bytes = utf8.encode(pin);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // Verify PIN
  Future<bool> verifyPin(String pin) async {
    final storedHash = await readSecure('pin_hash');
    if (storedHash == null) return false;
    return hashPin(pin) == storedHash;
  }

  // Save PIN
  Future<void> savePin(String pin) async {
    final hash = hashPin(pin);
    await saveSecure('pin_hash', hash);
  }
}