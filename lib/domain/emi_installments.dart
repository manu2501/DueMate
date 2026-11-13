import 'entities/credit_card_emi.dart';

/// Which installments of an EMI are paid. Pure.
///
/// An installment is paid when it has a posting (an expense for your own EMI,
/// a ledger entry for a shared one). Shared EMIs may also have installments
/// marked paid before the app tracked them, with no posting: those are the
/// earliest numbers without one, up to the EMI's paid count. Paid ones need
/// not be contiguous: one in the middle can be marked unpaid.
class EmiInstallments {
  final CreditCardEmi emi;

  /// Paid installment numbers (1-based).
  final Set<int> paid;

  const EmiInstallments._(this.emi, this.paid);

  /// From the installment numbers already [posted] for [emi].
  factory EmiInstallments.of(CreditCardEmi emi, Iterable<int> posted) {
    final n = emi.totalTenureMonths;
    final paid = {for (final k in posted) if (k >= 1 && k <= n) k};
    var untracked = emi.installmentsPaid - paid.length;
    for (var k = 1; k <= n && untracked > 0; k++) {
      if (paid.add(k)) untracked--;
    }
    return EmiInstallments._(emi, paid);
  }

  int get count => paid.length;
  bool isPaid(int k) => paid.contains(k);
  bool get isComplete => count >= emi.totalTenureMonths;

  /// Unpaid installment numbers, earliest first.
  Iterable<int> get unpaid sync* {
    for (var k = 1; k <= emi.totalTenureMonths; k++) {
      if (!paid.contains(k)) yield k;
    }
  }

  /// The earliest unpaid installment, or null when all are paid.
  int? get next => unpaid.firstOrNull;

  DateTime? get nextDueDate => next == null ? null : emi.getDueDateForInstallment(next!);

  /// What the next unpaid installment costs (0 when all are paid).
  double get nextAmount => next == null ? 0 : emi.getMonthlyInstallmentFor(next!);

  double get paidAmount => paid.fold(0, (s, k) => s + emi.getMonthlyInstallmentFor(k));
  double get remainingAmount => unpaid.fold(0, (s, k) => s + emi.getMonthlyInstallmentFor(k));
  double get progress => emi.totalTenureMonths > 0 ? (count / emi.totalTenureMonths).clamp(0.0, 1.0) : 1.0;
}
