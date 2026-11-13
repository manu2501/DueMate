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

  /// Posts installments that fell due since the EMI was last processed
  /// (all due ones the first time), up to [referenceDate] (default now).
  /// One left unpaid on purpose (count lowered on edit, expense deleted) is
  /// not posted again: only newly due dates are.
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
    final emis = (await emiRepository.getAllEmis())
        .where((e) => e.status == 'active' || (e.isForSelf && e.status == 'completed'))
        .toList();
    var generated = 0;

    for (final emi in emis) {
      final from = emi.lastProcessedDate == null ? 0 : dueCount(emi, emi.lastProcessedDate!);
      final to = dueCount(emi, now);
      generated += await database.transaction(() async {
        final posted = await postedInstallments(emi);
        final prepaid = _prepaid(emi, posted);
        var added = 0;
        Future<void> post(int k) async {
          final dueDate = emi.getDueDateForInstallment(k);
          await _post(emi, k, dueDate.isAfter(now) ? now : dueDate);
          posted.add(k);
          added++;
        }

        // Your own: every installment marked paid gets an expense.
        for (var k = 1; emi.isForSelf && posted.length < emi.installmentsPaid && k <= emi.totalTenureMonths; k++) {
          if (!posted.contains(k)) await post(k);
        }
        for (var k = from + 1; k <= to; k++) {
          if (!_isPaid(emi, posted, k)) await post(k);
        }
        await _savePaid(emi, _paidCount(emi, prepaid, posted),
            processedAt: now, force: added > 0 || to > from);
        return added;
      });
    }

    return EmiProcessorResult(emisChecked: emis.length, installmentsGenerated: generated);
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
      for (var k = 1; k <= emi.totalTenureMonths && added < count; k++) {
        if (_isPaid(emi, posted, k)) continue;
        await _post(emi, k, date);
        posted.add(k);
        added++;
      }
      // Paying ahead doesn't change what has fallen due: keep lastProcessedDate.
      if (added > 0) await _savePaid(emi, _paidCount(emi, prepaid, posted), force: true);
      return added;
    });
  }

  /// Brings what was already posted for an EMI in line with an edit
  /// ([before] → [after]), then saves [after]. Installments past the new
  /// paid count are removed; the rest take the new amounts, due dates, name
  /// and person. Changing between yours and shared starts the postings over.
  /// Installments already due but beyond the paid count stay unpaid: the
  /// count you typed wins; later due dates post as usual.
  Future<void> applyEdit(CreditCardEmi before, CreditCardEmi after, {DateTime? now}) {
    final today = now ?? DateTime.now();
    return database.transaction(() async {
      if (before.isForSelf != after.isForSelf) {
        await _deletePostings(before, (_) => true);
      } else {
        await _deletePostings(after, (k) => k > after.installmentsPaid);
        await _restatePostings(before, after, today);
      }
      await emiRepository.updateEmi(after.copyWith(
        lastProcessedDate: today,
        status: _statusFor(after, after.installmentsPaid),
      ));
    });
  }

  Future<void> _deletePostings(CreditCardEmi emi, bool Function(int k) which) async {
    final ids = [
      for (final p in await _postings(emi))
        if (p.k == null || which(p.k!)) p.id,
    ];
    if (ids.isEmpty) return;
    if (emi.isForSelf) {
      await (database.delete(database.expenses)..where((t) => t.id.isIn(ids))).go();
    } else {
      await (database.delete(database.transactions)..where((t) => t.id.isIn(ids))).go();
    }
  }

  /// Amount, date, name and person of each remaining posting, from [after].
  /// A posting dated on its old due date moves to the new one (not past
  /// [today]); one paid on another day (paid ahead) keeps its date.
  Future<void> _restatePostings(CreditCardEmi before, CreditCardEmi after, DateTime today) async {
    for (final p in await _postings(after)) {
      final k = p.k!;
      final newDue = after.getDueDateForInstallment(k);
      final date = _dayOf(p.date) == _dayOf(before.getDueDateForInstallment(k))
          ? (newDue.isAfter(today) ? _dayOf(today) : newDue)
          : p.date;
      final amount = after.getMonthlyInstallmentFor(k);
      final note = _note(after, k);
      final updatedAt = DateTime.now();
      if (after.isForSelf) {
        await (database.update(database.expenses)..where((t) => t.id.equals(p.id))).write(db.ExpensesCompanion(
          title: Value(after.itemName),
          amount: Value(amount),
          expenseDate: Value(date),
          notes: Value(note),
          updatedAt: Value(updatedAt),
        ));
      } else {
        await (database.update(database.transactions)..where((t) => t.id.equals(p.id))).write(db.TransactionsCompanion(
          personId: Value(after.personId),
          type: Value(after.isPaidByMe ? TransactionType.moneyGiven : TransactionType.paymentReceived),
          amount: Value(amount),
          transactionDate: Value(date),
          note: Value('$note: ${after.itemName}'),
          updatedAt: Value(updatedAt),
        ));
      }
    }
  }

  /// Every posting of [emi]: row id, installment number and date.
  Future<List<({String id, int? k, DateTime date})>> _postings(CreditCardEmi emi) async {
    if (emi.isForSelf) {
      final rows = await (database.select(database.expenses)..where((t) => t.emiId.equals(emi.id))).get();
      return [for (final r in rows) (id: r.id, k: r.installmentNumber, date: r.expenseDate)];
    }
    final rows = await (database.select(database.transactions)..where((t) => t.emiId.equals(emi.id))).get();
    return [for (final r in rows) (id: r.id, k: r.installmentNumber, date: r.transactionDate)];
  }

  /// Posted, or (shared EMIs) counted as paid before tracking.
  static bool _isPaid(CreditCardEmi emi, Set<int> posted, int k) =>
      posted.contains(k) || (!emi.isForSelf && k <= emi.installmentsPaid);

  static int _paidCount(CreditCardEmi emi, int prepaid, Set<int> posted) =>
      (prepaid + posted.length).clamp(0, emi.totalTenureMonths);

  static String _note(CreditCardEmi emi, int k) => 'EMI $k/${emi.totalTenureMonths} · ${emi.cardName}';

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
    final note = _note(emi, k);
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

  Future<void> _savePaid(CreditCardEmi emi, int paid, {DateTime? processedAt, required bool force}) async {
    final status = _statusFor(emi, paid);
    if (!force && paid == emi.installmentsPaid && status == emi.status) return;
    await emiRepository.updateEmi(emi.copyWith(
      installmentsPaid: paid,
      status: status,
      lastProcessedDate: processedAt ?? emi.lastProcessedDate,
      updatedAt: DateTime.now(),
    ));
  }

  /// Completed once every installment is paid; reopened if one no longer is.
  static String _statusFor(CreditCardEmi emi, int paid) => paid >= emi.totalTenureMonths
      ? 'completed'
      : (emi.status == 'completed' ? 'active' : emi.status);

  static DateTime _dayOf(DateTime d) => DateTime(d.year, d.month, d.day);
}
