import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:duemate/core/constants/app_constants.dart';
import 'package:duemate/core/constants/expense_category_x.dart';
import 'package:duemate/core/theme/app_theme.dart';
import 'package:duemate/core/utils/date_formatter.dart';
import 'package:duemate/core/utils/display_money.dart';
import 'package:duemate/core/widgets/empty_state_widget.dart';
import 'package:duemate/core/widgets/ui_kit.dart';
import 'package:duemate/data/providers/app_providers.dart';
import 'package:duemate/domain/entities/personal_expense.dart';
import 'package:duemate/domain/spending_pace.dart';
import 'package:duemate/features/expenses/presentation/widgets/add_edit_expense_sheet.dart';
import 'package:duemate/features/expenses/presentation/widgets/budget_dialog.dart';
import 'package:duemate/features/expenses/presentation/widgets/recurring_bills_card.dart';

/// What you spent this month, against your budget. EMI and loan
/// installments are repayments, not spending: they live on the EMIs tab.
class ExpensesScreen extends ConsumerWidget {
  const ExpensesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final symbol = ref.watch(currencySymbolProvider);

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
        onPressed: () => AddEditExpenseSheet.show(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add expense'),
      ),
      slivers: [
        SliverToBoxAdapter(child: _MonthHeader(symbol: symbol, onEditBudget: () => editMonthlyBudget(context, ref))),
        const SliverToBoxAdapter(child: _EmisLink()),
        ..._spendingSlivers(context, ref, symbol),
      ],
    );
  }

  /// Monthly repeats (rent, subscriptions): a plan, shown apart from (and
  /// above) what was actually spent.
  static List<Widget> _recurringSlivers(WidgetRef ref, String symbol) {
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

  /// Category, whether a monthly repeat added it, and how it was paid.
  static String _expenseSubtitle(PersonalExpense e) => [
        e.category.label,
        if (e.recurringId != null) 'Monthly',
        e.paymentMethod.label,
      ].join(' · ');

  static List<Widget> _spendingSlivers(BuildContext context, WidgetRef ref, String symbol) {
    final expenses = ref.watch(monthlyExpensesProvider).value ?? const <PersonalExpense>[];
    final recurring = _recurringSlivers(ref, symbol);
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
}


/// One row to the EMIs page. Installments are repayments, so they are not in
/// the total above; this says what they need this month.
class _EmisLink extends ConsumerWidget {
  const _EmisLink();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasEmis = (ref.watch(allEmisProvider).value ?? const []).any((e) => !e.isCancelled);
    final due = ref.watch(emiOutlookProvider).dueThisMonth;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.lg),
      child: GroupCard(
        children: [
          ListTile(
            onTap: () => context.push('/emis'),
            leading: const IconBadge(Icons.credit_card_outlined),
            title: const Text('EMIs & loans'),
            subtitle: Text(!hasEmis
                ? 'Track card EMIs and loans'
                : due > 0
                    ? '${ref.watch(displayMoneyProvider)(due)} due this month · not counted above'
                    : 'Nothing due this month'),
            trailing: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }
}

class _MonthHeader extends ConsumerWidget {
  final String symbol;
  final VoidCallback onEditBudget;

  const _MonthHeader({required this.symbol, required this.onEditBudget});

  /// "₹2,300 more than by this day in October"; null with nothing to compare.
  /// Neutral colour: spending more or less is information, not good or bad.
  static String? _paceLine(SpendingPace pace, DisplayMoney money) {
    if (!pace.hasComparison) return null;
    final month = DateFormat.MMMM().format(pace.lastMonthStart);
    final when = pace.wholeLastMonth ? 'in $month' : 'by this day in $month';
    final diff = pace.difference;
    if (diff.abs() < 1) return 'About the same as $when';
    return '${money(diff.abs())} ${diff > 0 ? 'more' : 'less'} than $when';
  }

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
          if (_paceLine(ref.watch(spendingPaceProvider), money) case final line?)
            Text(line, style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}
