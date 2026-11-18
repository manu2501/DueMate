import 'entities/personal_expense.dart';

/// This month's spending so far next to last month's by the same day, so
/// the comparison is fair early in the month.
class SpendingPace {
  /// Spent from the 1st of this month to the end of today.
  final double thisMonth;

  /// Spent from the 1st of last month to the end of the same day (the last
  /// day of last month when today is the last day of this one, or when last
  /// month is shorter).
  final double lastMonth;

  /// The 1st of last month, for its name.
  final DateTime lastMonthStart;

  /// True when [lastMonth] covers the whole of last month.
  final bool wholeLastMonth;

  const SpendingPace({
    required this.thisMonth,
    required this.lastMonth,
    required this.lastMonthStart,
    required this.wholeLastMonth,
  });

  /// Positive when more was spent this month.
  double get difference => thisMonth - lastMonth;

  /// Nothing to compare when last month had nothing by this day.
  bool get hasComparison => lastMonth > 0;

  static SpendingPace of(Iterable<PersonalExpense> expenses, DateTime now) {
    final thisStart = DateTime(now.year, now.month);
    final thisEnd = DateTime(now.year, now.month, now.day + 1);
    final lastStart = DateTime(now.year, now.month - 1);
    final lastDays = DateTime(now.year, now.month, 0).day;
    final isLastDay = now.day == DateTime(now.year, now.month + 1, 0).day;
    final lastDay = isLastDay || now.day >= lastDays ? lastDays : now.day;
    final lastEnd = DateTime(lastStart.year, lastStart.month, lastDay + 1);

    var thisMonth = 0.0, lastMonth = 0.0;
    for (final e in expenses) {
      final d = e.expenseDate;
      if (d.isBefore(lastStart) || !d.isBefore(thisEnd)) continue;
      if (!d.isBefore(thisStart)) {
        thisMonth += e.amount;
      } else if (d.isBefore(lastEnd)) {
        lastMonth += e.amount;
      }
    }
    return SpendingPace(
      thisMonth: thisMonth,
      lastMonth: lastMonth,
      lastMonthStart: lastStart,
      wholeLastMonth: lastDay == lastDays,
    );
  }
}
