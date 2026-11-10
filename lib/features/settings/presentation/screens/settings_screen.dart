import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smarava/core/constants/app_constants.dart';
import 'package:smarava/core/utils/backup_helper.dart';
import 'package:smarava/core/utils/csv_exporter.dart';
import 'package:smarava/core/utils/permission_manager.dart';
import 'package:smarava/data/providers/app_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _clearAllData(BuildContext context, WidgetRef ref) async {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Erase All Vault Data?', style: TextStyle(color: cs.error)),
        content: const Text(
          'This action is irreversible. All people, loans, repayments, and notes will be permanently deleted from this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: cs.error, foregroundColor: cs.onError),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Permanently Delete'),
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
          content: Text('All data has been cleared from local storage.',
              style: TextStyle(color: cs.onError, fontWeight: FontWeight.bold)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final currentCurrency = ref.watch(currencySymbolProvider);
    final currentThemeMode = ref.watch(themeModeProvider);
    final db = ref.watch(databaseProvider);
    final allTxsAsync = ref.watch(allTransactionsProvider);
    final personsMap = ref.watch(personsMapProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section: Preferences
            _sectionHeader('PREFERENCES', theme),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.currency_exchange_rounded, size: 20, color: cs.primary),
                      const SizedBox(width: 10),
                      Text(
                        'Currency',
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const Spacer(),
                      Text(
                        currentCurrency,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: cs.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: AppConstants.supportedCurrencies.map((c) {
                      final isSelected = currentCurrency == c.symbol;
                      return ChoiceChip(
                        label: Text('${c.symbol} ${c.code}'),
                        selected: isSelected,
                        onSelected: (_) =>
                            ref.read(currencySymbolProvider.notifier).setCurrency(c.symbol),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  Divider(height: 1, color: cs.outlineVariant),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Icon(Icons.palette_outlined, size: 20, color: cs.primary),
                      const SizedBox(width: 10),
                      Text(
                        'Appearance',
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<ThemeMode>(
                      segments: const [
                        ButtonSegment(
                          value: ThemeMode.system,
                          label: Text('System'),
                          icon: Icon(Icons.brightness_auto_rounded, size: 16),
                        ),
                        ButtonSegment(
                          value: ThemeMode.dark,
                          label: Text('Dark'),
                          icon: Icon(Icons.dark_mode_rounded, size: 16),
                        ),
                        ButtonSegment(
                          value: ThemeMode.light,
                          label: Text('Light'),
                          icon: Icon(Icons.light_mode_rounded, size: 16),
                        ),
                      ],
                      selected: {currentThemeMode},
                      onSelectionChanged: (set) =>
                          ref.read(themeModeProvider.notifier).setThemeMode(set.first),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Section: Data & Backup
            _sectionHeader('DATA & EXPORT', theme),
            Container(
              decoration: BoxDecoration(
                color: cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.table_view_rounded, color: cs.primary, size: 20),
                    ),
                    title: Text('Export CSV Statement',
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                    subtitle: Text('Spreadsheet compatible export',
                        style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      final txs = allTxsAsync.value ?? [];
                      CsvExporter.exportAndShareAllTransactions(
                        transactions: txs,
                        personsMap: personsMap,
                        currencySymbol: currentCurrency,
                      );
                    },
                  ),
                  Divider(height: 1, indent: 64, endIndent: 20, color: cs.outlineVariant),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: cs.secondary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.folder_zip_outlined, color: cs.secondary, size: 20),
                    ),
                    title: Text('Full JSON Backup',
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                    subtitle: Text('Complete device database backup',
                        style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => BackupHelper.exportBackup(db),
                  ),
                  Divider(height: 1, indent: 64, endIndent: 20, color: cs.outlineVariant),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: cs.tertiary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.security_rounded, color: cs.tertiary, size: 20),
                    ),
                    title: Text('Permissions',
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                    subtitle: Text('Contacts & storage access',
                        style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => PermissionManager.showPermissionsSheet(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Section: Danger Zone
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
                  'Clear All Vault Data',
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
            const SizedBox(height: 36),
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
