import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:duemate/core/widgets/amount_field.dart';
import 'package:duemate/data/providers/app_providers.dart';

/// Asks for a new monthly budget and saves it. Used from Expenses and Settings.
Future<void> editMonthlyBudget(BuildContext context, WidgetRef ref) async {
  final current = ref.read(monthlyBudgetLimitProvider);
  final symbol = ref.read(currencySymbolProvider);
  final controller = TextEditingController(text: AmountField.plain(current));
  final value = await showDialog<double>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Monthly budget'),
      content: TextField(
        controller: controller,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
        decoration: InputDecoration(prefixText: '$symbol ', labelText: 'Limit per month'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(double.tryParse(controller.text.trim())),
          child: const Text('Save'),
        ),
      ],
    ),
  );
  controller.dispose();
  if (value != null && value > 0) {
    await ref.read(monthlyBudgetLimitProvider.notifier).setBudget(value);
  }
}
