import 'package:flutter_test/flutter_test.dart';
import 'package:duemate/core/utils/currency_formatter.dart';
import 'package:duemate/core/utils/date_formatter.dart';

void main() {
  group('CurrencyFormatter tests', () {
    test('formats positive amounts with currency symbol', () {
      expect(CurrencyFormatter.format(10000, symbol: 'â‚¹'), 'â‚¹10,000');
      expect(CurrencyFormatter.format(500, symbol: 'â‚¹'), 'â‚¹500');
      expect(CurrencyFormatter.format(125000, symbol: 'â‚¹'), 'â‚¹1,25,000');
    });

    test('formats zero properly', () {
      expect(CurrencyFormatter.format(0, symbol: 'â‚¹'), 'â‚¹0');
    });

    test('formats negative amounts (overpayments)', () {
      expect(CurrencyFormatter.format(-1000, symbol: 'â‚¹'), '-â‚¹1,000');
    });

    test('formats decimals when present', () {
      expect(CurrencyFormatter.format(1500.50, symbol: 'â‚¹'), 'â‚¹1,500.50');
      expect(CurrencyFormatter.format(500.00, symbol: 'â‚¹'), 'â‚¹500');
    });

    test('compact formatting', () {
      expect(CurrencyFormatter.formatCompact(1500, symbol: 'â‚¹'), 'â‚¹1.5k');
      expect(CurrencyFormatter.formatCompact(150000, symbol: 'â‚¹'), 'â‚¹1.5L');
      expect(CurrencyFormatter.formatCompact(15000000, symbol: 'â‚¹'), 'â‚¹1.5Cr');
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

