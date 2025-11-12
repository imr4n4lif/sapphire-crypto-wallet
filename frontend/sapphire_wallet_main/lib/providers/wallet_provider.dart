import 'package:flutter/material.dart';
import '../models/wallet_models.dart';
import '../services/crypto_api_service.dart';

class WalletProvider with ChangeNotifier {
  List<Wallet> _wallets = [];
  Wallet? _currentWallet;
  bool _isWalletCreated = false;
  bool _isLoading = false;

  List<Wallet> get wallets => _wallets;
  Wallet? get currentWallet => _currentWallet;
  bool get isWalletCreated => _isWalletCreated;
  bool get isLoading => _isLoading;

  // Mock initial data with empty price history
  List<CryptoCoin> get initialCoins => [
    CryptoCoin(
      symbol: 'BTC',
      name: 'Bitcoin',
      balance: 0.5,
      price: 0.0, // Will be updated from API
      address: 'bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh',
      icon: '₿',
      priceHistory: [],
    ),
    CryptoCoin(
      symbol: 'ETH',
      name: 'Ethereum',
      balance: 3.2,
      price: 0.0, // Will be updated from API
      address: '0x742d35Cc6634C0532925a3b8Df8B5a5f2f6f7e7d',
      icon: 'Ξ',
      priceHistory: [],
    ),
    CryptoCoin(
      symbol: 'FIL',
      name: 'Filecoin',
      balance: 50.0,
      price: 0.0, // Will be updated from API
      address: 'f1r6p2zmsn5q3k7q2t1v4s8p9x0w3e5r2t6y7u8i9o0p',
      icon: '⨎',
      priceHistory: [],
    ),
  ];

  List<Transaction> get initialTransactions => [
    Transaction(
      id: '1',
      coinSymbol: 'BTC',
      type: 'receive',
      amount: 0.1,
      address: 'bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh',
      date: DateTime.now().subtract(const Duration(days: 1)),
      status: 'confirmed',
      fee: 0.0001,
    ),
    Transaction(
      id: '2',
      coinSymbol: 'ETH',
      type: 'send',
      amount: 0.5,
      address: '0x742d35Cc6634C0532925a3b8Df8B5a5f2f6f7e7d',
      date: DateTime.now().subtract(const Duration(days: 3)),
      status: 'confirmed',
      fee: 0.001,
    ),
  ];

  void createWallet(String name, String seedPhrase) {
    final newWallet = Wallet(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      seedPhrase: seedPhrase,
      createdAt: DateTime.now(),
      coins: initialCoins,
    );

    _wallets.add(newWallet);
    _currentWallet = newWallet;
    _isWalletCreated = true;
    _fetchCoinPrices();
    notifyListeners();
  }

  void importWallet(String name, String seedPhrase) {
    createWallet(name, seedPhrase);
  }

  void switchWallet(Wallet wallet) {
    _currentWallet = wallet;
    notifyListeners();
  }

  void removeWallet(String walletId) {
    _wallets.removeWhere((wallet) => wallet.id == walletId);
    if (_currentWallet?.id == walletId) {
      _currentWallet = _wallets.isNotEmpty ? _wallets.first : null;
      _isWalletCreated = _wallets.isNotEmpty;
    }
    notifyListeners();
  }

  void addWallet(Wallet wallet) {
    _wallets.add(wallet);
    notifyListeners();
  }

  double getTotalBalance() {
    if (_currentWallet == null) return 0.0;
    return _currentWallet!.coins.fold(0.0, (sum, coin) => sum + coin.valueInUSD);
  }

  Future<void> _fetchCoinPrices() async {
    if (_currentWallet == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      for (int i = 0; i < _currentWallet!.coins.length; i++) {
        final coin = _currentWallet!.coins[i];
        final coinInfo = CryptoApiService.getCoinId(coin.symbol);
        final price = await CryptoApiService.getCoinPrice(coinInfo['id']!);
        final priceHistory = await CryptoApiService.getCoinPriceHistory(coinInfo['id']!, 7);

        // Create a new coin object with updated price and history
        final updatedCoin = CryptoCoin(
          symbol: coin.symbol,
          name: coin.name,
          balance: coin.balance,
          price: price,
          address: coin.address,
          icon: coin.icon,
          priceHistory: priceHistory,
        );

        // Replace the coin in the list
        _currentWallet!.coins[i] = updatedCoin;
      }
    } catch (e) {
      print('Error fetching coin prices: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshPrices() async {
    await _fetchCoinPrices();
  }
}