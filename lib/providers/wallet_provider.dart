import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import '../models/wallet.dart';
import '../core/constants/app_constants.dart';
import '../core/services/wallet_service.dart';
import '../core/services/blockchain_service.dart';
import '../core/services/price_service.dart';
import '../core/services/secure_storage_service.dart';
import '../core/services/notification_service.dart';

class WalletProvider with ChangeNotifier {
  final WalletService _walletService = WalletService();
  final BlockchainService _blockchainService = BlockchainService();
  final PriceService _priceService = PriceService();
  final SecureStorageService _storage = SecureStorageService();
  final NotificationService _notificationService = NotificationService();

  // Multi-wallet support
  List<Map<String, dynamic>> _allWallets = [];
  String? _currentWalletId;

  WalletData? _wallet;
  bool _isMainnet = true;
  bool _isLoading = false;
  bool _isRefreshing = false;
  Map<CoinType, CoinBalance> _balances = {};
  Map<CoinType, List<Transaction>> _transactions = {};

  Timer? _autoRefreshTimer;
  static const Duration _refreshInterval = Duration(minutes: 5);

  WalletData? get wallet => _wallet;
  bool get isMainnet => _isMainnet;
  bool get isLoading => _isLoading;
  bool get isRefreshing => _isRefreshing;
  Map<CoinType, CoinBalance> get balances => _balances;
  Map<CoinType, List<Transaction>> get transactions => _transactions;
  List<Map<String, dynamic>> get allWallets => _allWallets;
  String? get currentWalletId => _currentWalletId;
  String? get currentWalletName => _getCurrentWalletName();

  double get totalPortfolioValue {
    final total = _balances.values.fold(0.0, (sum, balance) => sum + balance.usdValue);
    print('💰 Total portfolio value: \$$total');
    return total;
  }

  String? _getCurrentWalletName() {
    if (_currentWalletId == null) return null;
    final wallet = _allWallets.firstWhere(
          (w) => w['id'] == _currentWalletId,
      orElse: () => {},
    );
    return wallet['name'] as String?;
  }

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      print('🔄 Initializing wallet provider...');

      _isMainnet = await _storage.readBool(AppConstants.keyIsMainnet, defaultValue: true);
      _blockchainService.initialize(_isMainnet);

      // Load all wallets
      await _loadAllWallets();

      // Load current wallet ID
      _currentWalletId = await _storage.readString('current_wallet_id');

