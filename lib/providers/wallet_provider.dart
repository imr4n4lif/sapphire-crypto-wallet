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

  List<Map<String, dynamic>> _allWallets = [];
  String? _currentWalletId;

  WalletData? _wallet;
  bool _isMainnet = true;
  bool _isLoading = false;
  bool _isRefreshing = false;
  Map<CoinType, CoinBalance> _balances = {};
  Map<CoinType, List<Transaction>> _transactions = {};
  Map<CoinType, String> _lastKnownTxHash = {};

  // Network-separated portfolio history
  Map<String, List<PortfolioDataPoint>> _walletPortfolioHistory = {};

  Timer? _autoRefreshTimer;
  static const Duration _refreshInterval = Duration(minutes: 3);

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
    return _balances.values.fold(0.0, (sum, balance) => sum + balance.usdValue);
  }

  List<PortfolioDataPoint> get currentWalletPortfolioHistory {
    if (_currentWalletId == null) return [];
    final key = '${_currentWalletId}_${_isMainnet ? "mainnet" : "testnet"}';
    return _walletPortfolioHistory[key] ?? [];
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
      _isMainnet = await _storage.readBool(AppConstants.keyIsMainnet, defaultValue: true);
      _blockchainService.initialize(_isMainnet);

      await _loadAllWallets();
      _currentWalletId = await _storage.readString('current_wallet_id');

      await _loadPortfolioHistory();

      if (_allWallets.isNotEmpty) {
        if (_currentWalletId == null) {
          _currentWalletId = _allWallets.first['id'] as String;
          await _storage.saveString('current_wallet_id', _currentWalletId!);
        }

        await _loadCurrentWallet();

        // Fast background loading
        Future.microtask(() async {
          try {
            await refreshBalances();
            await Future.delayed(const Duration(milliseconds: 100));
            await refreshTransactions();
          } catch (e) {
            print('❌ Error: $e');
          }
        });

        _startAutoRefresh();
      }
    } catch (e) {
      print('❌ Error: $e');
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
      } catch (e) {
        _allWallets = [];
      }
    }
  }

  Future<void> _saveAllWallets() async {
    await _storage.saveString('all_wallets', json.encode(_allWallets));
  }

  Future<void> _loadPortfolioHistory() async {
    final historyJson = await _storage.readString('portfolio_history');
    if (historyJson != null) {
      try {
        final Map<String, dynamic> decoded = json.decode(historyJson);
        _walletPortfolioHistory = decoded.map((key, value) {
          final points = (value as List).map((p) => PortfolioDataPoint(
            timestamp: DateTime.parse(p['timestamp']),
            value: p['value'].toDouble(),
          )).toList();
          return MapEntry(key, points);
        });
      } catch (e) {
        _walletPortfolioHistory = {};
      }
    }
  }

  Future<void> _savePortfolioHistory() async {
    final encoded = json.encode(_walletPortfolioHistory.map((key, value) {
      return MapEntry(key, value.map((p) => {
        'timestamp': p.timestamp.toIso8601String(),
        'value': p.value,
      }).toList());
    }));
    await _storage.saveString('portfolio_history', encoded);
  }

  void _updatePortfolioHistory(double value) {
    if (_currentWalletId == null) return;
    final key = '${_currentWalletId}_${_isMainnet ? "mainnet" : "testnet"}';

    if (!_walletPortfolioHistory.containsKey(key)) {
      _walletPortfolioHistory[key] = [];
    }

    final now = DateTime.now();
    final history = _walletPortfolioHistory[key]!;

    history.removeWhere((p) => now.difference(p.timestamp).inDays > 365);
    history.add(PortfolioDataPoint(timestamp: now, value: value));

    _savePortfolioHistory();
  }

  Future<void> _loadCurrentWallet() async {
    if (_currentWalletId == null) return;

    final mnemonic = await _storage.readSecure('mnemonic_$_currentWalletId');
    if (mnemonic != null) {
      _wallet = await _walletService.createWalletFromMnemonic(mnemonic, _isMainnet);
    }
  }

  Future<String> createNewWallet(String name) async {
    try {
      final mnemonic = _walletService.generateMnemonic();
      final walletData = await _walletService.createWalletFromMnemonic(mnemonic, _isMainnet);

      final walletId = DateTime.now().millisecondsSinceEpoch.toString();

      await _storage.saveSecure('mnemonic_$walletId', mnemonic);

      _allWallets.add({
        'id': walletId,
        'name': name,
        'ethAddress': walletData.ethAddress,
        'btcAddress': walletData.btcAddress,
        'trxAddress': walletData.trxAddress,
        'createdAt': DateTime.now().toIso8601String(),
      });

      await _saveAllWallets();
      await switchWallet(walletId);

      return mnemonic;
    } catch (e) {
      throw Exception('Failed to create wallet: $e');
    }
  }

  Future<void> importExistingWallet(String name, String mnemonic) async {
    try {
      if (!_walletService.validateMnemonic(mnemonic)) {
        throw Exception('Invalid mnemonic phrase');
      }

      final walletData = await _walletService.createWalletFromMnemonic(mnemonic, _isMainnet);
      final walletId = DateTime.now().millisecondsSinceEpoch.toString();

      await _storage.saveSecure('mnemonic_$walletId', mnemonic);

      _allWallets.add({
        'id': walletId,
        'name': name,
        'ethAddress': walletData.ethAddress,
        'btcAddress': walletData.btcAddress,
        'trxAddress': walletData.trxAddress,
        'createdAt': DateTime.now().toIso8601String(),
      });

      await _saveAllWallets();
      await switchWallet(walletId);
    } catch (e) {
      throw Exception('Failed to import wallet: $e');
    }
  }

  Future<void> updateWalletName(String walletId, String newName) async {
    final index = _allWallets.indexWhere((w) => w['id'] == walletId);
    if (index != -1) {
      _allWallets[index]['name'] = newName;
      await _saveAllWallets();
      notifyListeners();
    }
  }

  Future<void> switchWallet(String walletId) async {
    _currentWalletId = walletId;
    await _storage.saveString('current_wallet_id', walletId);

    await _loadCurrentWallet();

    // Clear old data
    _balances.clear();
    _transactions.clear();
    notifyListeners();

    // Quick refresh
    Future.microtask(() async {
      try {
        await refreshBalances();
        await Future.delayed(const Duration(milliseconds: 100));
        await refreshTransactions();
      } catch (e) {
        print('❌ Error: $e');
      }
    });
  }

  Future<void> deleteWalletById(String walletId) async {
    if (_allWallets.length == 1) {
      throw Exception('Cannot delete the only wallet');
    }

    await _storage.deleteSecure('mnemonic_$walletId');
    _allWallets.removeWhere((w) => w['id'] == walletId);

    _walletPortfolioHistory.remove('${walletId}_mainnet');
    _walletPortfolioHistory.remove('${walletId}_testnet');

    await _saveAllWallets();
    await _savePortfolioHistory();

    if (_currentWalletId == walletId) {
      await switchWallet(_allWallets.first['id'] as String);
    }

    notifyListeners();
  }

  void _startAutoRefresh() {
    _stopAutoRefresh();
    _autoRefreshTimer = Timer.periodic(_refreshInterval, (timer) async {
      if (!_isRefreshing) {
        await refreshBalances();
        await refreshTransactions();
      }
    });
  }

  void _stopAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = null;
  }

  Future<String> createWallet(String name) async {
    _isLoading = true;
    notifyListeners();

    try {
      final mnemonic = _walletService.generateMnemonic();
      _wallet = await _walletService.createWalletFromMnemonic(mnemonic, _isMainnet);

      final walletId = DateTime.now().millisecondsSinceEpoch.toString();

      await _storage.saveSecure('mnemonic_$walletId', mnemonic);
      await _storage.saveBool(AppConstants.keyWalletCreated, true);

      _allWallets.add({
        'id': walletId,
        'name': name,
        'ethAddress': _wallet!.ethAddress,
        'btcAddress': _wallet!.btcAddress,
        'trxAddress': _wallet!.trxAddress,
        'createdAt': DateTime.now().toIso8601String(),
      });

      _currentWalletId = walletId;
      await _storage.saveString('current_wallet_id', walletId);
      await _saveAllWallets();

      Future.microtask(() async {
        await refreshBalances();
        await refreshTransactions();
      });

      _startAutoRefresh();

      _isLoading = false;
      notifyListeners();

      return mnemonic;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      throw Exception('Failed to create wallet: $e');
    }
  }

  Future<void> importWallet(String mnemonic) async {
    _isLoading = true;
    notifyListeners();

    try {
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
        'trxAddress': _wallet!.trxAddress,
        'createdAt': DateTime.now().toIso8601String(),
      });

      _currentWalletId = walletId;
      await _storage.saveString('current_wallet_id', walletId);
      await _saveAllWallets();

      Future.microtask(() async {
        await refreshBalances();
        await refreshTransactions();
      });

      _startAutoRefresh();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      throw Exception('Failed to import wallet: $e');
    }
  }

  Future<void> deleteWallet() async {
    _stopAutoRefresh();
    _blockchainService.clearCache();

    for (var wallet in _allWallets) {
      await _storage.deleteSecure('mnemonic_${wallet['id']}');
    }

    await _storage.saveString('all_wallets', '[]');
    await _storage.saveString('current_wallet_id', '');
    await _storage.saveString('portfolio_history', '{}');
    await _storage.saveBool(AppConstants.keyWalletCreated, false);

    _wallet = null;
    _allWallets.clear();
    _currentWalletId = null;
    _balances.clear();
    _transactions.clear();
    _lastKnownTxHash.clear();
    _walletPortfolioHistory.clear();
    notifyListeners();
  }

  Future<void> toggleNetwork() async {
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
  }

  Future<void> refreshBalances() async {
    if (_wallet == null || _isRefreshing) return;

    _isRefreshing = true;
    notifyListeners();

    try {
      final prices = await _priceService.fetchAllPrices();

      final btcBalance = await _blockchainService.getBitcoinBalance(_wallet!.btcAddress);
      await Future.delayed(const Duration(milliseconds: 200));

      final ethBalance = await _blockchainService.getEthereumBalance(_wallet!.ethAddress);
      await Future.delayed(const Duration(milliseconds: 200));

      final trxBalance = await _blockchainService.getTronBalance(_wallet!.trxAddress);

      final btcPrice = prices[CoinType.btc]?.price ?? 0.0;
      final ethPrice = prices[CoinType.eth]?.price ?? 0.0;
      final trxPrice = prices[CoinType.trx]?.price ?? 0.0;

      _balances = {
        CoinType.btc: CoinBalance(
          coinType: CoinType.btc,
          balance: btcBalance,
          pricePerCoin: btcPrice,
          usdValue: btcBalance * btcPrice,
          change24h: prices[CoinType.btc]?.change24h ?? 0.0,
        ),
        CoinType.eth: CoinBalance(
          coinType: CoinType.eth,
          balance: ethBalance,
          pricePerCoin: ethPrice,
          usdValue: ethBalance * ethPrice,
          change24h: prices[CoinType.eth]?.change24h ?? 0.0,
        ),
        CoinType.trx: CoinBalance(
          coinType: CoinType.trx,
          balance: trxBalance,
          pricePerCoin: trxPrice,
          usdValue: trxBalance * trxPrice,
          change24h: prices[CoinType.trx]?.change24h ?? 0.0,
        ),
      };

      _updatePortfolioHistory(totalPortfolioValue);
    } catch (e) {
      print('❌ Error: $e');
    } finally {
      _isRefreshing = false;
      notifyListeners();
    }
  }

  Future<void> refreshTransactions() async {
    if (_wallet == null || _isRefreshing) return;

    try {
      final btcTxs = await _blockchainService.getBitcoinTransactions(_wallet!.btcAddress);
      await Future.delayed(const Duration(milliseconds: 200));

      final ethTxs = await _blockchainService.getEthereumTransactions(_wallet!.ethAddress);
      await Future.delayed(const Duration(milliseconds: 200));

      final trxTxs = await _blockchainService.getTronTransactions(_wallet!.trxAddress);

      _checkForNewTransactions(CoinType.btc, btcTxs);
      _checkForNewTransactions(CoinType.eth, ethTxs);
      _checkForNewTransactions(CoinType.trx, trxTxs);

      _transactions = {
        CoinType.btc: btcTxs,
        CoinType.eth: ethTxs,
        CoinType.trx: trxTxs,
      };

      notifyListeners();
    } catch (e) {
      print('❌ Error: $e');
    }
  }

  void _checkForNewTransactions(CoinType coinType, List<Transaction> newTxs) {
    if (newTxs.isEmpty) return;

    final latestTx = newTxs.first;
    final lastKnownHash = _lastKnownTxHash[coinType];

    if (lastKnownHash != null &&
        lastKnownHash != latestTx.hash &&
        latestTx.isIncoming) {
      _notificationService.showTransactionReceived(
        coinSymbol: CoinInfo.allCoins.firstWhere((c) => c.type == coinType).symbol,
        amount: latestTx.amount,
        txHash: latestTx.hash,
      );
    }

    _lastKnownTxHash[coinType] = latestTx.hash;
  }

  Future<String> sendTransaction({
    required CoinType coinType,
    required String toAddress,
    required double amount,
  }) async {
    if (_wallet == null) throw Exception('No wallet found');

    try {
      String txHash;

      switch (coinType) {
        case CoinType.btc:
          txHash = await _blockchainService.sendBitcoin(
            fromAddress: _wallet!.btcAddress,
            toAddress: toAddress,
            privateKeyHex: _wallet!.btcPrivateKey,
            amount: amount,
            feeRate: 10.0,
          );
          break;
        case CoinType.eth:
          txHash = await _blockchainService.sendEthereum(
            toAddress: toAddress,
            privateKey: _wallet!.ethPrivateKey,
            amount: amount,
          );
          break;
        case CoinType.trx:
          txHash = await _blockchainService.sendTron(
            toAddress: toAddress,
            privateKey: _wallet!.trxPrivateKey,
            amount: amount,
          );
          break;
      }

      await _notificationService.showTransactionSent(
        coinSymbol: CoinInfo.allCoins.firstWhere((c) => c.type == coinType).symbol,
        amount: amount,
        txHash: txHash,
      );

      Future.delayed(const Duration(seconds: 2), () async {
        await refreshBalances();
        await refreshTransactions();
      });

      return txHash;
    } catch (e) {
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

class PortfolioDataPoint {
  final DateTime timestamp;
  final double value;

  PortfolioDataPoint({required this.timestamp, required this.value});
}