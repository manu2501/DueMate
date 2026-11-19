import 'emi_installments.dart';

/// What your EMIs and loans take: unpaid installments due by the end of this
/// month (including any left unpaid from earlier months), what was paid
/// towards this month's installments, and everything left to pay. Counts
/// your own EMIs and those on your card for someone else (both leave your
/// account); not ones the other person pays, nor cancelled ones.
class EmiOutlook {
  final double dueThisMonth;
  final int dueThisMonthCount;
  final double paidThisMonth;
  final double leftToPay;

  const EmiOutlook({
    required this.dueThisMonth,
    required this.dueThisMonthCount,
    required this.paidThisMonth,
    required this.leftToPay,
  });

  /// From each EMI's installments, as of [now].
  factory EmiOutlook.of(Iterable<EmiInstallments> states, DateTime now) {
    final monthStart = DateTime(now.year, now.month);
    final nextMonth = DateTime(now.year, now.month + 1);
    var due = 0.0, paid = 0.0, left = 0.0;
    var count = 0;
    for (final s in states) {
      final emi = s.emi;
      if (emi.isCancelled || !(emi.isForSelf || emi.isPaidByMe)) continue;
      for (var k = 1; k <= emi.totalTenureMonths; k++) {
        final amount = emi.getMonthlyInstallmentFor(k);
        final date = emi.getDueDateForInstallment(k);
        if (s.isPaid(k)) {
          if (!date.isBefore(monthStart) && date.isBefore(nextMonth)) paid += amount;
        } else {
          left += amount;
          if (date.isBefore(nextMonth)) {
            due += amount;
            count++;
          }
        }
      }
    }
    return EmiOutlook(dueThisMonth: due, dueThisMonthCount: count, paidThisMonth: paid, leftToPay: left);
  }
}
