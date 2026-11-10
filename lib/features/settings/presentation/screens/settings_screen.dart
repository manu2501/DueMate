import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:smarava/core/constants/app_constants.dart';
import 'package:smarava/core/utils/backup_helper.dart';
import 'package:smarava/core/utils/csv_exporter.dart';
import 'package:smarava/core/widgets/bento_card.dart';
import 'package:smarava/core/widgets/spotlight_background.dart';
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
        backgroundColor: const Color(0xFF18181B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0x28FFFFFF)),
        ),
        title: const Text('Initialize Demo Vault?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
          'This will populate your local ledger with real-world sample entries (Rahul, Suresh, Kiran) including loans, multiple partial repayments, and settled accounts.',
          style: TextStyle(color: Color(0xFFA1A1AA), height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF71717A))),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: const Color(0xFF09090B),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Load Demo', style: TextStyle(fontWeight: FontWeight.bold)),
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
        note: 'Festival shopping',
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
        const SnackBar(
          backgroundColor: Color(0xFF10B981),
          content: Text('Demo ledger entries populated successfully!', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      );
    }
  }

  Future<void> _clearAllData(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF18181B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0x35EF4444)),
        ),
        title: const Text('Erase All Vault Data?', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold)),
        content: const Text(
          'This action is irreversible. All people, loans, ad-hoc repayments, and statements will be permanently deleted from this device.',
          style: TextStyle(color: Color(0xFFA1A1AA), height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF71717A))),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Permanently Delete', style: TextStyle(fontWeight: FontWeight.bold)),
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
        const SnackBar(content: Text('Vault wiped clean.')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentCurrency = ref.watch(currencySymbolProvider);
    final currentThemeMode = ref.watch(themeModeProvider);
    final allTxsAsync = ref.watch(allTransactionsProvider);
    final personsMap = ref.watch(personsMapProvider);
    final db = ref.watch(databaseProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Settings & Vault',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
        ),
      ),
      body: SpotlightBackground(
        primaryGlow: const Color(0xFF10B981),
        secondaryGlow: const Color(0xFF6366F1),
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          children: [
            // Aceternity Engine Hero Card
            BentoCard(
              glowColor: const Color(0xFF10B981),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Color(0xFF10B981),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'OFFLINE ENGINE ACTIVE',
                              style: TextStyle(
                                color: Color(0xFF10B981),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      const Icon(Icons.shield_outlined, color: Color(0xFF10B981), size: 18),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'DueMate Local Vault',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Zero cloud dependencies. Transactions and relations persist on your device SQLite engine.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF71717A), height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Section Label
            _sectionLabel('PREFERENCES'),

            // Currency Bento Card
            BentoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.currency_exchange_rounded, size: 18, color: Color(0xFF10B981)),
                      const SizedBox(width: 8),
                      Text(
                        'Currency Denomination',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        currentCurrency,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF10B981),
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
                      return InkWell(
                        onTap: () => ref.read(currencySymbolProvider.notifier).setCurrency(c.symbol),
                        borderRadius: BorderRadius.circular(12),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF10B981).withValues(alpha: 0.2)
                                : isDark
                                    ? const Color(0xFF27272A).withValues(alpha: 0.5)
                                    : const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF10B981)
                                  : isDark
                                      ? const Color(0x18FFFFFF)
                                      : const Color(0xFFCBD5E1),
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                c.symbol,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: isSelected
                                      ? const Color(0xFF10B981)
                                      : isDark
                                          ? Colors.white
                                          : Colors.black87,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                c.code,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isSelected
                                      ? (isDark ? Colors.white : Colors.black87)
                                      : const Color(0xFF71717A),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Theme Mode Bento Card
            BentoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.palette_outlined, size: 18, color: Color(0xFF6366F1)),
                      const SizedBox(width: 8),
                      Text(
                        'Appearance & Theme',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _themePill('System', ThemeMode.system, currentThemeMode, Icons.brightness_auto_rounded, ref),
                      const SizedBox(width: 8),
                      _themePill('Obsidian', ThemeMode.dark, currentThemeMode, Icons.dark_mode_rounded, ref),
                      const SizedBox(width: 8),
                      _themePill('Light', ThemeMode.light, currentThemeMode, Icons.light_mode_rounded, ref),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Section Label
            _sectionLabel('VAULT BACKUP & DATA'),

            // Data Export & Backup Bento Grid
            Row(
              children: [
                Expanded(
                  child: BentoCard(
                    padding: const EdgeInsets.all(16),
                    onTap: () {
                      final txs = allTxsAsync.value ?? [];
                      CsvExporter.exportAndShareAllTransactions(
                        transactions: txs,
                        personsMap: personsMap,
                        currencySymbol: currentCurrency,
                      );
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.table_view_rounded, color: Color(0xFF10B981), size: 20),
                        ),
                        const SizedBox(height: 12),
                        const Text('Export CSV', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 2),
                        const Text('Spreadsheet format', style: TextStyle(fontSize: 11, color: Color(0xFF71717A))),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: BentoCard(
                    padding: const EdgeInsets.all(16),
                    onTap: () => BackupHelper.exportBackup(db),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.folder_zip_outlined, color: Color(0xFF6366F1), size: 20),
                        ),
                        const SizedBox(height: 12),
                        const Text('JSON Backup', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 2),
                        const Text('Full DB snapshot', style: TextStyle(fontSize: 11, color: Color(0xFF71717A))),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Welcome Animation Replay Card
            BentoCard(
              onTap: () => context.push('/welcome'),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEC4899).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.auto_awesome_rounded, color: Color(0xFFEC4899), size: 20),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Welcome Animation', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        Text('Replay kinetic onboarding animation', style: TextStyle(fontSize: 11, color: Color(0xFF71717A))),
                      ],
                    ),
                  ),
                  const Icon(Icons.play_circle_outline_rounded, color: Color(0xFFEC4899)),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Demo Sandbox Card
            BentoCard(
              onTap: () => _loadSampleData(context, ref),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.science_outlined, color: Color(0xFF0284C7), size: 20),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Initialize Demo Sandbox', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        Text('Seed sample loans and ad-hoc repayments', style: TextStyle(fontSize: 11, color: Color(0xFF71717A))),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: Color(0xFF71717A)),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Danger Zone Card
            BentoCard(
              glowColor: const Color(0xFFDC2626),
              onTap: () => _clearAllData(context, ref),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDC2626).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.delete_forever_rounded, color: Color(0xFFDC2626), size: 20),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Purge Local Vault', style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold, fontSize: 14)),
                        Text('Erase all people, loans, and transaction history', style: TextStyle(fontSize: 11, color: Color(0xFF71717A))),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: Color(0xFFDC2626)),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
          color: Color(0xFF71717A),
        ),
      ),
    );
  }

  Widget _themePill(
    String label,
    ThemeMode mode,
    ThemeMode current,
    IconData icon,
    WidgetRef ref,
  ) {
    final isSelected = mode == current;
    return Expanded(
      child: InkWell(
        onTap: () => ref.read(themeModeProvider.notifier).setThemeMode(mode),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF6366F1).withValues(alpha: 0.2)
                : const Color(0xFF27272A).withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? const Color(0xFF6366F1) : const Color(0x18FFFFFF),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, size: 18, color: isSelected ? const Color(0xFF818CF8) : const Color(0xFF71717A)),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : const Color(0xFF71717A),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
