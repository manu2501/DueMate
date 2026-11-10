import 'package:intl/intl.dart';

class DateFormatter {
  static String formatDate(DateTime dt) {
    return DateFormat('dd MMM yyyy').format(dt);
  }

  static String formatShortDate(DateTime dt) {
    return DateFormat('dd MMM').format(dt);
  }

  static String formatDateTime(DateTime dt) {
    return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
  }

  static String formatTime(DateTime dt) {
    return DateFormat('hh:mm a').format(dt);
  }

  static String formatMonthYear(DateTime dt) {
    return DateFormat('MMMM yyyy').format(dt);
  }

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
      return DateFormat('EEEE').format(date); // e.g. "Monday"
    } else if (date.year == now.year) {
      return DateFormat('dd MMM').format(date); // e.g. "08 Nov"
    } else {
      return DateFormat('dd MMM yyyy').format(date);
    }
  }
}

