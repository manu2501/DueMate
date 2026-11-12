/// Reminders (EMIs due, money due back), kept in step with the data.
library;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:duemate/core/constants/app_constants.dart';
import 'package:duemate/core/services/notification_service.dart';
import 'package:duemate/core/utils/currency_formatter.dart';
import 'package:duemate/domain/emi_reminder_planner.dart';
import 'app_lock_provider.dart';
import 'emi_providers.dart';
import 'ledger_providers.dart';
import 'settings_providers.dart';

final reminderSchedulerProvider = Provider<ReminderScheduler>((ref) => NotificationService());

/// What should be scheduled right now. Re-plans whenever EMIs, loans with a
/// "return by" date, names or amount privacy change. Planning is cheap and
/// the scheduler skips unchanged plans, so frequent re-plans cost almost
/// nothing.
final reminderPlanProvider = Provider<List<Reminder>?>((ref) {
  final emis = ref.watch(activeEmisProvider).asData?.value;
  // Not loaded yet: leave scheduled reminders alone rather than clear them.
  if (emis == null || !ref.watch(allTransactionsProvider).hasValue) return null;
  final people = ref.watch(personsMapProvider);
  final symbol = ref.watch(currencySymbolProvider);
  // Notifications can show on the lock screen: no amounts while they're
  // hidden in the app or App Lock is on.
  final private = ref.watch(hideBalancesProvider) || ref.watch(appLockSettingsProvider.select((s) => s.enabled));
  String money(double a) => CurrencyFormatter.format(a, symbol: symbol);
  final now = DateTime.now();
  return [
    ...EmiReminderPlanner.plan(
      emis,
      now: now,
      whoFor: (e) => e.personId == AppConstants.selfPersonId ? null : people[e.personId]?.name,
      amountText: private ? null : money,
    ),
    ...LoanReminderPlanner.plan(
      ref.watch(loanDuesProvider),
      now: now,
      nameOf: (id) => people[id]?.name ?? 'someone',
      amountText: private ? null : money,
    ),
  ]..sort((a, b) => a.at.compareTo(b.at));
});

/// Listened to once by the app root: pushes each new plan to the scheduler.
final reminderSyncProvider = Provider<void>((ref) {
  ref.listen(reminderPlanProvider, (_, plan) {
    if (plan != null) ref.read(reminderSchedulerProvider).replaceReminders(plan);
  }, fireImmediately: true);
});

/// What tapped reminders point at while the app runs (overridable in tests).
final reminderTapsProvider = Provider<Stream<ReminderTarget>>((ref) => NotificationService().reminderTaps);

/// What the reminder that launched the app points at, if any.
final reminderLaunchProvider =
    Provider<Future<ReminderTarget?> Function()>((ref) => NotificationService().reminderThatLaunchedApp);
