import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../data/database/app_database.dart' as db;
import '../../data/database/tables.dart';
import '../../domain/emi_installments.dart';
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
/// posted twice. Which installments count as paid is [EmiInstallments]; the
/// EMI's `installmentsPaid` is kept equal to its count.
///
/// Methods that change one EMI re-read it first, so a stale copy from the UI
/// never overwrites newer data.
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
  /// One left unpaid on purpose (marked unpaid, count lowered on edit,
  /// posting deleted) is not posted again: only newly due dates are.
  ///
  /// Your own EMIs: installments marked paid on the form (even before the
  /// app tracked them) are posted too, each in its own due month; ones not
  /// due yet (paid ahead) are dated [referenceDate].
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
        final paid = {...EmiInstallments.of(emi, posted).paid};
        final toPost = [
          // Your own: every installment counted as paid gets its expense.
          if (emi.isForSelf) ...paid.difference(posted),
          for (var k = from + 1; k <= to; k++)
            if (!paid.contains(k)) k,
        ]..sort();
        for (final k in toPost) {
          final dueDate = emi.getDueDateForInstallment(k);
          await _post(emi, k, dueDate.isAfter(now) ? now : dueDate);
          paid.add(k);
        }
        await _savePaid(emi, paid.length, processedAt: now, force: toPost.isNotEmpty || to > from);
        return toPost.length;
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
      final fresh = await _fresh(emi);
      if (fresh == null) return 0;
      final state = await installments(fresh);
      final ks = state.unpaid.take(count).toList();
      for (final k in ks) {
        await _post(fresh, k, date);
      }
      // Paying ahead doesn't change what has fallen due: keep lastProcessedDate.
      if (ks.isNotEmpty) await _savePaid(fresh, state.count + ks.length, force: true);
      return ks.length;
    });
  }

  /// Marks installment [k] paid on [paidOn] (default: its due date, or today
  /// if that is still ahead). False if it was already paid.
  Future<bool> markPaid(CreditCardEmi emi, int k, {DateTime? paidOn}) {
    return database.transaction(() async {
      final fresh = await _fresh(emi);
      if (fresh == null || k < 1 || k > fresh.totalTenureMonths) return false;
      final state = await installments(fresh);
      if (state.isPaid(k)) return false;
      final due = fresh.getDueDateForInstallment(k);
      final today = _dayOf(DateTime.now());
      await _post(fresh, k, paidOn ?? (due.isAfter(today) ? today : due));
      await _savePaid(fresh, state.count + 1, force: true);
      return true;
    });
  }

  /// Marks installment [k] unpaid: removes its expense or ledger entry (for
  /// one paid before tracking, just the count). It is not posted again on
  /// its own; the next due date that passes posts as usual. False if it
  /// wasn't paid.
  Future<bool> markUnpaid(CreditCardEmi emi, int k) {
    return database.transaction(() async {
      final fresh = await _fresh(emi);
      if (fresh == null) return false;
      final state = await installments(fresh);
      if (!state.isPaid(k)) return false;
      await _deletePostings(fresh, (n) => n == k);
      await _savePaid(fresh, state.count - 1, force: true);
      return true;
    });
  }

  /// Sets what installment [k] costs. Its expense or ledger entry, if it is
  /// already paid, takes the new amount too.
  Future<void> setInstallmentAmount(CreditCardEmi emi, int k, double amount) {
    return database.transaction(() async {
      final fresh = await _fresh(emi);
      if (fresh == null) return;
      final schedule = <String, dynamic>{
        if (fresh.customScheduleJson case final json? when json.isNotEmpty) ...jsonDecode(json) as Map<String, dynamic>,
        '$k': amount,
      };
      await emiRepository.updateEmi(fresh.copyWith(customScheduleJson: jsonEncode(schedule)));
      final now = DateTime.now();
      if (fresh.isForSelf) {
        await (database.update(database.expenses)
              ..where((t) => t.emiId.equals(fresh.id) & t.installmentNumber.equals(k)))
            .write(db.ExpensesCompanion(amount: Value(amount), updatedAt: Value(now)));
      } else {
        await (database.update(database.transactions)
              ..where((t) => t.emiId.equals(fresh.id) & t.installmentNumber.equals(k)))
            .write(db.TransactionsCompanion(amount: Value(amount), updatedAt: Value(now)));
      }
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

  /// Which installments of [emi] are paid, from what is posted.
  Future<EmiInstallments> installments(CreditCardEmi emi) async =>
      EmiInstallments.of(emi, await postedInstallments(emi));

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

  /// Installments due on or before [now].
  static int dueCount(CreditCardEmi emi, DateTime now) {
    var n = 0;
    while (n < emi.totalTenureMonths && !_dayOf(emi.getDueDateForInstallment(n + 1)).isAfter(_dayOf(now))) {
      n++;
    }
    return n;
  }

  Future<CreditCardEmi?> _fresh(CreditCardEmi emi) => emiRepository.getEmiById(emi.id);

  Future<void> _post(CreditCardEmi emi, int k, DateTime date) async {
    final now = DateTime.now();
    final amount = emi.getMonthlyInstallmentFor(k);
    final note = _note(emi, k);
    final method = emi.isLoan ? PaymentMethod.bankTransfer : PaymentMethod.card;
    if (emi.isForSelf) {
      await database.into(database.expenses).insert(db.ExpensesCompanion.insert(
            id: const Uuid().v4(),
            title: emi.itemName,
            amount: amount,
            category: ExpenseCategory.emi,
            expenseDate: date,
            paymentMethod: method,
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
      paymentMethod: method,
      note: '$note: ${emi.itemName}',
      emiId: emi.id,
      installmentNumber: k,
      createdAt: now,
      updatedAt: now,
    ));
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

  static String _note(CreditCardEmi emi, int k) => 'EMI $k/${emi.totalTenureMonths} · ${emi.cardName}';

  Future<void> _savePaid(CreditCardEmi emi, int paid, {DateTime? processedAt, required bool force}) async {
    final count = paid.clamp(0, emi.totalTenureMonths);
    final status = _statusFor(emi, count);
    if (!force && count == emi.installmentsPaid && status == emi.status) return;
    await emiRepository.updateEmi(emi.copyWith(
      installmentsPaid: count,
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
