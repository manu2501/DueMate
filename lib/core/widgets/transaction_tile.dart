import 'package:flutter/material.dart';
import 'package:smarava/core/constants/app_constants.dart';
import 'package:smarava/core/utils/currency_formatter.dart';
import 'package:smarava/core/utils/date_formatter.dart';
import 'package:smarava/data/database/tables.dart';
import 'package:smarava/domain/entities/ledger_transaction.dart';
import 'package:smarava/domain/entities/person.dart';

class TransactionTile extends StatelessWidget {
  final LedgerTransaction transaction;
  final Person? person;
  final String currencySymbol;
  final VoidCallback? onTap;

  const TransactionTile({
    super.key,
    required this.transaction,
    this.person,
    this.currencySymbol = '₹',
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isReceived = transaction.type == TransactionType.paymentReceived;

    final fgColor = isReceived ? colorScheme.primary : colorScheme.error;
    final bgColor = isReceived ? colorScheme.primaryContainer : colorScheme.errorContainer;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Leading Icon Avatar
            CircleAvatar(
              radius: 20,
              backgroundColor: bgColor,
              child: Icon(
                isReceived ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                color: fgColor,
                size: 18,
              ),
            ),
            const SizedBox(width: 14),

            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (person != null)
                        Expanded(
                          child: Text(
                            person!.name,
                            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        )
                      else
                        Expanded(
                          child: Text(
                            transaction.type.label,
                            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                      // Amount
                      Text(
                        '${isReceived ? '+' : '-'}${CurrencyFormatter.format(transaction.amount, symbol: currencySymbol)}',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: fgColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Metadata row: Payment Method Chip, Date, Note
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              transaction.paymentMethod.icon,
                              size: 11,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              transaction.paymentMethod.label,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Relative Date
                      Text(
                        DateFormatter.formatRelative(transaction.transactionDate),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),

                      if (transaction.note != null && transaction.note!.trim().isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '• "${transaction.note!.trim()}"',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontStyle: FontStyle.italic,
                              fontSize: 11,
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
          ],
        ),
      ),
    );
  }
}
