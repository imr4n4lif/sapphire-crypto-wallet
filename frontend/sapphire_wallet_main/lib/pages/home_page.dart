import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../models/wallet_model.dart';
import '../providers/wallet_provider.dart';
import '../providers/theme_provider.dart';
import 'coin_detail_page.dart';
import 'send_page.dart';
import 'receive_page.dart';
import 'manage_wallets_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final walletProvider = Provider.of<WalletProvider>(context, listen: false);
      if (walletProvider.currentWallet != null &&
          walletProvider.currentWallet!.coins.isNotEmpty &&
          walletProvider.currentWallet!.coins.first.price == 0) {
        walletProvider.refreshPrices();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final walletProvider = Provider.of<WalletProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);

    if (walletProvider.currentWallet == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('No wallet found'),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  // Navigate to create wallet
                },
                child: const Text('Create Wallet'),
              ),
            ],
          ),
        ),
      );
    }

    final wallet = walletProvider.currentWallet!;

    return Scaffold(
      appBar: AppBar(
        title: Text(wallet.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: walletProvider.isLoading ? null : () {
              walletProvider.refreshPrices();
            },
          ),
          IconButton(
            icon: Icon(themeProvider.themeMode == ThemeMode.dark
                ? Icons.light_mode
                : Icons.dark_mode),
            onPressed: themeProvider.toggleTheme,
          ),
          IconButton(
            icon: const Icon(Icons.account_balance_wallet),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ManageWalletsPage()),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => walletProvider.refreshPrices(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              // Total Balance
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(24.0),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      Theme.of(context).colorScheme.secondary.withOpacity(0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Text(
                      'Total Balance',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 8),
                    walletProvider.isLoading
                        ? Shimmer.fromColors(
                      baseColor: Colors.grey.shade300,
                      highlightColor: Colors.grey.shade100,
                      child: Container(
                        height: 40,
                        width: 150,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    )
                        : Text(
                      '\$${walletProvider.getTotalBalance().toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),

              // Action Buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildActionButton(
                        context,
                        icon: Icons.arrow_upward,
                        label: 'Send',
                        color: Colors.red,
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const SendPage()),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildActionButton(
                        context,
                        icon: Icons.arrow_downward,
                        label: 'Receive',
                        color: Colors.green,
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const ReceivePage()),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildActionButton(
                        context,
                        icon: Icons.swap_horiz,
                        label: 'Swap',
                        color: Colors.blue,
                        onPressed: () {
                          // TODO: Implement swap functionality
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Swap feature coming soon!')),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Coin List Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Your Assets',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${wallet.coins.length} coins',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Coin List
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: wallet.coins.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final coin = wallet.coins[index];
                  return _CoinCard(coin: coin, isLoading: walletProvider.isLoading);
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Material(
      borderRadius: BorderRadius.circular(12),
      color: color.withOpacity(0.1),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CoinCard extends StatelessWidget {
  final CryptoCoin coin;
  final bool isLoading;

  const _CoinCard({required this.coin, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    final priceChange = coin.priceHistory.length > 1
        ? ((coin.priceHistory.last.price - coin.priceHistory.first.price) / coin.priceHistory.first.price * 100)
        : 0.0;

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
          child: Text(
            coin.icon,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        title: Row(
          children: [
            Text(
              coin.name,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                coin.symbol,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              '${coin.balance.toStringAsFixed(4)} ${coin.symbol}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            if (coin.priceHistory.length > 1)
              Row(
                children: [
                  Icon(
                    priceChange >= 0 ? Icons.arrow_upward : Icons.arrow_downward,
                    size: 12,
                    color: priceChange >= 0 ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '${priceChange.abs().toStringAsFixed(2)}%',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: priceChange >= 0 ? Colors.green : Colors.red,
                    ),
                  ),
                ],
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            isLoading
                ? Shimmer.fromColors(
              baseColor: Colors.grey.shade300,
              highlightColor: Colors.grey.shade100,
              child: Container(
                height: 16,
                width: 80,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            )
                : Text(
              '\$${coin.valueInUSD.toStringAsFixed(2)}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            isLoading
                ? Shimmer.fromColors(
              baseColor: Colors.grey.shade300,
              highlightColor: Colors.grey.shade100,
              child: Container(
                height: 12,
                width: 60,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            )
                : Text(
              '\$${coin.price.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CoinDetailPage(coin: coin),
            ),
          );
        },
      ),
    );
  }
}