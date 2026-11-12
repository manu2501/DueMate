import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:duemate/core/constants/app_constants.dart';
import 'package:duemate/data/providers/app_providers.dart';
import 'package:duemate/features/settings/presentation/widgets/data_management_tile.dart';
import 'package:duemate/features/settings/presentation/widgets/notification_settings_tile.dart';
import 'package:duemate/features/settings/presentation/widgets/theme_and_currency_settings.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _clearAllData(BuildContext context, WidgetRef ref) async {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: cs.error),
            const SizedBox(width: 8),
            Text('Erase all data?', style: TextStyle(color: cs.error, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Every person, transaction, EMI and expense on this device will be deleted. There is no backup unless you exported one, and this can\'t be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: cs.error,
              foregroundColor: cs.onError,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Erase everything'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final db = ref.read(databaseProvider);
    await db.delete(db.transactions).go();
    await db.delete(db.persons).go();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: cs.error,
          content: Text(
            'All vault data has been cleared from local storage.',
            style: TextStyle(color: cs.onError, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final currentCurrency = ref.watch(currencySymbolProvider);
    final db = ref.watch(databaseProvider);
    final allTxsAsync = ref.watch(allTransactionsProvider);
    final personsMap = ref.watch(personsMapProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // App Identity Hero Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.asset(
                      'assets/images/app_logo.png',
                      width: 54,
                      height: 54,
                      fit: BoxFit.cover,
                      errorBuilder: (ctx, err, stack) => Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: cs.primaryContainer,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(Icons.account_balance_wallet_rounded, color: cs.primary, size: 28),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppConstants.appName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          AppConstants.appTagline,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: cs.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.shield_outlined, size: 12, color: cs.primary),
                              const SizedBox(width: 4),
                              Text(
                                'Stored on device',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: cs.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Section 1: Appearance
            _sectionHeader('APPEARANCE', theme),
            const ThemeSettingsCard(),
            const SizedBox(height: 24),

            // Section 2: Currency & Regional
            _sectionHeader('CURRENCY & REGIONAL', theme),
            const CurrencySettingsCard(),
            const SizedBox(height: 24),

            // Section 3: Reminders & Notifications
            _sectionHeader('REMINDERS & NOTIFICATIONS', theme),
            Container(
              decoration: BoxDecoration(
                color: cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const NotificationSettingsTile(),
            ),
            const SizedBox(height: 24),

            // Section 4: Data Management
            _sectionHeader('DATA MANAGEMENT', theme),
            DataManagementTile(
              allTransactions: allTxsAsync.value ?? [],
              personsMap: personsMap,
              currentCurrency: currentCurrency,
              db: db,
            ),
            const SizedBox(height: 24),

            // Section 5: Danger Zone
            _sectionHeader('DANGER ZONE', theme),
            Container(
              decoration: BoxDecoration(
                color: cs.errorContainer.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(24),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: cs.errorContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.delete_forever_rounded, color: cs.error, size: 20),
                ),
                title: Text(
                  'Clear all data',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.error,
                  ),
                ),
                subtitle: Text(
                  'Permanently delete records & contacts',
                  style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
                trailing: Icon(Icons.chevron_right_rounded, color: cs.error),
                onTap: () => _clearAllData(context, ref),
              ),
            ),
            const SizedBox(height: 32),

            // Version info footer
            Center(
              child: Column(
                children: [
                  Text(
                    '${AppConstants.appName} ${AppConstants.appVersionString}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Data stays on this device. No analytics.',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: cs.outline,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 1.0,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
