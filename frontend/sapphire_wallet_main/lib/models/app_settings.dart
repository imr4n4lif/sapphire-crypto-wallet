
// lib/models/app_settings.dart
import 'package:flutter/material.dart';

import 'network_model.dart';

class AppSettings {
  final ThemeMode themeMode;
  final NetworkType networkType;
  final bool biometricEnabled;
  final String currency;
  final bool notificationsEnabled;

  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.networkType = NetworkType.mainnet,
    this.biometricEnabled = false,
    this.currency = 'USD',
    this.notificationsEnabled = true,
  });

  AppSettings copyWith({
    ThemeMode? themeMode,
    NetworkType? networkType,
    bool? biometricEnabled,
    String? currency,
    bool? notificationsEnabled,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      networkType: networkType ?? this.networkType,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      currency: currency ?? this.currency,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'themeMode': themeMode.index,
      'networkType': networkType.index,
      'biometricEnabled': biometricEnabled,
      'currency': currency,
      'notificationsEnabled': notificationsEnabled,
    };
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      themeMode: ThemeMode.values[json['themeMode'] ?? 0],
      networkType: NetworkType.values[json['networkType'] ?? 0],
      biometricEnabled: json['biometricEnabled'] ?? false,
      currency: json['currency'] ?? 'USD',
      notificationsEnabled: json['notificationsEnabled'] ?? true,
    );
  }
}