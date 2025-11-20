import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/wallet_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/services/wallet_service.dart';
import '../../core/services/blockchain_service.dart';
import '../../core/constants/app_constants.dart';
import '../splash_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Settings'),
        ),
        body: ListView(
          children: [
          _buildSection(
          context,
          'Network',
          [
            _buildNetworkSwitch(context),
          ],
        ),
        _buildSection(
          context,
          'Appearance',
          [
            _buildThemeSwitch(context),
          ],
        ),
        _buildSection(
          context,
          'Security',
          [
            _buildBiometricSwitch(context),
            _buildChangePinTile(context),
          ],
        ),
        _buildSection(
          context,
          'Wallet',
          [
            _buildEditWalletNameTile(context),
            _buildViewSeedPhraseTile(context),
            _buildViewPrivateKeysTile(context),
            _buildClearCacheTile(context),
            _buildDeleteWalletTile(context),
          ],
        ),
            _buildSection(
              context,
              'About',
              [
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('Version'),
                  trailing: Text(
                    AppConstants.appVersion,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.speed),
                  title: const Text('API Rate Limits'),
                  subtitle: const Text('Auto-refresh every 5 minutes'),
                  trailing: const Icon(Icons.info_outline),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Rate Limiting Info'),
                        content: const SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('To avoid API rate limits:'),
                              SizedBox(height: 8),
                              Text('• Auto-refresh runs every 5 minutes'),
                              Text('• Manual refresh has 2 second delays'),
                              Text('• Cached data used when rate limited'),
                              SizedBox(height: 12),
                              Text('Mempool.space (Bitcoin):',
                                  style: TextStyle(fontWeight: FontWeight.bold)),
                              Text('• Uses testnet4 for testing'),
                              SizedBox(height: 8),
                              Text('Etherscan (Ethereum):',
                                  style: TextStyle(fontWeight: FontWeight.bold)),
                              Text('• 100,000 requests/day (free tier)'),
                            ],
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('OK'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
    );
  }

  Widget _buildSection(BuildContext context, String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        ...children,
        const Divider(height: 1),
      ],
    );
  }

  Widget _buildNetworkSwitch(BuildContext context) {
    return Consumer<WalletProvider>(
      builder: (context, walletProvider, _) {
        return SwitchListTile(
          secondary: Icon(
            walletProvider.isMainnet ? Icons.public : Icons.science,
            color: walletProvider.isMainnet ? Colors.green : Colors.orange,
          ),
          title: const Text('Mainnet'),
          subtitle: Text(walletProvider.isMainnet ? 'Using Mainnet' : 'Using Testnet'),
          value: walletProvider.isMainnet,
          onChanged: (value) async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Switch Network'),
                content: Text(
                  'Switch to ${value ? 'Mainnet' : 'Testnet'}? This will reload your wallet and clear cache.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Switch'),
                  ),
                ],
              ),
            );

            if (confirmed == true) {
              await walletProvider.toggleNetwork();
            }
          },
        );
      },
    );
  }

  Widget _buildThemeSwitch(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        return SwitchListTile(
          secondary: Icon(
            themeProvider.isDarkMode ? Icons.dark_mode : Icons.light_mode,
          ),
          title: const Text('Dark Mode'),
          subtitle: Text(themeProvider.isDarkMode ? 'Dark theme enabled' : 'Light theme enabled'),
          value: themeProvider.isDarkMode,
          onChanged: (value) {
            themeProvider.toggleTheme();
          },
        );
      },
    );
  }

  Widget _buildBiometricSwitch(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        if (!authProvider.biometricAvailable) {
          return ListTile(
            leading: const Icon(Icons.fingerprint),
            title: const Text('Biometric Authentication'),
            subtitle: const Text('Not available on this device'),
            enabled: false,
          );
        }

        return SwitchListTile(
          secondary: const Icon(Icons.fingerprint),
          title: Text(authProvider.biometricType),
          subtitle: Text(
            authProvider.biometricEnabled ? 'Enabled' : 'Disabled',
          ),
          value: authProvider.biometricEnabled,
          onChanged: (value) async {
            // Show loading indicator
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => const Center(
                child: CircularProgressIndicator(),
              ),
            );

            final success = await authProvider.setBiometricEnabled(value);

            if (context.mounted) {
              Navigator.pop(context); // Close loading dialog

              if (!success && value) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to enable ${authProvider.biometricType}'),
                    backgroundColor: Colors.red,
                  ),
                );
              } else if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      value
                          ? '${authProvider.biometricType} enabled'
                          : '${authProvider.biometricType} disabled',
                    ),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            }
          },
        );
      },
    );
  }

  Widget _buildChangePinTile(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.pin),
      title: const Text('Change PIN'),
      subtitle: const Text('Update your security PIN'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        showDialog(
          context: context,
          builder: (context) => _ChangePinDialog(),
        );
      },
    );
  }

  Widget _buildEditWalletNameTile(BuildContext context) {
    return Consumer<WalletProvider>(
      builder: (context, walletProvider, _) {
        return ListTile(
          leading: const Icon(Icons.edit_outlined),
          title: const Text('Edit Wallet Name'),
          subtitle: Text(walletProvider.currentWalletName ?? 'No wallet selected'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            if (walletProvider.currentWalletId == null) return;

            final controller = TextEditingController(
              text: walletProvider.currentWalletName ?? '',
            );

            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Edit Wallet Name'),
                content: TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    labelText: 'Wallet Name',
                    hintText: 'Enter new wallet name',
                  ),
                  autofocus: true,
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      final newName = controller.text.trim();
                      if (newName.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter a wallet name')),
                        );
                        return;
                      }

                      await walletProvider.updateWalletName(
                        walletProvider.currentWalletId!,
                        newName,
                      );

                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Wallet name updated'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    },
                    child: const Text('Save'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildViewSeedPhraseTile(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.key),
      title: const Text('View Seed Phrase'),
      subtitle: const Text('Show your 12-word recovery phrase'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ViewSeedPhraseScreen()),
        );
      },
    );
  }

  Widget _buildViewPrivateKeysTile(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.vpn_key),
      title: const Text('View Private Keys'),
      subtitle: const Text('Show private keys for each coin'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ViewPrivateKeysScreen()),
        );
      },
    );
  }

  Widget _buildClearCacheTile(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.cleaning_services),
      title: const Text('Clear Cache'),
      subtitle: const Text('Clear API cache if experiencing issues'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Clear Cache'),
            content: const Text(
              'This will clear cached API responses. Use this if you\'re getting rate limit errors or stale data.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Clear'),
              ),
            ],
          ),
        );

        if (confirmed == true && context.mounted) {
          BlockchainService().clearCache();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Cache cleared successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      },
    );
  }

  Widget _buildDeleteWalletTile(BuildContext context) {
    return ListTile(
      leading: Icon(Icons.delete_forever, color: Theme.of(context).colorScheme.error),
      title: Text(
        'Delete All Wallets',
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
      subtitle: const Text('Permanently delete all wallets'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete All Wallets'),
            content: const Text(
              'Are you sure you want to delete all wallets? Make sure you have backed up all seed phrases. This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
                child: const Text('Delete All'),
              ),
            ],
          ),
        );

        if (confirmed == true && context.mounted) {
          // Show loading
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => const Center(child: CircularProgressIndicator()),
          );

          await context.read<WalletProvider>().deleteWallet();

          if (context.mounted) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const SplashScreen()),
                  (route) => false,
            );
          }
        }
      },
    );
  }
}

