/// Personal expenses and the monthly budget.
library;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:duemate/domain/entities/personal_expense.dart';
import 'database_providers.dart';

final allExpensesProvider = StreamProvider<List<PersonalExpense>>((ref) {
  return ref.watch(expenseRepositoryProvider).watchAllExpenses();
});

final monthlyExpensesProvider = StreamProvider<List<PersonalExpense>>((ref) {
  return ref.watch(expenseRepositoryProvider).watchCurrentMonthExpenses();
});

final monthlyExpenseTotalProvider = Provider<double>((ref) {
  final expensesAsync = ref.watch(monthlyExpensesProvider);
  return expensesAsync.maybeWhen(
    data: (list) => list.fold(0.0, (sum, item) => sum + item.amount),
    orElse: () => 0.0,
  );
});

class MonthlyBudgetNotifier extends Notifier<double> {
  static const _key = 'duemate_monthly_budget_limit';

  @override
  double build() {
    _load();
    return 25000.0;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getDouble(_key);
    if (saved != null && saved > 0) {
      state = saved;
    }
  }

  Future<void> setBudget(double budget) async {
    state = budget;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_key, budget);
  }
}

final monthlyBudgetLimitProvider = NotifierProvider<MonthlyBudgetNotifier, double>(MonthlyBudgetNotifier.new);
