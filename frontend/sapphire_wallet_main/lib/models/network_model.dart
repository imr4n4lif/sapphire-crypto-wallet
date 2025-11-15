// lib/models/network_model.dart
enum NetworkType {
  mainnet,
  testnet,
}

class NetworkConfig {
  final NetworkType type;
  final String displayName;

  const NetworkConfig({
    required this.type,
    required this.displayName,
  });

  bool get isMainnet => type == NetworkType.mainnet;
  bool get isTestnet => type == NetworkType.testnet;
}
