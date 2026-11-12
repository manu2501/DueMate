import 'package:flutter/material.dart';
import 'package:duemate/core/theme/app_theme.dart';
import 'package:duemate/core/utils/currency_formatter.dart';
import 'package:duemate/core/utils/date_formatter.dart';
import 'package:duemate/domain/emi_calculator.dart';

/// Live result of the EMI form: the monthly figure and what it adds up to.
class EmiSummaryCard extends StatelessWidget {
  final EmiPlan plan;
  final bool isLoan;
  final bool splitMode;
  final String currencySymbol;
  final DateTime? lastInstallmentDate;
  final int customMonthsCount;
  final bool customWasReset;
  final VoidCallback onCustomizeMonths;

  const EmiSummaryCard({
    super.key,
    required this.plan,
    required this.isLoan,
    required this.splitMode,
    required this.currencySymbol,
    required this.lastInstallmentDate,
    required this.customMonthsCount,
    required this.customWasReset,
    required this.onCustomizeMonths,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final muted = cs.onSurfaceVariant;
    String money(double v) => CurrencyFormatter.format(v, symbol: currencySymbol);

    final rate = (!splitMode && plan.isValid)
        ? EmiCalculator.impliedAnnualRate(
            principal: plan.principal,
            monthly: plan.monthly,
            months: plan.months,
          )
        : null;

    return Container(
      padding: const EdgeInsets.all(AppSpace.lg),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Monthly EMI', style: theme.textTheme.labelLarge?.copyWith(color: muted)),
          const SizedBox(height: 2),
          if (!plan.isValid)
            Text(
              splitMode
                  ? 'Enter the amount and months to see the EMI.'
                  : 'Enter the EMI and months to see the total.',
              style: theme.textTheme.bodyMedium?.copyWith(color: muted),
            )
          else ...[
            Text(
              '${money(plan.monthly)} × ${plan.months} months',
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            Divider(height: 1, color: cs.outlineVariant),
            const SizedBox(height: AppSpace.sm),
            if (plan.principal > 0) _Row(isLoan ? 'Loan amount' : 'Amount', money(plan.principal)),
            if (splitMode && plan.interest > 0) _Row('Interest', money(plan.interest)),
            if (plan.charges > 0)
              _Row(
                plan.chargesInsideEmi ? 'Charges (spread over the EMIs)' : 'Charges (billed separately)',
                money(plan.charges),
              ),
            _Row(
              plan.chargesInsideEmi ? 'Total to pay' : 'EMIs add up to',
              money(plan.totalPayable),
              strong: plan.chargesInsideEmi,
            ),
            if (!plan.chargesInsideEmi && plan.charges > 0)
              _Row('Total cost with charges', money(plan.totalCost), strong: true),
            if (plan.extraCost != null && plan.extraCost! > 0)
              _Row('Extra over the amount', money(plan.extraCost!)),
            if (rate != null) _Row('Effective interest', '≈ ${rate.toStringAsFixed(1)}% a year'),
            if (lastInstallmentDate != null)
              _Row('Last installment', DateFormatter.formatShortDate(lastInstallmentDate!)),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: onCustomizeMonths,
              icon: const Icon(Icons.edit_calendar_outlined, size: 18),
              label: Text(
                customMonthsCount > 0
                    ? 'Uneven months ($customMonthsCount set)'
                    : 'Make some months different',
              ),
            ),
          ],
          if (customWasReset)
            Padding(
              padding: const EdgeInsets.only(top: AppSpace.sm),
              child: Text(
                'Your per-month amounts were cleared because the plan changed.',
                style: theme.textTheme.bodySmall?.copyWith(color: cs.error),
              ),
            ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final bool strong;

  const _Row(this.label, this.value, {this.strong = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(label,
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ),
          const SizedBox(width: AppSpace.md),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: strong ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
