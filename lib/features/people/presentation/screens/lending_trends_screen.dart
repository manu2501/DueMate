import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:duemate/core/theme/app_theme.dart';
import 'package:duemate/core/utils/date_formatter.dart';
import 'package:duemate/core/utils/display_money.dart';
import 'package:duemate/core/widgets/empty_state_widget.dart';
import 'package:duemate/core/widgets/ui_kit.dart';
import 'package:duemate/data/providers/app_providers.dart';
import 'package:duemate/domain/lending_cashflow.dart';

/// Money lent vs collected, month by month for a year, then the chosen
/// month and the year in numbers.
class LendingTrendsScreen extends ConsumerStatefulWidget {
  const LendingTrendsScreen({super.key});

  @override
  ConsumerState<LendingTrendsScreen> createState() => _LendingTrendsScreenState();
}

class _LendingTrendsScreenState extends ConsumerState<LendingTrendsScreen> {
  final _now = DateTime.now();
  late int _year = _now.year;
  late int _month = _now.month; // 1..12

  void _pickYear(int year) => setState(() {
        _year = year;
        _month = year == _now.year ? _now.month : 12;
      });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final ledger = LedgerColors.of(context);
    final symbol = ref.watch(currencySymbolProvider);
    final money = ref.watch(displayMoneyProvider);
    final txs = ref.watch(allTransactionsProvider).value ?? const [];

    final months = LendingCashflow.byMonth(txs, _year);
    final month = months[_month - 1];
    final yearLent = months.fold<double>(0, (s, m) => s + m.lent);
    final yearCollected = months.fold<double>(0, (s, m) => s + m.collected);
    final monthName = '${monthNamesLong[_month - 1]} $_year';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lending trends'),
        actions: [YearMenuButton(year: _year, years: LendingCashflow.years(txs, _now.year), onSelected: _pickYear)],
      ),
      body: yearLent == 0 && yearCollected == 0
          ? EmptyStateWidget(
              icon: Icons.insights_outlined,
              title: 'No lending in $_year',
              description: 'Money you give and get back shows up here, month by month.',
            )
          : ListView(
              padding: const EdgeInsets.only(bottom: AppSpace.xxl),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpace.screenGutter, AppSpace.sm, AppSpace.screenGutter, 0),
                  child: Text(
                    'Lent and collected each month in $_year · tap a month',
                    style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpace.screenGutter, AppSpace.md, AppSpace.screenGutter, 0),
                  child: Row(
                    children: [
                      _LegendKey(color: ledger.cashOut, label: 'Lent'),
                      const SizedBox(width: AppSpace.lg),
                      _LegendKey(color: ledger.cashIn, label: 'Collected'),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.md, AppSpace.lg, 0),
                  child: _PairedMonthBars(
                    months: months,
                    selected: _month - 1,
                    money: money,
                    lentColor: ledger.cashOut,
                    collectedColor: ledger.cashIn,
                    onSelect: (i) => setState(() => _month = i + 1),
                  ),
                ),

                // The chosen month, led by its one number: what came back net.
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpace.screenGutter, AppSpace.xl, AppSpace.screenGutter, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(monthName, style: theme.textTheme.labelLarge?.copyWith(color: cs.onSurfaceVariant)),
                      const SizedBox(height: AppSpace.xs),
                      _Net(flow: month, symbol: symbol, style: theme.textTheme.displaySmall),
                      Text(
                        month.isEmpty
                            ? 'Nothing lent or collected'
                            : month.net >= 0
                                ? 'more collected than lent'
                                : 'more lent than collected',
                        style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                SectionHeader(monthNamesLong[_month - 1]),
                _FlowCard(flow: month, symbol: symbol),
                SectionHeader('All of $_year'),
                _FlowCard(flow: MonthFlow(yearLent, yearCollected), symbol: symbol),
              ],
            ),
    );
  }
}

/// Net for a period: + (green) when more came back, − (neutral) when more
/// went out. Lending out is never red: it isn't money you owe.
class _Net extends StatelessWidget {
  final MonthFlow flow;
  final String symbol;
  final TextStyle? style;
  const _Net({required this.flow, required this.symbol, this.style});

  @override
  Widget build(BuildContext context) {
    final net = flow.net;
    return MoneyText(
      net.abs(),
      symbol: symbol,
      sign: net > 0 ? '+' : (net < 0 ? '−' : ''),
      tone: net > 0 ? MoneyTone.positive : MoneyTone.neutral,
      style: style,
    );
  }
}

/// Lent, collected and net as rows: the numbers behind the chart, in text.
class _FlowCard extends StatelessWidget {
  final MonthFlow flow;
  final String symbol;
  const _FlowCard({required this.flow, required this.symbol});

  @override
  Widget build(BuildContext context) {
    return GroupCard(
      dividerIndent: AppSpace.screenGutter,
      children: [
        ListTile(title: const Text('Lent'), trailing: MoneyText(flow.lent, symbol: symbol, sign: flow.lent > 0 ? '−' : '', meaning: '')),
        ListTile(
          title: const Text('Collected'),
          trailing: MoneyText(flow.collected, symbol: symbol, sign: flow.collected > 0 ? '+' : '', tone: MoneyTone.positive, meaning: ''),
        ),
        ListTile(title: const Text('Net'), trailing: _Net(flow: flow, symbol: symbol)),
      ],
    );
  }
}

class _LegendKey extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendKey({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: AppSpace.xs + 2),
        Text(label, style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ],
    );
  }
}

/// Two thin columns per month (lent, collected) on one shared scale. The
/// selected month is full strength; the rest are muted. Tap a month to pick it.
class _PairedMonthBars extends StatelessWidget {
  final List<MonthFlow> months;
  final int selected;
  final DisplayMoney money;
  final Color lentColor;
  final Color collectedColor;
  final ValueChanged<int> onSelect;

  const _PairedMonthBars({
    required this.months,
    required this.selected,
    required this.money,
    required this.lentColor,
    required this.collectedColor,
    required this.onSelect,
  });

  static const _plotHeight = 140.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final max = months.fold<double>(0, (m, f) => [m, f.lent, f.collected].reduce((a, b) => a > b ? a : b));

    Widget bar(double value, Color color, bool emphasised) => Expanded(
          child: Padding(
            // 2px surface gap between the pair and between months.
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: Container(
              height: value <= 0 || max == 0 ? 2 : (value / max * _plotHeight).clamp(4, _plotHeight),
              decoration: BoxDecoration(
                color: value <= 0 ? cs.outlineVariant : (emphasised ? color : color.withValues(alpha: 0.4)),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ),
          ),
        );

    return SizedBox(
      height: _plotHeight + 28,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < months.length; i++)
            Expanded(
              child: Semantics(
                button: true,
                selected: i == selected,
                label: money.hidden
                    ? '${monthNamesLong[i]}: ${DisplayMoney.hiddenLabel}'
                    : '${monthNamesLong[i]}: lent ${money(months[i].lent)}, collected ${money(months[i].collected)}',
                excludeSemantics: true,
                child: InkWell(
                  onTap: () => onSelect(i),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            bar(months[i].lent, lentColor, i == selected),
                            bar(months[i].collected, collectedColor, i == selected),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          monthNamesShort[i].substring(0, 1),
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
            ),
        ],
      ),
    );
  }
}
