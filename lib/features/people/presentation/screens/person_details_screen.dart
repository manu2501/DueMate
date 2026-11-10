import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smarava/core/utils/csv_exporter.dart';
import 'package:smarava/core/utils/currency_formatter.dart';
import 'package:smarava/core/utils/reminder_helper.dart';
import 'package:smarava/core/widgets/avatar_widget.dart';
import 'package:smarava/core/widgets/bento_card.dart';
import 'package:smarava/core/widgets/empty_state_widget.dart';
import 'package:smarava/core/widgets/quick_give_sheet.dart';
import 'package:smarava/core/widgets/quick_receive_sheet.dart';
import 'package:smarava/core/widgets/spotlight_background.dart';
import 'package:smarava/core/widgets/transaction_tile.dart';
import 'package:smarava/data/providers/app_providers.dart';
import 'package:smarava/features/people/presentation/screens/add_edit_person_screen.dart';
import 'package:smarava/features/transactions/presentation/widgets/transaction_details_dialog.dart';

class PersonDetailsScreen extends ConsumerWidget {
  final String personId;

  const PersonDetailsScreen({super.key, required this.personId});

  void _confirmArchive(BuildContext context, WidgetRef ref, bool isArchived, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF18181B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0x28FFFFFF)),
        ),
        title: Text(isArchived ? 'Unarchive $name?' : 'Archive $name?', style: const TextStyle(color: Colors.white)),
        content: Text(
          isArchived
              ? '$name will be restored to your active list.'
              : '$name will be hidden from the primary active list, but all transaction history and balance are preserved.',
          style: const TextStyle(color: Color(0xFFA1A1AA)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF71717A))),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: const Color(0xFF09090B)),
            onPressed: () async {
              Navigator.of(ctx).pop();
              if (isArchived) {
                await ref.read(personRepositoryProvider).unarchivePerson(personId);
              } else {
                await ref.read(personRepositoryProvider).archivePerson(personId);
              }
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(isArchived ? '$name unarchived' : '$name archived')),
                );
              }
            },
            child: Text(isArchived ? 'Unarchive' : 'Archive', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _confirmDeletePerson(BuildContext context, WidgetRef ref, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF18181B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0x35EF4444)),
        ),
        title: Text('Delete $name?', style: const TextStyle(color: Color(0xFFEF4444))),
        content: Text(
          'Are you sure you want to delete $name and ALL their transaction records? This action cannot be undone.',
          style: const TextStyle(color: Color(0xFFA1A1AA), height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF71717A))),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await ref.read(personRepositoryProvider).deletePerson(personId);
              if (context.mounted) {
                context.pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$name deleted')),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currencySymbol = ref.watch(currencySymbolProvider);
    final summaryAsync = ref.watch(personSummaryProvider(personId));
    final transactionsAsync = ref.watch(personTransactionsProvider(personId));

    return summaryAsync.when(
      data: (summary) {
        if (summary == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Person not found')),
          );
        }

        final person = summary.person;
        final balance = summary.balance;
        final owes = summary.owesMoney;
        final overpaid = summary.isOverpaid;

        Color balanceColor;
        String balanceLabel;
        if (owes) {
          balanceColor = const Color(0xFFF43F5E);
          balanceLabel = 'Owes you';
        } else if (overpaid) {
          balanceColor = const Color(0xFF8B5CF6);
          balanceLabel = 'Overpaid you';
        } else {
          balanceColor = const Color(0xFF10B981);
          balanceLabel = 'Settled';
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(person.name, style: const TextStyle(fontWeight: FontWeight.w800)),
            actions: [
              IconButton(
                tooltip: 'Send Balance Reminder (WhatsApp/SMS)',
                icon: const Icon(Icons.share_outlined),
                onPressed: () => ReminderHelper.shareReminder(summary, currencySymbol: currencySymbol),
              ),
              IconButton(
                tooltip: 'Export Statement (CSV)',
                icon: const Icon(Icons.receipt_long_outlined),
                onPressed: () {
                  final txs = transactionsAsync.value ?? [];
                  CsvExporter.exportAndSharePersonStatement(
                    summary: summary,
                    transactions: txs,
                    currencySymbol: currencySymbol,
                  );
                },
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (ctx) => AddEditPersonScreen(personToEdit: person),
                      ),
                    );
                  } else if (value == 'archive') {
                    _confirmArchive(context, ref, person.isArchived, person.name);
                  } else if (value == 'delete') {
                    _confirmDeletePerson(context, ref, person.name);
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 20),
                        SizedBox(width: 12),
                        Text('Edit Details'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'archive',
                    child: Row(
                      children: [
                        Icon(person.isArchived ? Icons.unarchive_outlined : Icons.archive_outlined, size: 20),
                        SizedBox(width: 12),
                        Text(person.isArchived ? 'Unarchive' : 'Archive'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, size: 20, color: Color(0xFFDC2626)),
                        SizedBox(width: 12),
                        Text('Delete Person', style: TextStyle(color: Color(0xFFDC2626))),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          body: SpotlightBackground(
            primaryGlow: balanceColor,
            secondaryGlow: const Color(0xFF6366F1),
            child: Column(
              children: [
                // Person Hero Bento Card
                BentoCard(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  glowColor: balanceColor,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          AvatarWidget(name: person.name, radius: 28),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  person.name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 18,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                                if (person.phone != null && person.phone!.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    person.phone!,
                                    style: const TextStyle(fontSize: 12, color: Color(0xFF71717A)),
                                  ),
                                ],
                                if (person.notes != null && person.notes!.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    person.notes!,
                                    style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Color(0xFF71717A)),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (person.isArchived)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF27272A),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text('Archived', style: TextStyle(fontSize: 11, color: Color(0xFFA1A1AA))),
                            ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Divider(height: 1, color: isDark ? const Color(0x18FFFFFF) : const Color(0xFFE2E8F0)),
                      const SizedBox(height: 18),

                      // Balance Display
                      Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: balanceColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              balanceLabel.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.1,
                                color: balanceColor,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            CurrencyFormatter.format(balance.abs(), symbol: currencySymbol),
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 34,
                              letterSpacing: -0.5,
                              color: balanceColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Total Given & Total Received Summary Row
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF27272A).withValues(alpha: 0.4) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                children: [
                                  const Text('Total Given', style: TextStyle(fontSize: 11, color: Color(0xFF71717A))),
                                  const SizedBox(height: 2),
                                  Text(
                                    CurrencyFormatter.format(summary.totalGiven, symbol: currencySymbol),
                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF27272A).withValues(alpha: 0.4) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                children: [
                                  const Text('Total Received', style: TextStyle(fontSize: 11, color: Color(0xFF71717A))),
                                  const SizedBox(height: 2),
                                  Text(
                                    CurrencyFormatter.format(summary.totalReceived, symbol: currencySymbol),
                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Primary Action Buttons
                      Row(
                        children: [
                          // Receive Payment Button
                          Expanded(
                            flex: 3,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.25),
                                    blurRadius: 14,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: FilledButton.icon(
                                onPressed: () => QuickReceiveSheet.show(context, personId: personId),
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF10B981),
                                  foregroundColor: const Color(0xFF09090B),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                icon: const Icon(Icons.arrow_downward_rounded, size: 20),
                                label: const Text(
                                  'Quick Receive',
                                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Give Money Button
                          Expanded(
                            flex: 2,
                            child: OutlinedButton.icon(
                              onPressed: () => QuickGiveSheet.show(context, personId: personId),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFF43F5E),
                                side: const BorderSide(color: Color(0xFFF43F5E)),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              icon: const Icon(Icons.arrow_outward_rounded, size: 18),
                              label: const Text(
                                '+ Give',
                                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Transaction Timeline Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Row(
                    children: [
                      const Text(
                        'Audit Timeline',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: -0.2),
                      ),
                      const Spacer(),
                      transactionsAsync.maybeWhen(
                        data: (list) => Text(
                          '${list.length} entries',
                          style: const TextStyle(color: Color(0xFF71717A), fontSize: 12),
                        ),
                        orElse: () => const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),

                // Transactions Timeline List
                Expanded(
                  child: transactionsAsync.when(
                    data: (txList) {
                      if (txList.isEmpty) {
                        return EmptyStateWidget(
                          icon: Icons.receipt_long_outlined,
                          title: 'No transactions yet',
                          description: 'Record money given to ${person.name} or repayment received.',
                          actionLabel: 'Give Money',
                          onActionPressed: () => QuickGiveSheet.show(context, personId: personId),
                        );
                      }

                      return BentoCard(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        padding: EdgeInsets.zero,
                        child: ListView.separated(
                          padding: const EdgeInsets.only(bottom: 24),
                          itemCount: txList.length,
                          separatorBuilder: (ctx, i) => Divider(
                            height: 1,
                            indent: 72,
                            endIndent: 20,
                            color: isDark ? const Color(0x18FFFFFF) : const Color(0xFFE2E8F0),
                          ),
                          itemBuilder: (ctx, index) {
                            final tx = txList[index];
                            return TransactionTile(
                              transaction: tx,
                              currencySymbol: currencySymbol,
                              onTap: () {
                                TransactionDetailsDialog.show(
                                  context,
                                  transaction: tx,
                                  person: person,
                                );
                              },
                            );
                          },
                        ),
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (err, _) => Center(child: Text('Error: $err')),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, _) => Scaffold(body: Center(child: Text('Error: $err'))),
    );
  }
}
