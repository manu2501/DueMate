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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final personName = person?.name ?? 'the borrower';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Transaction?', style: TextStyle(color: colorScheme.error)),
        content: Text(
          'Are you sure you want to delete this transaction?\n\n'
          'Deleting this will recalculate $personName\'s outstanding balance.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: colorScheme.error, foregroundColor: colorScheme.onError),
            onPressed: () async {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
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
          final theme = Theme.of(context);
          final colorScheme = theme.colorScheme;

          return AlertDialog(
            title: Text('Edit ${transaction.type.label}'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Amount',
                      prefixText: '₹ ',
                    ),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<PaymentMethod>(
                    initialValue: selectedMethod,
                    decoration: const InputDecoration(labelText: 'Payment Method'),
                    items: PaymentMethod.values.map((method) {
                      return DropdownMenuItem(
                        value: method,
                        child: Row(
                          children: [
                            Icon(method.icon, size: 16),
                            const SizedBox(width: 8),
                            Text(method.label),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => selectedMethod = val);
                    },
                  ),
                  const SizedBox(height: 14),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Date', style: TextStyle(fontSize: 13)),
                    subtitle: Text(
                      DateFormatter.formatDate(selectedDate),
                      style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold),
                    ),
                    trailing: const Icon(Icons.calendar_today_rounded, size: 20),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) setState(() => selectedDate = picked);
                    },
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: noteController,
                    decoration: const InputDecoration(
                      labelText: 'Optional Note',
                      hintText: 'e.g. Loan instalment',
                    ),
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
                child: const Text('Save Changes'),
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
    final colorScheme = theme.colorScheme;
    final currencySymbol = ref.watch(currencySymbolProvider);
    final isReceived = transaction.type == TransactionType.paymentReceived;
    final color = isReceived ? colorScheme.primary : colorScheme.error;

    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      title: Row(
        children: [
          CircleAvatar(
            backgroundColor: isReceived ? colorScheme.primaryContainer : colorScheme.errorContainer,
            child: Icon(
              isReceived ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.type.label,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                if (person != null)
                  Text(
                    person!.name,
                    style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
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
            Divider(height: 24, color: colorScheme.outlineVariant.withValues(alpha: 0.4)),
            Center(
              child: Text(
                CurrencyFormatter.format(transaction.amount, symbol: currencySymbol),
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: color,
                ),
              ),
            ),
            const SizedBox(height: 18),
            _infoRow('Date', DateFormatter.formatDate(transaction.transactionDate), theme),
            _infoRow('Time', DateFormatter.formatTime(transaction.transactionDate), theme),
            _infoRow('Payment Method', transaction.paymentMethod.label, theme),
            if (transaction.note != null && transaction.note!.isNotEmpty)
              _infoRow('Note', transaction.note!, theme),
            _infoRow('Recorded On', DateFormatter.formatDateTime(transaction.createdAt), theme),
          ],
        ),
      ),
      actions: [
        IconButton(
          tooltip: 'Delete Transaction',
          onPressed: () => _confirmDelete(context, ref),
          icon: Icon(Icons.delete_outline_rounded, color: colorScheme.error),
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

  Widget _infoRow(String label, String value, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
