import 'package:intl/intl.dart';

/// Utility class for formatting currency values
class CurrencyFormatter {
  static final NumberFormat _usdFormat = NumberFormat.currency(
    locale: 'en_US',
    symbol: '\$',
    decimalDigits: 2,
  );

  static final NumberFormat _compactFormat = NumberFormat.compactCurrency(
    locale: 'en_US',
    symbol: '\$',
    decimalDigits: 0,
  );

  /// Format amount as USD (e.g., $1,234.56)
  static String format(double amount) {
    return _usdFormat.format(amount);
  }

  /// Format amount as compact USD (e.g., $1.2K)
  static String formatCompact(double amount) {
    return _compactFormat.format(amount);
  }

  /// Format amount with sign (e.g., +$100.00 or -$50.00)
  static String formatWithSign(double amount) {
    final formatted = format(amount.abs());
    return amount >= 0 ? '+$formatted' : '-$formatted';
  }

  /// Format amount for display in safe-to-spend context
  static String formatSafeToSpend(double amount) {
    if (amount <= 0) {
      return '\$0';
    }
    // Round down for safe-to-spend (conservative)
    return '\$${amount.floor()}';
  }

  /// Parse currency string to double
  static double? parse(String value) {
    try {
      // Remove currency symbols and commas
      final cleaned = value.replaceAll(RegExp(r'[^\d.-]'), '');
      return double.tryParse(cleaned);
    } catch (_) {
      return null;
    }
  }
}
