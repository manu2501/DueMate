import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:duemate/core/theme/app_theme.dart';
import 'package:duemate/core/widgets/empty_state_widget.dart';
import 'package:duemate/core/widgets/ui_kit.dart';
import 'package:duemate/data/providers/app_providers.dart';
import 'package:duemate/domain/emi_installments.dart';
import 'package:duemate/features/emis/presentation/screens/add_edit_emi_screen.dart';
import 'package:duemate/features/emis/presentation/widgets/emi_card.dart';

/// Card EMIs and loans, apart from spending: what you bought on the card was
/// the spending; each installment pays that back. Leads with what is due
/// this month, then the rest: yours, with people, and finished ones folded
/// away.
class EmisScreen extends ConsumerStatefulWidget {
  const EmisScreen({super.key});

  @override
  ConsumerState<EmisScreen> createState() => _EmisScreenState();
}

class _EmisScreenState extends ConsumerState<EmisScreen> {
  bool _showFinished = false;

  @override
  Widget build(BuildContext context) {
    final symbol = ref.watch(currencySymbolProvider);
    final people = ref.watch(personsMapProvider);
    final now = DateTime.now();
    final nextMonth = DateTime(now.year, now.month + 1);
    final states = [
      for (final e in ref.watch(allEmisProvider).value ?? const [])
        if (!e.isCancelled) watchInstallments(ref, e),
    ]..sort((a, b) => (a.nextDueDate ?? DateTime(9999)).compareTo(b.nextDueDate ?? DateTime(9999)));

    final active = states.where((s) => !s.isComplete);
    final finished = states.where((s) => s.isComplete).toList();
    // Leaves your account by the end of the month (not ones they pay you).
    bool dueNow(EmiInstallments s) =>
        (s.emi.isForSelf || s.emi.isPaidByMe) && (s.nextDueDate?.isBefore(nextMonth) ?? false);
    final due = active.where(dueNow).toList();
    final rest = active.where((s) => !dueNow(s));

    List<Widget> section(String title, Iterable<EmiInstallments> group) => [
          if (group.isNotEmpty) ...[
            SliverToBoxAdapter(child: SectionHeader(title)),
            SliverToBoxAdapter(
              child: GroupCard(
                dividerIndent: 76,
                children: [
                  for (final s in group)
                    EmiCard(
                      emi: s.emi,
                      person: s.emi.isForSelf ? null : people[s.emi.personId],
                      currencySymbol: symbol,
                    ),
                ],
              ),
            ),
          ],
        ];

    return TabScaffold(
      title: 'EMIs & loans',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => AddEditEmiScreen.show(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add EMI or loan'),
      ),
      slivers: [
        if (states.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: AppSpace.xxl),
              child: EmptyStateWidget(
                icon: Icons.event_repeat_outlined,
                title: 'No EMIs or loans yet',
                description: 'Track card EMIs and loans. Installments are repayments, so they stay here '
                    'and never count as spending. Shared ones go to that person\'s ledger.',
                actionLabel: 'Add EMI or loan',
                onActionPressed: () => AddEditEmiScreen.show(context),
              ),
            ),
          )
        else ...[
          SliverToBoxAdapter(child: _OutlookHeader(symbol: symbol, month: now)),
          ...section('Due this month', due),
          ...section('Yours', rest.where((s) => s.emi.isForSelf)),
          ...section('With people', rest.where((s) => !s.emi.isForSelf)),
          if (finished.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: AppSpace.md),
                child: Center(
                  child: TextButton.icon(
                    onPressed: () => setState(() => _showFinished = !_showFinished),
                    icon: Icon(_showFinished ? Icons.expand_less_rounded : Icons.expand_more_rounded),
                    label: Text(_showFinished ? 'Hide finished' : 'Finished (${finished.length})'),
                  ),
                ),
              ),
            ),
            if (_showFinished) ...section('Finished', finished),
          ],
        ],
      ],
    );
  }
}

/// The one number: what your EMIs still need this month.
class _OutlookHeader extends ConsumerWidget {
  final String symbol;
  final DateTime month;

  const _OutlookHeader({required this.symbol, required this.month});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final due = ref.watch(emiOutlookProvider).dueThisMonth;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.screenGutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Due in ${DateFormat.MMMM().format(month)}',
              style: theme.textTheme.labelLarge?.copyWith(color: cs.onSurfaceVariant)),
          const SizedBox(height: AppSpace.xs),
          MoneyText(due, symbol: symbol, style: theme.textTheme.displaySmall),
          const SizedBox(height: AppSpace.sm),
          Text(
            due > 0 ? 'Repayments, not counted in your spending.' : 'Nothing left to pay this month.',
            style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
