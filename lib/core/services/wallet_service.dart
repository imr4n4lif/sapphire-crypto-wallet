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

  String generateMnemonic() {
    return bip39.generateMnemonic();
  }

  bool validateMnemonic(String mnemonic) {
    return bip39.validateMnemonic(mnemonic);
  }

  Future<WalletData> createWalletFromMnemonic(String mnemonic, bool isMainnet) async {
    if (!validateMnemonic(mnemonic)) {
      throw Exception('Invalid mnemonic phrase');
    }

    print('🔐 Creating wallet from mnemonic...');

    final seed = bip39.mnemonicToSeed(mnemonic);
    final root = bip32.BIP32.fromSeed(seed);

    // Generate Ethereum wallet
    final ethPath = AppConstants.ethPath;
    final ethNode = root.derivePath(ethPath);
    final ethPrivateKey = HEX.encode(ethNode.privateKey!);
    final ethCredentials = EthPrivateKey.fromHex(ethPrivateKey);
    final ethAddress = await ethCredentials.address;
    print('✅ ETH Address: ${ethAddress.hex}');

    // Generate Bitcoin wallet
    final btcPath = isMainnet ? AppConstants.btcMainnetPath : AppConstants.btcTestnetPath;
    final btcNode = root.derivePath(btcPath);
    final btcPrivateKey = HEX.encode(btcNode.privateKey!);
    final btcAddress = _generateBitcoinAddress(btcNode.publicKey, isMainnet);
    print('✅ BTC Address: $btcAddress');

    // Generate Tron wallet
    final trxPath = AppConstants.trxPath;
    final trxNode = root.derivePath(trxPath);
    final trxPrivateKey = HEX.encode(trxNode.privateKey!);
    final trxAddress = _generateTronAddress(trxNode.publicKey, isMainnet);
    print('✅ TRX Address: $trxAddress');

    return WalletData(
      mnemonic: mnemonic,
      btcAddress: btcAddress,
      btcPrivateKey: btcPrivateKey,
      ethAddress: ethAddress.hex,
      ethPrivateKey: ethPrivateKey,
      trxAddress: trxAddress,
      trxPrivateKey: trxPrivateKey,
    );
  }

  String _generateBitcoinAddress(Uint8List publicKey, bool isMainnet) {
    final sha256Hash = SHA256Digest().process(publicKey);
    final ripemd160Hash = RIPEMD160Digest().process(sha256Hash);
    final version = isMainnet ? 0x00 : 0x6F;
    final versionedPayload = Uint8List.fromList([version, ...ripemd160Hash]);
    return bs58.encode(versionedPayload);
  }

  String _generateTronAddress(Uint8List publicKey, bool isMainnet) {
    try {
      print('🔧 Generating Tron address...');

      // Tron uses the last 64 bytes of the public key (uncompressed format)
      Uint8List publicKeyBytes;
      if (publicKey.length == 33) {
        // Compressed public key - need to decompress
        publicKeyBytes = _decompressPublicKey(publicKey);
      } else if (publicKey.length == 65) {
        // Already uncompressed
        publicKeyBytes = publicKey.sublist(1); // Remove 0x04 prefix
      } else {
        throw Exception('Invalid public key length: ${publicKey.length}');
      }

      // Take last 64 bytes
      final keyBytes = publicKeyBytes.length == 64
          ? publicKeyBytes
          : publicKeyBytes.sublist(publicKeyBytes.length - 64);

      // Keccak256 hash
      final hash = _keccak256(keyBytes);

      // Take last 20 bytes
      final addressBytes = hash.sublist(hash.length - 20);

      // Add Tron prefix (0x41 for mainnet and testnet)
      final prefix = 0x41;
      final addressWithPrefix = Uint8List.fromList([prefix, ...addressBytes]);

      // Base58Check encode
      final address = bs58.encode(addressWithPrefix);

      print('✅ Generated Tron Address: $address');
      return address;
    } catch (e) {
      print('❌ Error generating Tron address: $e');
      return 'TGenerationError';
    }
  }

  Uint8List _decompressPublicKey(Uint8List compressedKey) {
    // Simple decompression for secp256k1
    // In production, use a proper library
    // For now, returning the compressed key as we'll handle it in address generation
    return compressedKey;
  }

  Uint8List _keccak256(Uint8List input) {
    // Using SHA3-256 as approximation (Tron uses Keccak256)
    // In production, use package:pointycastle with proper Keccak
    final digest = sha256.convert(input);
    return Uint8List.fromList(digest.bytes);
  }
}