class _ChangePinDialog extends StatefulWidget {
  @override
  State<_ChangePinDialog> createState() => _ChangePinDialogState();
}

class _ChangePinDialogState extends State<_ChangePinDialog> {
  final _oldPinController = TextEditingController();
  final _newPinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  String? _error;
  bool _isChanging = false;

  @override
  void dispose() {
    _oldPinController.dispose();
    _newPinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  Future<void> _changePin() async {
    if (_newPinController.text != _confirmPinController.text) {
      setState(() => _error = 'New PINs do not match');
      return;
    }

    if (_newPinController.text.length != 6) {
      setState(() => _error = 'PIN must be 6 digits');
      return;
    }

    setState(() {
      _isChanging = true;
      _error = null;
    });

    try {
      final authProvider = context.read<AuthProvider>();
      await authProvider.changePin(_oldPinController.text, _newPinController.text);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PIN changed successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isChanging = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Change PIN'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          TextField(
            controller: _oldPinController,
            decoration: const InputDecoration(labelText: 'Current PIN'),
            keyboardType: TextInputType.number,
            obscureText: true,
            maxLength: 6,
            enabled: !_isChanging,
          ),
          TextField(
            controller: _newPinController,
            decoration: const InputDecoration(labelText: 'New PIN'),
            keyboardType: TextInputType.number,
            obscureText: true,
            maxLength: 6,
            enabled: !_isChanging,
          ),
          TextField(
            controller: _confirmPinController,
            decoration: const InputDecoration(labelText: 'Confirm New PIN'),
            keyboardType: TextInputType.number,
            obscureText: true,
            maxLength: 6,
            enabled: !_isChanging,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isChanging ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isChanging ? null : _changePin,
          child: _isChanging
              ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
              : const Text('Change'),
        ),
      ],
    );
  }
}

