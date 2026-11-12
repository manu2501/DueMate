/// Ledger streams: summaries, transactions, people lookup.
library;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:duemate/core/constants/app_constants.dart';
import 'package:duemate/domain/entities/ledger_summary.dart';
import 'package:duemate/domain/entities/ledger_transaction.dart';
import 'package:duemate/domain/entities/person.dart' as domain;
import 'package:duemate/domain/entities/person_summary.dart';
import 'database_providers.dart';

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
  final map = summariesAsync.maybeWhen(
    data: (list) => {for (var s in list) s.person.id: s.person},
    orElse: () => <String, domain.Person>{},
  );
  map[AppConstants.selfPersonId] = domain.Person(
    id: AppConstants.selfPersonId,
    name: AppConstants.selfPersonName,
    createdAt: DateTime(2020),
    updatedAt: DateTime(2020),
  );
  return map;
});
