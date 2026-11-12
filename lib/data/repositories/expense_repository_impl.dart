import 'package:drift/drift.dart';
import 'package:duemate/data/database/app_database.dart';
import 'package:duemate/domain/entities/personal_expense.dart';
import 'package:duemate/domain/repositories/expense_repository.dart';

class ExpenseRepositoryImpl implements ExpenseRepository {
  final AppDatabase _db;

  ExpenseRepositoryImpl(this._db);

  PersonalExpense _mapToEntity(Expense row) {
    return PersonalExpense(
      id: row.id,
      title: row.title,
      amount: row.amount,
      category: row.category,
      expenseDate: row.expenseDate,
      paymentMethod: row.paymentMethod,
      notes: row.notes,
      recurringId: row.recurringId,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  @override
  Stream<List<PersonalExpense>> watchAllExpenses() {
    final query = _db.select(_db.expenses)
      ..orderBy([(t) => OrderingTerm(expression: t.expenseDate, mode: OrderingMode.desc)]);
    return query.watch().map((rows) => rows.map(_mapToEntity).toList());
  }

  @override
  Stream<List<PersonalExpense>> watchCurrentMonthExpenses() {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    final query = _db.select(_db.expenses)
      ..where((t) => t.expenseDate.isBetweenValues(startOfMonth, endOfMonth))
      ..orderBy([(t) => OrderingTerm(expression: t.expenseDate, mode: OrderingMode.desc)]);

    return query.watch().map((rows) => rows.map(_mapToEntity).toList());
  }

  @override
  Future<List<PersonalExpense>> getAllExpenses() async {
    final query = _db.select(_db.expenses)
      ..orderBy([(t) => OrderingTerm(expression: t.expenseDate, mode: OrderingMode.desc)]);
    final rows = await query.get();
    return rows.map(_mapToEntity).toList();
  }

  @override
  Future<PersonalExpense?> getExpenseById(String id) async {
    final query = _db.select(_db.expenses)..where((t) => t.id.equals(id));
    final row = await query.getSingleOrNull();
    return row != null ? _mapToEntity(row) : null;
  }

  @override
  Future<void> createExpense(PersonalExpense expense) async {
    await _db.into(_db.expenses).insert(
          ExpensesCompanion.insert(
            id: expense.id,
            title: expense.title,
            amount: expense.amount,
            category: expense.category,
            expenseDate: expense.expenseDate,
            paymentMethod: expense.paymentMethod,
            notes: Value(expense.notes),
            recurringId: Value(expense.recurringId),
            createdAt: expense.createdAt,
            updatedAt: expense.updatedAt,
          ),
        );
  }

  @override
  Future<void> updateExpense(PersonalExpense expense) async {
    await (_db.update(_db.expenses)..where((t) => t.id.equals(expense.id))).write(
          ExpensesCompanion(
            title: Value(expense.title),
            amount: Value(expense.amount),
            category: Value(expense.category),
            expenseDate: Value(expense.expenseDate),
            paymentMethod: Value(expense.paymentMethod),
            notes: Value(expense.notes),
            updatedAt: Value(expense.updatedAt),
          ),
        );
  }

  @override
  Future<void> deleteExpense(String id) async {
    await (_db.delete(_db.expenses)..where((t) => t.id.equals(id))).go();
  }
}
