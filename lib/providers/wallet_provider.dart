import 'package:flutter/material.dart';
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

  WalletData? _wallet;
  bool _isMainnet = true;
  bool _isLoading = false;
  Map<CoinType, CoinBalance> _balances = {};
  Map<CoinType, List<Transaction>> _transactions = {};

  WalletData? get wallet => _wallet;
  bool get isMainnet => _isMainnet;
  bool get isLoading => _isLoading;
  Map<CoinType, CoinBalance> get balances => _balances;
  Map<CoinType, List<Transaction>> get transactions => _transactions;

  double get totalPortfolioValue {
    return _balances.values.fold(0.0, (sum, balance) => sum + balance.usdValue);
  }

  // Initialize wallet
  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Load network preference
      _isMainnet = await _storage.readBool(AppConstants.keyIsMainnet, defaultValue: true);
      _blockchainService.initialize(_isMainnet);

      // Load wallet if exists
      final mnemonic = await _storage.readSecure(AppConstants.keyMnemonic);
      if (mnemonic != null) {
        _wallet = await _walletService.createWalletFromMnemonic(mnemonic, _isMainnet);
        await refreshBalances();
        await refreshTransactions();
      }
    } catch (e) {
      print('Error initializing wallet: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Create new wallet
  Future<String> createWallet() async {
    _isLoading = true;
    notifyListeners();

    try {
      final mnemonic = _walletService.generateMnemonic();
      _wallet = await _walletService.createWalletFromMnemonic(mnemonic, _isMainnet);

      // Save mnemonic securely
      await _storage.saveSecure(AppConstants.keyMnemonic, mnemonic);
      await _storage.saveBool(AppConstants.keyWalletCreated, true);

      await refreshBalances();

      _isLoading = false;
      notifyListeners();

      return mnemonic;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      throw Exception('Failed to create wallet: $e');
    }
  }

  // Import wallet from mnemonic
  Future<void> importWallet(String mnemonic) async {
    _isLoading = true;
    notifyListeners();

    try {
      if (!_walletService.validateMnemonic(mnemonic)) {
        throw Exception('Invalid mnemonic phrase');
      }

      _wallet = await _walletService.createWalletFromMnemonic(mnemonic, _isMainnet);

      // Save mnemonic securely
      await _storage.saveSecure(AppConstants.keyMnemonic, mnemonic);
      await _storage.saveBool(AppConstants.keyWalletCreated, true);

      await refreshBalances();
      await refreshTransactions();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      throw Exception('Failed to import wallet: $e');
    }
  }

  // Delete wallet
  Future<void> deleteWallet() async {
    await _storage.deleteSecure(AppConstants.keyMnemonic);
    await _storage.saveBool(AppConstants.keyWalletCreated, false);
    _wallet = null;
    _balances.clear();
    _transactions.clear();
    notifyListeners();
  }

  // Toggle network
  Future<void> toggleNetwork() async {
    _isMainnet = !_isMainnet;
    await _storage.saveBool(AppConstants.keyIsMainnet, _isMainnet);
    _blockchainService.initialize(_isMainnet);

    // Recreate wallet with new network
    if (_wallet != null) {
      final mnemonic = await _storage.readSecure(AppConstants.keyMnemonic);
      if (mnemonic != null) {
        _wallet = await _walletService.createWalletFromMnemonic(mnemonic, _isMainnet);
      }
    }

    await refreshBalances();
    await refreshTransactions();
    notifyListeners();
  }

  // Refresh all balances
  Future<void> refreshBalances() async {
    if (_wallet == null) return;

    try {
      // Fetch prices
      final prices = await _priceService.fetchAllPrices();

      // Fetch balances
      final btcBalance = await _blockchainService.getBitcoinBalance(_wallet!.btcAddress);
      final ethBalance = await _blockchainService.getEthereumBalance(_wallet!.ethAddress);
      final filBalance = await _blockchainService.getFilecoinBalance(_wallet!.filAddress);

      // Update balances with price data
      _balances = {
        CoinType.btc: CoinBalance(
          coinType: CoinType.btc,
          balance: btcBalance,
          pricePerCoin: prices[CoinType.btc]?.price ?? 0.0,
          usdValue: btcBalance * (prices[CoinType.btc]?.price ?? 0.0),
          change24h: prices[CoinType.btc]?.change24h ?? 0.0,
        ),
        CoinType.eth: CoinBalance(
          coinType: CoinType.eth,
          balance: ethBalance,
          pricePerCoin: prices[CoinType.eth]?.price ?? 0.0,
          usdValue: ethBalance * (prices[CoinType.eth]?.price ?? 0.0),
          change24h: prices[CoinType.eth]?.change24h ?? 0.0,
        ),
        CoinType.fil: CoinBalance(
          coinType: CoinType.fil,
          balance: filBalance,
          pricePerCoin: prices[CoinType.fil]?.price ?? 0.0,
          usdValue: filBalance * (prices[CoinType.fil]?.price ?? 0.0),
          change24h: prices[CoinType.fil]?.change24h ?? 0.0,
        ),
      };

      notifyListeners();
    } catch (e) {
      print('Error refreshing balances: $e');
    }
  }

  // Refresh transactions
  Future<void> refreshTransactions() async {
    if (_wallet == null) return;

    try {
      final btcTxs = await _blockchainService.getBitcoinTransactions(_wallet!.btcAddress);
      final ethTxs = await _blockchainService.getEthereumTransactions(_wallet!.ethAddress);

      _transactions = {
        CoinType.btc: btcTxs,
        CoinType.eth: ethTxs,
        CoinType.fil: <Transaction>[],
      };

      notifyListeners();
    } catch (e) {
      print('Error refreshing transactions: $e');
    }
  }

  // Send transaction
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

      // Show notification
      await _notificationService.showTransactionSent(
        coinSymbol: CoinInfo.allCoins.firstWhere((c) => c.type == coinType).symbol,
        amount: amount,
        txHash: txHash,
      );

      // Refresh balances and transactions
      await Future.delayed(const Duration(seconds: 2));
      await refreshBalances();
      await refreshTransactions();

      return txHash;
    } catch (e) {
      throw Exception('Failed to send transaction: $e');
    }
  }

  // Get coin balance
  CoinBalance? getCoinBalance(CoinType coinType) {
    return _balances[coinType];
  }

  // Get coin transactions
  List<Transaction> getCoinTransactions(CoinType coinType) {
    return _transactions[coinType] ?? [];
  }
}