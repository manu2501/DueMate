import 'package:flutter/material.dart';
import 'package:duemate/core/theme/app_theme.dart';
import 'package:duemate/core/utils/currency_formatter.dart';
import 'package:duemate/data/providers/app_providers.dart';

/// Net position plus the two sides of the ledger. Flat, theme-driven, no
/// gradients: the number is the hero.
class DashboardStatsCard extends StatelessWidget {
  final DashboardTotals totals;
  final String currencySymbol;

  const DashboardStatsCard({
    super.key,
    required this.totals,
    required this.currencySymbol,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final ledger = LedgerColors.of(context);

    final totalGiven = totals.totalGiven;
    final totalReceived = totals.totalReceived;
    final double progress =
        totalGiven > 0 ? (totalReceived / totalGiven).clamp(0.0, 1.0) : 1.0;
    final int percentRecovered = (progress * 100).round();
    final netBalance = totals.netBalance;
    final isSurplus = netBalance >= 0;

    String money(double v) => CurrencyFormatter.format(v, symbol: currencySymbol);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.screenGutter),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: cs.outlineVariant),
        ),
        padding: const EdgeInsets.all(AppSpace.lg + 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Net Ledger Balance',
              style: theme.textTheme.labelLarge
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpace.xs),
            Text(
              '${isSurplus ? '' : '−'}${money(netBalance.abs())}',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: isSurplus ? ledger.owedToYou : ledger.youOwe,
              ),
            ),
            Text(
              isSurplus ? 'More owed to you than you owe' : 'You owe more than is owed to you',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpace.lg),
            Row(
              children: [
                Expanded(
                  child: _Figure(
                    label: "You'll get",
                    value: money(totals.totalTheyOwe),
                    caption: totals.peopleOweUserCount == 1
                        ? '1 person'
                        : '${totals.peopleOweUserCount} people',
                    color: ledger.owedToYou,
                  ),
                ),
                Container(width: 1, height: 44, color: cs.outlineVariant),
                const SizedBox(width: AppSpace.lg),
                Expanded(
                  child: _Figure(
                    label: 'You owe',
                    value: money(totals.totalUserOwes),
                    caption: totals.peopleUserOwesCount == 1
                        ? '1 person'
                        : '${totals.peopleUserOwesCount} people',
                    color: totals.totalUserOwes > 0
                        ? ledger.youOwe
                        : cs.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Recovered so far',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: cs.onSurfaceVariant)),
                Text('$percentRecovered%',
                    style: theme.textTheme.labelMedium),
              ],
            ),
            const SizedBox(height: AppSpace.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: cs.surfaceContainerHigh,
                valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  final String label;
  final String value;
  final String caption;
  final Color color;

  const _Figure({
    required this.label,
    required this.value,
    required this.caption,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: theme.textTheme.bodySmall?.copyWith(color: muted)),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium
              ?.copyWith(color: color, fontWeight: FontWeight.w600),
        ),
        Text(caption,
            style: theme.textTheme.bodySmall?.copyWith(color: muted)),
      ],
    );
  }
}
