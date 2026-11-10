import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smarava/core/constants/app_constants.dart';
import 'package:smarava/core/utils/currency_formatter.dart';
import 'package:smarava/core/utils/date_formatter.dart';
import 'package:smarava/core/widgets/avatar_widget.dart';
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

  /// Opens the transaction details modal sheet
  static Future<void> show(
    BuildContext context, {
    required LedgerTransaction transaction,
    Person? person,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => TransactionDetailsDialog(
        transaction: transaction,
        person: person,
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final personName = person?.name ?? 'the borrower';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Entry?', style: TextStyle(color: cs.error)),
        content: Text(
          'Are you sure you want to delete this record?\n\n'
          'Deleting this will recalculate $personName\'s outstanding balance.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: cs.error,
              foregroundColor: cs.onError,
            ),
            onPressed: () async {
              Navigator.of(ctx).pop(); // Dismiss alert dialog
              Navigator.of(context).pop(); // Dismiss bottom sheet
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
          final cs = theme.colorScheme;

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
                      style: TextStyle(color: cs.primary, fontWeight: FontWeight.bold),
                    ),
                    trailing: const Icon(Icons.calendar_today_rounded, size: 18),
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
    final cs = theme.colorScheme;
    final currencySymbol = ref.watch(currencySymbolProvider);
    final isReceived = transaction.type == TransactionType.paymentReceived;
    final accentColor = isReceived ? cs.primary : cs.error;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header with type badge & close
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isReceived ? Icons.south_west_rounded : Icons.north_east_rounded,
                    color: accentColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        transaction.type.label,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        isReceived ? 'Money received into your ledger' : 'Money lent or advanced',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Large Hero Amount Card
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              decoration: BoxDecoration(
                color: cs.surfaceContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Text(
                    '${isReceived ? '+' : '-'}${CurrencyFormatter.format(transaction.amount, symbol: currencySymbol)}',
                    style: GoogleFonts.dmSans(
                      fontWeight: FontWeight.w800,
                      fontSize: 34,
                      letterSpacing: -0.8,
                      color: accentColor,
                    ),
                  ),
                  if (person != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AvatarWidget(name: person!.name, radius: 12),
                        const SizedBox(width: 8),
                        Text(
                          person!.name,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Metadata rows
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cs.surfaceContainer,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                children: [
                  _infoRow('Date', DateFormatter.formatDate(transaction.transactionDate), theme),
                  Divider(height: 16, color: cs.outlineVariant),
                  _infoRow('Time', DateFormatter.formatTime(transaction.transactionDate), theme),
                  Divider(height: 16, color: cs.outlineVariant),
                  _infoRow('Payment Method', transaction.paymentMethod.label, theme),
                  if (transaction.note != null && transaction.note!.trim().isNotEmpty) ...[
                    Divider(height: 16, color: cs.outlineVariant),
                    _infoRow('Note', transaction.note!.trim(), theme),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Action Buttons Row: Delete, Edit
            Row(
              children: [
                IconButton.filledTonal(
                  tooltip: 'Delete Entry',
                  onPressed: () => _confirmDelete(context, ref),
                  style: IconButton.styleFrom(
                    backgroundColor: cs.errorContainer.withValues(alpha: 0.5),
                    foregroundColor: cs.error,
                    padding: const EdgeInsets.all(14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.delete_outline_rounded, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: () => _showEditDialog(context, ref),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.edit_outlined, size: 18),
                        SizedBox(width: 8),
                        Text('Edit Entry'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value, ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
