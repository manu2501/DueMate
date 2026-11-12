import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:duemate/core/constants/app_constants.dart';
import 'package:duemate/core/services/notification_service.dart';
import 'package:duemate/core/theme/app_theme.dart';
import 'package:duemate/core/utils/backup_helper.dart';
import 'package:duemate/core/utils/csv_exporter.dart';
import 'package:duemate/core/utils/permission_manager.dart';
import 'package:duemate/core/widgets/app_logo.dart';
import 'package:duemate/core/widgets/confirm_dialog.dart';
import 'package:duemate/core/widgets/ui_kit.dart';
import 'package:duemate/data/providers/app_providers.dart';
import 'package:duemate/features/expenses/presentation/widgets/budget_dialog.dart';

/// Settings, grouped by what you're trying to do. Each row says what it
/// changes; anything destructive is last and asks first.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool? _remindersOn;

  @override
  void initState() {
    super.initState();
    NotificationService().areNotificationsEnabled().then((v) {
      if (mounted) setState(() => _remindersOn = v);
    }).catchError((_) {
      if (mounted) setState(() => _remindersOn = false);
    });
  }

  void _snack(String message) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  Future<void> _setReminders(bool on) async {
    if (on) {
      final granted = await NotificationService().requestPermissions();
      if (!granted) {
        _snack('Notifications are turned off for DueMate in system settings.');
        return;
      }
    }
    await NotificationService().setNotificationsEnabled(on);
    if (mounted) setState(() => _remindersOn = on);
  }

  Future<void> _sendTestReminder() async {
    final ok = await NotificationService().showTestNotification();
    if (mounted) _snack(ok ? 'Test reminder sent. Check your notifications.' : "Couldn't send. Check notification permission.");
  }

  void _pickCurrency(String current) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: RadioGroup<String>(
          groupValue: current,
          onChanged: (symbol) {
            if (symbol != null) ref.read(currencySymbolProvider.notifier).setCurrency(symbol);
            Navigator.of(ctx).pop();
          },
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpace.screenGutter, 0, AppSpace.screenGutter, AppSpace.sm),
                child: Text('Currency', style: Theme.of(ctx).textTheme.titleMedium),
              ),
              for (final c in AppConstants.supportedCurrencies)
                RadioListTile<String>(
                  value: c.symbol,
                  title: Text(c.name),
                  subtitle: Text(c.code),
                  secondary: Text(c.symbol, style: Theme.of(ctx).textTheme.titleMedium),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _exportCsv() async {
    final txs = await ref.read(allTransactionsProvider.future);
    await CsvExporter.exportAndShareAllTransactions(
      transactions: txs,
      personsMap: ref.read(personsMapProvider),
      currencySymbol: ref.read(currencySymbolProvider),
    );
  }

  Future<void> _erase() async {
    final ok = await showConfirmDialog(
      context,
      title: 'Erase all data?',
      message: "Every person, transaction, EMI and expense on this phone will be deleted. "
          "There's no undo. Make a backup first if you might need them.",
      confirmLabel: 'Erase everything',
      destructive: true,
    );
    if (!ok || !mounted) return;
    await ref.read(databaseProvider).eraseAllData();
    _snack('All data erased');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final themeMode = ref.watch(themeModeProvider);
    final symbol = ref.watch(currencySymbolProvider);
    final budget = ref.watch(monthlyBudgetLimitProvider);
    final currency = AppConstants.supportedCurrencies.where((c) => c.symbol == symbol).firstOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpace.xxl),
        children: [
          const SectionHeader('Appearance', padding: EdgeInsets.fromLTRB(AppSpace.screenGutter, AppSpace.sm, AppSpace.sm, AppSpace.sm)),
          GroupCard(
            dividerIndent: AppSpace.screenGutter,
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpace.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Theme', style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500)),
                    const SizedBox(height: AppSpace.md),
                    SegmentedButton<ThemeMode>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(value: ThemeMode.system, label: Text('System'), icon: Icon(Icons.brightness_auto_outlined)),
                        ButtonSegment(value: ThemeMode.light, label: Text('Light'), icon: Icon(Icons.light_mode_outlined)),
                        ButtonSegment(value: ThemeMode.dark, label: Text('Dark'), icon: Icon(Icons.dark_mode_outlined)),
                      ],
                      selected: {themeMode},
                      onSelectionChanged: (s) => ref.read(themeModeProvider.notifier).setThemeMode(s.first),
                    ),
                  ],
                ),
              ),
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: AppSpace.screenGutter),
                title: const Text('Hide amounts'),
                subtitle: const Text('Show dots instead of balances and totals, e.g. in public. Also on Home.'),
                value: ref.watch(hideBalancesProvider),
                onChanged: (v) => ref.read(hideBalancesProvider.notifier).set(v),
              ),
              ListTile(
                title: const Text('Currency'),
                subtitle: Text(currency == null ? symbol : '${currency.name} (${currency.code})'),
                trailing: Text(symbol, style: theme.textTheme.titleMedium),
                onTap: () => _pickCurrency(symbol),
              ),
            ],
          ),

          const SectionHeader('Money'),
          GroupCard(
            dividerIndent: AppSpace.screenGutter,
            children: [
              ListTile(
                title: const Text('Monthly budget'),
                subtitle: const Text('Used on Home and Expenses to show what\'s left'),
                trailing: Text(ref.watch(displayMoneyProvider)(budget), style: theme.textTheme.titleSmall),
                onTap: () => editMonthlyBudget(context, ref),
              ),
            ],
          ),

          const SectionHeader('Security'),
          GroupCard(
            dividerIndent: AppSpace.screenGutter,
            children: [
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: AppSpace.screenGutter),
                title: const Text('App Lock'),
                subtitle: const Text('Require Fingerprint, Face ID or PIN to open DueMate'),
                value: ref.watch(appLockEnabledProvider),
                onChanged: (v) async {
                  final success = await ref.read(appLockEnabledProvider.notifier).toggleAppLock(v);
                  if (!success && mounted && v) {
                    _snack('Authentication failed. App Lock remained unchanged.');
                  }
                },
              ),
            ],
          ),

          const SectionHeader('Reminders'),
          GroupCard(
            dividerIndent: AppSpace.screenGutter,
            children: [
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: AppSpace.screenGutter),
                title: const Text('Notifications'),
                subtitle: const Text('Allow DueMate to send you notifications'),
                value: _remindersOn ?? false,
                onChanged: _remindersOn == null ? null : _setReminders,
              ),
              ListTile(
                enabled: _remindersOn ?? false,
                title: const Text('Send a test notification'),
                subtitle: const Text('Check that notifications reach you'),
                onTap: _sendTestReminder,
              ),
              ListTile(
                title: const Text('App permissions'),
                subtitle: const Text('Contacts and notifications'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => PermissionManager.showPermissionsSheet(context),
              ),
            ],
          ),

          const SectionHeader('Your data'),
          GroupCard(
            dividerIndent: AppSpace.screenGutter,
            children: [
              ListTile(
                title: const Text('Back up everything'),
                subtitle: const Text('Saves one file you can keep in Drive or send to yourself'),
                onTap: () => BackupHelper.exportBackup(ref.read(databaseProvider)),
              ),
              ListTile(
                title: const Text('Export transactions'),
                subtitle: const Text('CSV for Excel or Google Sheets'),
                onTap: _exportCsv,
              ),
              ListTile(
                title: Text('Erase all data', style: TextStyle(color: cs.error)),
                subtitle: const Text('Removes everything from this phone'),
                onTap: _erase,
              ),
            ],
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpace.screenGutter, AppSpace.xxl, AppSpace.screenGutter, 0),
            child: Row(
              children: [
                const AppLogo(size: 40),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${AppConstants.appName} ${AppConstants.appVersionString}', style: theme.textTheme.titleSmall),
                      Text(
                        'Your data stays on this phone. No account, no tracking.',
                        style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
