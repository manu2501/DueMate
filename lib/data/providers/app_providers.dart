import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:duemate/core/constants/app_constants.dart';
import 'package:duemate/core/services/emi_processor_service.dart';
import 'package:duemate/domain/entities/credit_card_emi.dart';
import 'package:duemate/domain/entities/ledger_summary.dart';
import 'package:duemate/domain/entities/ledger_transaction.dart';
import 'package:duemate/domain/entities/person.dart' as domain;
import 'package:duemate/domain/entities/person_summary.dart';
import 'package:duemate/domain/entities/personal_expense.dart';
import 'package:duemate/domain/repositories/emi_repository.dart';
import 'package:duemate/domain/repositories/expense_repository.dart';
import 'package:duemate/domain/repositories/person_repository.dart';
import 'package:duemate/domain/repositories/transaction_repository.dart';
import 'package:duemate/data/database/app_database.dart' hide CreditCardEmi;
import 'package:duemate/data/repositories/emi_repository_impl.dart';
import 'package:duemate/data/repositories/expense_repository_impl.dart';
import 'package:duemate/data/repositories/person_repository_impl.dart';
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

final emiProcessorServiceProvider = Provider<EmiProcessorService>((ref) {
  return EmiProcessorService(
    emiRepository: ref.watch(emiRepositoryProvider),
    transactionRepository: ref.watch(transactionRepositoryProvider),
    database: ref.watch(databaseProvider),
  );
});

// App Settings Notifiers with persistent SharedPreferences storage
class CurrencyNotifier extends Notifier<String> {
  static const _key = 'duemate_currency_symbol';

  @override
  String build() {
    _load();
    return AppConstants.defaultCurrencySymbol;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    if (saved != null && saved.isNotEmpty) {
      state = saved;
    }
  }

  Future<void> setCurrency(String symbol) async {
    state = symbol;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, symbol);
  }
}

final currencySymbolProvider = NotifierProvider<CurrencyNotifier, String>(CurrencyNotifier.new);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  static const _key = 'duemate_theme_mode';

  @override
  ThemeMode build() {
    _load();
    return ThemeMode.system;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    if (saved != null) {
      state = ThemeMode.values.firstWhere(
        (m) => m.name == saved,
        orElse: () => ThemeMode.system,
      );
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

// Ledger & Summary Stream Providers
final ledgerSummaryProvider = StreamProvider<LedgerSummary>((ref) {
  return ref.watch(transactionRepositoryProvider).watchLedgerSummary();
});

final allPersonSummariesProvider = StreamProvider<List<PersonSummary>>((ref) {
  return ref.watch(transactionRepositoryProvider).watchPersonSummaries(includeArchived: true);
});

final personSummaryProvider = StreamProvider.family<PersonSummary?, String>((ref, personId) {
  return ref.watch(transactionRepositoryProvider).watchPersonSummary(personId);
});

final personTransactionsProvider = StreamProvider.family<List<LedgerTransaction>, String>((ref, personId) {
  return ref.watch(transactionRepositoryProvider).watchTransactionsForPerson(personId);
});

final recentTransactionsProvider = StreamProvider<List<LedgerTransaction>>((ref) {
  return ref.watch(transactionRepositoryProvider).watchAllTransactions(limit: 10);
});

final allTransactionsProvider = StreamProvider<List<LedgerTransaction>>((ref) {
  return ref.watch(transactionRepositoryProvider).watchAllTransactions();
});

// Persons Map Provider (for fast lookup by ID)
final personsMapProvider = Provider<Map<String, domain.Person>>((ref) {
  final summariesAsync = ref.watch(allPersonSummariesProvider);
  return summariesAsync.maybeWhen(
    data: (list) => {for (var s in list) s.person.id: s.person},
    orElse: () => {},
  );
});

// Dashboard Top Debtors Provider (ordered by highest outstanding balance)
final topDebtorsProvider = Provider<List<PersonSummary>>((ref) {
  final summariesAsync = ref.watch(allPersonSummariesProvider);
  return summariesAsync.maybeWhen(
    data: (list) {
      final owing = list.where((s) => !s.person.isArchived && s.owesMoney).toList();
      owing.sort((a, b) => b.balance.compareTo(a.balance));
      return owing;
    },
    orElse: () => [],
  );
});

class DashboardTotals {
  final double totalTheyOwe; // Money given out that is owed to user
  final double totalUserOwes; // Money user owes to others (overpaid/credit)
  final double netBalance;    // totalTheyOwe - totalUserOwes
  final double totalGiven;
  final double totalReceived;
  final int peopleOweUserCount;
  final int peopleUserOwesCount;

  const DashboardTotals({
    required this.totalTheyOwe,
    required this.totalUserOwes,
    required this.netBalance,
    required this.totalGiven,
    required this.totalReceived,
    required this.peopleOweUserCount,
    required this.peopleUserOwesCount,
  });

  static const empty = DashboardTotals(
    totalTheyOwe: 0,
    totalUserOwes: 0,
    netBalance: 0,
    totalGiven: 0,
    totalReceived: 0,
    peopleOweUserCount: 0,
    peopleUserOwesCount: 0,
  );
}

final dashboardTotalsProvider = Provider<DashboardTotals>((ref) {
  final summariesAsync = ref.watch(allPersonSummariesProvider);
  return summariesAsync.maybeWhen(
    data: (list) {
      double theyOwe = 0;
      double userOwes = 0;
      double given = 0;
      double received = 0;
      int oweUserCount = 0;
      int userOwesCount = 0;

      for (final s in list) {
        if (!s.person.isArchived) {
          if (s.balance > 0.0001) {
            theyOwe += s.balance;
            oweUserCount++;
          } else if (s.balance < -0.0001) {
            userOwes += s.balance.abs();
            userOwesCount++;
          }
        }
        given += s.totalGiven;
        received += s.totalReceived;
      }

      return DashboardTotals(
        totalTheyOwe: theyOwe,
        totalUserOwes: userOwes,
        netBalance: theyOwe - userOwes,
        totalGiven: given,
        totalReceived: received,
        peopleOweUserCount: oweUserCount,
        peopleUserOwesCount: userOwesCount,
      );
    },
    orElse: () => DashboardTotals.empty,
  );
});

// Top 5 people ordered by highest absolute balance (debts or credits)
final topPeopleByBalanceProvider = Provider<List<PersonSummary>>((ref) {
  final summariesAsync = ref.watch(allPersonSummariesProvider);
  return summariesAsync.maybeWhen(
    data: (list) {
      final active = list.where((s) => !s.person.isArchived && s.balance.abs() > 0.0001).toList();
      active.sort((a, b) => b.balance.abs().compareTo(a.balance.abs()));
      return active.take(5).toList();
    },
    orElse: () => [],
  );
});

// People Screen Filter & Sort Enums
enum PeopleFilter { all, active, settled, archived }
enum PeopleSort { highestOutstanding, recentlyActive, alphabetical, recentlyAdded }

class PeopleFilterNotifier extends Notifier<PeopleFilter> {
  @override
  PeopleFilter build() => PeopleFilter.all;

  void setFilter(PeopleFilter filter) => state = filter;
}

final peopleFilterProvider = NotifierProvider<PeopleFilterNotifier, PeopleFilter>(PeopleFilterNotifier.new);

class PeopleSortNotifier extends Notifier<PeopleSort> {
  @override
  PeopleSort build() => PeopleSort.highestOutstanding;

  void setSort(PeopleSort sort) => state = sort;
}

final peopleSortProvider = NotifierProvider<PeopleSortNotifier, PeopleSort>(PeopleSortNotifier.new);

class PeopleSearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String query) => state = query;
}

