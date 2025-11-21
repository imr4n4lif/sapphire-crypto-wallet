import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/address_book_entry.dart';
import '../../core/services/address_book_service.dart';
import '../../core/constants/app_constants.dart';
import '../../widgets/coin_icon.dart';

class AddressBookScreen extends StatefulWidget {
  const AddressBookScreen({super.key});

  @override
  State<AddressBookScreen> createState() => _AddressBookScreenState();
}

class _AddressBookScreenState extends State<AddressBookScreen> {
  final AddressBookService _addressBookService = AddressBookService();
  List<AddressBookEntry> _entries = [];
  CoinType? _filterCoinType;

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  void _loadEntries() {
    setState(() {
      if (_filterCoinType != null) {
        _entries = _addressBookService.getEntriesByCoin(_filterCoinType!);
      } else {
        _entries = _addressBookService.getAllEntries();
      }
    });
  }

  void _showAddDialog() {
    showDialog(
      context: context,
      builder: (context) => _AddEditAddressDialog(
        onSave: (entry) async {
          await _addressBookService.addEntry(entry);
          _loadEntries();
        },
      ),
    );
  }

  void _showEditDialog(AddressBookEntry entry) {
    showDialog(
      context: context,
      builder: (context) => _AddEditAddressDialog(
        entry: entry,
        onSave: (updatedEntry) async {
          await _addressBookService.updateEntry(updatedEntry);
          _loadEntries();
        },
      ),
    );
  }

  void _deleteEntry(AddressBookEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Address'),
        content: Text('Are you sure you want to delete "${entry.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _addressBookService.deleteEntry(entry.id);
      _loadEntries();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Address deleted'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Address Book'),
        actions: [
          PopupMenuButton<CoinType?>(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filter by coin',
            onSelected: (coinType) {
              setState(() {
                _filterCoinType = coinType;
                _loadEntries();
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: null,
                child: Row(
                  children: [
                    Icon(Icons.grid_view),
                    SizedBox(width: 12),
                    Text('All Coins'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              ...CoinInfo.allCoins.map((coin) {
                return PopupMenuItem(
                  value: coin.type,
                  child: Row(
                    children: [
                      CoinIcon(coinType: coin.type, size: 20),
                      const SizedBox(width: 12),
                      Text(coin.name),
                    ],
                  ),
                );
              }),
            ],
          ),
        ],
      ),
      body: _entries.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.contacts_outlined,
              size: 80,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
            ),
            const SizedBox(height: 24),
            Text(
              _filterCoinType != null
                  ? 'No ${CoinInfo.allCoins.firstWhere((c) => c.type == _filterCoinType).name} addresses'
                  : 'No addresses saved',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Add addresses to quickly send crypto',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _showAddDialog,
              icon: const Icon(Icons.add),
              label: const Text('Add Address'),
            ),
          ],
        ),
      )
          : Column(
        children: [
          if (_filterCoinType != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              child: Row(
                children: [
                  Text(
                    'Showing ${CoinInfo.allCoins.firstWhere((c) => c.type == _filterCoinType).name} addresses',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _filterCoinType = null;
                        _loadEntries();
                      });
                    },
                    child: const Text('Clear Filter'),
                  ),
                ],
              ),
            ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _entries.length,
              itemBuilder: (context, index) {
                final entry = _entries[index];
                return _buildAddressCard(entry);
              },
            ),
          ),
        ],
      ),
      floatingActionButton: _entries.isNotEmpty
          ? FloatingActionButton(
        onPressed: _showAddDialog,
        child: const Icon(Icons.add),
      )
          : null,
    );
  }

  Widget _buildAddressCard(AddressBookEntry entry) {
    final coinInfo = CoinInfo.allCoins.firstWhere((c) => c.type == entry.coinType);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showEditDialog(entry),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: CoinIcon(coinType: entry.coinType, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.name,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          coinInfo.name,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 20),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: entry.address));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Address copied'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    color: Colors.red,
                    onPressed: () => _deleteEntry(entry),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.address,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddEditAddressDialog extends StatefulWidget {
  final AddressBookEntry? entry;
  final Function(AddressBookEntry) onSave;

  const _AddEditAddressDialog({
    this.entry,
    required this.onSave,
  });

  @override
  State<_AddEditAddressDialog> createState() => _AddEditAddressDialogState();
}

class _AddEditAddressDialogState extends State<_AddEditAddressDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  CoinType _selectedCoinType = CoinType.btc;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.entry != null) {
      _nameController.text = widget.entry!.name;
      _addressController.text = widget.entry!.address;
      _selectedCoinType = widget.entry!.coinType;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final entry = AddressBookEntry(
      id: widget.entry?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text.trim(),
      address: _addressController.text.trim(),
      coinType: _selectedCoinType,
      createdAt: widget.entry?.createdAt ?? DateTime.now(),
    );

    widget.onSave(entry);

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.entry == null ? 'Address added' : 'Address updated'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  bool _validateAddress(String address) {
    switch (_selectedCoinType) {
      case CoinType.btc:
        return address.startsWith('1') || address.startsWith('3') ||
            address.startsWith('bc1') || address.startsWith('m') ||
            address.startsWith('n') || address.startsWith('2') ||
            address.startsWith('tb1');
      case CoinType.eth:
        return address.startsWith('0x') && address.length == 42;
      case CoinType.trx:
        return address.startsWith('T') && address.length >= 30;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.entry == null ? 'Add Address' : 'Edit Address'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  hintText: 'e.g., Mom\'s Wallet',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                textCapitalization: TextCapitalization.words,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<CoinType>(
                value: _selectedCoinType,
                decoration: const InputDecoration(
                  labelText: 'Coin',
                  prefixIcon: Icon(Icons.currency_bitcoin),
                ),
                items: CoinInfo.allCoins.map((coin) {
                  return DropdownMenuItem(
                    value: coin.type,
                    child: Row(
                      children: [
                        CoinIcon(coinType: coin.type, size: 20),
                        const SizedBox(width: 12),
                        Text(coin.name),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: widget.entry == null
                    ? (value) {
                  if (value != null) {
                    setState(() => _selectedCoinType = value);
                  }
                }
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'Address',
                  hintText: 'Enter wallet address',
                  prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                ),
                maxLines: 2,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter an address';
                  }
                  if (!_validateAddress(value.trim())) {
                    return 'Invalid ${CoinInfo.allCoins.firstWhere((c) => c.type == _selectedCoinType).symbol} address';
                  }

                  // Check for duplicates (except when editing same entry)
                  if (widget.entry == null || widget.entry!.address != value.trim()) {
                    if (AddressBookService().addressExists(value.trim(), _selectedCoinType)) {
                      return 'This address already exists';
                    }
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
              : Text(widget.entry == null ? 'Add' : 'Save'),
        ),
      ],
    );
  }
}