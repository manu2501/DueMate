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

  /// Ordered by date, then by when they were entered.
  static List<LedgerTransaction> _oldestFirst(Iterable<LedgerTransaction> txs) => txs.toList()
    ..sort((a, b) {
      final c = a.transactionDate.compareTo(b.transactionDate);
      return c != 0 ? c : a.createdAt.compareTo(b.createdAt);
    });

  /// One person's outstanding dated loans, earliest date first (same dates
  /// merged). Empty when nothing dated is outstanding.
  static List<DueBack> outstanding(Iterable<LedgerTransaction> transactions) {
    final gives = _oldestFirst(transactions.where((t) => t.isMoneyGiven));
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

/// How reliably someone pays back loans that had a "return by" date.
///
/// Repayments go to the oldest loans first (as in [LoanDues]), in the order
/// they were received, so each dated loan is paid off on a known day:
/// - paid off on or before its date: **on time**;
/// - paid off after it: **late**;
/// - still unpaid once it has passed: **missed** (also not on time);
/// - not paid off and its date is still ahead: not judged yet.
/// Loans without a date still take their share of repayments, but are not
/// judged.
class RepaymentRecord {
  final int onTime;
  final int late;
  final int missed;

  const RepaymentRecord({this.onTime = 0, this.late = 0, this.missed = 0});

  /// Dated loans whose outcome is known.
  int get judged => onTime + late + missed;

  /// Dated loans paid back in full (on time or late): some history to go by.
  int get repaid => onTime + late;

  /// Share repaid on time, 0–1, or null when nothing is judged yet.
  double? get onTimeShare => judged == 0 ? null : onTime / judged;

  /// One person's record from their [transactions], as of [today].
  factory RepaymentRecord.of(Iterable<LedgerTransaction> transactions, DateTime today) {
    const eps = 0.0001;
    final day = LoanDues._day(today);
    final gives = LoanDues._oldestFirst(transactions.where((t) => t.isMoneyGiven && t.amount > eps));
    final receipts = LoanDues._oldestFirst(transactions.where((t) => t.isPaymentReceived && t.amount > eps));
    var r = 0; // next receipt to draw from
    var available = receipts.isEmpty ? 0.0 : receipts.first.amount;
    var onTime = 0, late = 0, missed = 0;

    for (final give in gives) {
      var need = give.amount;
      DateTime? lastReceipt;
      while (need > eps && r < receipts.length) {
        final take = need < available ? need : available;
        need -= take;
        available -= take;
        lastReceipt = receipts[r].transactionDate;
        if (available <= eps && ++r < receipts.length) available = receipts[r].amount;
      }
      final due = give.dueDate;
      if (due == null) continue;
      final dueDay = LoanDues._day(due);
      if (need <= eps) {
        // Paid off by the receipt that covered the last of it (never before
        // the loan itself).
        final paidOff = LoanDues._day(lastReceipt!.isAfter(give.transactionDate) ? lastReceipt : give.transactionDate);
        paidOff.isAfter(dueDay) ? late++ : onTime++;
      } else if (dueDay.isBefore(day)) {
        missed++;
      }
    }
    return RepaymentRecord(onTime: onTime, late: late, missed: missed);
  }

  @override
  bool operator ==(Object other) => other is RepaymentRecord && other.onTime == onTime && other.late == late && other.missed == missed;
  @override
  int get hashCode => Object.hash(onTime, late, missed);

  @override
  String toString() => 'RepaymentRecord(onTime: $onTime, late: $late, missed: $missed)';
}
