import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../providers/wallet_provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/blockchain_service.dart';

class SendScreen extends StatefulWidget {
  final CoinType coinType;

  const SendScreen({super.key, required this.coinType});

  @override
  State<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends State<SendScreen> {
  final _formKey = GlobalKey<FormState>();
  final _addressController = TextEditingController();
  final _amountController = TextEditingController();
  bool _isSending = false;
  bool _isEstimatingFee = false;
  double? _estimatedFee;

  @override
  void dispose() {
    _addressController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  CoinInfo get _coinInfo {
    return CoinInfo.allCoins.firstWhere((c) => c.type == widget.coinType);
  }

  Future<void> _scanQRCode() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const QRScannerScreen()),
    );

    if (result != null) {
      _addressController.text = result;
    }
  }

  void _setMaxAmount() {
    final walletProvider = context.read<WalletProvider>();
    final balance = walletProvider.getCoinBalance(widget.coinType);

    if (balance != null) {
      double maxAmount = balance.balance;

      // For ETH, subtract estimated gas fee
      if (widget.coinType == CoinType.eth && _estimatedFee != null) {
        maxAmount = (maxAmount - _estimatedFee!).clamp(0.0, double.infinity);
      }

      _amountController.text = maxAmount.toStringAsFixed(8);
      _estimateGasFee();
    }
  }

  Future<void> _estimateGasFee() async {
    if (widget.coinType != CoinType.eth) return;

    final address = _addressController.text.trim();
    final amountText = _amountController.text.trim();

    if (address.isEmpty || amountText.isEmpty) return;

    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) return;

    setState(() {
      _isEstimatingFee = true;
      _estimatedFee = null;
    });

    try {
      final walletProvider = context.read<WalletProvider>();
      if (walletProvider.wallet == null) return;

      final estimate = await BlockchainService().estimateEthereumGasFee(
        fromAddress: walletProvider.wallet!.ethAddress,
        toAddress: address,
        amount: amount,
      );

      setState(() {
        _estimatedFee = estimate.totalFee;
        _isEstimatingFee = false;
      });
    } catch (e) {
      print('Error estimating fee: $e');
      setState(() {
        _estimatedFee = null;
        _isEstimatingFee = false;
      });
    }
  }

  Future<void> _sendTransaction() async {
    if (!_formKey.currentState!.validate()) return;

    final amountText = _amountController.text.trim();
    final amount = double.tryParse(amountText);

    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid amount'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Transaction'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Send $amount ${_coinInfo.symbol}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text('To: ${_addressController.text}'),
            if (_estimatedFee != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Estimated Gas Fee',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('${_estimatedFee!.toStringAsFixed(6)} ETH'),
                    const Divider(height: 16),
                    Text(
                      'Total: ${(amount + _estimatedFee!).toStringAsFixed(6)} ETH',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ] else ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Network fees will be deducted',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
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

    if (confirmed != true) return;

    setState(() => _isSending = true);

    try {
      final walletProvider = context.read<WalletProvider>();
      final txHash = await walletProvider.sendTransaction(
        coinType: widget.coinType,
        toAddress: _addressController.text.trim(),
        amount: amount,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '✅ Transaction sent successfully!',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Hash: ${txHash.substring(0, 20)}...',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      setState(() => _isSending = false);

      if (mounted) {
        String errorMessage = e.toString();
        if (errorMessage.contains('Exception:')) {
          errorMessage = errorMessage.split('Exception:').last.trim();
        }

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red),
                SizedBox(width: 8),
                Text('Transaction Failed'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(errorMessage),
                  const SizedBox(height: 16),
                  if (errorMessage.contains('Insufficient funds'))
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '💡 Tips:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 8),
                          Text('• Try a smaller amount'),
                          Text('• You need ETH for gas fees'),
                          Text('• Get testnet ETH from:'),
                          Text(
                            '  sepoliafaucet.com',
                            style: TextStyle(
                              color: Colors.blue,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ],
                      ),
                    ),
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
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Send ${_coinInfo.symbol}'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Consumer<WalletProvider>(
                builder: (context, walletProvider, _) {
                  final balance = walletProvider.getCoinBalance(widget.coinType);
                  final balanceValue = balance?.balance ?? 0.0;

                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Available Balance',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${balanceValue.toStringAsFixed(8)} ${_coinInfo.symbol}',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _addressController,
                decoration: InputDecoration(
                  labelText: 'Recipient Address',
                  hintText: 'Enter or scan address',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.qr_code_scanner),
                    onPressed: _scanQRCode,
                  ),
                ),
                onChanged: (_) => _estimateGasFee(),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter recipient address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                decoration: InputDecoration(
                  labelText: 'Amount',
                  hintText: '0.00',
                  suffixText: _coinInfo.symbol,
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.file_upload_outlined),
                    tooltip: 'Max',
                    onPressed: _setMaxAmount,
                  ),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => _estimateGasFee(),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter amount';
                  }

                  final amount = double.tryParse(value.trim());
                  if (amount == null || amount <= 0) {
                    return 'Please enter valid amount';
                  }

                  final balance = context.read<WalletProvider>().getCoinBalance(widget.coinType);
                  if (balance != null) {
                    final maxAvailable = widget.coinType == CoinType.eth && _estimatedFee != null
                        ? balance.balance - _estimatedFee!
                        : balance.balance;

                    if (amount > maxAvailable) {
                      return 'Insufficient balance';
                    }
                  }

                  return null;
                },
              ),

              // Gas Fee Display
              if (widget.coinType == CoinType.eth) ...[
                const SizedBox(height: 16),
                if (_isEstimatingFee)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.withOpacity(0.3)),
                    ),
                    child: const Row(
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 12),
                        Text('Estimating gas fee...'),
                      ],
                    ),
                  )
                else if (_estimatedFee != null)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.local_gas_station, color: Colors.blue),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Estimated Gas Fee',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                '${_estimatedFee!.toStringAsFixed(6)} ETH',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],

              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Double-check the address before sending. Transactions cannot be reversed.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSending ? null : _sendTransaction,
                  child: _isSending
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Text('Send'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR Code'),
      ),
      body: MobileScanner(
        onDetect: (capture) {
          final List<Barcode> barcodes = capture.barcodes;
          for (final barcode in barcodes) {
            if (barcode.rawValue != null) {
              Navigator.pop(context, barcode.rawValue);
              break;
            }
          }
        },
      ),
    );
  }
}