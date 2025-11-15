// lib/providers/wallet_provider.dart
import 'package:flutter/material.dart';
import 'package:bip39/bip39.dart' as bip39;
import '../models/wallet_model.dart';
import '../models/crypto_coin_model.dart';
import '../models/transaction_model.dart';
import '../models/network_model.dart';
import '../services/security/secure_storage_service.dart';
import '../services/blockchain/bitcoin_service.dart';
import '../services/blockchain/ethereum_service.dart';
import '../services/blockchain/filecoin_service.dart';
import '../services/price_service.dart';
import '../services/notification_service.dart';

class WalletProvider with ChangeNotifier {
  WalletModel? _currentWallet;
  List<WalletModel> _wallets = [];
  bool _isLoading = false;
  bool _isInitialized = false;
  NetworkType _networkType = NetworkType.mainnet;
  Map<String, List<TransactionModel>> _transactions = {};

  // Services
  final _storage = SecureStorageService();
  final _priceService = PriceService();
  final _notificationService = NotificationService();
  late BitcoinService _btcService;
  late EthereumService _ethService;
  late FilecoinService _filService;

  // Getters
  WalletModel? get currentWallet => _currentWallet;
  List<WalletModel> get wallets => _wallets;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  bool get hasWallet => _wallets.isNotEmpty;
  NetworkType get networkType => _networkType;

  List<TransactionModel> getTransactions(String coinSymbol) {
    return _transactions[coinSymbol] ?? [];
  }

  WalletProvider() {
    _initializeServices();
  }

  void _initializeServices() {
    final isTestnet = _networkType == NetworkType.testnet;
    _btcService = BitcoinService(isTestnet: isTestnet);
    _ethService = EthereumService(isTestnet: isTestnet);
    _filService = FilecoinService(isTestnet: isTestnet);
  }

