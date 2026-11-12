import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../domain/entities/personal_expense.dart';
import '../../domain/entities/recurring_expense.dart';
import '../../domain/repositories/recurring_expense_repository.dart';
import '../database/app_database.dart' as db;

class RecurringExpenseRepositoryImpl implements RecurringExpenseRepository {
  final db.AppDatabase _db;

  RecurringExpenseRepositoryImpl(this._db);

  static RecurringExpense _toDomain(db.RecurringExpense r) => RecurringExpense(
        id: r.id,
        title: r.title,
        amount: r.amount,
        category: r.category,
        paymentMethod: r.paymentMethod,
        notes: r.notes,
        dayOfMonth: r.dayOfMonth,
        startDate: r.startDate,
        lastPostedDate: r.lastPostedDate,
        createdAt: r.createdAt,
        updatedAt: r.updatedAt,
      );

  /// One posted occurrence of [rule] on [date].
  static db.ExpensesCompanion _occurrence(RecurringExpense rule, DateTime date, DateTime now) =>
      db.ExpensesCompanion.insert(
        id: const Uuid().v4(),
        title: rule.title,
        amount: rule.amount,
        category: rule.category,
        expenseDate: date,
        paymentMethod: rule.paymentMethod,
        notes: Value(rule.notes),
        recurringId: Value(rule.id),
        createdAt: now,
        updatedAt: now,
      );

  @override
  Stream<List<RecurringExpense>> watchAll() =>
      (_db.select(_db.recurringExpenses)..orderBy([(t) => OrderingTerm.asc(t.dayOfMonth)]))
          .watch()
          .map((rows) => rows.map(_toDomain).toList());

  @override
  Future<void> createWithFirst(RecurringExpense rule, PersonalExpense first) => _db.transaction(() async {
        await _db.into(_db.recurringExpenses).insert(db.RecurringExpensesCompanion.insert(
              id: rule.id,
              title: rule.title,
              amount: rule.amount,
              category: rule.category,
              paymentMethod: rule.paymentMethod,
              notes: Value(rule.notes),
              dayOfMonth: rule.dayOfMonth,
              startDate: rule.startDate,
              lastPostedDate: Value(first.expenseDate),
              createdAt: rule.createdAt,
              updatedAt: rule.updatedAt,
            ));
        await _db.into(_db.expenses).insert(db.ExpensesCompanion.insert(
              id: first.id,
              title: first.title,
              amount: first.amount,
              category: first.category,
              expenseDate: first.expenseDate,
              paymentMethod: first.paymentMethod,
              notes: Value(first.notes),
              recurringId: Value(rule.id),
              createdAt: first.createdAt,
              updatedAt: first.updatedAt,
            ));
      });

  @override
  Future<void> updateAmount(String id, double amount) =>
      (_db.update(_db.recurringExpenses)..where((t) => t.id.equals(id))).write(
        db.RecurringExpensesCompanion(amount: Value(amount), updatedAt: Value(DateTime.now())),
      );

  @override
  Future<void> delete(String id) => (_db.delete(_db.recurringExpenses)..where((t) => t.id.equals(id))).go();

  @override
  Future<int> postDue(DateTime now) => _db.transaction(() async {
        final rules = (await _db.select(_db.recurringExpenses).get()).map(_toDomain);
        var posted = 0;
        await _db.batch((b) {
          for (final rule in rules) {
            final dates = rule.dueDates(now);
            if (dates.isEmpty) continue;
            b.insertAll(_db.expenses, [for (final d in dates) _occurrence(rule, d, now)]);
            b.update(
              _db.recurringExpenses,
              db.RecurringExpensesCompanion(lastPostedDate: Value(dates.last)),
              where: (t) => t.id.equals(rule.id),
            );
            posted += dates.length;
          }
        });
        return posted;
      });
}
