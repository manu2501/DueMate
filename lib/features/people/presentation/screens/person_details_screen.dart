import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:duemate/core/utils/csv_exporter.dart';
import 'package:duemate/core/utils/pdf_exporter.dart';
import 'package:duemate/core/utils/reminder_helper.dart';
import 'package:duemate/core/utils/whatsapp_helper.dart';
import 'package:duemate/core/widgets/empty_state_widget.dart';
import 'package:duemate/core/widgets/export_options_sheet.dart';
import 'package:duemate/core/widgets/quick_give_sheet.dart';
import 'package:duemate/core/widgets/transaction_tile.dart';
import 'package:duemate/core/widgets/whatsapp_icon.dart';
import 'package:duemate/data/providers/app_providers.dart';
import 'package:duemate/features/emis/presentation/screens/add_edit_emi_screen.dart';
import 'package:duemate/features/people/presentation/screens/add_edit_person_screen.dart';
import 'package:duemate/features/people/presentation/widgets/person_active_emis_section.dart';
import 'package:duemate/features/people/presentation/widgets/person_header_card.dart';
import 'package:duemate/features/people/presentation/widgets/person_info_sheet.dart';
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

  void _navigateBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.go('/people');
    }
  }

  void _confirmDeletePerson(BuildContext context, WidgetRef ref, String name) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete $name?', style: TextStyle(color: cs.error)),
        content: Text(
          'This permanently deletes $name along with every transaction and EMI recorded with them. This can\'t be undone.\n\nIf you only want them out of your list, archive them instead.',
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
                _navigateBack(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$name and their records were deleted')),
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
    final isDark = theme.brightness == Brightness.dark;
    final currencySymbol = ref.watch(currencySymbolProvider);
    final summaryAsync = ref.watch(personSummaryProvider(personId));
    final transactionsAsync = ref.watch(personTransactionsProvider(personId));
    final emisAsync = ref.watch(personEmisProvider(personId));

    return summaryAsync.when(
      data: (summary) {
        if (summary == null) {
          return PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop) _navigateBack(context);
            },
            child: Scaffold(
              appBar: AppBar(
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () => _navigateBack(context),
                ),
              ),
              body: const Center(child: Text('Person not found')),
            ),
          );
        }

        final person = summary.person;
        final transactions = transactionsAsync.value ?? [];

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _navigateBack(context);
          },
          child: Scaffold(
            appBar: PreferredSize(
              preferredSize: const Size.fromHeight(64),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      // Back button in rounded white box (Screen 2 from screenshot)
                      InkWell(
                        onTap: () => _navigateBack(context),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: cs.outlineVariant),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.arrow_back_rounded,
                            size: 20,
                            color: cs.onSurface,
                          ),
                        ),
                      ),
                    const Spacer(),

                    // Action buttons (WhatsApp + Share reminder + Person Info + Options)
                    IconButton(
                      tooltip: 'WhatsApp Reminder',
                      icon: const WhatsAppIcon(size: 22),
                      onPressed: () {
                        final msg = WhatsAppHelper.generateLedgerReminderMessage(summary, currencySymbol: currencySymbol);
                        WhatsAppHelper.sendWhatsAppMessage(
                          phoneNumber: person.phone,
                          message: msg,
                          context: context,
                        );
                      },
                    ),
                    IconButton(
                      tooltip: 'Person Information',
                      icon: const Icon(Icons.info_outline_rounded),
                      onPressed: () => PersonInfoSheet.show(
                        context,
                        person: person,
                        summary: summary,
                        currencySymbol: currencySymbol,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Share Reminder',
                      icon: const Icon(Icons.share_outlined),
                      onPressed: () => ReminderHelper.shareReminder(summary, currencySymbol: currencySymbol),
                    ),
                    IconButton(
                      tooltip: 'Share Statement',
                      icon: const Icon(Icons.receipt_long_outlined),
                      onPressed: () {
                        ExportOptionsSheet.show(
                          context: context,
                          title: 'Statement for ${person.name}',
                          onSharePdf: () => PdfExporter.exportAndSharePersonStatement(
                            summary: summary,
                            transactions: transactions,
                            currencySymbol: currencySymbol,
                          ),
                          onShareCsv: () => CsvExporter.exportAndSharePersonStatement(
                            summary: summary,
                            transactions: transactions,
                            currencySymbol: currencySymbol,
                          ),
                        );
                      },
                    ),

                    // Help / Options button in rounded white box (Screen 2 from screenshot)
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'pdf') {
                          PdfExporter.exportAndSharePersonStatement(
                            summary: summary,
                            transactions: transactions,
                            currencySymbol: currencySymbol,
                          );
                        } else if (value == 'csv') {
                          CsvExporter.exportAndSharePersonStatement(
                            summary: summary,
                            transactions: transactions,
                            currencySymbol: currencySymbol,
                          );
                        } else if (value == 'edit') {
                          AddEditPersonScreen.show(context, personToEdit: person);
                        } else if (value == 'add_emi') {
                          AddEditEmiScreen.show(context, personId: personId);
                        } else if (value == 'archive') {
                          _confirmArchive(context, ref, person.isArchived, person.name);
                        } else if (value == 'delete') {
                          _confirmDeletePerson(context, ref, person.name);
                        }
                      },
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(
                          value: 'pdf',
                          child: Row(
                            children: [
                              Icon(Icons.picture_as_pdf_outlined, size: 20),
                              SizedBox(width: 12),
                              Text('Share PDF statement'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'csv',
                          child: Row(
                            children: [
                              Icon(Icons.table_chart_outlined, size: 20),
                              SizedBox(width: 12),
                              Text('Export CSV statement'),
                            ],
                          ),
                        ),
                        const PopupMenuDivider(),
                        PopupMenuItem(
                          value: 'add_emi',
                          child: Row(
                            children: [
                              Icon(Icons.event_repeat_rounded, size: 20, color: Theme.of(context).colorScheme.secondary),
                              SizedBox(width: 12),
                              Text('Add EMI or loan'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit_outlined, size: 20),
                              SizedBox(width: 12),
                              Text('Edit details'),
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
                              Text('Delete person', style: TextStyle(color: cs.error)),
                            ],
                          ),
                        ),
                      ],
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: cs.outlineVariant),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.more_vert_rounded,
                          size: 20,
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),

                // Person Header Summary Card
                PersonHeaderCard(
                  person: person,
                  summary: summary,
                  currencySymbol: currencySymbol,
                ),

                const SizedBox(height: 20),

                // Credit Card EMIs section
                emisAsync.when(
                  data: (emis) => PersonActiveEmisSection(
                    personId: personId,
                    person: person,
                    emis: emis,
                    currencySymbol: currencySymbol,
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                ),

                const SizedBox(height: 20),

                // 4. Transaction History Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Transaction History',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        '${transactions.length} entries',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // Transaction list or empty state
                if (transactions.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: EmptyStateWidget(
                      icon: Icons.receipt_long_outlined,
                      title: 'No transactions yet',
                      description: 'Record what you give or receive to start ${person.name}\'s ledger.',
                      actionLabel: 'Give money',
                      onActionPressed: () => QuickGiveSheet.show(context, personId: personId),
                    ),
                  )
                else
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: cs.outlineVariant),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: transactions.length,
                      separatorBuilder: (ctx, i) => Divider(
                        height: 1,
                        indent: 68,
                        endIndent: 16,
                        color: cs.outlineVariant.withValues(alpha: 0.6),
                      ),
                      itemBuilder: (ctx, index) {
                        final tx = transactions[index];
                        return TransactionTile(
                          transaction: tx,
                          person: person,
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
                  ),
              ],
            ),
          ),
        ),
      );
    },
      loading: () => PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _navigateBack(context);
        },
        child: Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => _navigateBack(context),
            ),
          ),
          body: const Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (err, _) => PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _navigateBack(context);
        },
        child: Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => _navigateBack(context),
            ),
          ),
          body: const Center(child: Text("Couldn't load this. Please try again.")),
        ),
      ),
    );
  }
}
