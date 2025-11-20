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

    return LayoutBuilder(
      builder: (context, constraints) {
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
      },
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
    final buffer = valueRange * 0.1;

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
                    horizontalInterval: (maxValue - minValue) / 3,
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
                        interval: (maxValue - minValue) / 3,
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
                      color: Theme.of(context).colorScheme.primary,
                      barWidth: 2,
                      dotData: FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      ),
                    ),
                  ],
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      tooltipBgColor: Theme.of(context).colorScheme.surface,
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

// Wallet Menu Bottom Sheet (same as before, omitted for brevity - no changes needed)
class _WalletMenuSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Same implementation as in your original code
    return Container();
  }
}