import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:duemate/core/utils/csv_exporter.dart';
import 'package:duemate/core/utils/currency_formatter.dart';
import 'package:duemate/core/utils/reminder_helper.dart';
import 'package:duemate/core/widgets/avatar_widget.dart';
import 'package:duemate/core/widgets/empty_state_widget.dart';
import 'package:duemate/core/widgets/quick_give_sheet.dart';
import 'package:duemate/core/widgets/quick_receive_sheet.dart';
import 'package:duemate/core/widgets/transaction_tile.dart';
import 'package:duemate/data/providers/app_providers.dart';
import 'package:duemate/features/people/presentation/screens/add_edit_person_screen.dart';
import 'package:duemate/features/transactions/presentation/widgets/transaction_details_dialog.dart';

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
              : '$name will be hidden from the primary active list, but all records remain safe.',
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
    final cs = theme.colorScheme;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete $name?', style: TextStyle(color: cs.error)),
        content: Text(
          'Are you sure you want to permanently delete $name and all associated transactions? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: cs.error, foregroundColor: cs.onError),
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
    final cs = theme.colorScheme;
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
          balanceColor = cs.error;
          balanceLabel = 'Owes you';
        } else if (overpaid) {
          balanceColor = cs.tertiary;
          balanceLabel = 'Overpaid you';
        } else {
          balanceColor = cs.primary;
          balanceLabel = 'All settled';
        }

        // Repaid progress calculation
        final double progress = summary.totalGiven > 0
            ? (summary.totalReceived / summary.totalGiven).clamp(0.0, 1.0)
            : 1.0;
        final int percentRepaid = (progress * 100).toInt();

        return Scaffold(
          appBar: AppBar(
            title: Text(person.name),
            actions: [
              IconButton(
                tooltip: 'Share Reminder',
                icon: const Icon(Icons.share_outlined),
                onPressed: () => ReminderHelper.shareReminder(summary, currencySymbol: currencySymbol),
              ),
              IconButton(
                tooltip: 'Export Statement',
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
                        Icon(Icons.delete_outline, size: 20, color: cs.error),
                        SizedBox(width: 12),
                        Text('Delete Person', style: TextStyle(color: cs.error)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          body: Column(
            children: [
              // Hero Summary Card
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        AvatarWidget(
                          name: person.name,
                          radius: 28,
                          heroTag: 'avatar-${person.id}',
                        ),
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
                                  style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                                ),
                              ],
                              if (person.notes != null && person.notes!.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  person.notes!,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: cs.onSurfaceVariant,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (person.isArchived)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: cs.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Archived',
                              style: theme.textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Balance Display
                    Column(
                      children: [
                        Text(
                          balanceLabel,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
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

                    // Repaid Progress Bar (only if there is a lending history)
                    if (summary.totalGiven > 0) ...[
                      const SizedBox(height: 14),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0.0, end: progress),
                          duration: const Duration(milliseconds: 700),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, _) {
                            return LinearProgressIndicator(
                              value: value,
                              minHeight: 6,
                              backgroundColor: cs.surfaceContainerHigh,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                value >= 1.0 ? cs.primary : cs.secondary,
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$percentRepaid% repaid',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),

                    // Given / Received breakdown
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: cs.surfaceContainer,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Given', style: theme.textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
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
                              color: cs.surfaceContainer,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Received', style: theme.textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
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

                    // Actions Row
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: FilledButton.tonal(
                            onPressed: () => QuickReceiveSheet.show(context, personId: personId),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.south_west_rounded, size: 16, color: cs.primary),
                                const SizedBox(width: 6),
                                const Text('Receive'),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: FilledButton(
                            onPressed: () => QuickGiveSheet.show(context, personId: personId),
                            style: FilledButton.styleFrom(
                              backgroundColor: cs.error,
                              foregroundColor: cs.onError,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.north_east_rounded, size: 16),
                                SizedBox(width: 6),
                                Text('Give'),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Timeline Header
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'History',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                    transactionsAsync.maybeWhen(
                      data: (list) => Text(
                        '${list.length} ${list.length == 1 ? 'entry' : 'entries'}',
                        style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                      ),
                      orElse: () => const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),

              // Transactions List
              Expanded(
                child: transactionsAsync.when(
                  data: (txList) {
                    if (txList.isEmpty) {
                      return EmptyStateWidget(
                        icon: Icons.receipt_long_outlined,
                        title: 'No transactions yet',
                        description: 'Record loans or repayments with ${person.name}.',
                        actionLabel: 'Give Money',
                        onActionPressed: () => QuickGiveSheet.show(context, personId: personId),
                      );
                    }

                    return Container(
                      margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        itemCount: txList.length,
                        separatorBuilder: (ctx, i) => Divider(
                          height: 1,
                          indent: 68,
                          endIndent: 16,
                          color: cs.outlineVariant,
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
