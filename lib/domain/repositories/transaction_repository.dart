import '../entities/ledger_summary.dart';
import '../entities/ledger_transaction.dart';
import '../entities/person_summary.dart';

abstract class TransactionRepository {
  Stream<List<LedgerTransaction>> watchAllTransactions({int? limit});
  Stream<List<LedgerTransaction>> watchTransactionsForPerson(String personId);
  Future<List<LedgerTransaction>> getTransactionsForPerson(String personId);
  Future<LedgerTransaction?> getTransactionById(String id);
  Future<void> addTransaction(LedgerTransaction transaction);
  Future<void> updateTransaction(LedgerTransaction transaction);
  Future<void> deleteTransaction(String id);

  Stream<LedgerSummary> watchLedgerSummary();
  Stream<List<PersonSummary>> watchPersonSummaries({bool includeArchived = false});
  Stream<PersonSummary?> watchPersonSummary(String personId);
}

