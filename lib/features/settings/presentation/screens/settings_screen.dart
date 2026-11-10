import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:smarava/core/constants/app_constants.dart';
import 'package:smarava/core/utils/csv_exporter.dart';
import 'package:smarava/data/database/tables.dart';
import 'package:smarava/data/providers/app_providers.dart';
import 'package:smarava/domain/entities/ledger_transaction.dart';
import 'package:smarava/domain/entities/person.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _loadSampleData(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Load Demo Data?'),
        content: const Text(
          'This will add sample people (Rahul, Suresh, Kiran) with loans and ad-hoc repayments so you can explore the ledger, timeline, and reports immediately.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Load Data')),
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
        notes: 'Office friend',
        createdAt: now.subtract(const Duration(days: 30)),
        updatedAt: now,
      ),
    );

    // Rahul transactions: Given 10k + 5k + 2k = 17k. Received 1k + 2k + 500 = 3.5k. Outstanding 13.5k
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
        note: 'Additional amount',
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
        note: 'Fuel expense help',
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
        note: 'Cash payment',
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
        phone: '+91 98123 45678',
        notes: 'Cousin',
        createdAt: now.subtract(const Duration(days: 20)),
        updatedAt: now,
      ),
    );
    await txRepo.addTransaction(
      LedgerTransaction(
        id: const Uuid().v4(),
        personId: sureshId,
        type: TransactionType.moneyGiven,
        amount: 15000,
        transactionDate: now.subtract(const Duration(days: 12)),
        paymentMethod: PaymentMethod.bankTransfer,
        note: 'Festival expense',
        createdAt: now.subtract(const Duration(days: 12)),
        updatedAt: now.subtract(const Duration(days: 12)),
      ),
    );
    await txRepo.addTransaction(
      LedgerTransaction(
        id: const Uuid().v4(),
        personId: sureshId,
        type: TransactionType.paymentReceived,
        amount: 2500,
        transactionDate: now.subtract(const Duration(days: 1)),
        paymentMethod: PaymentMethod.upi,
        note: 'Partial return',
        createdAt: now.subtract(const Duration(days: 1)),
        updatedAt: now.subtract(const Duration(days: 1)),
      ),
    );

    // 3. Kiran (Settled!)
    final kiranId = const Uuid().v4();
    await personRepo.createPerson(
      Person(
        id: kiranId,
        name: 'Kiran Rao',
        phone: '+91 97654 32109',
        notes: 'Roommate',
        createdAt: now.subtract(const Duration(days: 40)),
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
        note: 'Groceries advance',
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
        note: 'Fully settled',
        createdAt: now.subtract(const Duration(days: 3)),
        updatedAt: now.subtract(const Duration(days: 3)),
      ),
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sample demo data loaded successfully!')),
      );
    }
  }

  Future<void> _clearAllData(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete All Data?'),
        content: const Text(
          'This will permanently delete all people and all transactions from this device. Are you sure?',
          style: TextStyle(height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete Everything'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final db = ref.read(databaseProvider);
    await db.transaction(() async {
      await db.delete(db.transactions).go();
      await db.delete(db.persons).go();
    });

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All data cleared.')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final currentCurrency = ref.watch(currencySymbolProvider);
    final currentThemeMode = ref.watch(themeModeProvider);
    final allTxsAsync = ref.watch(allTransactionsProvider);
    final personsMap = ref.watch(personsMapProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // Section: Preferences
          _sectionHeader('PREFERENCES'),
          Card(
            child: Column(
              children: [
                // Currency Picker
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      currentCurrency,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  title: const Text('Currency Symbol'),
                  subtitle: Text('Current: $currentCurrency'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      builder: (ctx) => SafeArea(
                        child: ListView(
                          shrinkWrap: true,
                          children: AppConstants.supportedCurrencies.map((c) {
                            return ListTile(
                              leading: Text(c.symbol, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              title: Text(c.name),
                              subtitle: Text(c.code),
                              trailing: currentCurrency == c.symbol ? const Icon(Icons.check, color: Color(0xFF0D9488)) : null,
                              onTap: () {
                                ref.read(currencySymbolProvider.notifier).setCurrency(c.symbol);
                                Navigator.of(ctx).pop();
                              },
                            );
                          }).toList(),
                        ),
                      ),
                    );
                  },
                ),
                const Divider(height: 1, indent: 56),

                // Theme Mode
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      currentThemeMode == ThemeMode.dark
                          ? Icons.dark_mode_rounded
                          : currentThemeMode == ThemeMode.light
                              ? Icons.light_mode_rounded
                              : Icons.brightness_auto_rounded,
                      size: 20,
                    ),
                  ),
                  title: const Text('Appearance'),
                  subtitle: Text(
                    currentThemeMode == ThemeMode.dark
                        ? 'Dark theme'
                        : currentThemeMode == ThemeMode.light
                            ? 'Light theme'
                            : 'System default',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      builder: (ctx) => SafeArea(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ListTile(
                              leading: const Icon(Icons.brightness_auto_rounded),
                              title: const Text('System Default'),
                              trailing: currentThemeMode == ThemeMode.system ? const Icon(Icons.check, color: Color(0xFF0D9488)) : null,
                              onTap: () {
                                ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.system);
                                Navigator.of(ctx).pop();
                              },
                            ),
                            ListTile(
                              leading: const Icon(Icons.light_mode_rounded),
                              title: const Text('Light Theme'),
                              trailing: currentThemeMode == ThemeMode.light ? const Icon(Icons.check, color: Color(0xFF0D9488)) : null,
                              onTap: () {
                                ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.light);
                                Navigator.of(ctx).pop();
                              },
                            ),
                            ListTile(
                              leading: const Icon(Icons.dark_mode_rounded),
                              title: const Text('Dark Theme'),
                              trailing: currentThemeMode == ThemeMode.dark ? const Icon(Icons.check, color: Color(0xFF0D9488)) : null,
                              onTap: () {
                                ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.dark);
                                Navigator.of(ctx).pop();
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Section: Data & Backup
          _sectionHeader('DATA & BACKUP'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.file_download_outlined, color: Color(0xFF0D9488)),
                  title: const Text('Export All Data (CSV)'),
                  subtitle: const Text('Download full database export for spreadsheets'),
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
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.dataset_outlined, color: Color(0xFF0284C7)),
                  title: const Text('Load Demo Data'),
                  subtitle: const Text('Populate ledger with sample transactions'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _loadSampleData(context, ref),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.delete_forever_outlined, color: Color(0xFFDC2626)),
                  title: const Text('Clear All Data', style: TextStyle(color: Color(0xFFDC2626))),
                  subtitle: const Text('Permanently erase all local records'),
                  onTap: () => _clearAllData(context, ref),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Section: About
          _sectionHeader('ABOUT'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D9488).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.book_outlined, color: Color(0xFF0D9488), size: 24),
                      ),
                      const SizedBox(width: 14),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('DueMate', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Text('Version 1.0.0 • Offline-First', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Mental model: People → Money Given → Money Received → Balance.\n\n'
                    'DueMate is designed to make recording personal loans and repayments faster than remembering them.',
                    style: TextStyle(fontSize: 13, height: 1.4, color: Colors.black87),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.1,
          color: Colors.grey,
        ),
      ),
    );
  }
}
