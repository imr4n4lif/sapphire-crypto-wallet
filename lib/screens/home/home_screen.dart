import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/wallet_provider.dart';
import '../../core/constants/app_constants.dart';
import '../../models/wallet.dart';
import '../coin/coin_detail_screen.dart';
import '../settings/settings_screen.dart';
import 'package:intl/intl.dart';
import '../../widgets/coin_icon.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  List<double> _portfolioHistory = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Initial refresh
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshData();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Refresh when app comes to foreground
    if (state == AppLifecycleState.resumed) {
      print('🔄 App resumed, refreshing data...');
      _refreshData();
    }
  }

  Future<void> _refreshData() async {
    print('🔄 Manual refresh triggered');
    await context.read<WalletProvider>().refreshBalances();
    await context.read<WalletProvider>().refreshTransactions();

    // Update portfolio history for graph
    final totalValue = context.read<WalletProvider>().totalPortfolioValue;
    setState(() {
      _portfolioHistory.add(totalValue);
      // Keep only last 20 data points
      if (_portfolioHistory.length > 20) {
        _portfolioHistory.removeAt(0);
      }
    });
  }

  void _showWalletMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _WalletMenuSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: () => _showWalletMenu(context),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Consumer<WalletProvider>(
                builder: (context, walletProvider, _) {
                  return Text(
                    walletProvider.currentWalletName ?? 'Wallet',
                    style: Theme.of(context).textTheme.titleLarge,
                  );
                },
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_drop_down, size: 20),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _refreshData,
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: Consumer<WalletProvider>(
        builder: (context, walletProvider, _) {
          if (walletProvider.isLoading) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading wallet...'),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refreshData,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildPortfolioCard(walletProvider),
                const SizedBox(height: 16),
                _buildPortfolioGraph(walletProvider),
                const SizedBox(height: 16),
                _buildNetworkBadge(walletProvider),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Assets',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      'Auto-refresh: ON',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ...CoinInfo.allCoins.map((coin) {
                  final balance = walletProvider.getCoinBalance(coin.type);
                  return _buildCoinCard(context, coin, balance);
                }),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPortfolioCard(WalletProvider walletProvider) {
    final formatter = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
    final now = DateTime.now();
    final timeString = DateFormat('HH:mm').format(now);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.secondary,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total Balance',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            formatter.format(walletProvider.totalPortfolioValue),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(
                Icons.access_time,
                color: Colors.white.withOpacity(0.9),
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                'Last updated: $timeString',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPortfolioGraph(WalletProvider walletProvider) {
    if (_portfolioHistory.length < 2) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Portfolio Trend',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 120,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: false),
                  titlesData: FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: _portfolioHistory.asMap().entries.map((entry) {
                        return FlSpot(entry.key.toDouble(), entry.value);
                      }).toList(),
                      isCurved: true,
                      color: Theme.of(context).colorScheme.primary,
                      barWidth: 2,
                      dotData: FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNetworkBadge(WalletProvider walletProvider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: walletProvider.isMainnet
            ? Colors.green.withOpacity(0.1)
            : Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: walletProvider.isMainnet ? Colors.green : Colors.orange,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.circle,
            size: 8,
            color: walletProvider.isMainnet ? Colors.green : Colors.orange,
          ),
          const SizedBox(width: 8),
          Text(
            walletProvider.isMainnet ? 'Mainnet' : 'Testnet',
            style: TextStyle(
              color: walletProvider.isMainnet ? Colors.green : Colors.orange,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoinCard(BuildContext context, CoinInfo coin, CoinBalance? balance) {
    final formatter = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
    final balanceValue = balance?.balance ?? 0.0;
    final usdValue = balance?.usdValue ?? 0.0;
    final change24h = balance?.change24h ?? 0.0;
    final isPositive = change24h >= 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CoinDetailScreen(coinType: coin.type),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: CoinIcon(coinType: coin.type, size: 28),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      coin.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      '${balanceValue.toStringAsFixed(8)} ${coin.symbol}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatter.format(usdValue),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Row(
                    children: [
                      Icon(
                        isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                        size: 12,
                        color: isPositive ? Colors.green : Colors.red,
                      ),
                      Text(
                        '${change24h.abs().toStringAsFixed(2)}%',
                        style: TextStyle(
                          fontSize: 12,
                          color: isPositive ? Colors.green : Colors.red,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Wallet Menu Bottom Sheet - IMPROVED UI
class _WalletMenuSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<WalletProvider>(
      builder: (context, walletProvider, _) {
        final wallets = walletProvider.allWallets;

        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Your Wallets',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        // decoration: BoxDecoration(
                        //   color: Theme.of(context).colorScheme.primaryContainer,
                        //   shape: BoxShape.circle,
                        // ),
                        child: Icon(
                          Icons.add,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        _showCreateWalletDialog(context);
                      },
                      tooltip: 'Add Wallet',
                    ),
                  ],
                ),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: wallets.length,
                  itemBuilder: (context, index) {
                    final wallet = wallets[index];
                    final isSelected = walletProvider.currentWalletId == wallet['id'];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: isSelected ? 4 : 1,
                      color: isSelected
                          ? Theme.of(context).colorScheme.primaryContainer
                          : null,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.account_balance_wallet,
                            color: isSelected
                                ? Colors.white
                                : Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        title: Text(
                          wallet['name'] ?? 'Wallet ${wallet['id']}',
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          ),
                        ),
                        subtitle: Text(
                          '${(wallet['ethAddress'] as String).substring(0, 10)}...',
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                        ),
                        trailing: isSelected
                            ? Icon(
                          Icons.check_circle,
                          color: Theme.of(context).colorScheme.primary,
                        )
                            : IconButton(
                          icon: Icon(
                            Icons.delete_outline,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          onPressed: () {
                            _confirmDeleteWallet(context, wallet['id'] as String);
                          },
                        ),
                        onTap: () async {
                          if (!isSelected) {
                            await walletProvider.switchWallet(wallet['id'] as String);
                            if (context.mounted) {
                              Navigator.pop(context);
                            }
                          }
                        },
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  void _showCreateWalletDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                // decoration: BoxDecoration(
                //   color: Theme.of(context).colorScheme.primaryContainer,
                //   shape: BoxShape.circle,
                // ),
                child: Icon(
                  Icons.account_balance_wallet,
                  size: 48,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Add Wallet',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Text(
                'Choose how you want to add a new wallet to your account',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _showCreateNewWalletDialog(context);
                  },
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('Create New Wallet'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _showImportWalletDialog(context);
                  },
                  icon: const Icon(Icons.download),
                  label: const Text('Import Existing'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                      width: 2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreateNewWalletDialog(BuildContext context) {
    final controller = TextEditingController();
    bool isCreating = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Create New Wallet'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Wallet Name',
                  hintText: 'e.g., My Trading Wallet',
                  prefixIcon: Icon(Icons.label_outline),
                ),
                enabled: !isCreating,
              ),
              const SizedBox(height: 16),
              if (isCreating)
                const Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 12),
                    Text('Creating wallet...'),
                  ],
                )
              else
                const Text(
                  'A new wallet with a fresh mnemonic will be created.',
                  style: TextStyle(fontSize: 12),
                ),
            ],
          ),
          actions: [
            if (!isCreating)
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            if (!isCreating)
              ElevatedButton(
                onPressed: () async {
                  final name = controller.text.trim();
                  if (name.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter a wallet name')),
                    );
                    return;
                  }

                  setState(() => isCreating = true);

                  try {
                    final mnemonic = await context.read<WalletProvider>().createNewWallet(name);
                    if (context.mounted) {
                      Navigator.pop(context);
                      _showMnemonicDialog(context, name, mnemonic);
                    }
                  } catch (e) {
                    if (context.mounted) {
                      setState(() => isCreating = false);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e')),
                      );
                    }
                  }
                },
                child: const Text('Create'),
              ),
          ],
        ),
      ),
    );
  }

  void _showMnemonicDialog(BuildContext context, String walletName, String mnemonic) {
    final words = mnemonic.split(' ');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('$walletName Created'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: Theme.of(context).colorScheme.error),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Write down these words and store them safely!',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: words.length,
                itemBuilder: (context, index) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(8),
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
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            words[index],
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: mnemonic));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Mnemonic copied to clipboard')),
              );
            },
            icon: const Icon(Icons.copy),
            label: const Text('Copy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _showImportWalletDialog(BuildContext context) {
    final nameController = TextEditingController();
    final mnemonicController = TextEditingController();
    bool isImporting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Import Wallet'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Wallet Name',
                    hintText: 'e.g., My Imported Wallet',
                    prefixIcon: Icon(Icons.label_outline),
                  ),
                  enabled: !isImporting,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: mnemonicController,
                  decoration: const InputDecoration(
                    labelText: 'Seed Phrase',
                    hintText: 'Enter 12 words',
                    prefixIcon: Icon(Icons.key),
                  ),
                  maxLines: 3,
                  enabled: !isImporting,
                ),
                if (isImporting) ...[
                  const SizedBox(height: 16),
                  const Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 12),
                      Text('Importing wallet...'),
                    ],
                  ),
                ],
              ],
            ),
          ),
          actions: [
            if (!isImporting)
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            if (!isImporting)
              ElevatedButton(
                onPressed: () async {
                  final name = nameController.text.trim();
                  final mnemonic = mnemonicController.text.trim();

                  if (name.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter a wallet name')),
                    );
                    return;
                  }

                  if (mnemonic.split(RegExp(r'\s+')).length != 12) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter exactly 12 words')),
                    );
                    return;
                  }

                  setState(() => isImporting = true);

                  try {
                    await context.read<WalletProvider>().importExistingWallet(name, mnemonic);
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('✅ Imported wallet: $name')),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      setState(() => isImporting = false);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: ${e.toString()}')),
                      );
                    }
                  }
                },
                child: const Text('Import'),
              ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteWallet(BuildContext context, String walletId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Wallet'),
        content: const Text(
          'Are you sure? Make sure you have backed up the seed phrase.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await context.read<WalletProvider>().deleteWalletById(walletId);
              if (context.mounted) {
                Navigator.pop(context);
                Navigator.pop(context); // Close bottom sheet too
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}