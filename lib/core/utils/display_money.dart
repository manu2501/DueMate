import 'package:duemate/core/utils/currency_formatter.dart';

/// Formats amounts for showing on screen, honouring "hide amounts".
///
/// Use this for balances and totals that are displayed. Do not use it for
/// exports, PDFs, shared messages or amounts the user is typing: those must
/// always carry the real number (use [CurrencyFormatter] directly).
class DisplayMoney {
  final String symbol;
  final bool hidden;

  const DisplayMoney({required this.symbol, required this.hidden});

  /// What a hidden amount looks like. Same width whatever the value, so the
  /// size of the number gives nothing away.
  static const mask = '•••••';

  /// Read out by screen readers instead of the dots.
  static const hiddenLabel = 'Amount hidden';

  String call(double amount) => hidden ? '$symbol$mask' : CurrencyFormatter.format(amount, symbol: symbol);

  String compact(double amount) =>
      hidden ? '$symbol$mask' : CurrencyFormatter.formatCompact(amount, symbol: symbol);
}
