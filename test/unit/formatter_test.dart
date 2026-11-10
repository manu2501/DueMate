import 'package:flutter_test/flutter_test.dart';
import 'package:smarava/core/utils/currency_formatter.dart';
import 'package:smarava/core/utils/date_formatter.dart';

void main() {
  group('CurrencyFormatter tests', () {
    test('formats positive amounts with currency symbol', () {
      expect(CurrencyFormatter.format(10000, symbol: '₹'), '₹10,000');
      expect(CurrencyFormatter.format(500, symbol: '₹'), '₹500');
      expect(CurrencyFormatter.format(125000, symbol: '₹'), '₹1,25,000');
    });

    test('formats zero properly', () {
      expect(CurrencyFormatter.format(0, symbol: '₹'), '₹0');
    });

    test('formats negative amounts (overpayments)', () {
      expect(CurrencyFormatter.format(-1000, symbol: '₹'), '-₹1,000');
    });

    test('formats decimals when present', () {
      expect(CurrencyFormatter.format(1500.50, symbol: '₹'), '₹1,500.50');
      expect(CurrencyFormatter.format(500.00, symbol: '₹'), '₹500');
    });

    test('compact formatting', () {
      expect(CurrencyFormatter.formatCompact(1500, symbol: '₹'), '₹1.5k');
      expect(CurrencyFormatter.formatCompact(150000, symbol: '₹'), '₹1.5L');
      expect(CurrencyFormatter.formatCompact(15000000, symbol: '₹'), '₹1.5Cr');
    });
  });

  group('DateFormatter tests', () {
    test('formats relative dates accurately', () {
      final now = DateTime.now();
      expect(DateFormatter.formatRelative(now), 'Today');

      final yesterday = now.subtract(const Duration(days: 1));
      expect(DateFormatter.formatRelative(yesterday), 'Yesterday');
    });
  });
}

