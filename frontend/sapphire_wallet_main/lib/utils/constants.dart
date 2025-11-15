// lib/utils/constants.dart
class AppConstants {
  // App Info
  static const String appName = 'Sapphire Wallet';
  static const String appVersion = '1.0.0';

  // Supported Coins
  static const List<String> supportedCoins = ['BTC', 'ETH', 'FIL'];

  // Network Types
  static const String mainnetLabel = 'Mainnet';
  static const String testnetLabel = 'Testnet';

  // Transaction Statuses
  static const String statusPending = 'pending';
  static const String statusConfirmed = 'confirmed';
  static const String statusFailed = 'failed';

  // Transaction Types
  static const String typeSend = 'send';
  static const String typeReceive = 'receive';

  // Storage Keys
  static const String keyWallets = 'wallets';
  static const String keyCurrentWallet = 'current_wallet';
  static const String keySettings = 'settings';
  static const String keyPin = 'user_pin';
  static const String keyBiometric = 'biometric_enabled';

  // API Endpoints
  static const String coingeckoApi = 'https://api.coingecko.com/api/v3';
  static const String blockstreamMainnet = 'https://blockstream.info/api';
  static const String blockstreamTestnet = 'https://blockstream.info/testnet/api';

  // Limits
  static const int minPinLength = 6;
  static const int maxPinLength = 6;
  static const int mnemonicWords = 12;

  // Refresh Intervals
  static const Duration priceRefreshInterval = Duration(seconds: 30);
  static const Duration balanceRefreshInterval = Duration(minutes: 1);
}