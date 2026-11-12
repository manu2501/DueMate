import 'package:duemate/domain/entities/personal_expense.dart';

abstract class ExpenseRepository {
  Stream<List<PersonalExpense>> watchAllExpenses();
  Stream<List<PersonalExpense>> watchCurrentMonthExpenses();
  Future<List<PersonalExpense>> getAllExpenses();
  Future<PersonalExpense?> getExpenseById(String id);
  Future<void> createExpense(PersonalExpense expense);
  Future<void> updateExpense(PersonalExpense expense);
  Future<void> deleteExpense(String id);
}
