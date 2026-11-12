import 'package:duemate/domain/entities/personal_expense.dart';
import 'package:duemate/domain/entities/recurring_expense.dart';

abstract class RecurringExpenseRepository {
  Stream<List<RecurringExpense>> watchAll();

  /// Saves [rule] together with its first occurrence, [first], which counts
  /// as posted (so it's never posted twice). One transaction.
  Future<void> createWithFirst(RecurringExpense rule, PersonalExpense first);

  /// Changes the amount for future months; posted expenses keep theirs.
  Future<void> updateAmount(String id, double amount);

  /// Stops the rule. Expenses it already posted stay.
  Future<void> delete(String id);

  /// Posts every due, unposted occurrence as an expense; returns how many.
  Future<int> postDue(DateTime now);
}
