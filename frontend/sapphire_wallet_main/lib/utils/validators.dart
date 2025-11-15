
// lib/utils/validators.dart
class Validators {
  // Bitcoin address validation
  static bool isValidBitcoinAddress(String address) {
    if (address.isEmpty) return false;

    // Legacy addresses (P2PKH)
    if (address.startsWith('1') && address.length >= 26 && address.length <= 35) {
      return true;
    }

    // P2SH addresses
    if (address.startsWith('3') && address.length >= 26 && address.length <= 35) {
      return true;
    }

    // Bech32 addresses (native SegWit)
    if (address.startsWith('bc1') && address.length >= 42) {
      return true;
    }

    // Testnet
    if (address.startsWith('tb1') ||
        address.startsWith('2') ||
        address.startsWith('m') ||
        address.startsWith('n')) {
      return true;
    }

    return false;
  }

  // Ethereum address validation
  static bool isValidEthereumAddress(String address) {
    if (address.isEmpty) return false;

    // Must start with 0x and be 42 characters long
    if (!address.startsWith('0x') || address.length != 42) {
      return false;
    }

    // Must contain only hex characters after 0x
    final hexPart = address.substring(2);
    return RegExp(r'^[0-9a-fA-F]+$').hasMatch(hexPart);
  }

  // Filecoin address validation
  static bool isValidFilecoinAddress(String address) {
    if (address.isEmpty) return false;

    // Filecoin addresses start with 'f' or 't' (testnet)
    if (!address.startsWith('f') && !address.startsWith('t')) {
      return false;
    }

    // Must have a protocol identifier (f1, f3, etc.)
    if (address.length < 3) return false;

    final protocol = address.substring(1, 2);
    if (!['0', '1', '2', '3', '4'].contains(protocol)) {
      return false;
    }

    return true;
  }

  // Amount validation
  static bool isValidAmount(String amount, {double? max}) {
    if (amount.isEmpty) return false;

    final value = double.tryParse(amount);
    if (value == null) return false;

    if (value <= 0) return false;

    if (max != null && value > max) return false;

    return true;
  }

  // Mnemonic validation
  static bool isValidMnemonic(String mnemonic) {
    if (mnemonic.isEmpty) return false;

    final words = mnemonic.trim().split(RegExp(r'\s+'));

    // Must be 12, 15, 18, 21, or 24 words
    if (![12, 15, 18, 21, 24].contains(words.length)) {
      return false;
    }

    // Each word should not be empty
    for (final word in words) {
      if (word.isEmpty) return false;
    }

    return true;
  }
}