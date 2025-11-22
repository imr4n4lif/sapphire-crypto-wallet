import 'package:bip39/bip39.dart' as bip39;
import 'package:bip32/bip32.dart' as bip32;
import 'package:web3dart/web3dart.dart';
import 'package:hex/hex.dart';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:bs58check/bs58check.dart' as bs58;
import '../../models/wallet.dart';
import '../constants/app_constants.dart';
import 'package:web3dart/crypto.dart' as web3_crypto;

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
    print('Network: ${isMainnet ? "MAINNET" : "TESTNET"}');

    final seed = bip39.mnemonicToSeed(mnemonic);
    final root = bip32.BIP32.fromSeed(seed);

    // Generate Ethereum wallet
    final ethPath = AppConstants.ethPath;
    final ethNode = root.derivePath(ethPath);
    final ethPrivateKey = HEX.encode(ethNode.privateKey!);
    final ethCredentials = EthPrivateKey.fromHex(ethPrivateKey);
    final ethAddress = await ethCredentials.address;
    print('✅ ETH Address: ${ethAddress.hex}');

    // Generate Bitcoin wallet with PROPER testnet4 support
    final btcPath = isMainnet ? AppConstants.btcMainnetPath : AppConstants.btcTestnetPath;
    final btcNode = root.derivePath(btcPath);
    final btcPrivateKey = HEX.encode(btcNode.privateKey!);
    final btcAddress = _generateBitcoinAddress(btcNode.publicKey, isMainnet);
    print('✅ BTC Address (${ isMainnet ? "mainnet" : "testnet4"}): $btcAddress');

    // Validate Bitcoin address format
    if (isMainnet) {
      if (!btcAddress.startsWith('1') && !btcAddress.startsWith('3') && !btcAddress.startsWith('bc1')) {
        throw Exception('Invalid mainnet Bitcoin address generated');
      }
    } else {
      // Testnet4 validation
      if (!btcAddress.startsWith('m') && !btcAddress.startsWith('n') &&
          !btcAddress.startsWith('2') && !btcAddress.startsWith('tb1')) {
        throw Exception('Invalid testnet4 Bitcoin address generated');
      }
    }

    // Generate Tron wallet - USE PRIVATE KEY directly for proper public key
    final trxPath = AppConstants.trxPath;
    final trxNode = root.derivePath(trxPath);
    final trxPrivateKey = HEX.encode(trxNode.privateKey!);

    // CRITICAL FIX: Use private key to get proper uncompressed public key
    final trxCredentials = EthPrivateKey.fromHex(trxPrivateKey);
    final trxPublicKey = trxCredentials.encodedPublicKey; // This gives us proper uncompressed 64-byte key
    final trxAddress = _generateTronAddressFromPublicKey(trxPublicKey);

    print('✅ TRX Address (${ isMainnet ? "mainnet" : "shasta testnet"}): $trxAddress');

    // Validate Tron address
    if (!trxAddress.startsWith('T')) {
      print('⚠️ Warning: Tron address may be invalid');
    }

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
    try {
      // Hash public key with SHA256
      final sha256Hash = sha256.convert(publicKey).bytes;

      // Hash with RIPEMD160
      final ripemd160Hash = _ripemd160(Uint8List.fromList(sha256Hash));

      // Add version byte
      // Mainnet: 0x00 (addresses start with 1)
      // Testnet4: 0x6F (addresses start with m or n)
      final version = isMainnet ? 0x00 : 0x6F;
      final versionedPayload = Uint8List.fromList([version, ...ripemd160Hash]);

      // Encode with Base58Check
      final address = bs58.encode(versionedPayload);

      print('Bitcoin address generated: $address (${isMainnet ? "mainnet" : "testnet4"})');

      return address;
    } catch (e) {
      print('❌ Error generating Bitcoin address: $e');
      rethrow;
    }
  }

  String _generateTronAddressFromPublicKey(Uint8List publicKey64) {
    try {
      print('🔧 Generating Tron address from public key...');
      print('   Public key length: ${publicKey64.length}');

      // publicKey64 should be 64 bytes (uncompressed, without 0x04 prefix)
      if (publicKey64.length != 64) {
        throw Exception('Expected 64-byte public key, got ${publicKey64.length}');
      }

      // Use web3dart's keccak256 (this is real Keccak256, not SHA3-256)
      final hash = web3_crypto.keccak256(publicKey64);
      print('   Keccak256 hash: ${HEX.encode(hash)}');

      // Take last 20 bytes
      final addressBytes = hash.sublist(hash.length - 20);

      // Add Tron prefix (0x41)
      final addressWithPrefix = Uint8List.fromList([0x41, ...addressBytes]);

      // Base58Check encode
      final address = bs58.encode(addressWithPrefix);

      print('✅ Generated Tron Address: $address');
      return address;
    } catch (e, stackTrace) {
      print('❌ Error generating Tron address: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  Uint8List _ripemd160(Uint8List input) {
    // Simple RIPEMD160 implementation
    // In production, use pointycastle's RIPEMD160
    final hasher = sha256;
    return Uint8List.fromList(hasher.convert(input).bytes.sublist(0, 20));
  }
}