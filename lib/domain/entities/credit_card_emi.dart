import 'dart:convert';
import 'package:duemate/core/constants/app_constants.dart';

class CreditCardEmi {
  final String id;
  final String personId;
  final String itemName;
  final String cardName;
  final double totalAmount;
  final double monthlyInstallment;
  final int totalTenureMonths;
  final int installmentsPaid;
  final DateTime startDate;
  final int dueDayOfMonth;
  final bool isPaidByMe;
  final String status; // 'active', 'completed', 'cancelled'
  final double interestRate; // % per annum
  final String interestType; // 'reducing', 'flat'
  final String? customScheduleJson;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastProcessedDate;

  const CreditCardEmi({
    required this.id,
    required this.personId,
    required this.itemName,
    required this.cardName,
    required this.totalAmount,
    required this.monthlyInstallment,
    required this.totalTenureMonths,
    this.installmentsPaid = 0,
    required this.startDate,
    required this.dueDayOfMonth,
    this.isPaidByMe = true,
    this.status = 'active',
    this.interestRate = 0.0,
    this.interestType = 'reducing',
    this.customScheduleJson,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.lastProcessedDate,
  });

  bool get isActive => status == 'active' && installmentsPaid < totalTenureMonths;
  bool get isCompleted => status == 'completed' || installmentsPaid >= totalTenureMonths;
  bool get isCancelled => status == 'cancelled';
  bool get isForSelf => personId == AppConstants.selfPersonId;

  int get remainingInstallments => (totalTenureMonths - installmentsPaid).clamp(0, totalTenureMonths);
  double get paidAmount => (installmentsPaid * monthlyInstallment).clamp(0.0, totalAmount);
  double get remainingAmount => (remainingInstallments * monthlyInstallment).clamp(0.0, totalAmount);
  double get progress => totalTenureMonths > 0 ? (installmentsPaid / totalTenureMonths).clamp(0.0, 1.0) : 1.0;

  /// Returns the specific customized installment figure for month [installmentNumber], or fallback to default
  double getMonthlyInstallmentFor(int installmentNumber) {
    if (customScheduleJson != null && customScheduleJson!.isNotEmpty) {
      try {
        final Map<String, dynamic> parsed = jsonDecode(customScheduleJson!);
        final val = parsed['$installmentNumber'];
        if (val != null) {
          return (val as num).toDouble();
        }
      } catch (_) {}
    }
    return monthlyInstallment;
  }

  /// Calculates the due date for a specific installment number (1-based index)
  DateTime getDueDateForInstallment(int installmentNumber) {
    // Month offset from the start date
    int targetYear = startDate.year;
    int targetMonth = startDate.month + (installmentNumber - 1);

    while (targetMonth > 12) {
      targetYear++;
      targetMonth -= 12;
    }

    // Days in target month
    final daysInMonth = DateTime(targetYear, targetMonth + 1, 0).day;
    final clampedDay = dueDayOfMonth.clamp(1, daysInMonth);

    return DateTime(targetYear, targetMonth, clampedDay);
  }

  /// Next installment due date
  DateTime? get nextDueDate {
    if (isCompleted || isCancelled) return null;
    return getDueDateForInstallment(installmentsPaid + 1);
  }

  CreditCardEmi copyWith({
    String? id,
    String? personId,
    String? itemName,
    String? cardName,
    double? totalAmount,
    double? monthlyInstallment,
    int? totalTenureMonths,
    int? installmentsPaid,
    DateTime? startDate,
    int? dueDayOfMonth,
    bool? isPaidByMe,
    String? status,
    double? interestRate,
    String? interestType,
    String? customScheduleJson,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastProcessedDate,
  }) {
    return CreditCardEmi(
      id: id ?? this.id,
      personId: personId ?? this.personId,
      itemName: itemName ?? this.itemName,
      cardName: cardName ?? this.cardName,
      totalAmount: totalAmount ?? this.totalAmount,
      monthlyInstallment: monthlyInstallment ?? this.monthlyInstallment,
      totalTenureMonths: totalTenureMonths ?? this.totalTenureMonths,
      installmentsPaid: installmentsPaid ?? this.installmentsPaid,
      startDate: startDate ?? this.startDate,
      dueDayOfMonth: dueDayOfMonth ?? this.dueDayOfMonth,
      isPaidByMe: isPaidByMe ?? this.isPaidByMe,
      status: status ?? this.status,
      interestRate: interestRate ?? this.interestRate,
      interestType: interestType ?? this.interestType,
      customScheduleJson: customScheduleJson ?? this.customScheduleJson,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastProcessedDate: lastProcessedDate ?? this.lastProcessedDate,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CreditCardEmi && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
