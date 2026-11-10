import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smarava/core/constants/app_constants.dart';
import 'package:smarava/domain/entities/ledger_summary.dart';
import 'package:smarava/domain/entities/ledger_transaction.dart';
import 'package:smarava/domain/entities/person.dart' as domain;
import 'package:smarava/domain/entities/person_summary.dart';
import 'package:smarava/domain/repositories/person_repository.dart';
import 'package:smarava/domain/repositories/transaction_repository.dart';
import 'package:smarava/data/database/app_database.dart';
import 'package:smarava/data/repositories/person_repository_impl.dart';
import 'package:smarava/data/repositories/transaction_repository_impl.dart';

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

// People Screen Filter & Sort Enums
enum PeopleFilter { active, settled, archived, all }
enum PeopleSort { highestOutstanding, recentlyActive, alphabetical, recentlyAdded }

class PeopleFilterNotifier extends Notifier<PeopleFilter> {
  @override
  PeopleFilter build() => PeopleFilter.active;

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
          case PeopleFilter.active:
            if (item.person.isArchived) return false;
            return !item.isSettled;
          case PeopleFilter.settled:
            if (item.person.isArchived) return false;
            return item.isSettled;
          case PeopleFilter.archived:
            return item.person.isArchived;
          case PeopleFilter.all:
            return true;
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
