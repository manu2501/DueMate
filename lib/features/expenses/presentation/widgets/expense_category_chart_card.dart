import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:duemate/core/utils/currency_formatter.dart';
import 'package:duemate/data/database/tables.dart';
import 'package:duemate/domain/entities/personal_expense.dart';

class ExpenseCategoryChartCard extends StatelessWidget {
  final List<PersonalExpense> expenses;
  final String currencySymbol;
  final ExpenseCategory? selectedCategory;
  final ValueChanged<ExpenseCategory?>? onCategoryTap;

  const ExpenseCategoryChartCard({
    super.key,
    required this.expenses,
    required this.currencySymbol,
    this.selectedCategory,
    this.onCategoryTap,
  });

  String _getCategoryName(ExpenseCategory category) {
    switch (category) {
      case ExpenseCategory.groceries:
        return '🛒 Groceries';
      case ExpenseCategory.utilities:
        return '⚡ Utilities';
      case ExpenseCategory.rent:
        return '🏠 Rent';
      case ExpenseCategory.fuel:
        return '⛽ Fuel';
      case ExpenseCategory.food:
        return '🍔 Food';
      case ExpenseCategory.shopping:
        return '🛍️ Shopping';
      case ExpenseCategory.entertainment:
        return '🎬 Entertainment';
      case ExpenseCategory.health:
        return '🏥 Health';
      case ExpenseCategory.other:
        return '📦 Other';
    }
  }

  Color _getCategoryColor(ExpenseCategory category, ColorScheme cs) {
    switch (category) {
      case ExpenseCategory.groceries:
        return const Color(0xFF10B981); // Emerald
      case ExpenseCategory.utilities:
        return const Color(0xFF0EA5E9); // Sky
      case ExpenseCategory.rent:
        return const Color(0xFF8B5CF6); // Purple
      case ExpenseCategory.fuel:
        return const Color(0xFFF59E0B); // Amber
      case ExpenseCategory.food:
        return const Color(0xFFEF4444); // Red
      case ExpenseCategory.shopping:
        return const Color(0xFFEC4899); // Pink
      case ExpenseCategory.entertainment:
        return const Color(0xFF6366F1); // Indigo
      case ExpenseCategory.health:
        return const Color(0xFF14B8A6); // Teal
      case ExpenseCategory.other:
        return cs.outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    if (expenses.isEmpty) return const SizedBox.shrink();

    // Group spent amounts by category
    final Map<ExpenseCategory, double> categorySums = {};
    double totalSpent = 0.0;

    for (final e in expenses) {
      categorySums[e.category] = (categorySums[e.category] ?? 0.0) + e.amount;
      totalSpent += e.amount;
    }

    if (totalSpent <= 0) return const SizedBox.shrink();

    // Sort categories by highest spend
    final sortedEntries = categorySums.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(18),
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
                    Text(
                      'Category Usage & Spend Share',
                      style: GoogleFonts.inter(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                  ],
                ),
                if (selectedCategory != null)
                  InkWell(
                    onTap: () => onCategoryTap?.call(null),
                    child: Text(
                      'Show All',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: cs.primary,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            Column(
              children: sortedEntries.map((entry) {
                final category = entry.key;
                final amount = entry.value;
                final share = (amount / totalSpent).clamp(0.0, 1.0);
                final percentStr = (share * 100).toStringAsFixed(1);
                final isSelected = selectedCategory == category;
                final color = _getCategoryColor(category, cs);

                return InkWell(
                  onTap: () => onCategoryTap?.call(isSelected ? null : category),
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected ? color.withValues(alpha: 0.12) : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Text(
                                  _getCategoryName(category),
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                    color: isDark ? Colors.white : const Color(0xFF131438),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '$percentStr%',
                                    style: GoogleFonts.inter(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: color,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              CurrencyFormatter.format(amount, symbol: currencySymbol),
                              style: GoogleFonts.dmSans(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: cs.onSurface,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),

                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: share,
                            minHeight: 5,
                            backgroundColor: color.withValues(alpha: 0.12),
                            valueColor: AlwaysStoppedAnimation<Color>(color),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