      if (_allWallets.isNotEmpty) {
        // If no current wallet set, use first one
        if (_currentWalletId == null) {
          _currentWalletId = _allWallets.first['id'] as String;
          await _storage.saveString('current_wallet_id', _currentWalletId!);
        }

        // Load current wallet
        await _loadCurrentWallet();
        await refreshBalances();
        await refreshTransactions();

        _startAutoRefresh();
      } else {
        print('ℹ️ No wallets found');
      }
    } catch (e) {
      print('❌ Error initializing wallet: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadAllWallets() async {
    final walletsJson = await _storage.readString('all_wallets');
    if (walletsJson != null) {
      try {
        final List<dynamic> decoded = json.decode(walletsJson);
        _allWallets = decoded.cast<Map<String, dynamic>>();
        print('✅ Loaded ${_allWallets.length} wallets');
      } catch (e) {
        print('❌ Error loading wallets: $e');
        _allWallets = [];
      }
    }
  }

  Future<void> _saveAllWallets() async {
    final encoded = json.encode(_allWallets);
    await _storage.saveString('all_wallets', encoded);
  }

  Future<void> _loadCurrentWallet() async {
    if (_currentWalletId == null) return;

    final mnemonic = await _storage.readSecure('mnemonic_$_currentWalletId');
    if (mnemonic != null) {
      print('✅ Loading wallet: $_currentWalletId');
      _wallet = await _walletService.createWalletFromMnemonic(mnemonic, _isMainnet);
    }
  }

  Future<String> createNewWallet(String name) async {
    print('🆕 Creating new wallet: $name');

    try {
      final mnemonic = _walletService.generateMnemonic();
      final walletData = await _walletService.createWalletFromMnemonic(mnemonic, _isMainnet);

      // Generate unique ID
      final walletId = DateTime.now().millisecondsSinceEpoch.toString();

      // Save mnemonic
      await _storage.saveSecure('mnemonic_$walletId', mnemonic);

      // Add to wallets list
      _allWallets.add({
        'id': walletId,
        'name': name,
        'ethAddress': walletData.ethAddress,
        'btcAddress': walletData.btcAddress,
        'filAddress': walletData.filAddress,
        'createdAt': DateTime.now().toIso8601String(),
      });

      await _saveAllWallets();

      // Switch to new wallet
      await switchWallet(walletId);

      return mnemonic;
    } catch (e) {
      print('❌ Failed to create wallet: $e');
      throw Exception('Failed to create wallet: $e');
    }
  }

  Future<void> importExistingWallet(String name, String mnemonic) async {
    print('📥 Importing wallet: $name');

    try {
      if (!_walletService.validateMnemonic(mnemonic)) {
        throw Exception('Invalid mnemonic phrase');
      }

      final walletData = await _walletService.createWalletFromMnemonic(mnemonic, _isMainnet);

      // Generate unique ID
      final walletId = DateTime.now().millisecondsSinceEpoch.toString();

      // Save mnemonic
      await _storage.saveSecure('mnemonic_$walletId', mnemonic);

      // Add to wallets list
      _allWallets.add({
        'id': walletId,
        'name': name,
        'ethAddress': walletData.ethAddress,
        'btcAddress': walletData.btcAddress,
        'filAddress': walletData.filAddress,
        'createdAt': DateTime.now().toIso8601String(),
      });

      await _saveAllWallets();

      // Switch to imported wallet
      await switchWallet(walletId);

      print('✅ Wallet imported successfully');
    } catch (e) {
      print('❌ Failed to import wallet: $e');
      throw Exception('Failed to import wallet: $e');
    }
  }

  Future<void> switchWallet(String walletId) async {
    print('🔄 Switching to wallet: $walletId');

    _currentWalletId = walletId;
    await _storage.saveString('current_wallet_id', walletId);

    await _loadCurrentWallet();
    await refreshBalances();
    await refreshTransactions();

    notifyListeners();
  }

  Future<void> deleteWalletById(String walletId) async {
    print('🗑️ Deleting wallet: $walletId');

    // Don't delete if it's the only wallet
    if (_allWallets.length == 1) {
      throw Exception('Cannot delete the only wallet');
    }

    // Delete mnemonic
    await _storage.deleteSecure('mnemonic_$walletId');

    // Remove from list
    _allWallets.removeWhere((w) => w['id'] == walletId);
    await _saveAllWallets();

    // If deleted current wallet, switch to first available
    if (_currentWalletId == walletId) {
      await switchWallet(_allWallets.first['id'] as String);
    }

    notifyListeners();
  }

  void _startAutoRefresh() {
    _stopAutoRefresh();

    print('⏰ Starting auto-refresh (every ${_refreshInterval.inMinutes} minutes)');
    _autoRefreshTimer = Timer.periodic(_refreshInterval, (timer) async {
      if (!_isRefreshing) {
        print('🔄 Auto-refreshing wallet data...');
        await refreshBalances();
        await refreshTransactions();
      } else {
        print('⏭️ Skipping auto-refresh (already refreshing)');
      }
    });
  }

  void _stopAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = null;
  }

  Future<String> createWallet() async {
    _isLoading = true;
    notifyListeners();

    try {
      print('🆕 Creating new wallet...');
      final mnemonic = _walletService.generateMnemonic();
      _wallet = await _walletService.createWalletFromMnemonic(mnemonic, _isMainnet);

      final walletId = DateTime.now().millisecondsSinceEpoch.toString();

      await _storage.saveSecure('mnemonic_$walletId', mnemonic);
      await _storage.saveBool(AppConstants.keyWalletCreated, true);

      _allWallets.add({
        'id': walletId,
        'name': 'Main Wallet',
        'ethAddress': _wallet!.ethAddress,
        'btcAddress': _wallet!.btcAddress,
        'filAddress': _wallet!.filAddress,
        'createdAt': DateTime.now().toIso8601String(),
      });

      _currentWalletId = walletId;
      await _storage.saveString('current_wallet_id', walletId);
      await _saveAllWallets();

      await refreshBalances();

      _startAutoRefresh();

      _isLoading = false;
      notifyListeners();

      print('✅ Wallet created successfully');
      return mnemonic;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      print('❌ Failed to create wallet: $e');
      throw Exception('Failed to create wallet: $e');
    }
  }

  Future<void> importWallet(String mnemonic) async {
    _isLoading = true;
    notifyListeners();

    try {
      print('📥 Importing wallet...');

      if (!_walletService.validateMnemonic(mnemonic)) {
        throw Exception('Invalid mnemonic phrase');
      }

      _wallet = await _walletService.createWalletFromMnemonic(mnemonic, _isMainnet);

      final walletId = DateTime.now().millisecondsSinceEpoch.toString();

      await _storage.saveSecure('mnemonic_$walletId', mnemonic);
      await _storage.saveBool(AppConstants.keyWalletCreated, true);

      _allWallets.add({
        'id': walletId,
        'name': 'Imported Wallet',
        'ethAddress': _wallet!.ethAddress,
        'btcAddress': _wallet!.btcAddress,
        'filAddress': _wallet!.filAddress,
        'createdAt': DateTime.now().toIso8601String(),
      });

      _currentWalletId = walletId;
      await _storage.saveString('current_wallet_id', walletId);
      await _saveAllWallets();

      await refreshBalances();
      await refreshTransactions();

      _startAutoRefresh();

      _isLoading = false;
      notifyListeners();

      print('✅ Wallet imported successfully');
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      print('❌ Failed to import wallet: $e');
      throw Exception('Failed to import wallet: $e');
    }
  }

  Future<void> deleteWallet() async {
    print('🗑️ Deleting wallet...');

    _stopAutoRefresh();
    _blockchainService.clearCache();

    // Delete all wallets
    for (var wallet in _allWallets) {
      await _storage.deleteSecure('mnemonic_${wallet['id']}');
    }

    await _storage.saveString('all_wallets', '[]');
    await _storage.saveString('current_wallet_id', '');
    await _storage.saveBool(AppConstants.keyWalletCreated, false);

    _wallet = null;
    _allWallets.clear();
    _currentWalletId = null;
    _balances.clear();
    _transactions.clear();
    notifyListeners();

    print('✅ Wallet deleted');
  }

  Future<void> toggleNetwork() async {
    print('🔄 Toggling network...');

    _isMainnet = !_isMainnet;
    await _storage.saveBool(AppConstants.keyIsMainnet, _isMainnet);
    _blockchainService.initialize(_isMainnet);
    _blockchainService.clearCache();

    if (_wallet != null && _currentWalletId != null) {
      final mnemonic = await _storage.readSecure('mnemonic_$_currentWalletId');
      if (mnemonic != null) {
        _wallet = await _walletService.createWalletFromMnemonic(mnemonic, _isMainnet);
      }
    }

    await refreshBalances();
    await refreshTransactions();
    notifyListeners();

    print('✅ Switched to ${_isMainnet ? "Mainnet" : "Testnet"}');
  }

  Future<void> refreshBalances() async {
    if (_wallet == null) {
      print('⚠️ No wallet to refresh');
      return;
    }

    if (_isRefreshing) {
      print('⏭️ Already refreshing, skipping...');
      return;
    }

    _isRefreshing = true;
    notifyListeners();

    try {
      print('🔄 Refreshing balances...');

      // Fetch prices first
      print('💲 Fetching crypto prices...');
      final prices = await _priceService.fetchAllPrices();

      // Debug price fetching
      for (final coinType in CoinType.values) {
        final price = prices[coinType];
        if (price != null) {
          print('💲 ${coinType.name.toUpperCase()}: \$${price.price.toStringAsFixed(2)} (${price.change24h >= 0 ? '+' : ''}${price.change24h.toStringAsFixed(2)}%)');
        } else {
          print('⚠️ Failed to fetch price for ${coinType.name.toUpperCase()}');
        }
      }

      // Fetch balances with delays
      final btcBalance = await _blockchainService.getBitcoinBalance(_wallet!.btcAddress);
      await Future.delayed(const Duration(milliseconds: 500));

      final ethBalance = await _blockchainService.getEthereumBalance(_wallet!.ethAddress);
      await Future.delayed(const Duration(milliseconds: 500));

      final filBalance = await _blockchainService.getFilecoinBalance(_wallet!.filAddress);

      // Calculate USD values
      final btcPrice = prices[CoinType.btc]?.price ?? 0.0;
      final ethPrice = prices[CoinType.eth]?.price ?? 0.0;
      final filPrice = prices[CoinType.fil]?.price ?? 0.0;

      final btcUsd = btcBalance * btcPrice;
      final ethUsd = ethBalance * ethPrice;
      final filUsd = filBalance * filPrice;

      print('💰 Balance calculation:');
      print('   BTC: $btcBalance × \$$btcPrice = \$$btcUsd');
      print('   ETH: $ethBalance × \$$ethPrice = \$$ethUsd');
      print('   FIL: $filBalance × \$$filPrice = \$$filUsd');

      // Update balances
      _balances = {
        CoinType.btc: CoinBalance(
          coinType: CoinType.btc,
          balance: btcBalance,
          pricePerCoin: btcPrice,
          usdValue: btcUsd,
          change24h: prices[CoinType.btc]?.change24h ?? 0.0,
        ),
        CoinType.eth: CoinBalance(
          coinType: CoinType.eth,
          balance: ethBalance,
          pricePerCoin: ethPrice,
          usdValue: ethUsd,
          change24h: prices[CoinType.eth]?.change24h ?? 0.0,
        ),
        CoinType.fil: CoinBalance(
          coinType: CoinType.fil,
          balance: filBalance,
          pricePerCoin: filPrice,
          usdValue: filUsd,
          change24h: prices[CoinType.fil]?.change24h ?? 0.0,
        ),
      };

      print('✅ Balances refreshed - Total: \$${totalPortfolioValue.toStringAsFixed(2)}');
    } catch (e) {
      print('❌ Error refreshing balances: $e');
    } finally {
      _isRefreshing = false;
      notifyListeners();
    }
  }

  Future<void> refreshTransactions() async {
    if (_wallet == null) {
      print('⚠️ No wallet to refresh transactions');
      return;
    }

    if (_isRefreshing) {
      print('⏭️ Already refreshing, skipping transactions...');
      return;
    }

    try {
      print('🔄 Refreshing transactions...');

      final btcTxs = await _blockchainService.getBitcoinTransactions(_wallet!.btcAddress);
      await Future.delayed(const Duration(milliseconds: 1000));

      final ethTxs = await _blockchainService.getEthereumTransactions(_wallet!.ethAddress);

      _transactions = {
        CoinType.btc: btcTxs,
        CoinType.eth: ethTxs,
        CoinType.fil: <Transaction>[],
      };

      print('✅ Transactions refreshed - BTC: ${btcTxs.length}, ETH: ${ethTxs.length}');
      notifyListeners();
    } catch (e) {
      print('❌ Error refreshing transactions: $e');
    }
  }

  Future<String> sendTransaction({
    required CoinType coinType,
    required String toAddress,
    required double amount,
  }) async {
    if (_wallet == null) throw Exception('No wallet found');

    try {
      print('💸 Sending transaction...');
      String txHash;

      switch (coinType) {
        case CoinType.btc:
          txHash = await _blockchainService.sendBitcoin(
            fromAddress: _wallet!.btcAddress,
            toAddress: toAddress,
            privateKey: _wallet!.btcPrivateKey,
            amount: amount,
          );
          break;
        case CoinType.eth:
          txHash = await _blockchainService.sendEthereum(
            toAddress: toAddress,
            privateKey: _wallet!.ethPrivateKey,
            amount: amount,
          );
          break;
        case CoinType.fil:
          throw UnimplementedError('Filecoin sending not yet implemented');
      }

      print('✅ Transaction sent: $txHash');

      await _notificationService.showTransactionSent(
        coinSymbol: CoinInfo.allCoins.firstWhere((c) => c.type == coinType).symbol,
        amount: amount,
        txHash: txHash,
      );

      Future.delayed(const Duration(seconds: 5), () async {
        await refreshBalances();
        await refreshTransactions();
      });

      return txHash;
    } catch (e) {
      print('❌ Failed to send transaction: $e');
      throw Exception('Failed to send transaction: $e');
    }
  }

  CoinBalance? getCoinBalance(CoinType coinType) {
    return _balances[coinType];
  }

  List<Transaction> getCoinTransactions(CoinType coinType) {
    return _transactions[coinType] ?? [];
  }

  @override
  void dispose() {
    _stopAutoRefresh();
    super.dispose();
  }
}