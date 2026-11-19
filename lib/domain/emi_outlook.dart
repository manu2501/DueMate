import 'emi_installments.dart';

/// What your EMIs and loans still need this month: unpaid installments due by
/// the end of it (including any left unpaid from earlier months). Counts your
/// own EMIs and those on your card for someone else (both leave your
/// account); not ones the other person pays, nor cancelled ones.
class EmiOutlook {
  final double dueThisMonth;

  const EmiOutlook({required this.dueThisMonth});

  /// From each EMI's installments, as of [now].
  factory EmiOutlook.of(Iterable<EmiInstallments> states, DateTime now) {
    final nextMonth = DateTime(now.year, now.month + 1);
    var due = 0.0;
    for (final s in states) {
      final emi = s.emi;
      if (emi.isCancelled || !(emi.isForSelf || emi.isPaidByMe)) continue;
      for (final k in s.unpaid) {
        if (!emi.getDueDateForInstallment(k).isBefore(nextMonth)) break;
        due += emi.getMonthlyInstallmentFor(k);
      }
    }
    return EmiOutlook(dueThisMonth: due);
  }
}
