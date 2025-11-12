import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/wallet_provider.dart';
import 'create_import_wallet_page.dart';

class ManageWalletsPage extends StatelessWidget {
  const ManageWalletsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final walletProvider = Provider.of<WalletProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Wallets'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CreateImportWalletPage()),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Add New Wallet'),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: walletProvider.wallets.length,
              itemBuilder: (context, index) {
                final wallet = walletProvider.wallets[index];
                final isCurrent = walletProvider.currentWallet?.id == wallet.id;

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: ListTile(
                    leading: const Icon(Icons.account_balance_wallet),
                    title: Text(wallet.name),
                    subtitle: Text('Created: ${wallet.createdAt.toString().split(' ')[0]}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isCurrent)
                          const Chip(
                            label: Text('Current'),
                            backgroundColor: Colors.green,
                            labelStyle: TextStyle(color: Colors.white),
                          ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            _showDeleteDialog(context, walletProvider, wallet.id);
                          },
                        ),
                      ],
                    ),
                    onTap: () {
                      if (!isCurrent) {
                        walletProvider.switchWallet(wallet);
                        Navigator.pop(context);
                      }
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, WalletProvider walletProvider, String walletId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Wallet?'),
        content: const Text('This action cannot be undone. Make sure you have your seed phrase backed up.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              walletProvider.removeWallet(walletId);
              Navigator.pop(context);
              if (walletProvider.wallets.isEmpty) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const CreateImportWalletPage()),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}