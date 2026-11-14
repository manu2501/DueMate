import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:duemate/core/widgets/return_by_field.dart';
import 'package:duemate/core/theme/app_theme.dart';
import 'package:duemate/core/constants/app_constants.dart';
import 'package:duemate/core/widgets/confirm_dialog.dart';
import 'package:duemate/core/utils/currency_formatter.dart';
import 'package:duemate/core/utils/date_formatter.dart';
import 'package:duemate/core/widgets/avatar_widget.dart';
import 'package:duemate/data/database/tables.dart';
import 'package:duemate/data/providers/app_providers.dart';
import 'package:duemate/domain/entities/ledger_transaction.dart';
import 'package:duemate/domain/entities/person.dart';

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
      useRootNavigator: true,
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

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final isSelf = person?.id == AppConstants.selfPersonId;
    final personName = person?.name ?? 'this contact';
    final ok = await showConfirmDialog(
      context,
      title: 'Delete this entry?',
      message: isSelf || person == null
          ? 'This entry will be removed.'
          : "This entry will be removed and $personName's balance will be recalculated.",
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    // Grab what we need before closing the sheet; its context and ref go away.
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(transactionRepositoryProvider);
    Navigator.of(context).pop();
    await repo.deleteTransaction(transaction.id);
    messenger.showSnackBar(const SnackBar(content: Text('Entry deleted')));
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
    DateTime? dueDate = transaction.dueDate;

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
                    decoration: InputDecoration(
                      labelText: 'Amount',
                      prefixText: '${ref.read(currencySymbolProvider)} ',
                    ),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<PaymentMethod>(
                    initialValue: selectedMethod,
                    decoration: const InputDecoration(labelText: 'Paid with'),
                    items: PaymentMethodX.ordered.map((method) {
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
                  if (transaction.isMoneyGiven && !transaction.isEmi) ...[
                    const SizedBox(height: 8),
                    ReturnByField(value: dueDate, from: selectedDate, onChanged: (d) => setState(() => dueDate = d)),
                  ],
                  const SizedBox(height: 8),
                  TextField(
                    controller: noteController,
                    decoration: const InputDecoration(
                      labelText: 'Note (optional)',
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
                    dueDate: dueDate,
                    clearDueDate: dueDate == null,
                    note: noteController.text.trim().isEmpty ? null : noteController.text.trim(),
                    updatedAt: DateTime.now(),
                  );

                  await ref.read(transactionRepositoryProvider).updateTransaction(updatedTx);

                  if (ctx.mounted) Navigator.of(ctx).pop();
                  if (context.mounted) Navigator.of(context).pop();

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Changes saved')),
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
    final cs = theme.colorScheme;
    final currencySymbol = ref.watch(currencySymbolProvider);
    final isReceived = transaction.type == TransactionType.paymentReceived;
    final accentColor = isReceived ? LedgerColors.of(context).cashIn : cs.onSurface;

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
                        isReceived ? 'They paid you' : 'You gave or lent',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
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
                    ref.watch(hideBalancesProvider)
                        ? ref.watch(displayMoneyProvider)(transaction.amount, exact: true)
                        : '${isReceived ? '+' : '-'}${CurrencyFormatter.format(transaction.amount, symbol: currencySymbol)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 34,
                      letterSpacing: -0.8,
                      color: accentColor,
                    ),
                  ),
                  if (person != null && person!.id != AppConstants.selfPersonId) ...[
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
                  _infoRow('Paid with', transaction.paymentMethod.label, theme),
                  if (transaction.dueDate != null) ...[
                    Divider(height: 16, color: cs.outlineVariant),
                    _infoRow('Return by', DateFormatter.formatDate(transaction.dueDate!), theme),
                  ],
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
                        Text('Edit'),
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
