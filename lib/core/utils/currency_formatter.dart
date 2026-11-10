import 'package:intl/intl.dart';

class CurrencyFormatter {
  static final _inrInt = NumberFormat.currency(symbol: '', decimalDigits: 0, locale: 'en_IN');
  static final _inrDec = NumberFormat.currency(symbol: '', decimalDigits: 2, locale: 'en_IN');
  static final _usInt = NumberFormat.currency(symbol: '', decimalDigits: 0, locale: 'en_US');
  static final _usDec = NumberFormat.currency(symbol: '', decimalDigits: 2, locale: 'en_US');

  static String format(
    double amount, {
    String symbol = '₹',
    bool showSign = false,
  }) {
    final isNegative = amount < 0;
    final absAmount = amount.abs();
    final hasDecimals = (absAmount % 1) != 0;

    final NumberFormat formatter;
    if (symbol == '₹') {
      formatter = hasDecimals ? _inrDec : _inrInt;
    } else {
      formatter = hasDecimals ? _usDec : _usInt;
    }

    final formattedNumber = formatter.format(absAmount).trim();

    if (isNegative) {
      return '-$symbol$formattedNumber';
    } else if (showSign && amount > 0) {
      return '+$symbol$formattedNumber';
    } else {
      return '$symbol$formattedNumber';
    }
  }

  static String formatCompact(double amount, {String symbol = '₹'}) {
    final absAmount = amount.abs();
    final isNegative = amount < 0;

    String formatted;
    if (absAmount >= 10000000) {
      formatted = '${(absAmount / 10000000).toStringAsFixed(1)}Cr';
    } else if (absAmount >= 100000) {
      formatted = '${(absAmount / 100000).toStringAsFixed(1)}L';
    } else if (absAmount >= 1000) {
      formatted = '${(absAmount / 1000).toStringAsFixed(1)}k';
    } else {
      formatted = absAmount.toStringAsFixed(absAmount % 1 == 0 ? 0 : 2);
    }

    return '${isNegative ? '-' : ''}$symbol$formatted';
  }
}
