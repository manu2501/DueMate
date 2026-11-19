import 'package:duemate/data/database/tables.dart';

/// One paid installment of your own EMI or loan. A repayment of money already
/// spent (on the card or the loan), so it never counts as spending or against
/// the budget.
class EmiPayment {
  final String id;
  final String emiId;
  final int installmentNumber;
  final double amount;
  final DateTime paidOn;
  final PaymentMethod paymentMethod;
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;

  const EmiPayment({
    required this.id,
    required this.emiId,
    required this.installmentNumber,
    required this.amount,
    required this.paidOn,
    required this.paymentMethod,
    this.note,
    required this.createdAt,
    required this.updatedAt,
  });
}
