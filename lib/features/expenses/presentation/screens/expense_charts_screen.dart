import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:duemate/core/utils/currency_formatter.dart';
import 'package:duemate/core/widgets/animated_currency_text.dart';
import 'package:duemate/core/widgets/empty_state_widget.dart';
import 'package:duemate/data/providers/app_providers.dart';
import 'package:duemate/features/expenses/presentation/widgets/expense_category_chart_card.dart';

class ExpenseChartsScreen extends ConsumerStatefulWidget {
  const ExpenseChartsScreen({super.key});

  @override
  ConsumerState<ExpenseChartsScreen> createState() => _ExpenseChartsScreenState();
}

class _ExpenseChartsScreenState extends ConsumerState<ExpenseChartsScreen> {
  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month; // 1 - 12

  final List<String> _monthNames = const [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  final List<String> _fullMonthNames = const [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final currencySymbol = ref.watch(currencySymbolProvider);
    final allExpensesAsync = ref.watch(allExpensesProvider);
    final budgetLimit = ref.watch(monthlyBudgetLimitProvider);

    final allExpenses = allExpensesAsync.value ?? [];

    // Filter expenses for selected year
    final yearExpenses = allExpenses.where((e) => e.expenseDate.year == _selectedYear).toList();

    // Calculate monthly totals for the selected year (1-12)
    final List<double> monthlyTotals = List.filled(12, 0.0);
    for (final e in yearExpenses) {
      final m = e.expenseDate.month - 1;
      if (m >= 0 && m < 12) {
        monthlyTotals[m] += e.amount;
      }
    }

    // Find max monthly spend for bar scaling
    final maxMonthlySpend = monthlyTotals.fold(1.0, (max, v) => v > max ? v : max);

    // Selected month expenses
    final selectedMonthExpenses = yearExpenses.where((e) => e.expenseDate.month == _selectedMonth).toList();
    final selectedMonthTotal = monthlyTotals[_selectedMonth - 1];

    final daysInMonth = DateTime(_selectedYear, _selectedMonth + 1, 0).day;
    final dailyAvg = selectedMonthTotal > 0 ? selectedMonthTotal / daysInMonth : 0.0;
    final capPercent = budgetLimit > 0 ? (selectedMonthTotal / budgetLimit * 100).clamp(0.0, 999.0) : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Expense Analytics & Charts',
          style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
        ),
        actions: [
          PopupMenuButton<int>(
            initialValue: _selectedYear,
            tooltip: 'Select Year',
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Text(
                    '$_selectedYear',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: cs.primary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_drop_down_rounded, color: cs.primary),
                ],
              ),
            ),
            onSelected: (year) => setState(() => _selectedYear = year),
            itemBuilder: (_) => [2023, 2024, 2025, 2026].map((y) {
              return PopupMenuItem<int>(
                value: y,
                child: Text('$y', style: TextStyle(fontWeight: y == _selectedYear ? FontWeight.bold : FontWeight.normal)),
              );
            }).toList(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Month-over-Month Spending Trend Bar Chart
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: cs.outlineVariant),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: cs.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.bar_chart_rounded, color: cs.primary, size: 18),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Monthly Spending Trend',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: cs.onSurface,
                                ),
                              ),
                              Text(
                                'Year $_selectedYear • Tap any month bar',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // 12 Months Bar Chart Columns
                  SizedBox(
                    height: 140,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: List.generate(12, (index) {
                        final mTotal = monthlyTotals[index];
                        final monthNum = index + 1;
                        final isSelected = monthNum == _selectedMonth;
                        final barHeight = maxMonthlySpend > 0 ? (mTotal / maxMonthlySpend * 100).clamp(6.0, 100.0) : 6.0;

                        final barColor = isSelected
                            ? cs.primary
                            : (mTotal > 0
                                ? cs.primary.withValues(alpha: 0.35)
                                : cs.outlineVariant.withValues(alpha: 0.4));

                        return Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _selectedMonth = monthNum),
                            borderRadius: BorderRadius.circular(8),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (mTotal > 0)
                                  FittedBox(
                                    child: Text(
                                      CurrencyFormatter.formatCompact(mTotal, symbol: currencySymbol),
                                      style: GoogleFonts.inter(
                                        fontSize: 9,
                                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                                        color: isSelected ? cs.primary : cs.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: 4),

                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeOutCubic,
                                  width: isSelected ? 16 : 10,
                                  height: barHeight,
                                  decoration: BoxDecoration(
                                    color: barColor,
                                    borderRadius: BorderRadius.circular(6),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: cs.primary.withValues(alpha: 0.3),
                                              blurRadius: 6,
                                              offset: const Offset(0, 2),
                                            ),
                                          ]
                                        : null,
                                  ),
                                ),
                                const SizedBox(height: 8),

                                Text(
                                  _monthNames[index],
                                  style: GoogleFonts.inter(
                                    fontSize: 10.5,
                                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                                    color: isSelected ? cs.primary : cs.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 2. Selected Month Financial Overview Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_fullMonthNames[_selectedMonth - 1]} $_selectedYear Summary',
                        style: GoogleFonts.dmSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF131438),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${selectedMonthExpenses.length} Outflows',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: cs.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total Outflow Spent',
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 2),
                          AnimatedCurrencyText(
                            amount: selectedMonthTotal,
                            currencySymbol: currencySymbol,
                            style: GoogleFonts.dmSans(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: cs.error,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Daily Average',
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${CurrencyFormatter.format(dailyAvg, symbol: currencySymbol)}/day',
                            style: GoogleFonts.dmSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: cs.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  if (budgetLimit > 0) ...[
                    const SizedBox(height: 12),
                    Divider(color: cs.outlineVariant.withValues(alpha: 0.6), height: 1),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Versus Budget Cap (${CurrencyFormatter.formatCompact(budgetLimit, symbol: currencySymbol)}):',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          '${capPercent.toStringAsFixed(1)}% Used',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: capPercent >= 100
                                ? cs.error
                                : capPercent >= 80
                                    ? const Color(0xFFF59E0B)
                                    : const Color(0xFF10B981),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 3. Selected Month Category Usage & Share Breakdown
            if (selectedMonthExpenses.isNotEmpty)
              ExpenseCategoryChartCard(
                expenses: selectedMonthExpenses,
                currencySymbol: currencySymbol,
              )
            else
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: EmptyStateWidget(
                  icon: Icons.bar_chart_rounded,
                  title: 'No expenses recorded in ${_fullMonthNames[_selectedMonth - 1]} $_selectedYear',
                  description: 'Select another month from the trend chart above to inspect usage.',
                ),
              ),
          ],
        ),
      ),
    );
  }
}
