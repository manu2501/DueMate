import 'package:flutter_test/flutter_test.dart';
import 'package:duemate/core/constants/app_constants.dart';
import 'package:duemate/domain/emi_installments.dart';
import 'package:duemate/domain/entities/credit_card_emi.dart';

CreditCardEmi _emi({int paid = 0, int tenure = 6, bool self = true, String? custom}) => CreditCardEmi(
      id: 'e1',
      personId: self ? AppConstants.selfPersonId : 'p1',
      itemName: 'Phone',
      cardName: 'HDFC',
      totalAmount: 6000,
      monthlyInstallment: 1000,
      totalTenureMonths: tenure,
      installmentsPaid: paid,
      startDate: DateTime(2026, 7, 5),
      dueDayOfMonth: 5,
      customScheduleJson: custom,
      createdAt: DateTime(2026, 7, 1),
      updatedAt: DateTime(2026, 7, 1),
    );

void main() {
  test('nothing posted yet: the first installmentsPaid count as paid', () {
    final s = EmiInstallments.of(_emi(paid: 3), const {});
    expect(s.paid, {1, 2, 3});
    expect((s.count, s.next, s.nextDueDate), (3, 4, DateTime(2026, 10, 5)));
  });

  test('a gap stays a gap: the next is the earliest unpaid', () {
    final s = EmiInstallments.of(_emi(paid: 3), {1, 3, 4});
    expect(s.paid, {1, 3, 4});
    expect(s.unpaid.toList(), [2, 5, 6]);
    expect(s.next, 2);
    expect(s.paidAmount, 3000);
    expect(s.remainingAmount, 3000);
  });

  test('shared: installments paid before tracking are the earliest unposted ones', () {
    // 4 paid, 2 of them posted (#4, #5): #1 and #2 were paid before tracking.
    final s = EmiInstallments.of(_emi(paid: 4, self: false), {4, 5});
    expect(s.paid, {1, 2, 4, 5});
    expect(s.next, 3);
  });

  test('postings outside the schedule are ignored (tenure shortened)', () {
    final s = EmiInstallments.of(_emi(paid: 2, tenure: 3), {1, 2, 7});
    expect(s.paid, {1, 2});
    expect(s.next, 3);
  });

  test('all paid: complete, no next, nothing left', () {
    final s = EmiInstallments.of(_emi(paid: 6), {1, 2, 3, 4, 5, 6});
    expect((s.isComplete, s.next, s.nextDueDate, s.nextAmount), (true, null, null, 0.0));
    expect((s.remainingAmount, s.progress), (0.0, 1.0));
  });

  test('amounts follow months with a different amount', () {
    final s = EmiInstallments.of(_emi(paid: 1, custom: '{"2": 1500}'), {1});
    expect(s.nextAmount, 1500);
    expect(s.remainingAmount, 5500);
  });
}
