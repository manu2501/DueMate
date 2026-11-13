import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../data/database/app_database.dart' as db;
import '../../data/database/tables.dart';
import '../../domain/entities/credit_card_emi.dart';
import '../../domain/entities/ledger_transaction.dart';
import '../../domain/repositories/emi_repository.dart';
import '../../domain/repositories/transaction_repository.dart';

class EmiProcessorResult {
  final int emisChecked;
  final int installmentsGenerated;

  const EmiProcessorResult({
    required this.emisChecked,
    required this.installmentsGenerated,
  });
}

/// Posts EMI installments where they belong:
/// - your own EMIs and loans become **expenses** (category EMI), in the month
///   each was paid;
/// - EMIs shared with someone become **ledger entries** on that person.
///
/// Every posting carries the EMI id and installment number, so nothing is
/// posted twice.
class EmiProcessorService {
  final EmiRepository emiRepository;
  final TransactionRepository transactionRepository;
  final db.AppDatabase database;

  EmiProcessorService({
    required this.emiRepository,
    required this.transactionRepository,
    required this.database,
  });

  /// Posts every installment that is due by [referenceDate] (default now).
  ///
  /// Your own EMIs: installments marked paid on the form (even before the
  /// app tracked them) are posted too, each in its own due month; ones marked
  /// paid ahead of their due date are dated [referenceDate].
  /// Shared EMIs: installments marked paid on the form are treated as settled
  /// before tracking and are not posted.
  Future<EmiProcessorResult> processDueInstallments({DateTime? referenceDate}) async {
    final now = referenceDate ?? DateTime.now();
    // Active EMIs, plus your own finished ones: their installments marked
    // paid on the form still need posting to expenses.
    final activeEmis = (await emiRepository.getAllEmis())
        .where((e) => e.status == 'active' || (e.isForSelf && e.status == 'completed'))
        .toList();
    var generated = 0;

    for (final emi in activeEmis) {
      final due = dueCount(emi, now);
      generated += await database.transaction(() async {
        final posted = await postedInstallments(emi);
        final prepaid = _prepaid(emi, posted);
        final upTo = emi.isForSelf ? (emi.installmentsPaid > due ? emi.installmentsPaid : due) : due;
        var added = 0;
        for (var k = prepaid + 1; k <= upTo; k++) {
          if (posted.contains(k)) continue;
          final dueDate = emi.getDueDateForInstallment(k);
          await _post(emi, k, dueDate.isAfter(now) ? now : dueDate);
          posted.add(k);
          added++;
        }
        await _savePaid(emi, prepaid + posted.length, now, force: added > 0);
        return added;
      });
    }

    return EmiProcessorResult(emisChecked: activeEmis.length, installmentsGenerated: generated);
  }

  /// Records the next [count] unpaid installments as paid on [paidOn]
  /// (default today), including ones not due yet (paying ahead). Returns how
  /// many were recorded.
  Future<int> payInstallments(CreditCardEmi emi, {int count = 1, DateTime? paidOn}) {
    final date = paidOn ?? DateTime.now();
    return database.transaction(() async {
      final posted = await postedInstallments(emi);
      final prepaid = _prepaid(emi, posted);
      var added = 0;
      for (var k = prepaid + 1; k <= emi.totalTenureMonths && added < count; k++) {
        if (posted.contains(k)) continue;
        await _post(emi, k, date);
        posted.add(k);
        added++;
      }
      if (added > 0) await _savePaid(emi, prepaid + posted.length, date, force: true);
      return added;
    });
  }

  /// Installments due on or before [now].
  static int dueCount(CreditCardEmi emi, DateTime now) {
    var n = 0;
    while (n < emi.totalTenureMonths && !_dayOf(emi.getDueDateForInstallment(n + 1)).isAfter(_dayOf(now))) {
      n++;
    }
    return n;
  }

  /// Installment numbers already posted for [emi] (expenses for your own,
  /// ledger entries for shared ones).
  Future<Set<int>> postedInstallments(CreditCardEmi emi) async {
    if (emi.isForSelf) {
      final q = database.selectOnly(database.expenses)
        ..addColumns([database.expenses.installmentNumber])
        ..where(database.expenses.emiId.equals(emi.id));
      return {for (final r in await q.get()) ?r.read(database.expenses.installmentNumber)};
    }
    final q = database.selectOnly(database.transactions)
      ..addColumns([database.transactions.installmentNumber])
      ..where(database.transactions.emiId.equals(emi.id));
    return {for (final r in await q.get()) ?r.read(database.transactions.installmentNumber)};
  }

  /// Shared EMIs only: installments declared paid that have no ledger entry.
  /// Your own EMIs post every paid installment, so they have none.
  int _prepaid(CreditCardEmi emi, Set<int> posted) =>
      emi.isForSelf ? 0 : (emi.installmentsPaid - posted.length).clamp(0, emi.totalTenureMonths);

  Future<void> _post(CreditCardEmi emi, int k, DateTime date) async {
    final now = DateTime.now();
    final amount = emi.getMonthlyInstallmentFor(k);
    final note = 'EMI $k/${emi.totalTenureMonths} · ${emi.cardName}';
    if (emi.isForSelf) {
      await database.into(database.expenses).insert(db.ExpensesCompanion.insert(
            id: const Uuid().v4(),
            title: emi.itemName,
            amount: amount,
            category: ExpenseCategory.emi,
            expenseDate: date,
            paymentMethod: emi.isLoan ? PaymentMethod.bankTransfer : PaymentMethod.card,
            notes: Value(note),
            emiId: Value(emi.id),
            installmentNumber: Value(k),
            createdAt: now,
            updatedAt: now,
          ));
      return;
    }
    await transactionRepository.addTransaction(LedgerTransaction(
      id: const Uuid().v4(),
      personId: emi.personId,
      type: emi.isPaidByMe ? TransactionType.moneyGiven : TransactionType.paymentReceived,
      amount: amount,
      transactionDate: date,
      paymentMethod: emi.isLoan ? PaymentMethod.bankTransfer : PaymentMethod.card,
      note: '$note: ${emi.itemName}',
      emiId: emi.id,
      installmentNumber: k,
      createdAt: now,
      updatedAt: now,
    ));
  }

  Future<void> _savePaid(CreditCardEmi emi, int paid, DateTime processedAt, {required bool force}) async {
    final status = paid >= emi.totalTenureMonths ? 'completed' : emi.status;
    if (!force && paid == emi.installmentsPaid && status == emi.status) return;
    await emiRepository.updateEmi(emi.copyWith(
      installmentsPaid: paid,
      status: status,
      lastProcessedDate: processedAt,
      updatedAt: DateTime.now(),
    ));
  }

  static DateTime _dayOf(DateTime d) => DateTime(d.year, d.month, d.day);
}
