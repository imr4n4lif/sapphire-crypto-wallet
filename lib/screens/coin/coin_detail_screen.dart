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

enum TimelineOption { day, week, month }

class CoinDetailScreen extends StatefulWidget {
  final CoinType coinType;

  const CoinDetailScreen({super.key, required this.coinType});

  @override
  State<CoinDetailScreen> createState() => _CoinDetailScreenState();
}

class _CoinDetailScreenState extends State<CoinDetailScreen> with SingleTickerProviderStateMixin {
  TimelineOption _selectedTimeline = TimelineOption.week;
  List<PricePoint> _priceHistory = [];
  bool _loadingHistory = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _refreshData();
        _loadPriceHistory();
        _animationController.forward();
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _refreshData() async {
    // Check if widget is still mounted before accessing context
    if (!mounted) return;

    try {
      await context.read<WalletProvider>().refreshBalances();

      // Check again after async operation
      if (!mounted) return;

      await context.read<WalletProvider>().refreshTransactions();
    } catch (e) {
      print('❌ Error refreshing data: $e');
      // Only show error if widget is still mounted
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error refreshing: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadPriceHistory() async {
    if (_loadingHistory || !mounted) return;

    if (mounted) {
      setState(() => _loadingHistory = true);
    }

    try {
      final days = _getTimelineDays(_selectedTimeline);
      final history = await PriceService().fetchPriceHistory(widget.coinType, days: days);

      if (mounted && history.isNotEmpty) {
        setState(() {
          _priceHistory = history;
          _loadingHistory = false;
        });
      } else if (mounted) {
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
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              if (mounted) {
                await _refreshData();
                await _loadPriceHistory();
              }
            },
          ),
        ],
      ),
      body: Consumer<WalletProvider>(
        builder: (context, walletProvider, _) {
          final balance = walletProvider.getCoinBalance(widget.coinType);
          final transactions = walletProvider.getCoinTransactions(widget.coinType);

          return RefreshIndicator(
            onRefresh: () async {
              if (mounted) {
                await _refreshData();
                await _loadPriceHistory();
              }
            },
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildBalanceCard(balance),
                  const SizedBox(height: 24),
                  _buildPriceChart(balance),
                  const SizedBox(height: 24),
                  _buildActionButtons(),
                  const SizedBox(height: 32),
                  _buildTransactionsSection(transactions),
                ],
              ),
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

    return Hero(
      tag: 'balance_${widget.coinType}',
      child: Container(
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
                    isPositive ? Icons.trending_up : Icons.trending_down,
                    size: 16,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${isPositive ? '+' : ''}${change24h.toStringAsFixed(2)}% (24h)',
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
                '1 ${_coinInfo.symbol} = ${formatter.format(pricePerCoin)}',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceChart(CoinBalance? balance) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Price Chart',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_loadingHistory)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: TimelineOption.values.map((option) {
                final isSelected = _selectedTimeline == option;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Center(
                        child: Text(
                          _getTimelineLabel(option),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                      onSelected: (selected) {
                        if (selected && !_loadingHistory && mounted) {
                          setState(() => _selectedTimeline = option);
                          _loadPriceHistory();
                        }
                      },
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
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
    final buffer = priceRange > 0 ? priceRange * 0.1 : 1.0;

    final firstPrice = _priceHistory.first.price;
    final lastPrice = _priceHistory.last.price;
    final priceChange = lastPrice - firstPrice;
    final priceChangePercent = (priceChange / firstPrice) * 100;
    final isPositive = priceChange >= 0;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isPositive
                ? Colors.green.withOpacity(0.1)
                : Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '${isPositive ? '+' : ''}${priceChangePercent.toStringAsFixed(2)}% in ${_getTimelineLabel(_selectedTimeline)}',
            style: TextStyle(
              color: isPositive ? Colors.green : Colors.red,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: LineChart(
            LineChartData(
              minY: minPrice - buffer,
              maxY: maxPrice + buffer,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: priceRange > 0 ? (maxPrice - minPrice) / 4 : 1,
                getDrawingHorizontalLine: (value) {
                  return FlLine(
                    color: Colors.grey.withOpacity(0.2),
                    strokeWidth: 1,
                    dashArray: [5, 5],
                  );
                },
              ),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 50,
                    interval: priceRange > 0 ? (maxPrice - minPrice) / 4 : 1,
                    getTitlesWidget: (value, meta) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Text(
                          '\$${value >= 1000 ? '${(value / 1000).toStringAsFixed(1)}k' : value.toStringAsFixed(0)}',
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
                      } else if (_selectedTimeline == TimelineOption.week) {
                        label = DateFormat('E').format(date);
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
                  curveSmoothness: 0.3,
                  color: isPositive ? Colors.green : Colors.red,
                  barWidth: 2,
                  dotData: FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      colors: [
                        (isPositive ? Colors.green : Colors.red).withOpacity(0.3),
                        (isPositive ? Colors.green : Colors.red).withOpacity(0.0),
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
                  tooltipBorder: BorderSide(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                  ),
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
                handleBuiltInTouches: true,
                touchCallback: (FlTouchEvent event, LineTouchResponse? response) {},
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {
              if (mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SendScreen(coinType: widget.coinType),
                  ),
                );
              }
            },
            icon: const Icon(Icons.arrow_upward),
            label: const Text('Send'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              if (mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ReceiveScreen(coinType: widget.coinType),
                  ),
                );
              }
            },
            icon: const Icon(Icons.arrow_downward),
            label: const Text('Receive'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: BorderSide(
                color: Theme.of(context).colorScheme.primary,
                width: 2,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionsSection(List<Transaction> transactions) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Transactions',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (transactions.isNotEmpty)
              Text(
                '${transactions.length} total',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
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
                  const SizedBox(height: 8),
                  Text(
                    'Your transactions will appear here',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          )
        else
          ...transactions.take(10).map((tx) => _buildTransactionCard(tx)),
      ],
    );
  }

  Widget _buildTransactionCard(Transaction tx) {
    final dateFormat = DateFormat('MMM dd, yyyy • HH:mm');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TransactionDetailScreen(transaction: tx),
              ),
            );
          }
        },
        borderRadius: BorderRadius.circular(12),
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
                      _getStatusText(tx),
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
                        fontWeight: FontWeight.bold,
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

  String _getStatusText(Transaction tx) {
    switch (tx.status) {
      case TransactionStatus.pending:
        return 'Pending';
      case TransactionStatus.confirming:
        return '${tx.confirmations} confirmations';
      case TransactionStatus.confirmed:
        return 'Confirmed';
      case TransactionStatus.failed:
        return 'Failed';
    }
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