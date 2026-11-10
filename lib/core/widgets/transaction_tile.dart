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
    final isReceived = transaction.type == TransactionType.paymentReceived;
    final color = isReceived ? const Color(0xFF16A34A) : const Color(0xFFDC2626);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon Badge
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isReceived ? Icons.arrow_downward_rounded : Icons.arrow_outward_rounded,
                color: color,
                size: 22,
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
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        )
                      else
                        Expanded(
                          child: Text(
                            transaction.type.label,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      // Amount
                      Text(
                        '${isReceived ? '+' : '-'}${CurrencyFormatter.format(transaction.amount, symbol: currencySymbol)}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: color,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Metadata row: Payment Method Chip, Date, Note
                  Row(
                    children: [
                      // Payment method chip
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              transaction.paymentMethod.icon,
                              size: 11,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              transaction.paymentMethod.label,
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
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
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                          fontSize: 11,
                        ),
                      ),

                      if (transaction.note != null && transaction.note!.trim().isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '• "${transaction.note!.trim()}"',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
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
