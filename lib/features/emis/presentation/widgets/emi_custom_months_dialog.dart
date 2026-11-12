import 'package:flutter/material.dart';
import 'package:duemate/core/utils/date_formatter.dart';

/// Lets the user set a different amount for specific installments.
/// Resolves to the full month → amount map, or null if cancelled.
Future<Map<int, double>?> showEmiCustomMonthsDialog(
  BuildContext context, {
  required int months,
  required double defaultAmount,
  required Map<int, double> current,
  required DateTime Function(int installment) dueDateFor,
  required String currencySymbol,
}) {
  String plain(double v) => v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(2);
  final controllers = {
    for (var i = 1; i <= months; i++) i: TextEditingController(text: plain(current[i] ?? defaultAmount)),
  };

  return showDialog<Map<int, double>>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Uneven months'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Set a different amount for specific months, for example when the first month includes a fee.',
                style: Theme.of(ctx).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              for (var m = 1; m <= months; m++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: TextField(
                    controller: controllers[m],
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Month $m (${DateFormatter.formatShortDate(dueDateFor(m))})',
                      prefixText: '$currencySymbol ',
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop({
            for (var m = 1; m <= months; m++)
              m: double.tryParse(controllers[m]!.text.trim()) ?? defaultAmount,
          }),
          child: const Text('Apply'),
        ),
      ],
    ),
  ).whenComplete(() {
    for (final c in controllers.values) {
      c.dispose();
    }
  });
}
