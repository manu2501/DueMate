import 'package:flutter/material.dart';
import 'package:duemate/core/constants/app_constants.dart';
import 'package:duemate/core/utils/currency_formatter.dart';
import 'package:duemate/core/utils/date_formatter.dart';
import 'package:duemate/domain/entities/credit_card_emi.dart';
import 'package:duemate/domain/entities/person.dart';
import 'package:duemate/features/emis/presentation/widgets/emi_details_sheet.dart';

class EmiCard extends StatelessWidget {
  final CreditCardEmi emi;
  final Person? person;
  final String currencySymbol;
  final VoidCallback? onTap;

  const EmiCard({
    super.key,
    required this.emi,
    this.person,
    this.currencySymbol = '₹',
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final isCompleted = emi.isCompleted;
    final nextDate = emi.nextDueDate;

    final isLoan = emi.cardName.toLowerCase().contains('loan') ||
        emi.itemName.toLowerCase().contains('loan') ||
        emi.cardName.toLowerCase().contains('cash') ||
        emi.cardName.toLowerCase().contains('transfer') ||
        (emi.notes?.toLowerCase().contains('loan') ?? false);

    final accentColor = isCompleted
        ? cs.primary
        : (isLoan ? const Color(0xFF0D9488) : Theme.of(context).colorScheme.secondary);

    return RepaintBoundary(
      child: InkWell(
        onTap: onTap ?? () => EmiDetailsSheet.show(context, emi: emi, person: person),
        borderRadius: BorderRadius.circular(18),
        child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isCompleted
                ? cs.outlineVariant
                : accentColor.withValues(alpha: 0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Icon + Item & Card Name + Monthly Amount
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isLoan ? Icons.account_balance_wallet_rounded : Icons.credit_card_rounded,
                    color: accentColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        emi.itemName,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              emi.cardName,
                              style: TextStyle(
                                fontSize: 12,
                                color: cs.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (person != null && !emi.isForSelf && person!.id != AppConstants.selfPersonId) ...[
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: Text('•', style: TextStyle(color: cs.outline, fontSize: 12)),
                            ),
                            Flexible(
                              child: Text(
                                person!.name,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: cs.onSurfaceVariant,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      CurrencyFormatter.format(emi.monthlyInstallment, symbol: currencySymbol),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isCompleted
                            ? cs.onSurfaceVariant
                            : (emi.isPaidByMe ? cs.primary : cs.error),
                      ),
                    ),
                    Text(
                      '/ month',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: emi.progress,
                minHeight: 6,
                backgroundColor: cs.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation(accentColor),
              ),
            ),

            const SizedBox(height: 10),

            // Bottom row: Installments counter & Next due date
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: (emi.isForSelf
                                ? cs.primary
                                : (emi.isPaidByMe ? cs.primary : cs.error))
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        emi.isForSelf
                            ? (isLoan ? 'Personal Loan' : 'Self EMI')
                            : (isLoan
                                ? (emi.isPaidByMe
                                    ? '${person?.name ?? 'Contact'} repays'
                                    : 'You repay ${person?.name ?? 'Contact'}')
                                : (emi.isPaidByMe
                                    ? '${person?.name ?? 'Contact'} owes'
                                    : 'You owe ${person?.name ?? 'Contact'}')),
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: emi.isForSelf
                              ? cs.primary
                              : (emi.isPaidByMe ? cs.primary : cs.error),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${emi.installmentsPaid}/${emi.totalTenureMonths} mo',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                Text(
                  isCompleted
                      ? 'Completed'
                      : nextDate != null
                          ? 'Next: ${DateFormatter.formatShortDate(nextDate)}'
                          : 'Due: ${emi.dueDayOfMonth}th',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: isCompleted ? cs.primary : cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  }
}
