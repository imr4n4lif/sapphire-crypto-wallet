import 'package:flutter/material.dart';
import '../core/services/secure_storage_service.dart';
import '../core/constants/app_constants.dart';

class ThemeProvider with ChangeNotifier {
  final SecureStorageService _storage = SecureStorageService();
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  Future<void> initialize() async {
    final savedMode = await _storage.readString(AppConstants.keyThemeMode);
    if (savedMode != null) {
      _themeMode = ThemeMode.values.firstWhere(
            (mode) => mode.toString() == savedMode,
        orElse: () => ThemeMode.system,
      );
      notifyListeners();
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await _storage.saveString(AppConstants.keyThemeMode, mode.toString());
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    if (_themeMode == ThemeMode.light) {
      await setThemeMode(ThemeMode.dark);
    } else {
      await setThemeMode(ThemeMode.light);
    }
  }
}