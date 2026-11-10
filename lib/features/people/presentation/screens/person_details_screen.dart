import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smarava/core/utils/csv_exporter.dart';
import 'package:smarava/core/utils/currency_formatter.dart';
import 'package:smarava/core/utils/reminder_helper.dart';
import 'package:smarava/core/widgets/avatar_widget.dart';
import 'package:smarava/core/widgets/empty_state_widget.dart';
import 'package:smarava/core/widgets/quick_give_sheet.dart';
import 'package:smarava/core/widgets/quick_receive_sheet.dart';
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
        title: Text(isArchived ? 'Unarchive $name?' : 'Archive $name?'),
        content: Text(
          isArchived
              ? '$name will be restored to your active list.'
              : '$name will be hidden from the primary active list, but all transaction history and balance are preserved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
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
            child: Text(isArchived ? 'Unarchive' : 'Archive'),
          ),
        ],
      ),
    );
  }

  void _confirmDeletePerson(BuildContext context, WidgetRef ref, String name) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete $name?', style: TextStyle(color: colorScheme.error)),
        content: Text(
          'Are you sure you want to delete $name and ALL their transaction records? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: colorScheme.error, foregroundColor: colorScheme.onError),
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
    final colorScheme = theme.colorScheme;
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
          balanceColor = colorScheme.error;
          balanceLabel = 'Owes you';
        } else if (overpaid) {
          balanceColor = colorScheme.tertiary;
          balanceLabel = 'Overpaid you';
        } else {
          balanceColor = colorScheme.primary;
          balanceLabel = 'Settled';
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(person.name),
            actions: [
              IconButton(
                tooltip: 'Send Balance Reminder',
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
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, size: 20, color: colorScheme.error),
                        const SizedBox(width: 12),
                        Text('Delete Person', style: TextStyle(color: colorScheme.error)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          body: Column(
            children: [
              // Person Hero Card
              Card(
                elevation: 0,
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: colorScheme.surfaceContainerLow,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          AvatarWidget(name: person.name, radius: 26),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  person.name,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (person.phone != null && person.phone!.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    person.phone!,
                                    style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                                  ),
                                ],
                                if (person.notes != null && person.notes!.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    person.notes!,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontStyle: FontStyle.italic,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (person.isArchived)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Archived',
                                style: theme.textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Divider(height: 1, color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
                      const SizedBox(height: 16),

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
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                                color: balanceColor,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            CurrencyFormatter.format(balance.abs(), symbol: currencySymbol),
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                              color: balanceColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Total Given & Total Received Summary Row
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                children: [
                                  Text('Total Given', style: theme.textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant)),
                                  const SizedBox(height: 2),
                                  Text(
                                    CurrencyFormatter.format(summary.totalGiven, symbol: currencySymbol),
                                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
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
                                color: colorScheme.surfaceContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                children: [
                                  Text('Total Received', style: theme.textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant)),
                                  const SizedBox(height: 2),
                                  Text(
                                    CurrencyFormatter.format(summary.totalReceived, symbol: currencySymbol),
                                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
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
                          Expanded(
                            flex: 3,
                            child: FilledButton.tonalIcon(
                              onPressed: () => QuickReceiveSheet.show(context, personId: personId),
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: const Icon(Icons.arrow_downward_rounded, size: 18),
                              label: const Text(
                                'Receive',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: FilledButton.icon(
                              onPressed: () => QuickGiveSheet.show(context, personId: personId),
                              style: FilledButton.styleFrom(
                                backgroundColor: colorScheme.error,
                                foregroundColor: colorScheme.onError,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: const Icon(Icons.arrow_upward_rounded, size: 18),
                              label: const Text(
                                'Give',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Transaction Timeline Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: Row(
                  children: [
                    Text(
                      'Audit Timeline',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const Spacer(),
                    transactionsAsync.maybeWhen(
                      data: (list) => Text(
                        '${list.length} entries',
                        style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
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

                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      color: colorScheme.surfaceContainerLow,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
                      ),
                      child: ListView.separated(
                        padding: const EdgeInsets.only(bottom: 24),
                        itemCount: txList.length,
                        separatorBuilder: (ctx, i) => Divider(
                          height: 1,
                          indent: 72,
                          endIndent: 16,
                          color: colorScheme.outlineVariant.withValues(alpha: 0.3),
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
        );
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, _) => Scaffold(body: Center(child: Text('Error: $err'))),
    );
  }
}
