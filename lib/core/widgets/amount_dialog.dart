import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:duemate/core/widgets/amount_field.dart';

/// Asks for an amount; resolves to it (> 0) or null if cancelled.
Future<double?> showAmountDialog(
  BuildContext context, {
  required String title,
  required String label,
  required double initial,
  required String symbol,
}) async {
  final controller = TextEditingController(text: AmountField.plain(initial));
  final value = await showDialog<double>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
        decoration: InputDecoration(prefixText: '$symbol ', labelText: label),
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
  return value != null && value > 0 ? value : null;
}
