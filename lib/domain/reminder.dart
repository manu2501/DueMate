import 'package:flutter/foundation.dart';

/// What a tapped reminder opens.
sealed class ReminderTarget {
  const ReminderTarget();

  /// Parses a notification payload; null if it isn't a DueMate reminder.
  static ReminderTarget? parse(String? payload) {
    if (payload == null) return null;
    for (final (prefix, make) in _kinds) {
      if (payload.startsWith(prefix) && payload.length > prefix.length) {
        return make(payload.substring(prefix.length));
      }
    }
    return null;
  }

  static final _kinds = <(String, ReminderTarget Function(String))>[
    (EmiTarget.prefix, EmiTarget.new),
    (PersonTarget.prefix, PersonTarget.new),
  ];

  String get payload;

  @override
  bool operator ==(Object other) => other is ReminderTarget && other.payload == payload;
  @override
  int get hashCode => payload.hashCode;
}

/// An EMI's details.
class EmiTarget extends ReminderTarget {
  static const prefix = 'emi:';
  final String emiId;
  const EmiTarget(this.emiId);
  @override
  String get payload => '$prefix$emiId';
}

/// A person's ledger (money due back from them).
class PersonTarget extends ReminderTarget {
  static const prefix = 'loan:';
  final String personId;
  const PersonTarget(this.personId);
  @override
  String get payload => '$prefix$personId';
}

/// One scheduled DueMate notification.
@immutable
class Reminder {
  /// Stable for the same thing on the same date, so re-plans reuse ids.
  final int id;
  final ReminderTarget target;
  final DateTime at;
  final String title;
  final String body;

  const Reminder({required this.id, required this.target, required this.at, required this.title, required this.body});

  String get payload => target.payload;

  /// Whether a pending notification's payload is one of DueMate's reminders
  /// (so it can be replaced without touching anything else).
  static bool isReminderPayload(String? payload) => ReminderTarget.parse(payload) != null;

  /// 31-bit FNV-1a of [key]: stable across runs (String.hashCode isn't
  /// guaranteed to be) and a valid Android notification id.
  static int stableId(String key) {
    var h = 0x811c9dc5;
    for (final c in key.codeUnits) {
      h = ((h ^ c) * 0x01000193) & 0xffffffff;
    }
    return h & 0x7fffffff;
  }

  /// 9:00 the day before [due], or 9:00 on the day if that's passed; null
  /// once both have passed. Shared by every reminder kind.
  static (DateTime, String)? timing(DateTime due, DateTime now, {int hour = 9}) {
    final dayBefore = DateTime(due.year, due.month, due.day - 1, hour);
    if (dayBefore.isAfter(now)) return (dayBefore, 'tomorrow');
    final onTheDay = DateTime(due.year, due.month, due.day, hour);
    if (onTheDay.isAfter(now)) return (onTheDay, 'today');
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is Reminder &&
      other.id == id &&
      other.target == target &&
      other.at == at &&
      other.title == title &&
      other.body == body;

  @override
  int get hashCode => Object.hash(id, target, at, title, body);
}
