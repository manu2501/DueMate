import 'package:duemate/core/constants/app_constants.dart';
import 'entities/ledger_transaction.dart';

/// Money lent and collected in one month.
class MonthFlow {
  final double lent;
  final double collected;
  const MonthFlow(this.lent, this.collected);

  /// Positive when more came back than went out.
  double get net => collected - lent;
  bool get isEmpty => lent == 0 && collected == 0;
}

/// Month-by-month lending cashflow. Your own EMIs post as ledger entries
/// against the "self" row; they're spending, not lending, so they're left out.
class LendingCashflow {
  LendingCashflow._();

  /// Twelve [MonthFlow]s (Jan..Dec) for [year], in one pass.
  static List<MonthFlow> byMonth(Iterable<LedgerTransaction> transactions, int year) {
    final lent = List<double>.filled(12, 0);
    final collected = List<double>.filled(12, 0);
    for (final t in transactions) {
      if (t.transactionDate.year != year || t.personId == AppConstants.selfPersonId) continue;
      final m = t.transactionDate.month - 1;
      if (t.isMoneyGiven) {
        lent[m] += t.amount;
      } else {
        collected[m] += t.amount;
      }
    }
    return [for (var m = 0; m < 12; m++) MonthFlow(lent[m], collected[m])];
  }

  /// Years with lending activity, plus [current], oldest first.
  static List<int> years(Iterable<LedgerTransaction> transactions, int current) => {
        current,
        for (final t in transactions)
          if (t.personId != AppConstants.selfPersonId) t.transactionDate.year,
      }.toList()
        ..sort();
}
