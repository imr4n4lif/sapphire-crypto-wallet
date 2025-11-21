// lib/core/utils/tron_address_converter.dart

import 'dart:typed_data';
import 'package:bs58check/bs58check.dart' as bs58check;
import 'package:hex/hex.dart';

class TronAddressConverter {
  /// Convert Tron base58 address (Txxx...) to hex format (41xxx...)
  static String base58ToHex(String base58Address) {
    try {
      if (base58Address.startsWith('41')) {
        return base58Address.toLowerCase(); // Already hex
      }

      // Decode base58check
      final decoded = bs58check.decode(base58Address);

      // Convert to hex string
      final hexAddress = HEX.encode(decoded);

      print('   🔄 Base58 to Hex: $base58Address -> $hexAddress');
      return hexAddress.toLowerCase();
    } catch (e) {
      print('   ⚠️ Base58 to Hex conversion failed: $e');
      print('   Using fallback comparison');
      return base58Address.toLowerCase();
    }
  }

  /// Convert Tron hex address (41xxx...) to base58 format (Txxx...)
  static String hexToBase58(String hexAddress) {
    try {
      if (!hexAddress.startsWith('41')) {
        return hexAddress; // Not a valid Tron hex address
      }

      // Remove '0x' prefix if present
      if (hexAddress.startsWith('0x')) {
        hexAddress = hexAddress.substring(2);
      }

      // Convert hex to bytes
      final bytes = HEX.decode(hexAddress);

      // Encode to base58check
      final base58Address = bs58check.encode(Uint8List.fromList(bytes));

      print('   🔄 Hex to Base58: $hexAddress -> $base58Address');
      return base58Address;
    } catch (e) {
      print('   ⚠️ Hex to Base58 conversion failed: $e');
      return hexAddress; // Return hex on failure
    }
  }

  /// Compare two Tron addresses (handles both base58 and hex formats)
  static bool addressesMatch(String address1, String address2) {
    try {
      // Normalize both addresses to hex for comparison
      final hex1 = base58ToHex(address1).toLowerCase();
      final hex2 = base58ToHex(address2).toLowerCase();

      final match = hex1 == hex2;
      print('   🔍 Address comparison: ${match ? "MATCH ✅" : "NO MATCH ❌"}');
      print('      Addr1 (hex): $hex1');
      print('      Addr2 (hex): $hex2');

      return match;
    } catch (e) {
      print('   ⚠️ Address comparison failed: $e');
      // Fallback to string comparison
      return address1.toLowerCase() == address2.toLowerCase();
    }
  }

  /// Validate Tron address format
  static bool isValidAddress(String address) {
    try {
      // Tron mainnet/testnet addresses start with 'T'
      if (address.startsWith('T') && address.length == 34) {
        // Try to decode
        bs58check.decode(address);
        return true;
      }

      // Hex format: starts with '41' and is 42 chars
      if (address.startsWith('41') && address.length == 42) {
        return true;
      }

      return false;
    } catch (e) {
      return false;
    }
  }
}