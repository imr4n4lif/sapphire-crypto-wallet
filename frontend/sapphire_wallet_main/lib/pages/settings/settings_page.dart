// lib/pages/settings/settings_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/wallet_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/security/secure_storage_service.dart';
import '../../services/security/biometric_service.dart';
import '../../models/network_model.dart';
import 'security_settings_page.dart';
import 'view_seed_phrase_page.dart';
import 'view_private_keys_page.dart';
import '../wallet/manage_wallets_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _biometricService = BiometricService();
  bool _biometricAvailable = false;

  @override
  void initState() {
    super.initState();
    _checkBiometric();
  }

  Future<void> _checkBiometric() async {
    final available = await _biometricService.canCheckBiometrics();
    setState(() {
      _biometricAvailable = available;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Consumer2<WalletProvider, SettingsProvider>(
        builder: (context, walletProvider, settingsProvider, child) {
          return ListView(
            children: [
              // Wallet Settings
              _buildSectionHeader('Wallet'),
              _buildSettingsTile(
                icon: Icons.account_balance_wallet,
                title: 'Manage Wallets',
                subtitle: '${walletProvider.wallets.length} wallet(s)',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ManageWalletsPage(),
                    ),
                  );
                },
              ),
              _buildSettingsTile(
                icon: Icons.visibility,
                title: 'View Seed Phrase',
                subtitle: 'Backup your recovery phrase',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ViewSeedPhrasePage(),
                    ),
                  );
                },
              ),
              _buildSettingsTile(
                icon: Icons.vpn_key,
                title: 'View Private Keys',
                subtitle: 'Export private keys for each coin',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ViewPrivateKeysPage(),
                    ),
                  );
                },
              ),

              const Divider(height: 32),

              // Security Settings
              _buildSectionHeader('Security'),
              _buildSettingsTile(
                icon: Icons.lock,
                title: 'Change PIN',
                subtitle: 'Update your security PIN',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SecuritySettingsPage(),
                    ),
                  );
                },
              ),
              if (_biometricAvailable)
                _buildSwitchTile(
                  icon: Icons.fingerprint,
                  title: 'Biometric Authentication',
                  subtitle: 'Use fingerprint/face ID to unlock',
                  value: settingsProvider.biometricEnabled,
                  onChanged: (value) async {
                    if (value) {
                      final authenticated = await _biometricService.authenticate(
                        reason: 'Enable biometric authentication',
                      );
                      if (authenticated) {
                        await settingsProvider.setBiometricEnabled(true);
                        await SecureStorageService().setBiometricEnabled(true);
                      }
                    } else {
                      await settingsProvider.setBiometricEnabled(false);
                      await SecureStorageService().setBiometricEnabled(false);
                    }
                  },
                ),

              const Divider(height: 32),

              // Network Settings
              _buildSectionHeader('Network'),
              _buildRadioTile(
                icon: Icons.public,
                title: 'Mainnet',
                subtitle: 'Use real blockchain networks',
                value: NetworkType.mainnet,
                groupValue: walletProvider.networkType,
                onChanged: (value) async {
                  await _showNetworkChangeDialog(
                    context,
                    walletProvider,
                    NetworkType.mainnet,
                  );
                },
              ),
              _buildRadioTile(
                icon: Icons.science,
                title: 'Testnet',
                subtitle: 'Use test networks (no real funds)',
                value: NetworkType.testnet,
                groupValue: walletProvider.networkType,
                onChanged: (value) async {
                  await _showNetworkChangeDialog(
                    context,
                    walletProvider,
                    NetworkType.testnet,
                  );
                },
              ),

              const Divider(height: 32),

              // Appearance
              _buildSectionHeader('Appearance'),
              _buildRadioTile(
                icon: Icons.light_mode,
                title: 'Light Mode',
                subtitle: 'Use light theme',
                value: ThemeMode.light,
                groupValue: settingsProvider.themeMode,
                onChanged: (value) {
                  settingsProvider.setThemeMode(ThemeMode.light);
                },
              ),
              _buildRadioTile(
                icon: Icons.dark_mode,
                title: 'Dark Mode',
                subtitle: 'Use dark theme',
                value: ThemeMode.dark,
                groupValue: settingsProvider.themeMode,
                onChanged: (value) {
                  settingsProvider.setThemeMode(ThemeMode.dark);
                },
              ),
              _buildRadioTile(
                icon: Icons.brightness_auto,
                title: 'System Default',
                subtitle: 'Follow system theme',
                value: ThemeMode.system,
                groupValue: settingsProvider.themeMode,
                onChanged: (value) {
                  settingsProvider.setThemeMode(ThemeMode.system);
                },
              ),

              const Divider(height: 32),

              // Notifications
              _buildSectionHeader('Notifications'),
              _buildSwitchTile(
                icon: Icons.notifications,
                title: 'Push Notifications',
                subtitle: 'Receive transaction notifications',
                value: settingsProvider.settings.notificationsEnabled,
                onChanged: (value) {
                  settingsProvider.setNotificationsEnabled(value);
                },
              ),

              const Divider(height: 32),

              // About
              _buildSectionHeader('About'),
              _buildSettingsTile(
                icon: Icons.info_outline,
                title: 'Version',
                subtitle: '1.0.0',
                onTap: () {},
              ),
              _buildSettingsTile(
                icon: Icons.description,
                title: 'Terms of Service',
                onTap: () {},
              ),
              _buildSettingsTile(
                icon: Icons.privacy_tip,
                title: 'Privacy Policy',
                onTap: () {},
              ),

              const SizedBox(height: 32),

              // Danger Zone
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Danger Zone',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => _showDeleteWalletDialog(context, walletProvider),
                      icon: const Icon(Icons.delete_forever),
                      label: const Text('Delete Current Wallet'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle) : null,
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      secondary: Icon(icon),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle) : null,
      value: value,
      onChanged: onChanged,
    );
  }

  Widget _buildRadioTile<T>({
    required IconData icon,
    required String title,
    String? subtitle,
    required T value,
    required T groupValue,
    required ValueChanged<T?> onChanged,
  }) {
    return RadioListTile<T>(
      secondary: Icon(icon),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle) : null,
      value: value,
      groupValue: groupValue,
      onChanged: onChanged,
    );
  }

  Future<void> _showNetworkChangeDialog(
      BuildContext context,
      WalletProvider provider,
      NetworkType network,
      ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Network?'),
        content: Text(
          'Switching to ${network == NetworkType.mainnet ? "Mainnet" : "Testnet"} '
              'will reload your wallet addresses and balances.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await provider.switchNetwork(network);
    }
  }

  Future<void> _showDeleteWalletDialog(
      BuildContext context,
      WalletProvider provider,
      ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Wallet?'),
        content: const Text(
          'This action cannot be undone. Make sure you have backed up '
              'your seed phrase before proceeding.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && provider.currentWallet != null) {
      await provider.removeWallet(provider.currentWallet!.id);
      if (context.mounted) {
        Navigator.pop(context);
      }
    }
  }
}