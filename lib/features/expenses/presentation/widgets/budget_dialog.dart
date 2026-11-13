import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:duemate/core/widgets/amount_dialog.dart';
import 'package:duemate/data/providers/app_providers.dart';

export 'package:duemate/core/widgets/amount_dialog.dart';

/// Asks for a new monthly budget and saves it. Used from Expenses and Settings.
Future<void> editMonthlyBudget(BuildContext context, WidgetRef ref) async {
  final value = await showAmountDialog(
    context,
    title: 'Monthly budget',
    label: 'Limit per month',
    initial: ref.read(monthlyBudgetLimitProvider),
    symbol: ref.read(currencySymbolProvider),
  );
  if (value != null) await ref.read(monthlyBudgetLimitProvider.notifier).setBudget(value);
}
