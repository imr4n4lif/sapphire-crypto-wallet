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

    // Generate Filecoin wallet
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

  String _generateBitcoinAddress(Uint8List publicKey, bool isMainnet) {
    final sha256Hash = SHA256Digest().process(publicKey);
    final ripemd160Hash = RIPEMD160Digest().process(sha256Hash);
    final version = isMainnet ? 0x00 : 0x6F;
    final versionedPayload = Uint8List.fromList([version, ...ripemd160Hash]);
    return bs58.encode(versionedPayload);
  }

  String _generateFilecoinAddressImproved(Uint8List publicKey, bool isMainnet) {
    try {
      print('🔧 Generating Filecoin address (improved)...');
      print('Public Key Length: ${publicKey.length}');

      final hash = sha256.convert(publicKey).bytes;
      final payload = Uint8List.fromList(hash.sublist(0, 20));

      print('Payload Hash (20 bytes): ${HEX.encode(payload)}');

      final protocol = 1;
      final addressPayload = Uint8List.fromList([protocol, ...payload]);

      final checksumHash = sha256.convert(addressPayload).bytes;
      final checksum = Uint8List.fromList(checksumHash.sublist(0, 4));

      print('Checksum (4 bytes): ${HEX.encode(checksum)}');

      final combined = Uint8List.fromList([...addressPayload, ...checksum]);
      final base32Encoded = _base32EncodeNoPadding(combined);

      print('Base32 encoded: $base32Encoded');

      final prefix = isMainnet ? 'f' : 't';
      final address = '$prefix$protocol$base32Encoded';

      print('✅ Generated Filecoin Address: $address');
      return address;
    } catch (e) {
      print('❌ Error generating Filecoin address: $e');
      final prefix = isMainnet ? 'f' : 't';
      return '${prefix}1unavailable';
    }
  }

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

}