import 'package:flutter/material.dart';
import 'package:duemate/core/utils/currency_formatter.dart';

class EmiBreakdownCard extends StatelessWidget {
  final bool isLoan;
  final double baseAmount;
  final double charges;
  final double totalPayable;
  final double monthlyInstallment;
  final int tenureMonths;
  final String currencySymbol;

  const EmiBreakdownCard({
    super.key,
    required this.isLoan,
    required this.baseAmount,
    required this.charges,
    required this.totalPayable,
    required this.monthlyInstallment,
    required this.tenureMonths,
    required this.currencySymbol,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final accentColor = isLoan ? const Color(0xFF0D9488) : Theme.of(context).colorScheme.secondary;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isLoan ? 'Principal Loan:' : 'Base Amount:',
                style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant),
              ),
              Text(
                CurrencyFormatter.format(baseAmount, symbol: currencySymbol),
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          if (charges > 0) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isLoan ? 'Interest / Extra Charges:' : 'Additional Charges:',
                  style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant),
                ),
                Text(
                  '+ ${CurrencyFormatter.format(charges, symbol: currencySymbol)}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: cs.error,
                  ),
                ),
              ],
            ),
          ],
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(height: 1),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Payable Amount:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
              Text(
                CurrencyFormatter.format(totalPayable, symbol: currencySymbol),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: accentColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Monthly Installment:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
              Text(
                '${CurrencyFormatter.format(monthlyInstallment, symbol: currencySymbol)} / mo',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: cs.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
