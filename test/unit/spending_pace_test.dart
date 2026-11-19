import 'package:flutter_test/flutter_test.dart';
import 'package:duemate/data/database/tables.dart';
import 'package:duemate/domain/entities/personal_expense.dart';
import 'package:duemate/domain/spending_pace.dart';

PersonalExpense _x(double amount, DateTime date) => PersonalExpense(
      id: '$amount$date',
      title: 'x',
      amount: amount,
      category: ExpenseCategory.food,
      expenseDate: date,
      paymentMethod: PaymentMethod.upi,
      createdAt: date,
      updatedAt: date,
    );

void main() {
  test('compares this month so far with last month by the same day', () {
    final pace = SpendingPace.of([
      _x(500, DateTime(2026, 11, 1)),
      _x(700, DateTime(2026, 11, 18, 21)), // later today counts
      _x(9999, DateTime(2026, 11, 19)), // dated ahead: not yet
      _x(300, DateTime(2026, 10, 2)),
      _x(400, DateTime(2026, 10, 18, 23, 59)),
      _x(8000, DateTime(2026, 10, 19)), // after the same day last month
      _x(1000, DateTime(2026, 9, 30)), // two months ago
    ], DateTime(2026, 11, 18, 10));

    expect(pace.thisMonth, 1200);
    expect(pace.lastMonth, 700);
    expect(pace.difference, 500);
    expect(pace.hasComparison, isTrue);
    expect(pace.wholeLastMonth, isFalse);
    expect(pace.lastMonthStart, DateTime(2026, 10));
  });

  test('on the last day of a month, compares with all of last month', () {
    final pace = SpendingPace.of([
      _x(100, DateTime(2026, 3, 31)),
      _x(200, DateTime(2026, 4, 30)),
    ], DateTime(2026, 4, 30));
    expect(pace.lastMonth, 100);
    expect(pace.wholeLastMonth, isTrue);
  });

  test('when last month is shorter, its last day is the limit', () {
    final pace = SpendingPace.of([_x(100, DateTime(2026, 2, 28))], DateTime(2026, 3, 30));
    expect(pace.lastMonth, 100);
    expect(pace.wholeLastMonth, isTrue);
  });

  test('January compares with December of the year before', () {
    final pace = SpendingPace.of([_x(250, DateTime(2025, 12, 3))], DateTime(2026, 1, 5));
    expect(pace.lastMonth, 250);
    expect(pace.lastMonthStart, DateTime(2025, 12));
  });

  test('no comparison when last month had nothing by this day', () {
    final pace = SpendingPace.of([_x(100, DateTime(2026, 11, 2))], DateTime(2026, 11, 18));
    expect(pace.hasComparison, isFalse);
  });
}
