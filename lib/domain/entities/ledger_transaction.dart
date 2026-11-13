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
  final bool isSettled;

  /// For money given: when it should be back (optional).
  final DateTime? dueDate;
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
    this.isSettled = false,
    this.dueDate,
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
    bool? isSettled,
    DateTime? dueDate,
    bool clearDueDate = false,
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
      isSettled: isSettled ?? this.isSettled,
      dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
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

