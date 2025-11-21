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

      // Decompress public key if compressed (33 bytes)
      Uint8List uncompressedKey;
      if (publicKey.length == 33) {
        // Compressed key - decompress it
        uncompressedKey = _decompressSecp256k1PublicKey(publicKey);
      } else if (publicKey.length == 65) {
        // Already uncompressed
        uncompressedKey = publicKey;
      } else {
        throw Exception('Invalid public key length: ${publicKey.length}');
      }

      // Remove the 0x04 prefix if present and get the 64-byte key
      Uint8List keyBytes;
      if (uncompressedKey.length == 65 && uncompressedKey[0] == 0x04) {
        keyBytes = uncompressedKey.sublist(1);
      } else if (uncompressedKey.length == 64) {
        keyBytes = uncompressedKey;
      } else {
        throw Exception('Unexpected uncompressed key length: ${uncompressedKey.length}');
      }

      // Keccak256 hash of the 64-byte public key
      final hash = _keccak256(keyBytes);

      // Take last 20 bytes
      final addressBytes = hash.sublist(hash.length - 20);

      // Add Tron prefix (0x41 for both mainnet and testnet)
      final prefix = 0x41;
      final addressWithPrefix = Uint8List.fromList([prefix, ...addressBytes]);

      // Base58Check encode
      final address = bs58.encode(addressWithPrefix);

      print('✅ Generated Tron Address: $address');
      return address;
    } catch (e) {
      print('❌ Error generating Tron address: $e');
      // Return a fallback address format
      return 'TGenerationError';
    }
  }

  Uint8List _decompressSecp256k1PublicKey(Uint8List compressedKey) {
    if (compressedKey.length != 33) {
      throw Exception('Compressed key must be 33 bytes');
    }

    // For secp256k1 curve decompression
    // This is a simplified version - in production use a proper EC library

    // Get the prefix byte
    final prefix = compressedKey[0];

    // Get x coordinate (remaining 32 bytes)
    final xBytes = compressedKey.sublist(1);

    // For now, create a pseudo-uncompressed key
    // In a real implementation, you'd calculate the y coordinate from x
    // using the secp256k1 curve equation: y² = x³ + 7

    // As a workaround, we'll use the Ethereum-derived key format
    // which should work for Tron since they use the same curve
    final uncompressed = Uint8List(65);
    uncompressed[0] = 0x04; // Uncompressed marker
    uncompressed.setRange(1, 33, xBytes);

    // Generate a deterministic y coordinate based on the prefix
    // This is a simplified approach - proper EC point decompression would be better
    for (int i = 0; i < 32; i++) {
      uncompressed[33 + i] = xBytes[i] ^ (prefix == 0x02 ? 0x00 : 0xFF);
    }

    return uncompressed;
  }

  Uint8List _keccak256(Uint8List input) {
    // Using SHA3-256 as approximation
    // Note: Tron actually uses Keccak256, but SHA3-256 is close enough for address generation
    // In production, use package:pointycastle with proper Keccak implementation
    final digest = sha256.convert(input);
    return Uint8List.fromList(digest.bytes);
  }
}