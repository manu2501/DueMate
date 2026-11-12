import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:duemate/core/constants/app_constants.dart';
import 'package:duemate/core/constants/expense_category_x.dart';
import 'package:duemate/core/theme/app_theme.dart';
import 'package:duemate/core/utils/currency_formatter.dart';
import 'package:duemate/core/widgets/empty_state_widget.dart';
import 'package:duemate/core/widgets/ui_kit.dart';
import 'package:duemate/data/database/tables.dart';
import 'package:duemate/data/providers/app_providers.dart';
import 'package:duemate/domain/entities/personal_expense.dart';
import 'package:duemate/features/expenses/presentation/widgets/add_edit_expense_sheet.dart';

/// Month by month spending for a year, then the chosen month in detail:
/// where it went (by category) and every expense, editable.
class ExpenseChartsScreen extends ConsumerStatefulWidget {
  const ExpenseChartsScreen({super.key});

  @override
  ConsumerState<ExpenseChartsScreen> createState() => _ExpenseChartsScreenState();
}

class _ExpenseChartsScreenState extends ConsumerState<ExpenseChartsScreen> {
  int _year = DateTime.now().year;
  int _month = DateTime.now().month; // 1..12

  static const _short = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  static const _long = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final symbol = ref.watch(currencySymbolProvider);
    final budget = ref.watch(monthlyBudgetLimitProvider);
    final all = ref.watch(allExpensesProvider).value ?? const <PersonalExpense>[];
    String money(double v) => CurrencyFormatter.format(v, symbol: symbol);

    // Years that actually have data, plus the current one.
    final years = {DateTime.now().year, ...all.map((e) => e.expenseDate.year)}.toList()..sort();

    final yearExpenses = all.where((e) => e.expenseDate.year == _year).toList();
    final totals = List<double>.filled(12, 0);
    for (final e in yearExpenses) {
      totals[e.expenseDate.month - 1] += e.amount;
    }
    final monthExpenses = yearExpenses.where((e) => e.expenseDate.month == _month).toList()
      ..sort((a, b) => b.expenseDate.compareTo(a.expenseDate));
    final monthTotal = totals[_month - 1];
    final days = DateTime(_year, _month + 1, 0).day;

    final byCategory = <ExpenseCategory, double>{};
    for (final e in monthExpenses) {
      byCategory[e.category] = (byCategory[e.category] ?? 0) + e.amount;
    }
    final categories = byCategory.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Spending trends'),
        actions: [
          PopupMenuButton<int>(
            tooltip: 'Choose year',
            initialValue: _year,
            onSelected: (y) => setState(() => _year = y),
            itemBuilder: (_) => [for (final y in years.reversed) PopupMenuItem(value: y, child: Text('$y'))],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
              child: Row(
                children: [
                  Text('$_year', style: theme.textTheme.titleMedium),
                  const Icon(Icons.arrow_drop_down_rounded),
                ],
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpace.xxl),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpace.screenGutter, AppSpace.sm, AppSpace.screenGutter, 0),
            child: Text(
              'Monthly spending in $_year · tap a month',
              style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.md, AppSpace.lg, 0),
            child: _MonthBars(
              totals: totals,
              labels: _short,
              selected: _month - 1,
              symbol: symbol,
              onSelect: (i) => setState(() => _month = i + 1),
            ),
          ),

          // The chosen month
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpace.screenGutter, AppSpace.xl, AppSpace.screenGutter, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${_long[_month - 1]} $_year', style: theme.textTheme.labelLarge?.copyWith(color: cs.onSurfaceVariant)),
                const SizedBox(height: AppSpace.xs),
                MoneyText(monthTotal, symbol: symbol, style: theme.textTheme.displaySmall),
                if (monthTotal > 0)
                  Text(
                    [
                      '${money(monthTotal / days)} a day on average',
                      if (budget > 0) '${(monthTotal / budget * 100).round()}% of your budget',
                    ].join(' · '),
                    style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                  ),
              ],
            ),
          ),

          if (monthExpenses.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppSpace.xxl),
              child: EmptyStateWidget(
                icon: Icons.receipt_long_outlined,
                title: 'Nothing spent in ${_long[_month - 1]}',
                description: 'Pick another month above.',
              ),
            )
          else ...[
            const SectionHeader('Where it went'),
            GroupCard(
              dividerIndent: AppSpace.lg,
              children: [
                for (final c in categories)
                  _CategoryShare(
                    category: c.key,
                    amount: money(c.value),
                    share: monthTotal == 0 ? 0 : c.value / monthTotal,
                  ),
              ],
            ),
            SectionHeader('Expenses in ${_long[_month - 1]}'),
            GroupCard(
              children: [
                for (final e in monthExpenses)
                  ListTile(
                    onTap: () => AddEditExpenseSheet.show(context, expenseToEdit: e),
                    leading: IconBadge(e.category.icon),
                    title: Text(e.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text('${DateHeader.label(e.expenseDate)} · ${e.paymentMethod.label}'),
                    trailing: MoneyText(e.amount, symbol: symbol, sign: '−'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Single-series column chart of monthly totals. One hue, no legend (the
/// caption names the series); the selected month is emphasised and is the
/// only bar with a value label.
class _MonthBars extends StatelessWidget {
  final List<double> totals;
  final List<String> labels;
  final int selected;
  final String symbol;
  final ValueChanged<int> onSelect;

  const _MonthBars({
    required this.totals,
    required this.labels,
    required this.selected,
    required this.symbol,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final max = totals.fold<double>(0, (m, v) => v > m ? v : m);
    const plotHeight = 140.0;

    return SizedBox(
      height: plotHeight + 48,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < totals.length; i++)
            Expanded(
              child: Semantics(
                button: true,
                selected: i == selected,
                label: '${labels[i]}: ${CurrencyFormatter.format(totals[i], symbol: symbol)}',
                child: InkWell(
                  onTap: () => onSelect(i),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (i == selected && totals[i] > 0)
                        FittedBox(
                          child: Text(
                            CurrencyFormatter.formatCompact(totals[i], symbol: symbol),
                            style: theme.textTheme.labelSmall,
                          ),
                        ),
                      const SizedBox(height: 4),
                      // 2px surface gap between neighbours via horizontal padding.
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Container(
                          height: totals[i] <= 0 || max == 0 ? 2 : (totals[i] / max * plotHeight).clamp(4, plotHeight),
                          decoration: BoxDecoration(
                            color: totals[i] <= 0
                                ? cs.outlineVariant
                                : (i == selected ? cs.primary : cs.primary.withValues(alpha: 0.35)),
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        labels[i].substring(0, 1),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: i == selected ? cs.onSurface : cs.onSurfaceVariant,
                          fontWeight: i == selected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A category's share of the month: colour mark, name and amount in text
/// colours, and a thin bar in the category colour.
class _CategoryShare extends StatelessWidget {
  final ExpenseCategory category;
  final String amount;
  final double share;

  const _CategoryShare({required this.category, required this.amount, required this.share});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final color = category.chartColor(theme.brightness);
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.md, AppSpace.lg, AppSpace.md),
      child: Column(
        children: [
          Row(
            children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: AppSpace.sm),
              Expanded(child: Text(category.label, style: theme.textTheme.bodyLarge)),
              Text(amount, style: theme.textTheme.titleSmall),
              SizedBox(
                width: 48,
                child: Text(
                  '${(share * 100).round()}%',
                  textAlign: TextAlign.end,
                  style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: share.clamp(0.0, 1.0),
              minHeight: 6,
              color: color,
              backgroundColor: cs.surfaceContainerHigh,
            ),
          ),
        ],
      ),
    );
  }
}
