/// EMI streams and the installment processor.
library;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:duemate/core/services/emi_processor_service.dart';
import 'package:duemate/domain/entities/credit_card_emi.dart';
import 'package:duemate/domain/emi_installments.dart';
import 'package:duemate/domain/entities/ledger_transaction.dart';
import 'package:duemate/domain/entities/personal_expense.dart';
import 'database_providers.dart';
import 'expense_providers.dart';
import 'ledger_providers.dart';

final emiProcessorServiceProvider = Provider<EmiProcessorService>((ref) {
  return EmiProcessorService(
    emiRepository: ref.watch(emiRepositoryProvider),
    transactionRepository: ref.watch(transactionRepositoryProvider),
    database: ref.watch(databaseProvider),
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

/// Installment numbers posted per EMI id: expenses for your own EMIs, ledger
/// entries for shared ones. Built from streams the app already watches.
final emiPostingsProvider = Provider<Map<String, Set<int>>>((ref) {
  final out = <String, Set<int>>{};
  void add(String? emiId, int? k) {
    if (emiId != null && k != null) out.putIfAbsent(emiId, () => {}).add(k);
  }

  for (final t in ref.watch(allTransactionsProvider).value ?? const <LedgerTransaction>[]) {
    add(t.emiId, t.installmentNumber);
  }
  for (final e in ref.watch(allExpensesProvider).value ?? const <PersonalExpense>[]) {
    add(e.emiId, e.installmentNumber);
  }
  return out;
});

/// Which installments of [emi] are paid. Until postings load, falls back to
/// the first `installmentsPaid` ones.
EmiInstallments watchInstallments(WidgetRef ref, CreditCardEmi emi) =>
    EmiInstallments.of(emi, ref.watch(emiPostingsProvider.select((m) => m[emi.id])) ?? const {});
