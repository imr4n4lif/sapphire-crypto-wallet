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

enum PortfolioTimelineOption { day, week, month, threeMonths, year }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  PortfolioTimelineOption _selectedTimeline = PortfolioTimelineOption.week;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

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
    if (state == AppLifecycleState.resumed) {
      _refreshData();
    }
  }

  Future<void> _refreshData() async {
    if (!mounted) return;
    await context.read<WalletProvider>().refreshBalances();
    await context.read<WalletProvider>().refreshTransactions();
  }

  void _showWalletMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _WalletMenuSheet(),
    );
  }

  List<PortfolioDataPoint> _filterHistoryByTimeline(
      List<PortfolioDataPoint> history,
      PortfolioTimelineOption timeline,
      ) {
    if (history.isEmpty) return [];

    final now = DateTime.now();
    DateTime cutoffDate;

    switch (timeline) {
      case PortfolioTimelineOption.day:
        cutoffDate = now.subtract(const Duration(hours: 24));
        break;
      case PortfolioTimelineOption.week:
        cutoffDate = now.subtract(const Duration(days: 7));
        break;
      case PortfolioTimelineOption.month:
        cutoffDate = now.subtract(const Duration(days: 30));
        break;
      case PortfolioTimelineOption.threeMonths:
        cutoffDate = now.subtract(const Duration(days: 90));
        break;
      case PortfolioTimelineOption.year:
        cutoffDate = now.subtract(const Duration(days: 365));
        break;
    }

    return history.where((p) => p.timestamp.isAfter(cutoffDate)).toList();
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
                  return Flexible(
                    child: Text(
                      walletProvider.currentWalletName ?? 'Wallet',
                      style: Theme.of(context).textTheme.titleLarge,
                      overflow: TextOverflow.ellipsis,
                    ),
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
      padding: const EdgeInsets.all(20),
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
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              formatter.format(walletProvider.totalPortfolioValue),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.bold,
              ),
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
    final fullHistory = walletProvider.currentWalletPortfolioHistory;
    final filteredHistory = _filterHistoryByTimeline(fullHistory, _selectedTimeline);

    if (filteredHistory.length < 2) {
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
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: PortfolioTimelineOption.values.map((option) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(_getPortfolioTimelineLabel(option)),
                        selected: _selectedTimeline == option,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() => _selectedTimeline = option);
                          }
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 40),
              Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.trending_up,
                      size: 48,
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                    ),
                    const SizedBox(height: 8),
                    const Text('Not enough data yet'),
                    const SizedBox(height: 4),
                    Text(
                      'Portfolio history will appear here',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      );
    }

    final minValue = filteredHistory.map((p) => p.value).reduce((a, b) => a < b ? a : b);
    final maxValue = filteredHistory.map((p) => p.value).reduce((a, b) => a > b ? a : b);
    final valueRange = maxValue - minValue;
    final buffer = valueRange > 0 ? valueRange * 0.1 : 1.0;

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
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: PortfolioTimelineOption.values.map((option) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(_getPortfolioTimelineLabel(option)),
                      selected: _selectedTimeline == option,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _selectedTimeline = option);
                        }
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 150,
              child: LineChart(
                LineChartData(
                  minY: minValue - buffer,
                  maxY: maxValue + buffer,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: valueRange > 0 ? (maxValue - minValue) / 3 : 1.0,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: Colors.grey.withOpacity(0.2),
                        strokeWidth: 1,
                      );
                    },
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 45,
                        interval: valueRange > 0 ? (maxValue - minValue) / 3 : 1.0,
                        getTitlesWidget: (value, meta) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Text(
                              '\$${value.toStringAsFixed(0)}',
                              style: const TextStyle(fontSize: 10),
                            ),
                          );
                        },
                      ),
                    ),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 25,
                        interval: (filteredHistory.length / 3).ceilToDouble(),
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= filteredHistory.length) {
                            return const SizedBox();
                          }

                          final date = filteredHistory[index].timestamp;
                          String label;

                          if (_selectedTimeline == PortfolioTimelineOption.day) {
                            label = DateFormat('HH:mm').format(date);
                          } else {
                            label = DateFormat('MM/dd').format(date);
                          }

                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(label, style: const TextStyle(fontSize: 10)),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: filteredHistory.asMap().entries.map((entry) {
                        return FlSpot(entry.key.toDouble(), entry.value.value);
                      }).toList(),
                      isCurved: true,
                      curveSmoothness: 0.35,
                      color: Theme.of(context).colorScheme.primary,
                      barWidth: 3,
                      dotData: FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            Theme.of(context).colorScheme.primary.withOpacity(0.3),
                            Theme.of(context).colorScheme.primary.withOpacity(0.0),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ],
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (touchedSpot) =>
                      Theme.of(context).colorScheme.surface,
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          final date = filteredHistory[spot.x.toInt()].timestamp;
                          return LineTooltipItem(
                            '\$${spot.y.toStringAsFixed(2)}\n${DateFormat('MMM dd, HH:mm').format(date)}',
                            TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontSize: 12,
                            ),
                          );
                        }).toList();
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getPortfolioTimelineLabel(PortfolioTimelineOption option) {
    switch (option) {
      case PortfolioTimelineOption.day:
        return '24H';
      case PortfolioTimelineOption.week:
        return '1W';
      case PortfolioTimelineOption.month:
        return '1M';
      case PortfolioTimelineOption.threeMonths:
        return '3M';
      case PortfolioTimelineOption.year:
        return '1Y';
    }
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
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${balanceValue.toStringAsFixed(6)} ${coin.symbol}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      formatter.format(usdValue),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
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

// Wallet Menu Bottom Sheet with FIXED loading
class _WalletMenuSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Consumer<WalletProvider>(
          builder: (context, walletProvider, _) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'My Wallets',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: walletProvider.allWallets.length,
                    itemBuilder: (context, index) {
                      final wallet = walletProvider.allWallets[index];
                      final walletId = wallet['id'] as String;
                      final walletName = wallet['name'] as String;
                      final isSelected = walletId == walletProvider.currentWalletId;

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.primary.withOpacity(0.2),
                          child: Text(
                            walletName[0].toUpperCase(),
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          walletName,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        subtitle: Text(
                          '${(wallet['ethAddress'] as String).substring(0, 10)}...',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        trailing: isSelected
                            ? Icon(
                          Icons.check_circle,
                          color: Theme.of(context).colorScheme.primary,
                        )
                            : PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert),
                          onSelected: (value) async {
                            if (value == 'rename') {
                              _showRenameDialog(context, walletProvider, walletId, walletName);
                            } else if (value == 'delete') {
                              _showDeleteDialog(context, walletProvider, walletId, walletName);
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'rename',
                              child: Row(
                                children: [
                                  Icon(Icons.edit_outlined, size: 20),
                                  SizedBox(width: 12),
                                  Text('Rename'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete_outline, size: 20, color: Colors.red),
                                  SizedBox(width: 12),
                                  Text('Delete', style: TextStyle(color: Colors.red)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        onTap: isSelected
                            ? null
                            : () async {
                          Navigator.pop(context);
                          await walletProvider.switchWallet(walletId);
                        },
                      );
                    },
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _showCreateWalletDialog(context, walletProvider);
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Create New Wallet'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _showImportWalletDialog(context, walletProvider);
                          },
                          icon: const Icon(Icons.download_outlined),
                          label: const Text('Import Wallet'),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: Theme.of(context).colorScheme.primary,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // FIXED: Wallet creation with proper loading handling
  void _showCreateWalletDialog(BuildContext context, WalletProvider walletProvider) {
    final controller = TextEditingController(text: 'Wallet ${walletProvider.allWallets.length + 1}');

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Create New Wallet'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Wallet Name',
            hintText: 'Enter wallet name',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a wallet name')),
                );
                return;
              }

              // Close the name dialog first
              Navigator.pop(dialogContext);

              // Show loading dialog
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (loadingContext) => WillPopScope(
                  onWillPop: () async => false,
                  child: const Center(
                    child: Card(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text('Creating wallet...'),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );

              try {
                final mnemonic = await walletProvider.createNewWallet(name);

                if (context.mounted) {
                  // Close loading dialog
                  Navigator.pop(context);

                  // Show seed phrase dialog
                  _showSeedPhraseDialog(context, mnemonic);
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context); // Close loading
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showImportWalletDialog(BuildContext context, WalletProvider walletProvider) {
    final nameController = TextEditingController(text: 'Imported Wallet ${walletProvider.allWallets.length + 1}');
    final mnemonicController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import Wallet'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Wallet Name',
                hintText: 'Enter wallet name',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: mnemonicController,
              decoration: const InputDecoration(
                labelText: 'Seed Phrase',
                hintText: 'Enter 12-word seed phrase',
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final mnemonic = mnemonicController.text.trim();

              if (name.isEmpty || mnemonic.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please fill all fields')),
                );
                return;
              }

              Navigator.pop(context);

              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const Center(child: CircularProgressIndicator()),
              );

              try {
                await walletProvider.importExistingWallet(name, mnemonic);

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ Wallet imported successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Import'),
          ),
        ],
      ),
    );
  }

  void _showSeedPhraseDialog(BuildContext context, String mnemonic) {
    final words = mnemonic.split(' ');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ Save Your Seed Phrase'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red),
                ),
                child: const Text(
                  'Write down these 12 words and store them safely.',
                  style: TextStyle(fontSize: 12),
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
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            words[index],
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: mnemonic));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Seed phrase copied')),
                    );
                  },
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('Copy to Clipboard'),
                ),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('I\'ve Saved It'),
          ),
        ],
      ),
    );
  }

  void _showRenameDialog(BuildContext context, WalletProvider walletProvider, String walletId, String currentName) {
    final controller = TextEditingController(text: currentName);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Wallet'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Wallet Name',
            hintText: 'Enter new name',
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

              await walletProvider.updateWalletName(walletId, newName);

              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ Wallet renamed successfully'),
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
  }

  void _showDeleteDialog(BuildContext context, WalletProvider walletProvider, String walletId, String walletName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Wallet'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to delete "$walletName"?'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red),
              ),
              child: const Text(
                'Make sure you have backed up your seed phrase.',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);

              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const Center(child: CircularProgressIndicator()),
              );

              try {
                await walletProvider.deleteWalletById(walletId);

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ Wallet deleted successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}