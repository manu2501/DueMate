import '../entities/credit_card_emi.dart';
import '../entities/emi_payment.dart';

abstract class EmiRepository {
  Stream<List<CreditCardEmi>> watchAllEmis({String? status});

  /// Every paid installment of your own EMIs and loans, newest first.
  Stream<List<EmiPayment>> watchAllPayments();
  Stream<List<CreditCardEmi>> watchEmisForPerson(String personId);
  Future<List<CreditCardEmi>> getEmisForPerson(String personId);
  Future<List<CreditCardEmi>> getActiveEmis();
  Future<List<CreditCardEmi>> getAllEmis();
  Future<CreditCardEmi?> getEmiById(String id);
  Future<void> createEmi(CreditCardEmi emi);
  Future<void> updateEmi(CreditCardEmi emi);
  /// Deletes the EMI and every installment it posted (your payments or the
  /// ledger entries), in one transaction.
  Future<void> deleteEmi(String id);
}

