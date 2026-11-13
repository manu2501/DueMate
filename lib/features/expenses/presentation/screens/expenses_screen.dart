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
import 'package:duemate/domain/entities/personal_expense.dart';
import 'package:duemate/features/emis/presentation/screens/add_edit_emi_screen.dart';
import 'package:duemate/features/emis/presentation/widgets/emi_card.dart';
import 'package:duemate/features/expenses/presentation/widgets/add_edit_expense_sheet.dart';
import 'package:duemate/features/expenses/presentation/widgets/budget_dialog.dart';
import 'package:duemate/features/expenses/presentation/widgets/recurring_bills_card.dart';

enum _View { spending, emis }

enum _EmiOwner { mine, shared, all }

class ExpensesScreen extends ConsumerStatefulWidget {
  /// 'emis' opens the EMIs view (used by links from Home).
  final String? initialTab;

  const ExpensesScreen({super.key, this.initialTab});

  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen> {
  late _View _view = widget.initialTab == 'emis' ? _View.emis : _View.spending;
  _EmiOwner _owner = _EmiOwner.all;

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
                ButtonSegment(value: _View.spending, label: Text('Spending')),
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
                  trailing: MoneyText(e.amount, symbol: symbol, sign: '−'),
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

  List<Widget> _emiSlivers(String symbol) {
    final all = ref.watch(allEmisProvider).value ?? const [];
    final people = ref.watch(personsMapProvider);
    final emis = all.where((e) {
      if (e.isCancelled) return false;
      return switch (_owner) {
        _EmiOwner.mine => e.isForSelf,
        _EmiOwner.shared => !e.isForSelf,
        _EmiOwner.all => true,
      };
    }).toList()
      ..sort((a, b) {
        // Active first, then by next due date.
        if (a.isCompleted != b.isCompleted) return a.isCompleted ? 1 : -1;
        final ad = a.nextDueDate ?? DateTime(9999);
        final bd = b.nextDueDate ?? DateTime(9999);
        return ad.compareTo(bd);
      });

    final monthlyOut = all
        .where((e) => e.isActive && (e.isForSelf || e.isPaidByMe))
        .fold<double>(0, (s, e) => s + e.getMonthlyInstallmentFor(e.installmentsPaid + 1));

    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.md, AppSpace.lg, 0),
          child: Wrap(
            spacing: AppSpace.sm,
            children: [
              for (final o in _EmiOwner.values)
                ChoiceChip(
                  label: Text(switch (o) {
                    _EmiOwner.mine => 'Mine',
                    _EmiOwner.shared => 'Shared',
                    _EmiOwner.all => 'All',
                  }),
                  selected: _owner == o,
                  onSelected: (_) => setState(() => _owner = o),
                ),
            ],
          ),
        ),
      ),
      if (monthlyOut > 0)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSpace.screenGutter, AppSpace.md, AppSpace.screenGutter, 0),
            child: Text(
              '${ref.watch(displayMoneyProvider)(monthlyOut)} goes out each month on active EMIs',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
        ),
      if (emis.isEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: AppSpace.xxl),
            child: EmptyStateWidget(
              icon: Icons.event_repeat_outlined,
              title: 'No EMIs or loans here',
              description: 'Track card EMIs and loans. On each due date, yours are added to expenses and shared ones to the ledger.',
              actionLabel: 'Add EMI or loan',
              onActionPressed: () => AddEditEmiScreen.show(context),
            ),
          ),
        )
      else ...[
        const SliverToBoxAdapter(child: SizedBox(height: AppSpace.md)),
        SliverToBoxAdapter(
          child: GroupCard(
            dividerIndent: 76,
            children: [
              for (final e in emis)
                EmiCard(
                  emi: e,
                  person: e.personId == AppConstants.selfPersonId ? null : people[e.personId],
                  currencySymbol: symbol,
                ),
            ],
          ),
        ),
      ],
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
