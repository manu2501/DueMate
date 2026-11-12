import 'package:flutter_test/flutter_test.dart';
import 'package:duemate/domain/emi_calculator.dart';

void main() {
  group('fromTotal (split a total)', () {
    test('no interest, no charges: plain division', () {
      final p = EmiCalculator.fromTotal(principal: 12000, months: 12);
      expect(p.monthly, 1000);
      expect(p.totalPayable, 12000);
      expect(p.interest, 0);
      expect(p.extraCost, 0);
    });

    test('charges are spread across the installments', () {
      final p = EmiCalculator.fromTotal(principal: 12000, months: 12, charges: 600);
      expect(p.totalPayable, 12600);
      expect(p.monthly, 1050);
      expect(p.chargesInsideEmi, isTrue);
      expect(p.totalCost, 12600); // not double counted
      expect(p.extraCost, 600);
    });

    test('flat interest is on the full amount for the term', () {
      // 12% p.a. flat, 1 year on 10,000 -> 1,200
      final p = EmiCalculator.fromTotal(
          principal: 10000, months: 12, ratePercentPerYear: 12, flat: true);
      expect(p.interest, 1200);
      expect(p.monthly, closeTo(933.33, 0.01));
    });

    test('reducing balance matches the bank EMI formula', () {
      // 1,00,000 at 12% p.a. over 12 months -> EMI 8884.88, interest ~6,619
      final p = EmiCalculator.fromTotal(
          principal: 100000, months: 12, ratePercentPerYear: 12);
      expect(p.interest, closeTo(6619, 1));
      expect(p.monthly, closeTo(8884.88, 1));
    });

    test('invalid inputs give an empty plan', () {
      expect(EmiCalculator.fromTotal(principal: 0, months: 12).isValid, isFalse);
      expect(EmiCalculator.fromTotal(principal: 1000, months: 0).isValid, isFalse);
    });
  });

  group('fromMonthly (EMI typed in)', () {
    test('installments are exactly what was typed', () {
      final p = EmiCalculator.fromMonthly(monthly: 9500, months: 12);
      expect(p.monthly, 9500);
      expect(p.totalPayable, 114000);
      expect(p.extraCost, isNull); // original amount unknown
    });

    test('charges are billed separately and added to total cost only', () {
      final p = EmiCalculator.fromMonthly(
          monthly: 9500, months: 12, principal: 100000, charges: 1000);
      expect(p.totalPayable, 114000); // what the installments add up to
      expect(p.chargesInsideEmi, isFalse);
      expect(p.totalCost, 115000);
      expect(p.extraCost, 15000);
    });

    test('invalid inputs give an empty plan', () {
      expect(EmiCalculator.fromMonthly(monthly: 0, months: 12).isValid, isFalse);
    });
  });

  group('impliedAnnualRate', () {
    test('recovers the rate used to build the EMI', () {
      final plan = EmiCalculator.fromTotal(
          principal: 100000, months: 12, ratePercentPerYear: 12);
      final rate = EmiCalculator.impliedAnnualRate(
          principal: 100000, monthly: plan.monthly, months: 12);
      expect(rate, isNotNull);
      expect(rate!, closeTo(12, 0.2));
    });

    test('null when nothing extra is paid', () {
      expect(
          EmiCalculator.impliedAnnualRate(principal: 12000, monthly: 1000, months: 12),
          isNull);
    });

    test('null when the original amount is unknown', () {
      expect(
          EmiCalculator.impliedAnnualRate(principal: 0, monthly: 1000, months: 12),
          isNull);
    });
  });

  test('GST applies to fee + interest, not principal', () {
    expect(EmiCalculator.gst(feeAndInterest: 1000), 180);
    expect(EmiCalculator.gst(feeAndInterest: 0), 0);
  });
}
