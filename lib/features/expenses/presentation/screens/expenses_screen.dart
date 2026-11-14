import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:duemate/core/constants/app_constants.dart';
import 'package:duemate/core/constants/expense_category_x.dart';
import 'package:duemate/core/theme/app_theme.dart';
import 'package:duemate/core/utils/date_formatter.dart';
import 'package:duemate/core/widgets/empty_state_widget.dart';
import 'package:duemate/core/widgets/ui_kit.dart';
import 'package:duemate/data/providers/app_providers.dart';
import 'package:duemate/domain/emi_installments.dart';
import 'package:duemate/domain/entities/personal_expense.dart';
import 'package:duemate/features/emis/presentation/screens/add_edit_emi_screen.dart';
import 'package:duemate/features/emis/presentation/widgets/emi_card.dart';
import 'package:duemate/features/expenses/presentation/widgets/add_edit_expense_sheet.dart';
import 'package:duemate/features/expenses/presentation/widgets/budget_dialog.dart';
import 'package:duemate/features/expenses/presentation/widgets/recurring_bills_card.dart';

enum _View { spending, emis }

class ExpensesScreen extends ConsumerStatefulWidget {
  /// 'emis' opens the EMIs view (used by links from Home).
  final String? initialTab;

  const ExpensesScreen({super.key, this.initialTab});

  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen> {
  late _View _view = widget.initialTab == 'emis' ? _View.emis : _View.spending;

  @override
  void didUpdateWidget(ExpensesScreen old) {
    super.didUpdateWidget(old);
    if (old.initialTab != widget.initialTab && widget.initialTab == 'emis') {
      setState(() => _view = _View.emis);
    }
  }

  @override
  Widget build(BuildContext context) {
    final symbol = ref.watch(currencySymbolProvider);
    final isEmis = _view == _View.emis;

    return TabScaffold(
      title: 'Expenses',
      actions: [
        IconButton(
          tooltip: 'Trends and categories',
          icon: const Icon(Icons.insights_outlined),
          onPressed: () => context.push('/expense-charts'),
        ),
      ],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => isEmis ? AddEditEmiScreen.show(context) : AddEditExpenseSheet.show(context),
        icon: const Icon(Icons.add_rounded),
        label: Text(isEmis ? 'Add EMI or loan' : 'Add expense'),
      ),
      slivers: [
        SliverToBoxAdapter(child: _MonthHeader(symbol: symbol, onEditBudget: () => editMonthlyBudget(context, ref))),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.lg, AppSpace.lg, 0),
            child: SegmentedButton<_View>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: _View.spending, label: Text('Spent')),
                ButtonSegment(value: _View.emis, label: Text('EMIs & loans')),
              ],
              selected: {_view},
              onSelectionChanged: (s) => setState(() => _view = s.first),
            ),
          ),
        ),
        if (isEmis) ..._emiSlivers(symbol) else ..._spendingSlivers(symbol),
      ],
    );
  }

  /// Monthly repeats (rent, subscriptions): a plan, shown apart from (and
  /// above) what was actually spent.
  List<Widget> _recurringSlivers(String symbol) {
    final rules = ref.watch(recurringExpensesProvider).value ?? const [];
    if (rules.isEmpty) return const [];
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(top: AppSpace.lg),
          child: RecurringBillsCard(rules: rules, symbol: symbol),
        ),
      ),
    ];
  }

  /// Category, how it was added (monthly repeat or EMI installment) and how
  /// it was paid.
  static String _expenseSubtitle(PersonalExpense e) => [
        e.category.label,
        if (e.recurringId != null) 'Monthly',
        if (e.installmentNumber case final k? when e.isEmi) 'Installment $k',
        e.paymentMethod.label,
      ].join(' · ');

  List<Widget> _spendingSlivers(String symbol) {
    final expenses = ref.watch(monthlyExpensesProvider).value ?? const <PersonalExpense>[];
    final recurring = _recurringSlivers(symbol);
    if (expenses.isEmpty) {
      return [
        ...recurring,
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: AppSpace.xxl),
            child: EmptyStateWidget(
              icon: Icons.receipt_long_outlined,
              title: 'Nothing spent this month',
              description: 'Add what you spend and it shows up here, grouped by day.',
              actionLabel: 'Add expense',
              onActionPressed: () => AddEditExpenseSheet.show(context),
            ),
          ),
        ),
      ];
    }

    final sorted = [...expenses]..sort((a, b) => b.expenseDate.compareTo(a.expenseDate));
    final byDay = <DateTime, List<PersonalExpense>>{};
    for (final e in sorted) {
      final d = DateTime(e.expenseDate.year, e.expenseDate.month, e.expenseDate.day);
      byDay.putIfAbsent(d, () => []).add(e);
    }

    return [
      ...recurring,
      const SliverToBoxAdapter(
        child: SectionHeader(
          "This month's expenses",
          padding: EdgeInsets.fromLTRB(AppSpace.screenGutter, AppSpace.xl, AppSpace.screenGutter, 0),
        ),
      ),
      for (final entry in byDay.entries) ...[
        SliverToBoxAdapter(
          child: DateHeader(
            entry.key,
            trailing: MoneyText(
              entry.value.fold<double>(0, (s, e) => s + e.amount),
              symbol: symbol,
              tone: MoneyTone.muted,
              style: Theme.of(context).textTheme.labelLarge,
              meaning: 'spent that day',
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: GroupCard(
            children: [
              for (final e in entry.value)
                ListTile(
                  onTap: () => AddEditExpenseSheet.show(context, expenseToEdit: e),
                  leading: IconBadge(e.category.icon),
                  title: Text(e.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(_expenseSubtitle(e)),
                  trailing: MoneyText(e.amount, symbol: symbol, sign: '−', meaning: 'spent'),
                ),
            ],
          ),
        ),
      ],
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(top: AppSpace.md),
          child: Center(
            child: TextButton.icon(
              onPressed: () => context.push('/expense-charts'),
              icon: const Icon(Icons.history_rounded),
              label: const Text('Earlier months'),
            ),
          ),
        ),
      ),
    ];
  }

  /// EMIs in two plain sections, yours and those with people, rather than
  /// another row of filters under the Spent / EMIs tabs.
  List<Widget> _emiSlivers(String symbol) {
    final all = ref.watch(allEmisProvider).value ?? const [];
    final people = ref.watch(personsMapProvider);
    final states = [
      for (final e in all)
        if (!e.isCancelled) watchInstallments(ref, e),
    ]..sort((a, b) {
        // Unfinished first, then by the earliest unpaid installment.
        if (a.isComplete != b.isComplete) return a.isComplete ? 1 : -1;
        return (a.nextDueDate ?? DateTime(9999)).compareTo(b.nextDueDate ?? DateTime(9999));
      });

    if (states.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: AppSpace.xxl),
            child: EmptyStateWidget(
              icon: Icons.event_repeat_outlined,
              title: 'No EMIs or loans yet',
              description: 'Track card EMIs and loans. On each due date, yours are added to expenses and shared ones to the ledger.',
              actionLabel: 'Add EMI or loan',
              onActionPressed: () => AddEditEmiScreen.show(context),
            ),
          ),
        ),
      ];
    }

    final monthlyOut = states
        .where((s) => !s.isComplete && (s.emi.isForSelf || s.emi.isPaidByMe))
        .fold<double>(0, (sum, s) => sum + s.nextAmount);

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

    return [
      if (monthlyOut > 0)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSpace.screenGutter, AppSpace.lg, AppSpace.screenGutter, 0),
            child: Text(
              '${ref.watch(displayMoneyProvider)(monthlyOut)} goes out each month',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
        ),
      ...section('Yours', states.where((s) => s.emi.isForSelf)),
      ...section('With people', states.where((s) => !s.emi.isForSelf)),
    ];
  }
}


