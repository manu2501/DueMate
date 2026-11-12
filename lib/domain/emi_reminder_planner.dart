import 'entities/credit_card_emi.dart';
import 'loan_dues.dart';
import 'reminder.dart';

export 'reminder.dart';

/// Works out which EMI reminders should be scheduled. Pure: the same EMIs and
/// clock always give the same plan, so it's cheap to re-run on every change.
class EmiReminderPlanner {
  EmiReminderPlanner._();

  /// Upcoming installments scheduled per EMI. More than one, so reminders
  /// keep coming even if the app isn't opened (installments post on open).
  static const perEmi = 3;

  /// [whoFor] names the person a shared EMI is with (null for your own).
  /// [amountText] formats an amount, or is null to leave amounts out
  /// (amounts hidden / App Lock on: notifications show on the lock screen).
  static List<Reminder> plan(
    Iterable<CreditCardEmi> emis, {
    required DateTime now,
    String? Function(CreditCardEmi emi)? whoFor,
    String Function(double amount)? amountText,
  }) {
    final out = <Reminder>[];
    for (final emi in emis) {
      if (!emi.isActive) continue;
      final last = (emi.installmentsPaid + perEmi).clamp(0, emi.totalTenureMonths);
      for (var k = emi.installmentsPaid + 1; k <= last; k++) {
        final timing = Reminder.timing(emi.getDueDateForInstallment(k), now);
        if (timing == null) continue; // Already due; it posts when the app opens.
        final who = whoFor?.call(emi);
        out.add(Reminder(
          id: Reminder.stableId('${emi.id}#$k'),
          target: EmiTarget(emi.id),
          at: timing.$1,
          title: '${emi.itemName} due ${timing.$2}',
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
}

/// Reminders for money due back: the day before each "return by" date.
class LoanReminderPlanner {
  LoanReminderPlanner._();

  /// Upcoming dates scheduled per person.
  static const perPerson = 3;

  static List<Reminder> plan(
    Map<String, LoanDueStatus> dues, {
    required DateTime now,
    required String Function(String personId) nameOf,
    String Function(double amount)? amountText,
  }) {
    final out = <Reminder>[];
    for (final MapEntry(key: personId, value: status) in dues.entries) {
      var scheduled = 0;
      for (final due in status.dues) {
        if (scheduled == perPerson) break;
        final timing = Reminder.timing(due.date, now);
        if (timing == null) continue; // Overdue: shown in the app instead.
        final name = nameOf(personId);
        out.add(Reminder(
          id: Reminder.stableId('loan#$personId#${due.date.toIso8601String()}'),
          target: PersonTarget(personId),
          at: timing.$1,
          title: amountText == null
              ? 'Money due back from $name ${timing.$2}'
              : '${amountText(due.amount)} due back from $name ${timing.$2}',
          body: 'Send a reminder or record it when it arrives',
        ));
        scheduled++;
      }
    }
    out.sort((a, b) => a.at.compareTo(b.at));
    return out;
  }
}
