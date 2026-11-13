import 'package:duemate/data/database/tables.dart';

class PersonalExpense {
  final String id;
  final String title;
  final double amount;
  final ExpenseCategory category;
  final DateTime expenseDate;
  final PaymentMethod paymentMethod;
  final String? notes;

  /// The recurring rule that posted it, if any.
  final String? recurringId;

  /// Your own EMI or loan that posted it, and the installment number.
  final String? emiId;
  final int? installmentNumber;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PersonalExpense({
    required this.id,
    required this.title,
    required this.amount,
    required this.category,
    required this.expenseDate,
    required this.paymentMethod,
    this.notes,
    this.recurringId,
    this.emiId,
    this.installmentNumber,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isEmi => emiId != null;

  PersonalExpense copyWith({
    String? id,
    String? title,
    double? amount,
    ExpenseCategory? category,
    DateTime? expenseDate,
    PaymentMethod? paymentMethod,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PersonalExpense(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      expenseDate: expenseDate ?? this.expenseDate,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      notes: notes ?? this.notes,
      recurringId: recurringId,
      emiId: emiId,
      installmentNumber: installmentNumber,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
