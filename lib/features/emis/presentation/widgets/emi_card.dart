import 'package:flutter/material.dart';
import 'package:duemate/core/theme/app_theme.dart';
import 'package:duemate/core/utils/currency_formatter.dart';
import 'package:duemate/core/utils/date_formatter.dart';
import 'package:duemate/core/widgets/ui_kit.dart';
import 'package:duemate/domain/entities/credit_card_emi.dart';
import 'package:duemate/domain/entities/person.dart';
import 'package:duemate/features/emis/presentation/widgets/emi_details_sheet.dart';

/// An EMI or loan as a list row: what, how far along, what's next.
/// Designed to sit inside a [GroupCard].
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

  /// Who pays whom, in plain words. Null for the user's own EMIs.
  static String? relation(CreditCardEmi emi, Person? person) {
    if (emi.isForSelf) return null;
    final name = person?.name ?? 'They';
    if (emi.isLoan) return emi.isPaidByMe ? '$name repays you' : 'You repay $name';
    return emi.isPaidByMe ? 'On your card for $name' : 'On $name\'s card for you';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final done = emi.isCompleted;
    final next = emi.nextDueDate;

    final status = done
        ? 'Completed'
        : '${emi.installmentsPaid} of ${emi.totalTenureMonths} paid'
            '${next != null ? ' · next ${DateFormatter.formatShortDate(next)}' : ''}';
    final rel = relation(emi, person);

    return InkWell(
      onTap: onTap ?? () => EmiDetailsSheet.show(context, emi: emi, person: person),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpace.screenGutter, AppSpace.md, AppSpace.screenGutter, AppSpace.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconBadge(emi.isLoan ? Icons.account_balance_outlined : Icons.credit_card_outlined),
            const SizedBox(width: AppSpace.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          emi.itemName,
                          style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: AppSpace.sm),
                      Text(
                        '${CurrencyFormatter.format(emi.monthlyInstallment, symbol: currencySymbol)}/mo',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: done ? cs.onSurfaceVariant : cs.onSurface,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    [emi.cardName, ?rel].join(' · '),
                    style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpace.sm),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: emi.progress,
                      minHeight: 4,
                      color: done ? cs.outline : cs.primary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    status,
                    style: theme.textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
