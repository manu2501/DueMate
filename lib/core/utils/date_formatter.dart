import 'package:intl/intl.dart';

class DateFormatter {
  static final _fullDate = DateFormat('dd MMM yyyy');
  static final _shortDate = DateFormat('dd MMM');
  static final _dateTime = DateFormat('dd MMM yyyy, hh:mm a');
  static final _time = DateFormat('hh:mm a');
  static final _monthYear = DateFormat('MMMM yyyy');
  static final _dayOfWeek = DateFormat('EEEE');

  static String formatDate(DateTime dt) => _fullDate.format(dt);

  static String formatShortDate(DateTime dt) => _shortDate.format(dt);

  static String formatDateTime(DateTime dt) => _dateTime.format(dt);

  static String formatTime(DateTime dt) => _time.format(dt);

  static String formatMonthYear(DateTime dt) => _monthYear.format(dt);

  static String formatRelative(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final diff = today.difference(target).inDays;

    if (diff == 0) {
      return 'Today';
    } else if (diff == 1) {
      return 'Yesterday';
    } else if (diff == -1) {
      return 'Tomorrow';
    } else if (diff > 1 && diff < 7) {
      return _dayOfWeek.format(date);
    } else if (date.year == now.year) {
      return _shortDate.format(date);
    } else {
      return _fullDate.format(date);
    }
  }
}
