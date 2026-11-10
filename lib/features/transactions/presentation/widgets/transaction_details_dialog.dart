import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smarava/core/constants/app_constants.dart';
import 'package:smarava/core/utils/currency_formatter.dart';
import 'package:smarava/core/utils/date_formatter.dart';
import 'package:smarava/data/database/tables.dart';
import 'package:smarava/data/providers/app_providers.dart';
import 'package:smarava/domain/entities/ledger_transaction.dart';
import 'package:smarava/domain/entities/person.dart';

class TransactionDetailsDialog extends ConsumerWidget {
  final LedgerTransaction transaction;
  final Person? person;

  const TransactionDetailsDialog({
    super.key,
    required this.transaction,
    this.person,
  });

  static Future<void> show(
    BuildContext context, {
    required LedgerTransaction transaction,
    Person? person,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => TransactionDetailsDialog(
        transaction: transaction,
        person: person,
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    final personName = person?.name ?? 'the borrower';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Transaction?'),
        content: Text(
          'Are you sure you want to delete this transaction?\n\n'
          'Deleting this will recalculate $personName\'s outstanding balance.',
          style: const TextStyle(height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            onPressed: () async {
              Navigator.of(ctx).pop(); // Close confirm dialog
              Navigator.of(context).pop(); // Close details dialog
              await ref.read(transactionRepositoryProvider).deleteTransaction(transaction.id);

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Transaction deleted')),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref) {
    final amountController = TextEditingController(
      text: transaction.amount % 1 == 0
          ? transaction.amount.toInt().toString()
          : transaction.amount.toStringAsFixed(2),
    );
    final noteController = TextEditingController(text: transaction.note ?? '');
    DateTime selectedDate = transaction.transactionDate;
    PaymentMethod selectedMethod = transaction.paymentMethod;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          return AlertDialog(
            title: Text('Edit ${transaction.type.label}'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Amount'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<PaymentMethod>(
                    initialValue: selectedMethod,
                    decoration: const InputDecoration(labelText: 'Payment Method'),
                    items: PaymentMethod.values.map((m) {
                      return DropdownMenuItem(
                        value: m,
                        child: Text(m.label),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => selectedMethod = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Date'),
                    subtitle: Text(DateFormatter.formatDate(selectedDate)),
                    trailing: const Icon(Icons.calendar_today_rounded, size: 20),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setState(() => selectedDate = picked);
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: noteController,
                    decoration: const InputDecoration(labelText: 'Note'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  final newAmount = double.tryParse(amountController.text.trim()) ?? 0;
                  if (newAmount <= 0) return;

                  final updatedTx = transaction.copyWith(
                    amount: newAmount,
                    paymentMethod: selectedMethod,
                    transactionDate: selectedDate,
                    note: noteController.text.trim().isEmpty ? null : noteController.text.trim(),
                    updatedAt: DateTime.now(),
                  );

                  await ref.read(transactionRepositoryProvider).updateTransaction(updatedTx);

                  if (ctx.mounted) Navigator.of(ctx).pop();
                  if (context.mounted) Navigator.of(context).pop();

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Transaction updated')),
                    );
                  }
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final currencySymbol = ref.watch(currencySymbolProvider);
    final isReceived = transaction.type == TransactionType.paymentReceived;
    final color = isReceived ? const Color(0xFF16A34A) : const Color(0xFFDC2626);

    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isReceived ? Icons.arrow_downward_rounded : Icons.arrow_outward_rounded,
              color: color,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.type.label,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                if (person != null)
                  Text(
                    person!.name,
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
              ],
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Divider(height: 24),
            Center(
              child: Text(
                CurrencyFormatter.format(transaction.amount, symbol: currencySymbol),
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _infoRow(context, 'Date', DateFormatter.formatDate(transaction.transactionDate)),
            _infoRow(context, 'Time', DateFormatter.formatTime(transaction.transactionDate)),
            _infoRow(context, 'Payment Method', transaction.paymentMethod.label),
            if (transaction.note != null && transaction.note!.isNotEmpty)
              _infoRow(context, 'Note', transaction.note!),
            _infoRow(context, 'Recorded On', DateFormatter.formatDateTime(transaction.createdAt)),
          ],
        ),
      ),
      actions: [
        IconButton(
          tooltip: 'Delete Transaction',
          onPressed: () => _confirmDelete(context, ref),
          icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626)),
        ),
        const Spacer(),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        FilledButton.tonal(
          onPressed: () => _showEditDialog(context, ref),
          child: const Text('Edit'),
        ),
      ],
    );
  }

  Widget _infoRow(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
