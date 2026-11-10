import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:smarava/core/constants/app_constants.dart';
import 'package:smarava/core/utils/backup_helper.dart';
import 'package:smarava/core/utils/csv_exporter.dart';
import 'package:smarava/core/utils/permission_manager.dart';
import 'package:smarava/data/database/tables.dart';
import 'package:smarava/data/providers/app_providers.dart';
import 'package:smarava/domain/entities/ledger_transaction.dart';
import 'package:smarava/domain/entities/person.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _loadSampleData(BuildContext context, WidgetRef ref) async {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Initialize Demo Vault?'),
        content: const Text(
          'This will populate your local ledger with real-world sample entries (Rahul, Suresh, Kiran) including loans, multiple partial repayments, and settled accounts.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Load Demo'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final personRepo = ref.read(personRepositoryProvider);
    final txRepo = ref.read(transactionRepositoryProvider);
    final now = DateTime.now();

    // 1. Rahul
    final rahulId = const Uuid().v4();
    await personRepo.createPerson(
      Person(
        id: rahulId,
        name: 'Rahul Kumar',
        phone: '+91 98765 43210',
        notes: 'Office colleague',
        createdAt: now.subtract(const Duration(days: 30)),
        updatedAt: now,
      ),
    );

    await txRepo.addTransaction(
      LedgerTransaction(
        id: const Uuid().v4(),
        personId: rahulId,
        type: TransactionType.moneyGiven,
        amount: 10000,
        transactionDate: now.subtract(const Duration(days: 15)),
        paymentMethod: PaymentMethod.bankTransfer,
        note: 'Emergency loan',
        createdAt: now.subtract(const Duration(days: 15)),
        updatedAt: now.subtract(const Duration(days: 15)),
      ),
    );
    await txRepo.addTransaction(
      LedgerTransaction(
        id: const Uuid().v4(),
        personId: rahulId,
        type: TransactionType.moneyGiven,
        amount: 5000,
        transactionDate: now.subtract(const Duration(days: 10)),
        paymentMethod: PaymentMethod.upi,
        note: 'Additional advance',
        createdAt: now.subtract(const Duration(days: 10)),
        updatedAt: now.subtract(const Duration(days: 10)),
      ),
    );
    await txRepo.addTransaction(
      LedgerTransaction(
        id: const Uuid().v4(),
        personId: rahulId,
        type: TransactionType.moneyGiven,
        amount: 2000,
        transactionDate: now.subtract(const Duration(days: 7)),
        paymentMethod: PaymentMethod.upi,
        note: 'Fuel expense',
        createdAt: now.subtract(const Duration(days: 7)),
        updatedAt: now.subtract(const Duration(days: 7)),
      ),
    );
    await txRepo.addTransaction(
      LedgerTransaction(
        id: const Uuid().v4(),
        personId: rahulId,
        type: TransactionType.paymentReceived,
        amount: 1000,
        transactionDate: now.subtract(const Duration(days: 5)),
        paymentMethod: PaymentMethod.upi,
        note: 'First installment',
        createdAt: now.subtract(const Duration(days: 5)),
        updatedAt: now.subtract(const Duration(days: 5)),
      ),
    );
    await txRepo.addTransaction(
      LedgerTransaction(
        id: const Uuid().v4(),
        personId: rahulId,
        type: TransactionType.paymentReceived,
        amount: 2000,
        transactionDate: now.subtract(const Duration(days: 2)),
        paymentMethod: PaymentMethod.cash,
        note: 'Cash handoff',
        createdAt: now.subtract(const Duration(days: 2)),
        updatedAt: now.subtract(const Duration(days: 2)),
      ),
    );
    await txRepo.addTransaction(
      LedgerTransaction(
        id: const Uuid().v4(),
        personId: rahulId,
        type: TransactionType.paymentReceived,
        amount: 500,
        transactionDate: now,
        paymentMethod: PaymentMethod.upi,
        note: 'Daily repayment',
        createdAt: now,
        updatedAt: now,
      ),
    );

    // 2. Suresh
    final sureshId = const Uuid().v4();
    await personRepo.createPerson(
      Person(
        id: sureshId,
        name: 'Suresh Patel',
        phone: '+91 91234 56789',
        notes: 'Childhood friend',
        createdAt: now.subtract(const Duration(days: 60)),
        updatedAt: now,
      ),
    );

    await txRepo.addTransaction(
      LedgerTransaction(
        id: const Uuid().v4(),
        personId: sureshId,
        type: TransactionType.moneyGiven,
        amount: 50000,
        transactionDate: now.subtract(const Duration(days: 45)),
        paymentMethod: PaymentMethod.bankTransfer,
        note: 'Business inventory purchase',
        createdAt: now.subtract(const Duration(days: 45)),
        updatedAt: now.subtract(const Duration(days: 45)),
      ),
    );
    await txRepo.addTransaction(
      LedgerTransaction(
        id: const Uuid().v4(),
        personId: sureshId,
        type: TransactionType.paymentReceived,
        amount: 10000,
        transactionDate: now.subtract(const Duration(days: 30)),
        paymentMethod: PaymentMethod.bankTransfer,
        note: 'First return',
        createdAt: now.subtract(const Duration(days: 30)),
        updatedAt: now.subtract(const Duration(days: 30)),
      ),
    );
    await txRepo.addTransaction(
      LedgerTransaction(
        id: const Uuid().v4(),
        personId: sureshId,
        type: TransactionType.paymentReceived,
        amount: 15000,
        transactionDate: now.subtract(const Duration(days: 15)),
        paymentMethod: PaymentMethod.upi,
        note: 'Second return',
        createdAt: now.subtract(const Duration(days: 15)),
        updatedAt: now.subtract(const Duration(days: 15)),
      ),
    );

    // 3. Kiran
    final kiranId = const Uuid().v4();
    await personRepo.createPerson(
      Person(
        id: kiranId,
        name: 'Kiran Rao',
        phone: '+91 99887 76655',
        notes: 'Roommate',
        createdAt: now.subtract(const Duration(days: 20)),
        updatedAt: now,
      ),
    );

    await txRepo.addTransaction(
      LedgerTransaction(
        id: const Uuid().v4(),
        personId: kiranId,
        type: TransactionType.moneyGiven,
        amount: 5000,
        transactionDate: now.subtract(const Duration(days: 18)),
        paymentMethod: PaymentMethod.upi,
        note: 'Rent contribution',
        createdAt: now.subtract(const Duration(days: 18)),
        updatedAt: now.subtract(const Duration(days: 18)),
      ),
    );
    await txRepo.addTransaction(
      LedgerTransaction(
        id: const Uuid().v4(),
        personId: kiranId,
        type: TransactionType.paymentReceived,
        amount: 5000,
        transactionDate: now.subtract(const Duration(days: 3)),
        paymentMethod: PaymentMethod.upi,
        note: 'Settled completely',
        createdAt: now.subtract(const Duration(days: 3)),
        updatedAt: now.subtract(const Duration(days: 3)),
      ),
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: colorScheme.primary,
          content: Text('Demo ledger entries populated successfully!', style: TextStyle(color: colorScheme.onPrimary, fontWeight: FontWeight.bold)),
        ),
      );
    }
  }

  Future<void> _clearAllData(BuildContext context, WidgetRef ref) async {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Erase All Vault Data?', style: TextStyle(color: colorScheme.error)),
        content: const Text(
          'This action is irreversible. All people, loans, ad-hoc repayments, and statements will be permanently deleted from this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: colorScheme.error, foregroundColor: colorScheme.onError),
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
          backgroundColor: colorScheme.error,
          content: Text('All data has been wiped from local storage.', style: TextStyle(color: colorScheme.onError, fontWeight: FontWeight.bold)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final currentCurrency = ref.watch(currencySymbolProvider);
    final currentThemeMode = ref.watch(themeModeProvider);
    final db = ref.watch(databaseProvider);
    final allTxsAsync = ref.watch(allTransactionsProvider);
    final personsMap = ref.watch(personsMapProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings & Storage'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Database Engine Status Card
            Card(
              elevation: 0,
              color: colorScheme.surfaceContainerLow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.storage_rounded, color: colorScheme.onPrimaryContainer, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Local Offline Engine', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Text(
                            'SQLite Drift Database • Version 1.0',
                            style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Active',
                        style: TextStyle(
                          color: colorScheme.onPrimaryContainer,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Section: Preferences
            _sectionHeader('PREFERENCES', theme),

            // Currency Card
            Card(
              elevation: 0,
              color: colorScheme.surfaceContainerLow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.currency_exchange_rounded, size: 18, color: colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Currency Denomination',
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const Spacer(),
                        Text(
                          currentCurrency,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: AppConstants.supportedCurrencies.map((c) {
                        final isSelected = currentCurrency == c.symbol;
                        return ChoiceChip(
                          label: Text('${c.symbol} (${c.code})'),
                          selected: isSelected,
                          onSelected: (_) => ref.read(currencySymbolProvider.notifier).setCurrency(c.symbol),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Appearance Theme Card
            Card(
              elevation: 0,
              color: colorScheme.surfaceContainerLow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.palette_outlined, size: 18, color: colorScheme.secondary),
                        const SizedBox(width: 8),
                        Text(
                          'Appearance & Theme',
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<ThemeMode>(
                        segments: const [
                          ButtonSegment(value: ThemeMode.system, label: Text('System'), icon: Icon(Icons.brightness_auto_rounded)),
                          ButtonSegment(value: ThemeMode.dark, label: Text('Dark'), icon: Icon(Icons.dark_mode_rounded)),
                          ButtonSegment(value: ThemeMode.light, label: Text('Light'), icon: Icon(Icons.light_mode_rounded)),
                        ],
                        selected: {currentThemeMode},
                        onSelectionChanged: (set) => ref.read(themeModeProvider.notifier).setThemeMode(set.first),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Section: Vault Backup & Data
            _sectionHeader('BACKUP & EXPORT', theme),

            Row(
              children: [
                Expanded(
                  child: Card(
                    elevation: 0,
                    color: colorScheme.surfaceContainerLow,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        final txs = allTxsAsync.value ?? [];
                        CsvExporter.exportAndShareAllTransactions(
                          transactions: txs,
                          personsMap: personsMap,
                          currencySymbol: currentCurrency,
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(Icons.table_view_rounded, color: colorScheme.onPrimaryContainer, size: 20),
                            ),
                            const SizedBox(height: 12),
                            Text('Export CSV', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 2),
                            Text('Spreadsheet format', style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Card(
                    elevation: 0,
                    color: colorScheme.surfaceContainerLow,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => BackupHelper.exportBackup(db),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: colorScheme.secondaryContainer,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(Icons.folder_zip_outlined, color: colorScheme.onSecondaryContainer, size: 20),
                            ),
                            const SizedBox(height: 12),
                            Text('JSON Backup', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 2),
                            Text('Full database snapshot', style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Section: App Features & Permissions
            _sectionHeader('PERMISSIONS & DEMO', theme),

            Card(
              elevation: 0,
              color: colorScheme.surfaceContainerLow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.security_rounded, color: colorScheme.onPrimaryContainer, size: 20),
                    ),
                    title: Text('App Permissions', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                    subtitle: Text('Manage Contacts & Reminder permissions', style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => PermissionManager.showPermissionsSheet(context),
                  ),
                  Divider(height: 1, indent: 56, color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colorScheme.tertiaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.science_outlined, color: colorScheme.onTertiaryContainer, size: 20),
                    ),
                    title: Text('Load Demo Entries', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                    subtitle: Text('Seed realistic borrowers & repayments', style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _loadSampleData(context, ref),
                  ),
                  Divider(height: 1, indent: 56, color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.auto_awesome_rounded, color: colorScheme.onSecondaryContainer, size: 20),
                    ),
                    title: Text('Welcome Overview', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                    subtitle: Text('Revisit introductory onboarding', style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.push('/welcome'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Section: Danger Zone
            _sectionHeader('DANGER ZONE', theme),

            Card(
              elevation: 0,
              color: colorScheme.errorContainer.withValues(alpha: 0.3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: colorScheme.error.withValues(alpha: 0.3)),
              ),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.delete_forever_rounded, color: colorScheme.onErrorContainer, size: 20),
                ),
                title: Text(
                  'Purge Local Vault',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: colorScheme.error),
                ),
                subtitle: Text(
                  'Permanently erase all ledger entries & contacts',
                  style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
                trailing: Icon(Icons.chevron_right_rounded, color: colorScheme.error),
                onTap: () => _clearAllData(context, ref),
              ),
            ),
            const SizedBox(height: 32),
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
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}
