// lib/services/security/secure_storage_service.dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'dart:convert';

class SecureStorageService {
  static final SecureStorageService _instance = SecureStorageService._internal();
  factory SecureStorageService() => _instance;
  SecureStorageService._internal();

  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  // Encryption key (in production, derive from user PIN/password)
  late encrypt.Key _encryptionKey;
  late encrypt.IV _iv;

  Future<void> initialize() async {
    // Check if encryption key exists
    final keyStr = await _storage.read(key: 'encryption_key');
    if (keyStr == null) {
      // Generate new key
      _encryptionKey = encrypt.Key.fromSecureRandom(32);
      _iv = encrypt.IV.fromSecureRandom(16);
      await _storage.write(key: 'encryption_key', value: _encryptionKey.base64);
      await _storage.write(key: 'encryption_iv', value: _iv.base64);
    } else {
      _encryptionKey = encrypt.Key.fromBase64(keyStr);
      final ivStr = await _storage.read(key: 'encryption_iv');
      _iv = encrypt.IV.fromBase64(ivStr!);
    }
  }

  // Encrypt and store
  Future<void> writeSecure(String key, String value) async {
    final encrypter = encrypt.Encrypter(encrypt.AES(_encryptionKey));
    final encrypted = encrypter.encrypt(value, iv: _iv);
    await _storage.write(key: key, value: encrypted.base64);
  }

  // Read and decrypt
  Future<String?> readSecure(String key) async {
    final encrypted = await _storage.read(key: key);
    if (encrypted == null) return null;

    try {
      final encrypter = encrypt.Encrypter(encrypt.AES(_encryptionKey));
      final decrypted = encrypter.decrypt64(encrypted, iv: _iv);
      return decrypted;
    } catch (e) {
      print('Decryption error: $e');
      return null;
    }
  }

  // Store wallet data
  Future<void> storeWallet({
    required String id,
    required String name,
    required String mnemonic,
  }) async {
    final walletData = json.encode({
      'id': id,
      'name': name,
      'mnemonic': mnemonic,
      'createdAt': DateTime.now().toIso8601String(),
    });
    await writeSecure('wallet_$id', walletData);

    // Add to wallet list
    final walletIds = await getWalletIds();
    walletIds.add(id);
    await _storage.write(key: 'wallet_ids', value: json.encode(walletIds));
  }

  // Get wallet
  Future<Map<String, dynamic>?> getWallet(String id) async {
    final data = await readSecure('wallet_$id');
    if (data == null) return null;
    return json.decode(data);
  }

  // Get all wallet IDs
  Future<List<String>> getWalletIds() async {
    final ids = await _storage.read(key: 'wallet_ids');
    if (ids == null) return [];
    return List<String>.from(json.decode(ids));
  }

  // Delete wallet
  Future<void> deleteWallet(String id) async {
    await _storage.delete(key: 'wallet_$id');
    final walletIds = await getWalletIds();
    walletIds.remove(id);
    await _storage.write(key: 'wallet_ids', value: json.encode(walletIds));
  }

  // PIN management
  Future<void> setPin(String pin) async {
    await writeSecure('user_pin', pin);
  }

  Future<String?> getPin() async {
    return await readSecure('user_pin');
  }

  Future<bool> verifyPin(String pin) async {
    final storedPin = await getPin();
    return storedPin == pin;
  }

  // Biometric preference
  Future<void> setBiometricEnabled(bool enabled) async {
    await _storage.write(key: 'biometric_enabled', value: enabled.toString());
  }

  Future<bool> isBiometricEnabled() async {
    final value = await _storage.read(key: 'biometric_enabled');
    return value == 'true';
  }

  // Current wallet ID
  Future<void> setCurrentWalletId(String id) async {
    await _storage.write(key: 'current_wallet_id', value: id);
  }

  Future<String?> getCurrentWalletId() async {
    return await _storage.read(key: 'current_wallet_id');
  }

  // Clear all data
  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}