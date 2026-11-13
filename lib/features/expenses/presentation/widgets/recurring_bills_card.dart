import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:duemate/core/constants/expense_category_x.dart';
import 'package:duemate/core/utils/date_formatter.dart';
import 'package:duemate/core/widgets/ui_kit.dart';
import 'package:duemate/data/providers/app_providers.dart';
import 'package:duemate/domain/entities/recurring_expense.dart';
import 'package:duemate/features/expenses/presentation/widgets/recurring_expense_sheet.dart';

/// Monthly repeats (rent, subscriptions) as a plan, kept apart from what was
/// actually spent: one summary row (how many, the monthly total, how many are
/// already added this month) that opens to the rules. Rules show "a month"
/// and their status, never a minus sign: they are not money spent.
class RecurringBillsCard extends ConsumerStatefulWidget {
  final List<RecurringExpense> rules;
  final String symbol;

  const RecurringBillsCard({super.key, required this.rules, required this.symbol});

  @override
  ConsumerState<RecurringBillsCard> createState() => _RecurringBillsCardState();
}

class _RecurringBillsCardState extends ConsumerState<RecurringBillsCard> {
  bool _open = false;

  static bool _addedThisMonth(RecurringExpense r, DateTime now) =>
      r.lastPostedDate != null && r.lastPostedDate!.year == now.year && r.lastPostedDate!.month == now.month;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final money = ref.watch(displayMoneyProvider);
    final now = DateTime.now();
    final rules = widget.rules;
    final total = rules.fold<double>(0, (s, r) => s + r.amount);
    final added = rules.where((r) => _addedThisMonth(r, now)).length;
    final count = rules.length == 1 ? '1 bill' : '${rules.length} bills';

    return GroupCard(
      children: [
        ListTile(
          onTap: () => setState(() => _open = !_open),
          leading: const IconBadge(Icons.autorenew_rounded),
          title: const Text('Repeats every month'),
          subtitle: Text('$count · ${money(total)} a month · $added of ${rules.length} added'),
          trailing: Icon(_open ? Icons.expand_less_rounded : Icons.expand_more_rounded),
        ),
        if (_open)
          for (final r in rules)
            ListTile(
              onTap: () => RecurringExpenseSheet.show(context, r),
              leading: IconBadge(r.category.icon),
              title: Text(r.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                _addedThisMonth(r, now)
                    ? 'Added ${DateFormatter.formatShortDate(r.lastPostedDate!)} · next ${DateFormatter.formatShortDate(r.nextDate(now))}'
                    : recurringScheduleLabel(r, now),
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  MoneyText(r.amount, symbol: widget.symbol, tone: MoneyTone.muted),
                  Text('a month', style: theme.textTheme.bodySmall?.copyWith(color: muted)),
                ],
              ),
            ),
      ],
    );
  }
}
