import 'package:flutter/foundation.dart';
import 'entities/credit_card_emi.dart';

/// One scheduled "EMI due" notification.
@immutable
class EmiReminder {
  /// Stable per EMI + installment, so a re-plan reuses the same ids.
  final int id;

  /// The EMI it's about: tapping the notification opens it.
  final String emiId;
  final DateTime at;
  final String title;
  final String body;

  const EmiReminder({
    required this.id,
    required this.emiId,
    required this.at,
    required this.title,
    required this.body,
  });

  /// Marks notifications as DueMate EMI reminders, so they can be replaced
  /// without touching any other notification, and says which EMI to open.
  static const payloadPrefix = 'emi:';
  String get payload => '$payloadPrefix$emiId';

  /// The EMI id in a notification payload, or null if it isn't a reminder.
  static String? emiIdFromPayload(String? payload) =>
      payload != null && payload.length > payloadPrefix.length && payload.startsWith(payloadPrefix)
          ? payload.substring(payloadPrefix.length)
          : null;

  @override
  bool operator ==(Object other) =>
      other is EmiReminder &&
      other.id == id &&
      other.emiId == emiId &&
      other.at == at &&
      other.title == title &&
      other.body == body;

  @override
  int get hashCode => Object.hash(id, emiId, at, title, body);
}

/// Works out which EMI reminders should be scheduled. Pure: the same EMIs and
/// clock always give the same plan, so it's cheap to re-run on every change.
class EmiReminderPlanner {
  EmiReminderPlanner._();

  /// Upcoming installments scheduled per EMI. More than one, so reminders
  /// keep coming even if the app isn't opened (installments post on open).
  static const perEmi = 3;

  /// Reminders go out at this hour, the day before the due date.
  static const hour = 9;

  /// [whoFor] names the person a shared EMI is with (null for your own).
  /// [amountText] formats an amount, or is null to leave amounts out
  /// (amounts hidden / App Lock on: notifications show on the lock screen).
  static List<EmiReminder> plan(
    Iterable<CreditCardEmi> emis, {
    required DateTime now,
    String? Function(CreditCardEmi emi)? whoFor,
    String Function(double amount)? amountText,
  }) {
    final out = <EmiReminder>[];
    for (final emi in emis) {
      if (!emi.isActive) continue;
      final last = (emi.installmentsPaid + perEmi).clamp(0, emi.totalTenureMonths);
      for (var k = emi.installmentsPaid + 1; k <= last; k++) {
        final due = emi.getDueDateForInstallment(k);
        final dayBefore = DateTime(due.year, due.month, due.day - 1, hour);
        final onTheDay = DateTime(due.year, due.month, due.day, hour);
        final DateTime at;
        final String when;
        if (dayBefore.isAfter(now)) {
          at = dayBefore;
          when = 'due tomorrow';
        } else if (onTheDay.isAfter(now)) {
          at = onTheDay;
          when = 'due today';
        } else {
          continue; // Already due; the installment posts when the app opens.
        }
        final who = whoFor?.call(emi);
        out.add(EmiReminder(
          id: _id(emi.id, k),
          emiId: emi.id,
          at: at,
          title: '${emi.itemName} $when',
          body: [
            if (amountText != null) amountText(emi.getMonthlyInstallmentFor(k)),
            'installment $k of ${emi.totalTenureMonths}',
            emi.cardName,
            if (who != null) 'with $who',
          ].join(' · '),
        ));
      }
    }
    out.sort((a, b) => a.at.compareTo(b.at));
    return out;
  }

  /// 31-bit FNV-1a of "emiId#k": stable across runs (String.hashCode isn't
  /// guaranteed to be) and a valid Android notification id.
  static int _id(String emiId, int k) {
    var h = 0x811c9dc5;
    for (final c in '$emiId#$k'.codeUnits) {
      h = ((h ^ c) * 0x01000193) & 0xffffffff;
    }
    return h & 0x7fffffff;
  }
}
