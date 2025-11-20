import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/wallet_provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/price_service.dart';
import '../../models/wallet.dart';
import 'send_screen.dart';
import 'receive_screen.dart';
import 'transaction_detail_screen.dart';
import '../../widgets/coin_icon.dart';

enum TimelineOption { day, week, month, threeMonths, year }

class CoinDetailScreen extends StatefulWidget {
  final CoinType coinType;

  const CoinDetailScreen({super.key, required this.coinType});

  @override
  State<CoinDetailScreen> createState() => _CoinDetailScreenState();
}

class _CoinDetailScreenState extends State<CoinDetailScreen> {
  TimelineOption _selectedTimeline = TimelineOption.week;
  List<PricePoint> _priceHistory = [];
  bool _loadingHistory = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshData();
      _loadPriceHistory();
    });
  }

  Future<void> _refreshData() async {
    if (!mounted) return;
    await context.read<WalletProvider>().refreshBalances();
    await context.read<WalletProvider>().refreshTransactions();
  }

  Future<void> _loadPriceHistory() async {
    if (_loadingHistory) return;

    setState(() => _loadingHistory = true);

    try {
      final days = _getTimelineDays(_selectedTimeline);
      final history = await PriceService().fetchPriceHistory(widget.coinType, days: days);

      if (mounted && history.isNotEmpty) {
        setState(() {
          _priceHistory = history;
          _loadingHistory = false;
        });
      } else {
        setState(() {
          _priceHistory = [];
          _loadingHistory = false;
        });
      }
    } catch (e) {
      print('❌ Error loading price history: $e');
      if (mounted) {
        setState(() {
          _priceHistory = [];
          _loadingHistory = false;
        });
      }
    }
  }

  int _getTimelineDays(TimelineOption timeline) {
    switch (timeline) {
      case TimelineOption.day:
        return 1;
      case TimelineOption.week:
        return 7;
      case TimelineOption.month:
        return 30;
      case TimelineOption.threeMonths:
        return 90;
      case TimelineOption.year:
        return 365;
    }
  }

  String _getTimelineLabel(TimelineOption timeline) {
    switch (timeline) {
      case TimelineOption.day:
        return '24H';
      case TimelineOption.week:
        return '1W';
      case TimelineOption.month:
        return '1M';
      case TimelineOption.threeMonths:
        return '3M';
      case TimelineOption.year:
        return '1Y';
    }
  }

  CoinInfo get _coinInfo {
    return CoinInfo.allCoins.firstWhere((c) => c.type == widget.coinType);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_coinInfo.name),
      ),
      body: Consumer<WalletProvider>(
        builder: (context, walletProvider, _) {
          final balance = walletProvider.getCoinBalance(widget.coinType);
          final transactions = walletProvider.getCoinTransactions(widget.coinType);

          return RefreshIndicator(
            onRefresh: () async {
              await _refreshData();
              await _loadPriceHistory();
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildBalanceCard(balance),
                const SizedBox(height: 24),
                _buildPriceChart(balance),
                const SizedBox(height: 24),
                _buildActionButtons(),
                const SizedBox(height: 32),
                Text(
                  'Recent Transactions',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                if (transactions.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Icon(
                            Icons.receipt_long_outlined,
                            size: 64,
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No transactions yet',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...transactions.map((tx) => _buildTransactionCard(tx)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBalanceCard(CoinBalance? balance) {
    final formatter = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
    final balanceValue = balance?.balance ?? 0.0;
    final usdValue = balance?.usdValue ?? 0.0;
    final pricePerCoin = balance?.pricePerCoin ?? 0.0;
    final change24h = balance?.change24h ?? 0.0;
    final isPositive = change24h >= 0;

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
          ),
          child: Column(
            children: [
              CoinIcon(coinType: widget.coinType, size: 48),
              const SizedBox(height: 16),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '${balanceValue.toStringAsFixed(8)} ${_coinInfo.symbol}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                formatter.format(usdValue),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isPositive
                      ? Colors.green.withOpacity(0.2)
                      : Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                      size: 16,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${change24h.abs().toStringAsFixed(2)}% (24h)',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '${formatter.format(pricePerCoin)} per ${_coinInfo.symbol}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPriceChart(CoinBalance? balance) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Price History',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: TimelineOption.values.map((option) {
                  final isSelected = _selectedTimeline == option;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(_getTimelineLabel(option)),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected && !_loadingHistory) {
                          setState(() => _selectedTimeline = option);
                          _loadPriceHistory();
                        }
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: _loadingHistory
                  ? const Center(child: CircularProgressIndicator())
                  : _priceHistory.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.show_chart,
                      size: 48,
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                    ),
                    const SizedBox(height: 8),
                    const Text('No price data available'),
                  ],
                ),
              )
                  : _buildChart(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChart() {
    if (_priceHistory.isEmpty) return const SizedBox();

    final minPrice = _priceHistory.map((p) => p.price).reduce((a, b) => a < b ? a : b);
    final maxPrice = _priceHistory.map((p) => p.price).reduce((a, b) => a > b ? a : b);
    final priceRange = maxPrice - minPrice;
    final buffer = priceRange * 0.1;

    return LineChart(
      LineChartData(
        minY: minPrice - buffer,
        maxY: maxPrice + buffer,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: (maxPrice - minPrice) / 4,
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
              reservedSize: 50,
              interval: (maxPrice - minPrice) / 4,
              getTitlesWidget: (value, meta) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    '\$${value.toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 10),
                    textAlign: TextAlign.right,
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
              reservedSize: 30,
              interval: (_priceHistory.length / 4).ceilToDouble(),
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= _priceHistory.length) {
                  return const SizedBox();
                }

                final date = _priceHistory[index].timestamp;
                String label;

                if (_selectedTimeline == TimelineOption.day) {
                  label = DateFormat('HH:mm').format(date);
                } else {
                  label = DateFormat('MM/dd').format(date);
                }

                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    label,
                    style: const TextStyle(fontSize: 10),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: _priceHistory.asMap().entries.map((entry) {
              return FlSpot(entry.key.toDouble(), entry.value.price);
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
                final date = _priceHistory[spot.x.toInt()].timestamp;
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
    );
  }

  Widget _buildActionButtons() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SendScreen(coinType: widget.coinType),
                    ),
                  );
                },
                icon: const Icon(Icons.arrow_upward),
                label: const Text('Send'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ReceiveScreen(coinType: widget.coinType),
                    ),
                  );
                },
                icon: const Icon(Icons.arrow_downward),
                label: const Text('Receive'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTransactionCard(Transaction tx) {
    final dateFormat = DateFormat('MMM dd, yyyy • HH:mm');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TransactionDetailScreen(transaction: tx),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: tx.isIncoming
                      ? Colors.green.withOpacity(0.1)
                      : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  tx.isIncoming ? Icons.arrow_downward : Icons.arrow_upward,
                  color: tx.isIncoming ? Colors.green : Colors.red,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tx.isIncoming ? 'Received' : 'Sent',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      dateFormat.format(tx.timestamp),
                      style: Theme.of(context).textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${tx.confirmations} confirmations',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: _getStatusColor(tx.status),
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
                      '${tx.isIncoming ? '+' : '-'}${tx.amount.toStringAsFixed(6)}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: tx.isIncoming ? Colors.green : Colors.red,
                      ),
                    ),
                  ),
                  Text(
                    _coinInfo.symbol,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(TransactionStatus status) {
    switch (status) {
      case TransactionStatus.pending:
        return Colors.orange;
      case TransactionStatus.confirming:
        return Colors.blue;
      case TransactionStatus.confirmed:
        return Colors.green;
      case TransactionStatus.failed:
        return Colors.red;
    }
  }
}