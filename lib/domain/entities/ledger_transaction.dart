import '../../data/database/tables.dart';

class LedgerTransaction {
  final String id;
  final String personId;
  final TransactionType type;
  final double amount;
  final DateTime transactionDate;
  final PaymentMethod paymentMethod;
  final String? note;
  final String? emiId;
  final int? installmentNumber;
  final DateTime createdAt;
  final DateTime updatedAt;

  const LedgerTransaction({
    required this.id,
    required this.personId,
    required this.type,
    required this.amount,
    required this.transactionDate,
    required this.paymentMethod,
    this.note,
    this.emiId,
    this.installmentNumber,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isMoneyGiven => type == TransactionType.moneyGiven;
  bool get isPaymentReceived => type == TransactionType.paymentReceived;
  bool get isEmi => emiId != null;

  LedgerTransaction copyWith({
    String? id,
    String? personId,
    TransactionType? type,
    double? amount,
    DateTime? transactionDate,
    PaymentMethod? paymentMethod,
    String? note,
    String? emiId,
    int? installmentNumber,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return LedgerTransaction(
      id: id ?? this.id,
      personId: personId ?? this.personId,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      transactionDate: transactionDate ?? this.transactionDate,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      note: note ?? this.note,
      emiId: emiId ?? this.emiId,
      installmentNumber: installmentNumber ?? this.installmentNumber,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LedgerTransaction &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

