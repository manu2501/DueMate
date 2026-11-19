import 'package:flutter_test/flutter_test.dart';
import 'package:duemate/core/constants/app_constants.dart';
import 'package:duemate/domain/emi_installments.dart';
import 'package:duemate/domain/emi_outlook.dart';
import 'package:duemate/domain/entities/credit_card_emi.dart';

/// 6 × ₹1,000 due on the 5th, first due 5 July 2026.
CreditCardEmi _emi({String id = 'e1', bool self = true, bool paidByMe = true, String status = 'active'}) => CreditCardEmi(
      id: id,
      personId: self ? AppConstants.selfPersonId : 'p1',
      itemName: 'Phone',
      cardName: 'HDFC',
      totalAmount: 6000,
      monthlyInstallment: 1000,
      totalTenureMonths: 6,
      isPaidByMe: paidByMe,
      status: status,
      startDate: DateTime(2026, 7, 5),
      dueDayOfMonth: 5,
      createdAt: DateTime(2026, 7, 1),
      updatedAt: DateTime(2026, 7, 1),
    );

double _due(List<(CreditCardEmi, Set<int>)> emis, DateTime now) =>
    EmiOutlook.of([for (final (e, posted) in emis) EmiInstallments.of(e, posted)], now).dueThisMonth;

void main() {
  final sep20 = DateTime(2026, 9, 20);

  test("this month's unpaid installment is due; once paid, nothing is", () {
    expect(_due([(_emi(), {1, 2})], sep20), 1000);
    expect(_due([(_emi(), {1, 2, 3})], sep20), 0);
  });

  test('an earlier month left unpaid is still due; months ahead are not', () {
    expect(_due([(_emi(), {1})], sep20), 2000); // August and September
    expect(_due([(_emi(), {1, 2, 3, 4})], sep20), 0, reason: 'October was paid ahead');
  });

  test('counts yours and those on your card; not ones the other person pays, nor cancelled ones', () {
    expect(
      _due([
        (_emi(id: 'mine'), {1, 2}),
        (_emi(id: 'on-my-card', self: false), {1, 2}),
        (_emi(id: 'they-pay', self: false, paidByMe: false), {1, 2}),
        (_emi(id: 'cancelled', status: 'cancelled'), {1, 2}),
      ], sep20),
      2000,
    );
  });
}
