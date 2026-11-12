import 'package:duemate/data/database/tables.dart';

class PersonalExpense {
  final String id;
  final String title;
  final double amount;
  final ExpenseCategory category;
  final DateTime expenseDate;
  final PaymentMethod paymentMethod;
  final String? notes;
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
    required this.createdAt,
    required this.updatedAt,
  });

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
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