  // Initialize provider
  Future<void> initialize() async {
    if (_isInitialized) return;

    _isLoading = true;
    notifyListeners();

    try {
      await _storage.initialize();
      await _notificationService.initialize();
      await _loadWallets();
      await _loadNetworkType();
      _initializeServices();

      if (_currentWallet != null) {
        await refreshBalancesAndPrices();
        _startPriceUpdates();
      }

      _isInitialized = true;
    } catch (e) {
      print('Error initializing wallet provider: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Load wallets from storage
  Future<void> _loadWallets() async {
    try {
      final walletIds = await _storage.getWalletIds();
      _wallets = [];

      for (final id in walletIds) {
        final walletData = await _storage.getWallet(id);
        if (walletData != null) {
          final wallet = await _createWalletFromData(walletData);
          _wallets.add(wallet);
        }
      }

      if (_wallets.isNotEmpty) {
        final currentId = await _storage.getCurrentWalletId();
        _currentWallet = _wallets.firstWhere(
              (w) => w.id == currentId,
          orElse: () => _wallets.first,
        );
      }
    } catch (e) {
      print('Error loading wallets: $e');
    }
  }

  Future<WalletModel> _createWalletFromData(Map<String, dynamic> data) async {
    final mnemonic = data['mnemonic'];
    final isTestnet = _networkType == NetworkType.testnet;

    // Generate addresses and keys for all coins
    final btcAddress = _btcService.getAddress(mnemonic);
    final btcPrivateKey = _btcService.getPrivateKey(mnemonic);

    final ethAddress = _ethService.getAddress(mnemonic);
    final ethPrivateKey = _ethService.getPrivateKey(mnemonic);

    final filAddress = _filService.getAddress(mnemonic);
    final filPrivateKey = _filService.getPrivateKey(mnemonic);

    return WalletModel(
      id: data['id'],
      name: data['name'],
      mnemonic: mnemonic,
      createdAt: DateTime.parse(data['createdAt']),
      coins: [
        CryptoCoinModel(
          symbol: 'BTC',
          name: 'Bitcoin',
          balance: 0.0,
          price: 0.0,
          address: btcAddress,
          privateKey: btcPrivateKey,
          icon: '₿',
          priceHistory: [],
        ),
        CryptoCoinModel(
          symbol: 'ETH',
          name: 'Ethereum',
          balance: 0.0,
          price: 0.0,
          address: ethAddress,
          privateKey: ethPrivateKey,
          icon: 'Ξ',
          priceHistory: [],
        ),
        CryptoCoinModel(
          symbol: 'FIL',
          name: 'Filecoin',
          balance: 0.0,
          price: 0.0,
          address: filAddress,
          privateKey: filPrivateKey,
          icon: '⨎',
          priceHistory: [],
        ),
      ],
    );
  }

  // Create new wallet
  Future<void> createWallet(String name) async {
    _isLoading = true;
    notifyListeners();

    try {
      final mnemonic = bip39.generateMnemonic();
      final id = DateTime.now().millisecondsSinceEpoch.toString();

      await _storage.storeWallet(
        id: id,
        name: name,
        mnemonic: mnemonic,
      );

      final wallet = await _createWalletFromData({
        'id': id,
        'name': name,
        'mnemonic': mnemonic,
        'createdAt': DateTime.now().toIso8601String(),
      });

      _wallets.add(wallet);
      _currentWallet = wallet;
      await _storage.setCurrentWalletId(id);

      await refreshBalancesAndPrices();
      _startPriceUpdates();
    } catch (e) {
      print('Error creating wallet: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Import wallet
  Future<void> importWallet(String name, String mnemonic) async {
    if (!bip39.validateMnemonic(mnemonic)) {
      throw Exception('Invalid mnemonic phrase');
    }

    _isLoading = true;
    notifyListeners();

    try {
      final id = DateTime.now().millisecondsSinceEpoch.toString();

      await _storage.storeWallet(
        id: id,
        name: name,
        mnemonic: mnemonic,
      );

      final wallet = await _createWalletFromData({
        'id': id,
        'name': name,
        'mnemonic': mnemonic,
        'createdAt': DateTime.now().toIso8601String(),
      });

      _wallets.add(wallet);
      _currentWallet = wallet;
      await _storage.setCurrentWalletId(id);

      await refreshBalancesAndPrices();
      _startPriceUpdates();
    } catch (e) {
      print('Error importing wallet: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Switch wallet
  Future<void> switchWallet(String walletId) async {
    final wallet = _wallets.firstWhere((w) => w.id == walletId);
    _currentWallet = wallet;
    await _storage.setCurrentWalletId(walletId);
    await refreshBalancesAndPrices();
    notifyListeners();
  }

  // Remove wallet
  Future<void> removeWallet(String walletId) async {
    await _storage.deleteWallet(walletId);
    _wallets.removeWhere((w) => w.id == walletId);

    if (_currentWallet?.id == walletId) {
      _currentWallet = _wallets.isNotEmpty ? _wallets.first : null;
      if (_currentWallet != null) {
        await _storage.setCurrentWalletId(_currentWallet!.id);
      }
    }

    notifyListeners();
  }

  // Refresh balances and prices
  Future<void> refreshBalancesAndPrices() async {
    if (_currentWallet == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      // Get prices
      final prices = await _priceService.getCurrentPrices();

      // Update each coin
      final updatedCoins = <CryptoCoinModel>[];

      for (final coin in _currentWallet!.coins) {
        double balance = 0.0;
        List<TransactionModel> txs = [];

        // Get balance and transactions based on coin type
        switch (coin.symbol) {
          case 'BTC':
            balance = await _btcService.getBalance(coin.address);
            txs = await _btcService.getTransactions(coin.address);
            break;
          case 'ETH':
            balance = await _ethService.getBalance(coin.address);
            txs = await _ethService.getTransactions(coin.address);
            break;
          case 'FIL':
            balance = await _filService.getBalance(coin.address);
            txs = await _filService.getTransactions(coin.address);
            break;
        }

        // Get price history
        final history = await _priceService.getPriceHistory(coin.symbol, 7);

        // Calculate 24h change
        double change24h = 0.0;
        if (history.length >= 2) {
          final oldPrice = history.first.price;
          final newPrice = history.last.price;
          change24h = ((newPrice - oldPrice) / oldPrice) * 100;
        }

        updatedCoins.add(coin.copyWith(
          balance: balance,
          price: prices[coin.symbol] ?? 0.0,
          priceHistory: history,
          change24h: change24h,
        ));

        _transactions[coin.symbol] = txs;
      }

      _currentWallet = _currentWallet!.copyWith(coins: updatedCoins);

      // Update wallet in list
      final index = _wallets.indexWhere((w) => w.id == _currentWallet!.id);
      if (index != -1) {
        _wallets[index] = _currentWallet!;
      }
    } catch (e) {
      print('Error refreshing data: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Start price updates
  void _startPriceUpdates() {
    _priceService.startPriceUpdates((prices) {
      if (_currentWallet != null) {
        final updatedCoins = _currentWallet!.coins.map((coin) {
          return coin.copyWith(price: prices[coin.symbol] ?? coin.price);
        }).toList();

        _currentWallet = _currentWallet!.copyWith(coins: updatedCoins);
        notifyListeners();
      }
    });
  }

  // Send transaction
  Future<String> sendTransaction({
    required String coinSymbol,
    required String toAddress,
    required double amount,
  }) async {
    if (_currentWallet == null) {
      throw Exception('No active wallet');
    }

    try {
      String txId;

      switch (coinSymbol) {
        case 'BTC':
          txId = await _btcService.sendTransaction(
            mnemonic: _currentWallet!.mnemonic,
            toAddress: toAddress,
            amount: amount,
          );
          break;
        case 'ETH':
          txId = await _ethService.sendTransaction(
            mnemonic: _currentWallet!.mnemonic,
            toAddress: toAddress,
            amount: amount,
          );
          break;
        case 'FIL':
          txId = await _filService.sendTransaction(
            mnemonic: _currentWallet!.mnemonic,
            toAddress: toAddress,
            amount: amount,
          );
          break;
        default:
          throw Exception('Unsupported coin');
      }

      // Show notification
      await _notificationService.showTransactionNotification(
        title: 'Transaction Sent',
        body: 'Sent $amount $coinSymbol',
        txId: txId,
      );

      // Refresh balances after a delay
      Future.delayed(const Duration(seconds: 5), refreshBalancesAndPrices);

      return txId;
    } catch (e) {
      throw Exception('Transaction failed: $e');
    }
  }

  // Get total portfolio value
  double getTotalBalance() {
    if (_currentWallet == null) return 0.0;
    return _currentWallet!.coins.fold(
      0.0,
          (sum, coin) => sum + coin.valueInUSD,
    );
  }

  // Switch network
  Future<void> switchNetwork(NetworkType network) async {
    if (_networkType == network) return;

    _networkType = network;
    _initializeServices();

    // Save network preference
    await _storage.writeSecure('network_type', network.index.toString());

    // Reload wallets with new network
    await _loadWallets();
    await refreshBalancesAndPrices();

    notifyListeners();
  }

  Future<void> _loadNetworkType() async {
    final networkStr = await _storage.readSecure('network_type');
    if (networkStr != null) {
      _networkType = NetworkType.values[int.parse(networkStr)];
    }
  }

  // Get coin by symbol
  CryptoCoinModel? getCoin(String symbol) {
    return _currentWallet?.coins.firstWhere(
          (c) => c.symbol == symbol,
      orElse: () => _currentWallet!.coins.first,
    );
  }

  @override
  void dispose() {
    _priceService.stopPriceUpdates();
    _ethService.dispose();
    super.dispose();
  }
}