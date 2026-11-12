import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:duemate/core/utils/currency_formatter.dart';
import 'package:duemate/core/widgets/animated_currency_text.dart';
import 'package:duemate/data/providers/app_providers.dart';
import 'package:duemate/features/expenses/presentation/widgets/add_edit_expense_sheet.dart';

class MonthlyBudgetCard extends ConsumerWidget {
  const MonthlyBudgetCard({super.key});

  void _showEditBudgetDialog(BuildContext context, WidgetRef ref, double currentLimit) {
    final controller = TextEditingController(text: currentLimit.toStringAsFixed(0));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Set Monthly Budget Cap'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Monthly Budget Limit',
            hintText: 'e.g. 25000',
            prefixText: '₹ ',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final newCap = double.tryParse(controller.text.trim());
              if (newCap != null && newCap > 0) {
                ref.read(monthlyBudgetLimitProvider.notifier).setBudget(newCap);
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Monthly budget cap updated')),
                );
              }
            },
            child: const Text('Save Limit'),
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
    final totalSpent = ref.watch(monthlyExpenseTotalProvider);
    final budgetLimit = ref.watch(monthlyBudgetLimitProvider);

    final double progress = budgetLimit > 0 ? (totalSpent / budgetLimit).clamp(0.0, 1.0) : 1.0;
    final int percentUsed = (progress * 100).round();

    Color statusColor;
    String statusMessage;
    if (progress >= 1.0) {
      statusColor = cs.error;
      statusMessage = 'Budget cap exceeded!';
    } else if (progress >= 0.8) {
      statusColor = const Color(0xFFF59E0B);
      statusMessage = 'Approaching budget cap';
    } else {
      statusColor = const Color(0xFF10B981);
      statusMessage = 'On track this month';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
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
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.pie_chart_outline_rounded, color: Color(0xFFF59E0B), size: 18),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Personal Expenses & Budget',
                          style: GoogleFonts.inter(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: cs.onSurface,
                          ),
                        ),
                        Text(
                          statusMessage,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton.filledTonal(
                  onPressed: () => _showEditBudgetDialog(context, ref, budgetLimit),
                  icon: const Icon(Icons.tune_rounded, size: 16),
                  tooltip: 'Set Monthly Budget',
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 14),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Row(
                  children: [
                    AnimatedCurrencyText(
                      amount: totalSpent,
                      currencySymbol: currencySymbol,
                      style: GoogleFonts.dmSans(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: statusColor,
                      ),
                    ),
                    Text(
                      ' spent',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                Text(
                  'Cap: ${CurrencyFormatter.formatCompact(budgetLimit, symbol: currencySymbol)}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 7,
                backgroundColor: statusColor.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation<Color>(statusColor),
              ),
            ),
            const SizedBox(height: 12),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$percentUsed% of monthly limit used',
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurfaceVariant,
                  ),
                ),
                InkWell(
                  onTap: () => AddEditExpenseSheet.show(context),
                  borderRadius: BorderRadius.circular(8),
                  child: Row(
                    children: [
                      Icon(Icons.add_rounded, size: 14, color: cs.primary),
                      const SizedBox(width: 2),
                      Text(
                        'Log Expense',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: cs.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
