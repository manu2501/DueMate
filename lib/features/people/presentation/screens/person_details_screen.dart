import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:duemate/core/theme/app_theme.dart';
import 'package:duemate/core/utils/csv_exporter.dart';
import 'package:duemate/core/utils/date_formatter.dart';
import 'package:duemate/core/utils/pdf_exporter.dart';
import 'package:duemate/core/utils/reminder_helper.dart';
import 'package:duemate/core/utils/whatsapp_helper.dart';
import 'package:duemate/core/widgets/avatar_widget.dart';
import 'package:duemate/core/widgets/confirm_dialog.dart';
import 'package:duemate/core/widgets/empty_state_widget.dart';
import 'package:duemate/core/widgets/export_options_sheet.dart';
import 'package:duemate/core/widgets/quick_give_sheet.dart';
import 'package:duemate/core/widgets/quick_receive_sheet.dart';
import 'package:duemate/core/widgets/transaction_tile.dart';
import 'package:duemate/core/widgets/ui_kit.dart';
import 'package:duemate/data/providers/app_providers.dart';
import 'package:duemate/domain/entities/ledger_transaction.dart';
import 'package:duemate/domain/loan_dues.dart';
import 'package:duemate/domain/entities/person_summary.dart';
import 'package:duemate/features/emis/presentation/screens/add_edit_emi_screen.dart';
import 'package:duemate/features/emis/presentation/widgets/emi_card.dart';
import 'package:duemate/features/people/presentation/screens/add_edit_person_screen.dart';
import 'package:duemate/features/people/presentation/widgets/person_info_sheet.dart';
import 'package:duemate/features/transactions/presentation/widgets/transaction_details_dialog.dart';

class PersonDetailsScreen extends ConsumerWidget {
  final String personId;

  const PersonDetailsScreen({super.key, required this.personId});

  Future<void> _confirmArchive(BuildContext context, WidgetRef ref, bool isArchived, String name) async {
    final ok = await showConfirmDialog(
      context,
      title: isArchived ? 'Unarchive $name?' : 'Archive $name?',
      message: isArchived
          ? '$name will be back in your people list.'
          : '$name will be hidden from your people list. Their records are kept.',
      confirmLabel: isArchived ? 'Unarchive' : 'Archive',
    );
    if (!ok || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(personRepositoryProvider);
    if (isArchived) {
      await repo.unarchivePerson(personId);
    } else {
      await repo.archivePerson(personId);
    }
    messenger.showSnackBar(SnackBar(content: Text(isArchived ? '$name unarchived' : '$name archived')));
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

  Future<void> _confirmDeletePerson(BuildContext context, WidgetRef ref, String name) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Delete $name?',
      message: "This permanently deletes $name along with every transaction and EMI recorded with them. "
          "This can't be undone.\n\nIf you only want them out of your list, archive them instead.",
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    await ref.read(personRepositoryProvider).deletePerson(personId);
    if (context.mounted) _navigateBack(context);
    messenger.showSnackBar(SnackBar(content: Text('$name and their records were deleted')));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final symbol = ref.watch(currencySymbolProvider);
    final summaryAsync = ref.watch(personSummaryProvider(personId));

    return summaryAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, _) => Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text("Couldn't load this. Please try again.")),
      ),
      data: (summary) {
        if (summary == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const EmptyStateWidget(
              icon: Icons.person_off_outlined,
              title: 'This person was removed',
              description: 'Their records are no longer in your ledger.',
            ),
          );
        }
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _navigateBack(context);
          },
          child: _PersonLedger(
            summary: summary,
            symbol: symbol,
            onBack: () => _navigateBack(context),
            onArchive: () => _confirmArchive(context, ref, summary.person.isArchived, summary.person.name),
            onDelete: () => _confirmDeletePerson(context, ref, summary.person.name),
          ),
        );
      },
    );
  }
}

enum _MenuAction { statement, shareText, details, edit, archive, delete }