class ViewSeedPhraseScreen extends StatelessWidget {
  const ViewSeedPhraseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Seed Phrase'),
      ),
      body: Consumer<WalletProvider>(
        builder: (context, walletProvider, _) {
          if (walletProvider.wallet == null) {
            return const Center(child: Text('No wallet found'));
          }

          final words = walletProvider.wallet!.mnemonic.split(' ');

          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Theme.of(context).colorScheme.error),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text('Never share your seed phrase with anyone!'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 3,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: words.length,
                itemBuilder: (context, index) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          '${index + 1}.',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            words[index],
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: walletProvider.wallet!.mnemonic));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Seed phrase copied')),
                  );
                },
                icon: const Icon(Icons.copy),
                label: const Text('Copy to Clipboard'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class ViewPrivateKeysScreen extends StatelessWidget {
  const ViewPrivateKeysScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Private Keys'),
      ),
      body: Consumer<WalletProvider>(
        builder: (context, walletProvider, _) {
          if (walletProvider.wallet == null) {
            return const Center(child: Text('No wallet found'));
          }

          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Theme.of(context).colorScheme.error),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text('Never share your private keys with anyone!'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              ...CoinInfo.allCoins.map((coin) {
                // CHANGE THIS LINE - Use WalletHelper instead of WalletService
                final privateKey = WalletHelper.getPrivateKey(walletProvider.wallet!, coin.type);
                return _PrivateKeyCard(coin: coin, privateKey: privateKey);
              }),
            ],
          );
        },
      ),
    );
  }
}

class _PrivateKeyCard extends StatefulWidget {
  final CoinInfo coin;
  final String privateKey;

  const _PrivateKeyCard({required this.coin, required this.privateKey});

  @override
  State<_PrivateKeyCard> createState() => _PrivateKeyCardState();
}

class _PrivateKeyCardState extends State<_PrivateKeyCard> {
  bool _isVisible = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  widget.coin.icon,
                  style: const TextStyle(fontSize: 24),
                ),
                const SizedBox(width: 12),
                Text(
                  widget.coin.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                _isVisible ? widget.privateKey : '••••••••••••••••••••',
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() => _isVisible = !_isVisible);
                    },
                    icon: Icon(_isVisible ? Icons.visibility_off : Icons.visibility),
                    label: Text(_isVisible ? 'Hide' : 'Show'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: widget.privateKey));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('${widget.coin.symbol} private key copied')),
                      );
                    },
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}