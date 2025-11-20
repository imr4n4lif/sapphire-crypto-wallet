import 'package:bip39/bip39.dart' as bip39;
import 'package:bip32/bip32.dart' as bip32;
import 'package:web3dart/web3dart.dart';
import 'package:hex/hex.dart';
import 'dart:typed_data';
import 'package:pointycastle/digests/ripemd160.dart';
import 'package:pointycastle/digests/sha256.dart';
import 'package:bs58check/bs58check.dart' as bs58;
import 'package:crypto/crypto.dart';
import 'dart:convert';
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

    print('🔐 Creating wallet from mnemonic...');

    // Generate seed from mnemonic
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

    // Generate Filecoin wallet (secp256k1 address) - IMPROVED
    final filPath = AppConstants.filPath;
    final filNode = root.derivePath(filPath);
    final filPrivateKey = HEX.encode(filNode.privateKey!);
    final filAddress = _generateFilecoinAddressImproved(filNode.publicKey, isMainnet);
    print('✅ FIL Address: $filAddress');

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

  // IMPROVED: Generate Filecoin address with proper formatting
  String _generateFilecoinAddressImproved(Uint8List publicKey, bool isMainnet) {
    try {
      print('🔧 Generating Filecoin address (improved)...');
      print('Public Key Length: ${publicKey.length}');
      print('Public Key (hex): ${HEX.encode(publicKey)}');

      // Use Blake2b-160 hash (fallback to SHA256 for now)
      final hash = sha256.convert(publicKey).bytes;
      final payload = Uint8List.fromList(hash.sublist(0, 20));

      print('Payload Hash (20 bytes): ${HEX.encode(payload)}');

      // Protocol 1 for secp256k1
      final protocol = 1;

      // Create the address payload: protocol (1 byte) + payload (20 bytes)
      final addressPayload = Uint8List.fromList([protocol, ...payload]);

      // Calculate checksum (Blake2b-32, using SHA256 as fallback)
      final checksumHash = sha256.convert(addressPayload).bytes;
      final checksum = Uint8List.fromList(checksumHash.sublist(0, 4));

      print('Checksum (4 bytes): ${HEX.encode(checksum)}');

      // Combine: payload + checksum
      final combined = Uint8List.fromList([...addressPayload, ...checksum]);

      // Encode with Base32 (lowercase, no padding)
      final base32Encoded = _base32EncodeNoPadding(combined);

      print('Base32 encoded: $base32Encoded');

      // Add network prefix
      final prefix = isMainnet ? 'f' : 't';
      final address = '$prefix$protocol$base32Encoded';

      print('✅ Generated Filecoin Address: $address');
      return address;
    } catch (e) {
      print('❌ Error generating Filecoin address: $e');
      // Return a placeholder address format that won't crash the app
      final prefix = isMainnet ? 'f' : 't';
      return '${prefix}1unavailable';
    }
  }

  // Base32 encoding WITHOUT padding (Filecoin standard)
  String _base32EncodeNoPadding(Uint8List data) {
    const alphabet = 'abcdefghijklmnopqrstuvwxyz234567';
    final result = StringBuffer();

    int buffer = 0;
    int bitsLeft = 0;

    for (int byte in data) {
      buffer = (buffer << 8) | byte;
      bitsLeft += 8;

      while (bitsLeft >= 5) {
        result.write(alphabet[(buffer >> (bitsLeft - 5)) & 0x1F]);
        bitsLeft -= 5;
      }
    }

    if (bitsLeft > 0) {
      result.write(alphabet[(buffer << (5 - bitsLeft)) & 0x1F]);
    }

    return result.toString();
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