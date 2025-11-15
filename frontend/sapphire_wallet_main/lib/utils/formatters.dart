// lib/utils/formatters.dart
import 'package:intl/intl.dart';

class Formatters {
  static final _currencyFormatter = NumberFormat.currency(
    symbol: '\$',
    decimalDigits: 2,
  );

  static final _cryptoFormatter = NumberFormat.currency(
    symbol: '',
    decimalDigits: 6,
  );

  static String formatCurrency(double amount) {
    return _currencyFormatter.format(amount);
  }

  static String formatCrypto(double amount, {int? decimals}) {
    if (decimals != null) {
      final formatter = NumberFormat.currency(
        symbol: '',
        decimalDigits: decimals,
      );
      return formatter.format(amount);
    }
    return _cryptoFormatter.format(amount);
  }

  static String formatAddress(String address, {int start = 8, int end = 8}) {
    if (address.length <= start + end) return address;
    return '${address.substring(0, start)}...${address.substring(address.length - end)}';
  }

  static String formatDate(DateTime date) {
    return DateFormat('MMM dd, yyyy').format(date);
  }

  static String formatDateTime(DateTime date) {
    return DateFormat('MMM dd, yyyy HH:mm').format(date);
  }

  static String formatTime(DateTime date) {
    return DateFormat('HH:mm').format(date);
  }

  static String formatRelativeTime(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()} year${difference.inDays ~/ 365 > 1 ? 's' : ''} ago';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()} month${difference.inDays ~/ 30 > 1 ? 's' : ''} ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }
}