class _MonthHeader extends ConsumerWidget {
  final String symbol;
  final VoidCallback onEditBudget;

  const _MonthHeader({required this.symbol, required this.onEditBudget});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final spent = ref.watch(monthlyExpenseTotalProvider);
    final budget = ref.watch(monthlyBudgetLimitProvider);
    final money = ref.watch(displayMoneyProvider);
    final ratio = budget > 0 ? spent / budget : 0.0;
    final over = budget > 0 && spent > budget;
    final month = DateFormatter.formatMonthYear(DateTime.now()).split(' ').first;

    final String status;
    final Color statusColor;
    if (over) {
      status = '${money(spent - budget)} over your ${money(budget)} budget';
      statusColor = cs.error;
    } else if (ratio >= 0.85) {
      status = 'Only ${money(budget - spent)} left of ${money(budget)}';
      statusColor = cs.tertiary;
    } else {
      status = '${money(budget - spent)} left of ${money(budget)}';
      statusColor = cs.onSurfaceVariant;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.screenGutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Spent in $month', style: theme.textTheme.labelLarge?.copyWith(color: cs.onSurfaceVariant)),
          const SizedBox(height: AppSpace.xs),
          MoneyText(spent, symbol: symbol, style: theme.textTheme.displaySmall),
          const SizedBox(height: AppSpace.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: ratio.clamp(0.0, 1.0),
              color: over ? cs.error : (ratio >= 0.85 ? cs.tertiary : cs.primary),
            ),
          ),
          Row(
            children: [
              Expanded(child: Text(status, style: theme.textTheme.bodyMedium?.copyWith(color: statusColor))),
              TextButton(onPressed: onEditBudget, child: const Text('Edit budget')),
            ],
          ),
        ],
      ),
    );
  }
}
