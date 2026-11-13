import '../entities/credit_card_emi.dart';

abstract class EmiRepository {
  Stream<List<CreditCardEmi>> watchAllEmis({String? status});
  Stream<List<CreditCardEmi>> watchEmisForPerson(String personId);
  Future<List<CreditCardEmi>> getEmisForPerson(String personId);
  Future<List<CreditCardEmi>> getActiveEmis();
  Future<List<CreditCardEmi>> getAllEmis();
  Future<CreditCardEmi?> getEmiById(String id);
  Future<void> createEmi(CreditCardEmi emi);
  Future<void> updateEmi(CreditCardEmi emi);
  /// Deletes the EMI and every installment it posted (your expenses or the
  /// ledger entries), in one transaction.
  Future<void> deleteEmi(String id);
}

