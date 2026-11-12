import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:duemate/core/constants/app_constants.dart';
import 'package:duemate/core/constants/expense_category_x.dart';
import 'package:duemate/core/theme/app_theme.dart';
import 'package:duemate/core/utils/date_formatter.dart';
import 'package:duemate/core/widgets/confirm_dialog.dart';
import 'package:duemate/core/widgets/ui_kit.dart';
import 'package:duemate/data/providers/app_providers.dart';
import 'package:duemate/domain/entities/recurring_expense.dart';
import 'package:duemate/features/expenses/presentation/widgets/budget_dialog.dart';

/// "On the 5th · next 5 Dec": when a recurring expense posts.
String recurringScheduleLabel(RecurringExpense r, DateTime now) =>
    'On the ${ordinal(r.dayOfMonth)} · next ${DateFormatter.formatShortDate(r.nextDate(now))}';

/// One repeating expense: what it is, when it posts, and the two things you
/// can do with it. Stopping keeps every expense it already added.
class RecurringExpenseSheet extends ConsumerWidget {
  final RecurringExpense rule;
  const RecurringExpenseSheet({super.key, required this.rule});

  static Future<void> show(BuildContext context, RecurringExpense rule) => showModalBottomSheet(
        context: context,
        useRootNavigator: true,
        showDragHandle: true,
        builder: (_) => RecurringExpenseSheet(rule: rule),
      );

  Future<void> _changeAmount(BuildContext context, WidgetRef ref) async {
    final value = await showAmountDialog(
      context,
      title: 'Change amount',
      label: 'Each month from now on',
      initial: rule.amount,
      symbol: ref.read(currencySymbolProvider),
    );
    if (value == null || !context.mounted) return;
    Navigator.of(context).pop();
    await ref.read(recurringExpenseRepositoryProvider).updateAmount(rule.id, value);
  }

  Future<void> _stop(BuildContext context, WidgetRef ref) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Stop repeating?',
      message: '"${rule.title}" won\'t be added any more. Expenses it already added stay.',
      confirmLabel: 'Stop repeating',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    await ref.read(recurringExpenseRepositoryProvider).delete(rule.id);
    messenger.showSnackBar(SnackBar(content: Text('"${rule.title}" stopped repeating')));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final symbol = ref.watch(currencySymbolProvider);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpace.xl, 0, AppSpace.xl, AppSpace.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                IconBadge(rule.category.icon),
                const SizedBox(width: AppSpace.md),
                Expanded(child: Text(rule.title, style: theme.textTheme.titleLarge)),
              ],
            ),
            const SizedBox(height: AppSpace.lg),
            MoneyText(rule.amount, symbol: symbol, sign: '−', style: theme.textTheme.displaySmall),
            Text(
              'Every month · ${recurringScheduleLabel(rule, DateTime.now())} · ${rule.paymentMethod.label}',
              style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpace.xl),
            OutlinedButton.icon(
              onPressed: () => _changeAmount(context, ref),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Change amount'),
            ),
            const SizedBox(height: AppSpace.sm),
            TextButton.icon(
              onPressed: () => _stop(context, ref),
              style: TextButton.styleFrom(foregroundColor: cs.error),
              icon: const Icon(Icons.event_busy_outlined),
              label: const Text('Stop repeating'),
            ),
          ],
        ),
      ),
    );
  }
}
