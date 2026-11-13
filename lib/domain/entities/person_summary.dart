import 'ledger_transaction.dart';
import 'person.dart';

class PersonSummary {
  final Person person;
  final double totalGiven;
  final double totalReceived;
  final double balance; // totalGiven - totalReceived
  final LedgerTransaction? lastTransaction;
  final int transactionCount;

  const PersonSummary({
    required this.person,
    required this.totalGiven,
    required this.totalReceived,
    required this.balance,
    this.lastTransaction,
    this.transactionCount = 0,
  });

  bool get owesMoney => balance > 0.0001;
  bool get isSettled => balance.abs() <= 0.0001 && (totalGiven > 0 || totalReceived > 0);
  bool get isOverpaid => balance < -0.0001;
  bool get hasNoTransactions => totalGiven == 0 && totalReceived == 0;

  /// How much has been paid back, whichever way the money went. When they
  /// owe you (or it's settled): what they've repaid of what you gave. When
  /// you owe them: what you've repaid of what they gave. Null with no entries.
  Repayment? get repayment {
    if (hasNoTransactions) return null;
    return isOverpaid
        ? Repayment(paid: totalGiven, of: totalReceived, byYou: true)
        : Repayment(paid: totalReceived, of: totalGiven, byYou: false);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PersonSummary &&
          runtimeType == other.runtimeType &&
          person.id == other.person.id &&
          balance == other.balance &&
          totalGiven == other.totalGiven &&
          totalReceived == other.totalReceived;

  @override
  int get hashCode => person.id.hashCode ^ balance.hashCode;
}


/// Progress of paying back: [paid] of [of]. [byYou] when you're the one
/// repaying (you owe them).
class Repayment {
  final double paid;
  final double of;
  final bool byYou;

  const Repayment({required this.paid, required this.of, required this.byYou});

  /// 0..1, for a progress bar.
  double get fraction => of <= 0 ? 0 : (paid / of).clamp(0.0, 1.0);

  /// Whole percent; only shows 100 when fully paid, never rounded up to it.
  int get percent => fraction >= 1 ? 100 : (fraction * 100).floor().clamp(0, 99);

  /// Some paid back, not all: the only time a list shows the bar. At 0% it
  /// says nothing new; at 100% the row already says "settled".
  bool get isPartial => paid > 0.0001 && fraction < 1;
}