class _PersonLedger extends ConsumerWidget {
  final PersonSummary summary;
  final String symbol;
  final VoidCallback onBack;
  final VoidCallback onArchive;
  final VoidCallback onDelete;

  const _PersonLedger({
    required this.summary,
    required this.symbol,
    required this.onBack,
    required this.onArchive,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final person = summary.person;
    final transactions = ref.watch(personTransactionsProvider(person.id)).value ?? const <LedgerTransaction>[];
    final emis = ref.watch(personEmisProvider(person.id)).value ?? const [];
    final dueList = LoanDues.outstanding(transactions);
    final due = dueList.isEmpty ? null : LoanDueStatus(dueList);
    final hasPhone = person.phone?.trim().isNotEmpty ?? false;
    final canRemind = summary.owesMoney && hasPhone;

    final firstName = person.name.split(' ').first;
    final String headline;
    final MoneyTone tone;
    if (summary.owesMoney) {
      headline = '$firstName owes you';
      tone = MoneyTone.positive;
    } else if (summary.isOverpaid) {
      headline = 'You owe $firstName';
      tone = MoneyTone.negative;
    } else {
      headline = summary.hasNoTransactions ? 'No entries yet' : 'All settled';
      tone = MoneyTone.neutral;
    }

    void remind() => WhatsAppHelper.sendWhatsAppMessage(
          phoneNumber: person.phone,
          message: WhatsAppHelper.generateLedgerReminderMessage(summary,
              currencySymbol: symbol, upiId: ref.read(upiIdForRemindersProvider)),
          context: context,
        );

    void addEmi() => AddEditEmiScreen.show(context, personId: person.id);
    // Three actions share the row: trim the side padding so labels fit on one line.
    final actionStyle = FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm));

    void onMenu(_MenuAction a) {
      switch (a) {
        case _MenuAction.statement:
          ExportOptionsSheet.show(
            context: context,
            title: 'Statement for ${person.name}',
            onSharePdf: () => PdfExporter.exportAndSharePersonStatement(
              summary: summary,
              transactions: transactions,
              currencySymbol: symbol,
            ),
            onShareCsv: () => CsvExporter.exportAndSharePersonStatement(
              summary: summary,
              transactions: transactions,
              currencySymbol: symbol,
            ),
          );
        case _MenuAction.shareText:
          ReminderHelper.shareReminder(summary, currencySymbol: symbol, upiId: ref.read(upiIdForRemindersProvider));
        case _MenuAction.details:
          PersonInfoSheet.show(context, person: person, summary: summary, currencySymbol: symbol);
        case _MenuAction.edit:
          AddEditPersonScreen.show(context, personToEdit: person);
        case _MenuAction.archive:
          onArchive();
        case _MenuAction.delete:
          onDelete();
      }
    }

