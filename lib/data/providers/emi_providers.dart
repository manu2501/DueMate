/// EMI streams and the installment processor.
library;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:duemate/core/services/emi_processor_service.dart';
import 'package:duemate/domain/entities/credit_card_emi.dart';
import 'database_providers.dart';

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
