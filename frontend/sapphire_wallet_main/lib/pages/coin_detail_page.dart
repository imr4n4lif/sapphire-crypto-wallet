import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/wallet_model.dart';
import '../providers/wallet_provider.dart';

class CoinDetailPage extends StatefulWidget {
  final CryptoCoin coin;

  const CoinDetailPage({super.key, required this.coin});

  @override
  State<CoinDetailPage> createState() => _CoinDetailPageState();
}

class _CoinDetailPageState extends State<CoinDetailPage> {
  int _selectedTimeframe = 7; // 7 days

  Widget _buildPriceChart() {
    if (widget.coin.priceHistory.isEmpty) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.show_chart, size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 8),
              Text(
                'Price data not available',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      );
    }

    // Simple custom chart implementation
    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: CustomPaint(
        painter: _PriceChartPainter(
          priceHistory: widget.coin.priceHistory,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildTimeframeSelector() {
    final List<Map<String, dynamic>> timeframes = [
      {'days': 1, 'label': '1D'},
      {'days': 7, 'label': '1W'},
      {'days': 30, 'label': '1M'},
      {'days': 365, 'label': '1Y'},
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: timeframes.map((timeframe) {
        final isSelected = _selectedTimeframe == timeframe['days'] as int;
        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedTimeframe = timeframe['days'] as int;
              // TODO: Fetch data for selected timeframe
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey.shade400,
              ),
            ),
            child: Text(
              timeframe['label'] as String,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  String _formatAddress(String address) {
    if (address.length <= 16) return address;
    return '${address.substring(0, 8)}...${address.substring(address.length - 8)}';
  }

  @override
  Widget build(BuildContext context) {
    final walletProvider = Provider.of<WalletProvider>(context);
    final transactions = walletProvider.initialTransactions
        .where((tx) => tx.coinSymbol == widget.coin.symbol)
        .toList();

    final priceChange = widget.coin.priceHistory.length > 1
        ? widget.coin.priceHistory.last.price - widget.coin.priceHistory.first.price
        : 0.0;
    final priceChangePercent = widget.coin.priceHistory.length > 1
        ? (priceChange / widget.coin.priceHistory.first.price * 100)
        : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.coin.name} Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              walletProvider.refreshPrices();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Coin Overview Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                          child: Text(
                            widget.coin.icon,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '\$${widget.coin.price.toStringAsFixed(2)}',
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  priceChange >= 0 ? Icons.arrow_upward : Icons.arrow_downward,
                                  size: 16,
                                  color: priceChange >= 0 ? Colors.green : Colors.red,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  '${priceChangePercent.toStringAsFixed(2)}%',
                                  style: TextStyle(
                                    color: priceChange >= 0 ? Colors.green : Colors.red,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildStatItem('Balance', '${widget.coin.balance} ${widget.coin.symbol}'),
                        _buildStatItem('Value', '\$${widget.coin.valueInUSD.toStringAsFixed(2)}'),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Price Chart
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildTimeframeSelector(),
                    const SizedBox(height: 16),
                    _buildPriceChart(),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Address Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your ${widget.coin.symbol} Address',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.background,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: SelectableText(
                        widget.coin.address,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              // Copy to clipboard
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Address copied to clipboard')),
                              );
                            },
                            icon: const Icon(Icons.copy),
                            label: const Text('Copy Address'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              // Share address
                            },
                            icon: const Icon(Icons.share),
                            label: const Text('Share'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Transaction History
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Transaction History',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${transactions.length} transactions',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    transactions.isEmpty
                        ? _buildEmptyTransactions()
                        : Column(
                      children: transactions.map((tx) => _buildTransactionTile(tx)).toList(),
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

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionTile(Transaction tx) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: tx.type == 'send'
                  ? Colors.red.withOpacity(0.1)
                  : Colors.green.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              tx.type == 'send' ? Icons.arrow_upward : Icons.arrow_downward,
              color: tx.type == 'send' ? Colors.red : Colors.green,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${tx.type.toUpperCase()} ${tx.amount} ${tx.coinSymbol}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  'To: ${_formatAddress(tx.address)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  'Date: ${tx.date.toString().split(' ')[0]}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${tx.type == 'send' ? '-' : '+'}${tx.amount}',
                style: TextStyle(
                  color: tx.type == 'send' ? Colors.red : Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: tx.status == 'confirmed'
                      ? Colors.green.withOpacity(0.1)
                      : Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  tx.status,
                  style: TextStyle(
                    color: tx.status == 'confirmed' ? Colors.green : Colors.orange,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyTransactions() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(Icons.receipt_long, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            'No transactions yet',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            'Your transaction history will appear here',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _PriceChartPainter extends CustomPainter {
  final List<PricePoint> priceHistory;
  final Color color;

  _PriceChartPainter({required this.priceHistory, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (priceHistory.length < 2) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..color = color.withOpacity(0.1)
      ..style = PaintingStyle.fill;

    final path = Path();
    final fillPath = Path();

    final minPrice = priceHistory.map((p) => p.price).reduce((a, b) => a < b ? a : b);
    final maxPrice = priceHistory.map((p) => p.price).reduce((a, b) => a > b ? a : b);
    final priceRange = maxPrice - minPrice;

    final points = priceHistory.asMap().entries.map((entry) {
      final x = (entry.key / (priceHistory.length - 1)) * size.width;
      final y = size.height - ((entry.value.price - minPrice) / priceRange) * size.height;
      return Offset(x, y);
    }).toList();

    // Draw filled area
    fillPath.moveTo(points.first.dx, size.height);
    for (final point in points) {
      fillPath.lineTo(point.dx, point.dy);
    }
    fillPath.lineTo(points.last.dx, size.height);
    fillPath.close();
    canvas.drawPath(fillPath, fillPaint);

    // Draw line
    path.moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}