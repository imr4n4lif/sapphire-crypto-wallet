// lib/providers/settings_provider.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_settings.dart';
import '../models/network_model.dart';

class SettingsProvider with ChangeNotifier {
  AppSettings _settings = const AppSettings();

  AppSettings get settings => _settings;
  ThemeMode get themeMode => _settings.themeMode;
  NetworkType get networkType => _settings.networkType;
  bool get biometricEnabled => _settings.biometricEnabled;

  SettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = prefs.getString('app_settings');

      if (settingsJson != null) {
        _settings = AppSettings.fromJson(
          Map<String, dynamic>.from(
            // In real app, use proper JSON parsing
              {} // Simplified for example
          ),
        );
      }
    } catch (e) {
      print('Error loading settings: $e');
    }
    notifyListeners();
  }

  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // In real app, save as JSON
      await prefs.setString('app_settings', '');
    } catch (e) {
      print('Error saving settings: $e');
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _settings = _settings.copyWith(themeMode: mode);
    await _saveSettings();
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    final newMode = _settings.themeMode == ThemeMode.light
        ? ThemeMode.dark
        : ThemeMode.light;
    await setThemeMode(newMode);
  }

  Future<void> setNetworkType(NetworkType type) async {
    _settings = _settings.copyWith(networkType: type);
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    _settings = _settings.copyWith(biometricEnabled: enabled);
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    _settings = _settings.copyWith(notificationsEnabled: enabled);
    await _saveSettings();
    notifyListeners();
  }
}