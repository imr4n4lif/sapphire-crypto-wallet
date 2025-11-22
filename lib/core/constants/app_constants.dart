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
  static const String trxPath = "m/44'/195'/0'/0/0";

  // Get API Keys from .env
  static String get infuraProjectId => dotenv.env['INFURA_PROJECT_ID'] ?? '';
  static String get etherscanApiKey => dotenv.env['ETHERSCAN_API_KEY'] ?? '';
  static String get tronGridApiKey => dotenv.env['TRONGRID_API_KEY'] ?? '';

  // Network URLs
  static String get ethMainnetRpc => 'https://mainnet.infura.io/v3/$infuraProjectId';
  static String get ethTestnetRpc => 'https://sepolia.infura.io/v3/$infuraProjectId';

  // Bitcoin - Using reliable APIs
  static const String btcMainnetApi = 'https://blockstream.info/api';
  static const String btcTestnetApi = 'https://blockstream.info/testnet/api';

  // Etherscan API
  // Etherscan API V2 - Unified endpoint for all chains
  static const String etherscanV2Api = 'https://api.etherscan.io/v2/api';

// Chain IDs for V2 API
  static const String ethMainnetChainId = '1';
  static const String ethSepoliaChainId = '11155111';

  // Tron - TronGrid API
  static const String trxMainnetApi = 'https://api.trongrid.io';
  static const String trxTestnetApi = 'https://api.shasta.trongrid.io';

  // Price API - CoinGecko (free, no key required)
  static const String priceApiUrl = 'https://api.coingecko.com/api/v3';

  // Coin IDs for price API
  static const String btcCoinId = 'bitcoin';
  static const String ethCoinId = 'ethereum';
  static const String trxCoinId = 'tron';

  // Confirmations
  static const int btcConfirmations = 3;
  static const int ethConfirmations = 12;
  static const int trxConfirmations = 19;

  // Decimals
  static const int btcDecimals = 8;
  static const int ethDecimals = 18;
  static const int trxDecimals = 6;
}

enum NetworkType {
  mainnet,
  testnet,
}

enum CoinType {
  btc,
  eth,
  trx,
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

  static const trx = CoinInfo(
    name: 'Tron',
    symbol: 'TRX',
    icon: 'Ⓣ',
    type: CoinType.trx,
  );

  static List<CoinInfo> get allCoins => [btc, eth, trx];
}

// Helper functions for wallet service
class WalletHelper {
  static String getPrivateKey(dynamic wallet, CoinType coinType) {
    switch (coinType) {
      case CoinType.btc:
        return wallet.btcPrivateKey;
      case CoinType.eth:
        return wallet.ethPrivateKey;
      case CoinType.trx:
        return wallet.trxPrivateKey;
    }
  }

  static String getAddress(dynamic wallet, CoinType coinType) {
    switch (coinType) {
      case CoinType.btc:
        return wallet.btcAddress;
      case CoinType.eth:
        return wallet.ethAddress;
      case CoinType.trx:
        return wallet.trxAddress;
    }
  }
}