    PopupMenuItem<_MenuAction> item(_MenuAction a, IconData icon, String label, {Color? color}) =>
        PopupMenuItem(
          value: a,
          child: Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: AppSpace.md),
              Text(label, style: color == null ? null : TextStyle(color: color)),
            ],
          ),
        );

    // Group history by month, newest first.
    final byMonth = <String, List<LedgerTransaction>>{};
    for (final t in transactions) {
      byMonth.putIfAbsent(DateFormatter.formatMonthYear(t.transactionDate), () => []).add(t);
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            leading: IconButton(
              tooltip: 'Back',
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: onBack,
            ),
            title: Text(person.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            actions: [
              if (canRemind)
                IconButton(
                  tooltip: 'Remind on WhatsApp',
                  icon: const Icon(Icons.chat_outlined),
                  onPressed: remind,
                ),
              PopupMenuButton<_MenuAction>(
                tooltip: 'More',
                onSelected: onMenu,
                itemBuilder: (_) => [
                  item(_MenuAction.statement, Icons.description_outlined, 'Share statement'),
                  item(_MenuAction.shareText, Icons.ios_share_rounded, 'Share balance as text'),
                  item(_MenuAction.details, Icons.info_outline_rounded, 'Contact details'),
                  item(_MenuAction.edit, Icons.edit_outlined, 'Edit'),
                  const PopupMenuDivider(),
                  item(_MenuAction.archive, Icons.archive_outlined, person.isArchived ? 'Unarchive' : 'Archive'),
                  item(_MenuAction.delete, Icons.delete_outline_rounded, 'Delete', color: cs.error),
                ],
              ),
            ],
          ),

          // Who and where you stand
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppSpace.screenGutter, AppSpace.sm, AppSpace.screenGutter, AppSpace.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      AvatarWidget(name: person.name, radius: 24, heroTag: 'avatar-${person.id}'),
                      const SizedBox(width: AppSpace.md),
                      Expanded(
                        child: Text(
                          [if (hasPhone) person.phone!, if (person.isArchived) 'Archived'].join(' · '),
                          style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpace.lg),
                  Text(headline, style: theme.textTheme.labelLarge?.copyWith(color: cs.onSurfaceVariant)),
                  const SizedBox(height: AppSpace.xs),
                  MoneyText(summary.balance, symbol: symbol, tone: tone, style: theme.textTheme.displaySmall),
                  if (summary.repayment case final repayment?) ...[
                    const SizedBox(height: AppSpace.md),
                    RepaymentBar(repayment, thickness: 8),
                  ],
                  if (due != null) ...[
                    const SizedBox(height: AppSpace.sm),
                    DueBackLine(due, style: theme.textTheme.bodyMedium),
                  ],
                ],
              ),
            ),
          ),

          // What you can do with them
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.tonalIcon(
                      style: actionStyle,
                      onPressed: () => QuickGiveSheet.show(context, personId: person.id),
                      icon: const Icon(Icons.north_east_rounded, size: 20),
                      label: const Text('Give'),
                    ),
                  ),
                  const SizedBox(width: AppSpace.sm),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      style: actionStyle,
                      onPressed: () => QuickReceiveSheet.show(context, personId: person.id),
                      icon: const Icon(Icons.south_west_rounded, size: 20),
                      label: const Text('Receive'),
                    ),
                  ),
                  const SizedBox(width: AppSpace.sm),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      style: actionStyle,
                      onPressed: addEmi,
                      icon: const Icon(Icons.credit_card_outlined, size: 20),
                      label: const Text('EMI'),
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: SectionHeader('EMIs and loans', actionLabel: 'Add', onAction: addEmi),
          ),
          SliverToBoxAdapter(
            child: GroupCard(
              children: emis.isEmpty
                  ? [
                      ListTile(
                        onTap: addEmi,
                        leading: const IconBadge(Icons.credit_card_outlined),
                        title: const Text('Card EMI or loan'),
                        subtitle: Text("Each installment is added to ${person.name.split(' ').first}'s ledger on its due date"),
                        trailing: const Icon(Icons.chevron_right_rounded),
                      ),
                    ]
                  : [for (final e in emis) EmiCard(emi: e, person: person, currencySymbol: symbol)],
            ),
          ),

          if (transactions.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: AppSpace.xxl),
                child: EmptyStateWidget(
                  icon: Icons.receipt_long_outlined,
                  title: 'Nothing recorded yet',
                  description: 'Use Give or Receive above to start ${person.name.split(' ').first}\'s ledger.',
                ),
              ),
            )
          else
            for (final entry in byMonth.entries) ...[
              SliverToBoxAdapter(child: SectionHeader(entry.key)),
              SliverToBoxAdapter(
                child: GroupCard(
                  children: [
                    for (final t in entry.value)
                      TransactionTile(
                        transaction: t,
                        person: person,
                        currencySymbol: symbol,
                        showPerson: false,
                        onTap: () => TransactionDetailsDialog.show(context, transaction: t, person: person),
                      ),
                  ],
                ),
              ),
            ],
          const SliverToBoxAdapter(child: SizedBox(height: AppSpace.xxl)),
        ],
      ),
    );
  }
}
