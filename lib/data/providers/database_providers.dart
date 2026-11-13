/// Database and repository wiring.
library;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:duemate/domain/repositories/emi_repository.dart';
import 'package:duemate/domain/repositories/expense_repository.dart';
import 'package:duemate/domain/repositories/person_repository.dart';
import 'package:duemate/domain/repositories/recurring_expense_repository.dart';
import 'package:duemate/domain/repositories/transaction_repository.dart';
import 'package:duemate/data/database/app_database.dart' hide CreditCardEmi, RecurringExpense;
import 'package:duemate/data/repositories/emi_repository_impl.dart';
import 'package:duemate/data/repositories/expense_repository_impl.dart';
import 'package:duemate/data/repositories/person_repository_impl.dart';
import 'package:duemate/data/repositories/recurring_expense_repository_impl.dart';
import 'package:duemate/data/repositories/transaction_repository_impl.dart';

// Database Provider
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

// Repository Providers
final personRepositoryProvider = Provider<PersonRepository>((ref) {
  return PersonRepositoryImpl(ref.watch(databaseProvider));
});

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return TransactionRepositoryImpl(ref.watch(databaseProvider));
});

final emiRepositoryProvider = Provider<EmiRepository>((ref) {
  return EmiRepositoryImpl(ref.watch(databaseProvider));
});

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  return ExpenseRepositoryImpl(ref.watch(databaseProvider));
});

final recurringExpenseRepositoryProvider = Provider<RecurringExpenseRepository>((ref) {
  return RecurringExpenseRepositoryImpl(ref.watch(databaseProvider));
});
