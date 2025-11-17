import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConstants {
  // App Info
  static const String appName = 'Sapphire Wallet';
  static const String appVersion = '1.0.0';

  // Secure Storage Keys
  static const String keyMnemonic = 'mnemonic';
  static const String keyPin = 'pin';
  static const String keyBiometricEnabled = 'biometric_enabled';
  static const String keyIsMainnet = 'is_mainnet';
  static const String keyWalletCreated = 'wallet_created';
  static const String keyThemeMode = 'theme_mode';

  // BIP44 Derivation Paths
  static const String btcMainnetPath = "m/44'/0'/0'/0/0";
  static const String btcTestnetPath = "m/44'/1'/0'/0/0";
  static const String ethPath = "m/44'/60'/0'/0/0";
  static const String filPath = "m/44'/461'/0'/0/0";

  // Get Infura Project ID from .env
  static String get infuraProjectId => dotenv.env['INFURA_PROJECT_ID'] ?? '';

  // Network URLs
  static String get ethMainnetRpc => 'https://mainnet.infura.io/v3/$infuraProjectId';
  static String get ethTestnetRpc => 'https://sepolia.infura.io/v3/$infuraProjectId';

  // Bitcoin (using BlockCypher API)
  static const String btcMainnetApi = 'https://api.blockcypher.com/v1/btc/main';
  static const String btcTestnetApi = 'https://api.blockcypher.com/v1/btc/test3';

  // Filecoin (using public RPC)
  static const String filMainnetRpc = 'https://api.node.glif.io';
  static const String filTestnetRpc = 'https://api.calibration.node.glif.io';

  // Price API
  static const String priceApiUrl = 'https://api.coingecko.com/api/v3';

  // Coin IDs for price fetching
  static const String btcCoinId = 'bitcoin';
  static const String ethCoinId = 'ethereum';
  static const String filCoinId = 'filecoin';

  // Transaction confirmations required
  static const int btcConfirmations = 3;
  static const int ethConfirmations = 12;
  static const int filConfirmations = 30;

  // Decimal places
  static const int btcDecimals = 8;
  static const int ethDecimals = 18;
  static const int filDecimals = 18;
}

enum NetworkType {
  mainnet,
  testnet,
}

enum CoinType {
  btc,
  eth,
  fil,
}

class CoinInfo {
  final String name;
  final String symbol;
  final String icon;
  final CoinType type;

  const CoinInfo({
    required this.name,
    required this.symbol,
    required this.icon,
    required this.type,
  });

  static const btc = CoinInfo(
    name: 'Bitcoin',
    symbol: 'BTC',
    icon: '₿',
    type: CoinType.btc,
  );

  static const eth = CoinInfo(
    name: 'Ethereum',
    symbol: 'ETH',
    icon: 'Ξ',
    type: CoinType.eth,
  );

  static const fil = CoinInfo(
    name: 'Filecoin',
    symbol: 'FIL',
    icon: '⨎',
    type: CoinType.fil,
  );

  static List<CoinInfo> get allCoins => [btc, eth, fil];
}