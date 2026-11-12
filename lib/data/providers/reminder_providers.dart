/// EMI due reminders, kept in step with the data.
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

final emiReminderSchedulerProvider = Provider<EmiReminderScheduler>((ref) => NotificationService());

/// What should be scheduled right now. Re-plans whenever EMIs change
/// (create, edit, delete, an installment posting, restore, erase), names
/// change, or amounts become hidden. Planning is cheap and the scheduler
/// skips unchanged plans, so frequent re-plans cost almost nothing.
final emiReminderPlanProvider = Provider<List<EmiReminder>?>((ref) {
  final emis = ref.watch(activeEmisProvider).asData?.value;
  if (emis == null) return null; // Not loaded yet: leave reminders alone.
  final people = ref.watch(personsMapProvider);
  final symbol = ref.watch(currencySymbolProvider);
  // Notifications can show on the lock screen: no amounts while they're
  // hidden in the app or App Lock is on.
  final private = ref.watch(hideBalancesProvider) || ref.watch(appLockSettingsProvider.select((s) => s.enabled));
  return EmiReminderPlanner.plan(
    emis,
    now: DateTime.now(),
    whoFor: (e) => e.personId == AppConstants.selfPersonId ? null : people[e.personId]?.name,
    amountText: private ? null : (a) => CurrencyFormatter.format(a, symbol: symbol),
  );
});

/// Listened to once by the app root: pushes each new plan to the scheduler.
final emiReminderSyncProvider = Provider<void>((ref) {
  ref.listen(emiReminderPlanProvider, (_, plan) {
    if (plan != null) ref.read(emiReminderSchedulerProvider).replaceEmiReminders(plan);
  }, fireImmediately: true);
});

/// EMI ids from tapped reminders while the app runs (overridable in tests).
final emiReminderTapsProvider = Provider<Stream<String>>((ref) => NotificationService().emiReminderTaps);

/// The EMI id of the reminder that launched the app, if any.
final emiReminderLaunchProvider =
    Provider<Future<String?> Function()>((ref) => NotificationService().emiReminderThatLaunchedApp);