final peopleSearchQueryProvider = NotifierProvider<PeopleSearchQueryNotifier, String>(PeopleSearchQueryNotifier.new);

// Filtered and Sorted People Provider
final filteredPersonSummariesProvider = Provider<List<PersonSummary>>((ref) {
  final summariesAsync = ref.watch(allPersonSummariesProvider);
  final filter = ref.watch(peopleFilterProvider);
  final sort = ref.watch(peopleSortProvider);
  final query = ref.watch(peopleSearchQueryProvider).trim().toLowerCase();

  return summariesAsync.maybeWhen(
    data: (list) {
      var filtered = list.where((item) {
        // Apply Archive / Status Filter
        switch (filter) {
          case PeopleFilter.all:
            return !item.person.isArchived;
          case PeopleFilter.active:
            if (item.person.isArchived) return false;
            return item.balance.abs() > 0.0001;
          case PeopleFilter.settled:
            if (item.person.isArchived) return false;
            return item.balance.abs() <= 0.0001;
          case PeopleFilter.archived:
            return item.person.isArchived;
        }
      }).where((item) {
        // Apply Search Filter (name, phone, notes)
        if (query.isEmpty) return true;
        final nameMatch = item.person.name.toLowerCase().contains(query);
        final phoneMatch = item.person.phone?.toLowerCase().contains(query) ?? false;
        final notesMatch = item.person.notes?.toLowerCase().contains(query) ?? false;
        return nameMatch || phoneMatch || notesMatch;
      }).toList();

      // Apply Sorting
      switch (sort) {
        case PeopleSort.highestOutstanding:
          filtered.sort((a, b) => b.balance.compareTo(a.balance));
          break;
        case PeopleSort.recentlyActive:
          filtered.sort((a, b) {
            final aTime = a.lastTransaction?.transactionDate ?? a.person.createdAt;
            final bTime = b.lastTransaction?.transactionDate ?? b.person.createdAt;
            return bTime.compareTo(aTime);
          });
          break;
        case PeopleSort.alphabetical:
          filtered.sort((a, b) => a.person.name.toLowerCase().compareTo(b.person.name.toLowerCase()));
          break;
        case PeopleSort.recentlyAdded:
          filtered.sort((a, b) => b.person.createdAt.compareTo(a.person.createdAt));
          break;
      }

      return filtered;
    },
    orElse: () => [],
  );
});

// EMI Stream Providers
final activeEmisProvider = StreamProvider<List<CreditCardEmi>>((ref) {
  return ref.watch(emiRepositoryProvider).watchAllEmis(status: 'active');
});

final allEmisProvider = StreamProvider<List<CreditCardEmi>>((ref) {
  return ref.watch(emiRepositoryProvider).watchAllEmis();
});

final personEmisProvider = StreamProvider.family<List<CreditCardEmi>, String>((ref, personId) {
  return ref.watch(emiRepositoryProvider).watchEmisForPerson(personId);
});

// Runs automatically on app start / provider read to post any pending monthly installments
final emiAutoProcessorProvider = FutureProvider<EmiProcessorResult>((ref) async {
  final processor = ref.read(emiProcessorServiceProvider);
  return await processor.processDueInstallments();
});
