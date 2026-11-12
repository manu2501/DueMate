import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';
import 'package:duemate/data/database/app_database.dart';
import 'package:duemate/data/database/tables.dart';
import 'package:duemate/data/repositories/expense_repository_impl.dart';
import 'package:duemate/domain/entities/personal_expense.dart';

void main() {
  late AppDatabase db;
  late ExpenseRepositoryImpl repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = ExpenseRepositoryImpl(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('Creates, retrieves, and deletes a personal expense record in SQLite', () async {
    final now = DateTime.now();
    final expense = PersonalExpense(
      id: const Uuid().v4(),
      title: 'Supermarket Grocery Run',
      amount: 1850.0,
      category: ExpenseCategory.groceries,
      expenseDate: now,
      paymentMethod: PaymentMethod.upi,
      notes: 'Weekly household supplies',
      createdAt: now,
      updatedAt: now,
    );

    await repo.createExpense(expense);

    final all = await repo.getAllExpenses();
    expect(all.length, equals(1));
    expect(all.first.title, equals('Supermarket Grocery Run'));
    expect(all.first.amount, equals(1850.0));
    expect(all.first.category, equals(ExpenseCategory.groceries));
    expect(all.first.paymentMethod, equals(PaymentMethod.upi));

    // Delete expense
    await repo.deleteExpense(expense.id);
    final emptyList = await repo.getAllExpenses();
    expect(emptyList, isEmpty);
  });

  test('Monthly expenses stream returns only current month records', () async {
    final now = DateTime.now();
    final currentMonthExpense = PersonalExpense(
      id: 'current-1',
      title: 'Current Month Electricity Bill',
      amount: 2400.0,
      category: ExpenseCategory.utilities,
      expenseDate: now,
      paymentMethod: PaymentMethod.card,
      createdAt: now,
      updatedAt: now,
    );

    final pastDate = DateTime(2022, 1, 15);
    final pastMonthExpense = PersonalExpense(
      id: 'past-1',
      title: 'Past Year Expense',
      amount: 5000.0,
      category: ExpenseCategory.shopping,
      expenseDate: pastDate,
      paymentMethod: PaymentMethod.cash,
      createdAt: pastDate,
      updatedAt: pastDate,
    );

    await repo.createExpense(currentMonthExpense);
    await repo.createExpense(pastMonthExpense);

    final monthlyStream = repo.watchCurrentMonthExpenses();
    final currentMonthList = await monthlyStream.first;

    expect(currentMonthList.length, equals(1));
    expect(currentMonthList.first.id, equals('current-1'));
    expect(currentMonthList.first.amount, equals(2400.0));
  });
}
