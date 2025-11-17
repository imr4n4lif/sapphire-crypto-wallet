import 'package:bip39/bip39.dart' as bip39;
import 'package:bip32/bip32.dart' as bip32;
import 'package:web3dart/web3dart.dart';
import 'package:hex/hex.dart';
import 'dart:typed_data';
import 'package:pointycastle/digests/ripemd160.dart';
import 'package:pointycastle/digests/sha256.dart';
import 'package:bs58check/bs58check.dart' as bs58;
import 'package:crypto/crypto.dart';
import '../../models/wallet.dart';
import '../constants/app_constants.dart';

class WalletService {
  static final WalletService _instance = WalletService._internal();
  factory WalletService() => _instance;
  WalletService._internal();

  // Generate new 12-word mnemonic
  String generateMnemonic() {
    return bip39.generateMnemonic();
  }

  // Validate mnemonic
  bool validateMnemonic(String mnemonic) {
    return bip39.validateMnemonic(mnemonic);
  }

  // Create wallet from mnemonic
  Future<WalletData> createWalletFromMnemonic(String mnemonic, bool isMainnet) async {
    if (!validateMnemonic(mnemonic)) {
      throw Exception('Invalid mnemonic phrase');
    }

    // Generate seed from mnemonic
    final seed = bip39.mnemonicToSeed(mnemonic);
    final root = bip32.BIP32.fromSeed(seed);

    // Generate Ethereum wallet
    final ethPath = AppConstants.ethPath;
    final ethNode = root.derivePath(ethPath);
    final ethPrivateKey = HEX.encode(ethNode.privateKey!);
    final ethCredentials = EthPrivateKey.fromHex(ethPrivateKey);
    final ethAddress = await ethCredentials.address;

    // Generate Bitcoin wallet
    final btcPath = isMainnet ? AppConstants.btcMainnetPath : AppConstants.btcTestnetPath;
    final btcNode = root.derivePath(btcPath);
    final btcPrivateKey = HEX.encode(btcNode.privateKey!);
    final btcAddress = _generateBitcoinAddress(btcNode.publicKey, isMainnet);

    // Generate Filecoin wallet (secp256k1 address)
    final filPath = AppConstants.filPath;
    final filNode = root.derivePath(filPath);
    final filPrivateKey = HEX.encode(filNode.privateKey!);
    final filAddress = _generateFilecoinAddress(filNode.publicKey, isMainnet);

    return WalletData(
      mnemonic: mnemonic,
      btcAddress: btcAddress,
      btcPrivateKey: btcPrivateKey,
      ethAddress: ethAddress.hex,
      ethPrivateKey: ethPrivateKey,
      filAddress: filAddress,
      filPrivateKey: filPrivateKey,
    );
  }

  // Generate Bitcoin address from public key
  String _generateBitcoinAddress(Uint8List publicKey, bool isMainnet) {
    // SHA-256 hash
    final sha256Hash = SHA256Digest().process(publicKey);

    // RIPEMD-160 hash
    final ripemd160Hash = RIPEMD160Digest().process(sha256Hash);

    // Add version byte (0x00 for mainnet, 0x6F for testnet)
    final version = isMainnet ? 0x00 : 0x6F;
    final versionedPayload = Uint8List.fromList([version, ...ripemd160Hash]);

    // Encode with Base58Check
    return bs58.encode(versionedPayload);
  }

  // Generate Filecoin address from public key (FIXED)
  String _generateFilecoinAddress(Uint8List publicKey, bool isMainnet) {
    // Filecoin secp256k1 address (protocol 1)
    // Hash the public key
    final hash = sha256.convert(publicKey).bytes;

    // Take first 20 bytes for payload
    final payload = Uint8List.fromList(hash.sublist(0, 20));

    // Create address bytes: [protocol, ...payload]
    // Protocol 1 = secp256k1
    final addressBytes = Uint8List.fromList([1, ...payload]);

    // Network prefix: 'f' for mainnet, 't' for testnet
    final prefix = isMainnet ? 'f' : 't';

    // Encode with base32 (simplified - using base58 for now)
    final encoded = bs58.encode(addressBytes);

    return '$prefix$encoded';
  }

  // Get private key for specific coin
  String getPrivateKey(WalletData wallet, CoinType coinType) {
    switch (coinType) {
      case CoinType.btc:
        return wallet.btcPrivateKey;
      case CoinType.eth:
        return wallet.ethPrivateKey;
      case CoinType.fil:
        return wallet.filPrivateKey;
    }
  }

  // Get address for specific coin
  String getAddress(WalletData wallet, CoinType coinType) {
    switch (coinType) {
      case CoinType.btc:
        return wallet.btcAddress;
      case CoinType.eth:
        return wallet.ethAddress;
      case CoinType.fil:
        return wallet.filAddress;
    }
  }
}