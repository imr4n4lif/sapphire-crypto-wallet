import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../models/wallet.dart';
import '../../core/constants/app_constants.dart';

class TransactionDetailScreen extends StatelessWidget {
  final Transaction transaction;

  const TransactionDetailScreen({
    super.key,
    required this.transaction,
  });

  CoinInfo get _coinInfo {
    return CoinInfo.allCoins.firstWhere((c) => c.type == transaction.coinType);
  }

  Color _getStatusColor(BuildContext context) {
    switch (transaction.status) {
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

  String _getStatusText() {
    switch (transaction.status) {
      case TransactionStatus.pending:
        return 'Pending';
      case TransactionStatus.confirming:
        return 'Confirming';
      case TransactionStatus.confirmed:
        return 'Confirmed';
      case TransactionStatus.failed:
        return 'Failed';
    }
  }

  void _copyToClipboard(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copied to clipboard')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM dd, yyyy • HH:mm:ss');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_new),
            tooltip: 'View on Explorer',
            onPressed: () {
              // Open in block explorer
              String explorerUrl = '';
              if (transaction.coinType == CoinType.btc) {
                explorerUrl = transaction.isIncoming
                    ? 'https://mempool.space/testnet4/tx/${transaction.hash}'
                    : 'https://blockstream.info/tx/${transaction.hash}';
              } else if (transaction.coinType == CoinType.eth) {
                explorerUrl = 'https://sepolia.etherscan.io/tx/${transaction.hash}';
              }

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Explorer: $explorerUrl'),
                  action: SnackBarAction(
                    label: 'Copy',
                    onPressed: () => _copyToClipboard(context, explorerUrl, 'Explorer URL'),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Status Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: _getStatusColor(context).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      transaction.isIncoming
                          ? Icons.arrow_downward
                          : Icons.arrow_upward,
                      size: 40,
                      color: _getStatusColor(context),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    transaction.isIncoming ? 'Received' : 'Sent',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${transaction.isIncoming ? '+' : '-'}${transaction.amount.toStringAsFixed(8)} ${_coinInfo.symbol}',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: transaction.isIncoming ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: _getStatusColor(context).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _getStatusColor(context)),
                    ),
                    child: Text(
                      _getStatusText(),
                      style: TextStyle(
                        color: _getStatusColor(context),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Transaction Details
          _buildDetailCard(
            context,
            'Transaction Details',
            [
              _buildDetailRow(
                context,
                'Hash',
                transaction.hash,
                onTap: () => _copyToClipboard(context, transaction.hash, 'Transaction hash'),
              ),
              _buildDetailRow(
                context,
                'Date',
                dateFormat.format(transaction.timestamp),
              ),
              _buildDetailRow(
                context,
                'Confirmations',
                '${transaction.confirmations}',
              ),
              if (transaction.blockHeight != null)
                _buildDetailRow(
                  context,
                  'Block Height',
                  '${transaction.blockHeight}',
                ),
              if (transaction.blockHash != null)
                _buildDetailRow(
                  context,
                  'Block Hash',
                  transaction.blockHash!,
                  onTap: () => _copyToClipboard(context, transaction.blockHash!, 'Block hash'),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Addresses
          _buildDetailCard(
            context,
            'Addresses',
            [
              _buildDetailRow(
                context,
                'From',
                transaction.from,
                onTap: () => _copyToClipboard(context, transaction.from, 'From address'),
              ),
              _buildDetailRow(
                context,
                'To',
                transaction.to,
                onTap: () => _copyToClipboard(context, transaction.to, 'To address'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Fee Information
          if (transaction.fee > 0)
            _buildDetailCard(
              context,
              'Fee Information',
              [
                _buildDetailRow(
                  context,
                  'Transaction Fee',
                  '${transaction.fee.toStringAsFixed(8)} ${_coinInfo.symbol}',
                ),
                _buildDetailRow(
                  context,
                  'Total Amount',
                  '${(transaction.amount + transaction.fee).toStringAsFixed(8)} ${_coinInfo.symbol}',
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildDetailCard(BuildContext context, String title, List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(
      BuildContext context,
      String label,
      String value, {
        VoidCallback? onTap,
      }) {
    final isLongValue = value.length > 20;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 4),
          InkWell(
            onTap: onTap,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    isLongValue ? '${value.substring(0, 20)}...' : value,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontFamily: isLongValue ? 'monospace' : null,
                    ),
                  ),
                ),
                if (onTap != null) ...[
                  const SizedBox(width: 8),
                  Icon(
                    Icons.copy,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}