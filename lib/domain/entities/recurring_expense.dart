import 'package:duemate/data/database/tables.dart';

/// An expense that repeats every month on [dayOfMonth] (rent, a
/// subscription). Each month's occurrence becomes an ordinary expense.
class RecurringExpense {
  final String id;
  final String title;
  final double amount;
  final ExpenseCategory category;
  final PaymentMethod paymentMethod;
  final String? notes;
  final int dayOfMonth;
  final DateTime startDate;

  /// The latest occurrence already posted as an expense.
  final DateTime? lastPostedDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  const RecurringExpense({
    required this.id,
    required this.title,
    required this.amount,
    required this.category,
    required this.paymentMethod,
    this.notes,
    required this.dayOfMonth,
    required this.startDate,
    this.lastPostedDate,
    required this.createdAt,
    required this.updatedAt,
  });

  /// This rule's date in a given month; the day is clamped for short months
  /// (the 31st posts on 30 Apr, 28/29 Feb).
  DateTime occurrenceIn(int year, int month) {
    final last = DateTime(year, month + 1, 0).day;
    return DateTime(year, month, dayOfMonth.clamp(1, last));
  }

  /// Occurrences that are due (on or before [now]'s day) but not posted yet,
  /// oldest first. Starts from the last posted month, so it stays cheap.
  List<DateTime> dueDates(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final from = lastPostedDate ?? startDate;
    final out = <DateTime>[];
    var y = from.year, m = from.month;
    while (true) {
      final d = occurrenceIn(y, m);
      if (d.isAfter(today)) break;
      final afterStart = !d.isBefore(DateTime(startDate.year, startDate.month, startDate.day));
      final notPosted = lastPostedDate == null || d.isAfter(lastPostedDate!);
      if (afterStart && notPosted) out.add(d);
      if (++m > 12) {
        m = 1;
        y++;
      }
    }
    return out;
  }

  /// The next occurrence after [now]'s day.
  DateTime nextDate(DateTime now) {
    final thisMonth = occurrenceIn(now.year, now.month);
    final today = DateTime(now.year, now.month, now.day);
    final next = thisMonth.isAfter(today) ? thisMonth : occurrenceIn(now.year, now.month + 1);
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    return next.isBefore(start) ? occurrenceIn(start.year, start.month) : next;
  }

  RecurringExpense copyWith({double? amount, DateTime? lastPostedDate, DateTime? updatedAt}) => RecurringExpense(
        id: id,
        title: title,
        amount: amount ?? this.amount,
        category: category,
        paymentMethod: paymentMethod,
        notes: notes,
        dayOfMonth: dayOfMonth,
        startDate: startDate,
        lastPostedDate: lastPostedDate ?? this.lastPostedDate,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
