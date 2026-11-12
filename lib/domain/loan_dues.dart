import 'package:duemate/core/constants/app_constants.dart';
import 'entities/ledger_transaction.dart';

/// Money due back by a date: the unpaid part of loans given with that
/// "return by" date.
class DueBack {
  final DateTime date;
  final double amount;
  const DueBack(this.date, this.amount);

  @override
  bool operator ==(Object other) => other is DueBack && other.date == date && other.amount == amount;
  @override
  int get hashCode => Object.hash(date, amount);
  @override
  String toString() => 'DueBack($date, $amount)';
}

/// One person's dated loans that aren't paid back yet.
class LoanDueStatus {
  /// Earliest first.
  final List<DueBack> dues;
  const LoanDueStatus(this.dues);

  DueBack get next => dues.first;

  /// Past their date (as of [today], a date without time).
  List<DueBack> overdue(DateTime today) => [for (final d in dues) if (d.date.isBefore(today)) d];
  bool isOverdue(DateTime today) => next.date.isBefore(today);
  double overdueAmount(DateTime today) => overdue(today).fold(0, (s, d) => s + d.amount);

  // Value equality, so watching one person's status with select() only
  // rebuilds when their dues actually change.
  @override
  bool operator ==(Object other) =>
      other is LoanDueStatus &&
      other.dues.length == dues.length &&
      Iterable<int>.generate(dues.length).every((i) => other.dues[i] == dues[i]);
  @override
  int get hashCode => Object.hashAll(dues);
}

/// Works out what's due back from whom. Repayments pay off the oldest loans
/// first, so a dated loan counts only for the part that's still unpaid.
class LoanDues {
  LoanDues._();

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  /// One person's outstanding dated loans, earliest date first (same dates
  /// merged). Empty when nothing dated is outstanding.
  static List<DueBack> outstanding(Iterable<LedgerTransaction> transactions) {
    final gives = [for (final t in transactions) if (t.isMoneyGiven) t]
      ..sort((a, b) {
        final c = a.transactionDate.compareTo(b.transactionDate);
        return c != 0 ? c : a.createdAt.compareTo(b.createdAt);
      });
    var repaid = transactions.where((t) => t.isPaymentReceived).fold<double>(0, (s, t) => s + t.amount);

    final byDate = <DateTime, double>{};
    for (final g in gives) {
      final covered = repaid < g.amount ? repaid : g.amount;
      repaid -= covered;
      final left = g.amount - covered;
      if (left > 0.0001 && g.dueDate != null) {
        final d = _day(g.dueDate!);
        byDate[d] = (byDate[d] ?? 0) + left;
      }
    }
    return [for (final e in byDate.entries) DueBack(e.key, e.value)]..sort((a, b) => a.date.compareTo(b.date));
  }

  /// Everyone with outstanding dated loans, in one pass over [transactions].
  /// Your own "self" row (EMIs) is left out.
  static Map<String, LoanDueStatus> byPerson(Iterable<LedgerTransaction> transactions) {
    final grouped = <String, List<LedgerTransaction>>{};
    for (final t in transactions) {
      if (t.personId == AppConstants.selfPersonId) continue;
      grouped.putIfAbsent(t.personId, () => []).add(t);
    }
    return {
      for (final e in grouped.entries)
        // Most people have no dated loans: skip the sort for them.
        if (e.value.any((t) => t.dueDate != null))
          if (outstanding(e.value) case final dues when dues.isNotEmpty) e.key: LoanDueStatus(dues),
    };
  }
}
