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

EmiOutlook _of(List<(CreditCardEmi, Set<int>)> emis, DateTime now) =>
    EmiOutlook.of([for (final (e, posted) in emis) EmiInstallments.of(e, posted)], now);

void main() {
  final sep20 = DateTime(2026, 9, 20);

  test("this month's unpaid installment is due; paid ones count as paid this month", () {
    final unpaid = _of([(_emi(), {1, 2})], sep20);
    expect((unpaid.dueThisMonth, unpaid.dueThisMonthCount, unpaid.paidThisMonth), (1000.0, 1, 0.0));
    expect(unpaid.leftToPay, 4000);

    final paid = _of([(_emi(), {1, 2, 3})], sep20);
    expect((paid.dueThisMonth, paid.dueThisMonthCount, paid.paidThisMonth), (0.0, 0, 1000.0));
    expect(paid.leftToPay, 3000);
  });

  test('an earlier month left unpaid is still due; months ahead are not', () {
    final o = _of([(_emi(), {1, 3})], sep20); // #2 (August) skipped
    expect((o.dueThisMonth, o.dueThisMonthCount), (1000.0, 1));
    expect(o.paidThisMonth, 1000);
  });

  test('counts yours and those on your card; not ones the other person pays, nor cancelled ones', () {
    final o = _of([
      (_emi(id: 'mine'), {1, 2}),
      (_emi(id: 'on-my-card', self: false), {1, 2}),
      (_emi(id: 'they-pay', self: false, paidByMe: false), {1, 2}),
      (_emi(id: 'cancelled', status: 'cancelled'), {1, 2}),
    ], sep20);
    expect((o.dueThisMonth, o.dueThisMonthCount, o.leftToPay), (2000.0, 2, 8000.0));
  });

  test('a finished EMI leaves nothing due', () {
    final o = _of([(_emi(), {1, 2, 3, 4, 5, 6})], DateTime(2027, 1, 10));
    expect((o.dueThisMonth, o.leftToPay, o.paidThisMonth), (0.0, 0.0, 0.0));
  });
}
