import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:duemate/core/constants/app_constants.dart';
import 'package:duemate/core/constants/expense_category_x.dart';
import 'package:duemate/core/theme/app_theme.dart';
import 'package:duemate/core/utils/date_formatter.dart';
import 'package:duemate/core/widgets/amount_field.dart';
import 'package:duemate/core/widgets/confirm_dialog.dart';
import 'package:duemate/core/widgets/ui_kit.dart' show ChipRow;
import 'package:duemate/data/database/tables.dart';
import 'package:duemate/data/providers/app_providers.dart';
import 'package:duemate/domain/entities/personal_expense.dart';
import 'package:duemate/domain/entities/recurring_expense.dart';

/// Add or edit a personal expense. Amount first, then what it was.
class AddEditExpenseSheet extends ConsumerStatefulWidget {
  final PersonalExpense? expenseToEdit;

  const AddEditExpenseSheet({super.key, this.expenseToEdit});

  static Future<void> show(BuildContext context, {PersonalExpense? expenseToEdit}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      useRootNavigator: true,
      builder: (_) => AddEditExpenseSheet(expenseToEdit: expenseToEdit),
    );
  }

  @override
  ConsumerState<AddEditExpenseSheet> createState() => _AddEditExpenseSheetState();
}

class _AddEditExpenseSheetState extends ConsumerState<AddEditExpenseSheet> {
  late final TextEditingController _amountController;
  late final TextEditingController _titleController;
  late final TextEditingController _notesController;

  ExpenseCategory _category = ExpenseCategory.groceries;
  PaymentMethod _method = PaymentMethod.upi;
  DateTime _date = DateTime.now();
  bool _isSaving = false;
  bool _repeat = false;

  bool get isEditing => widget.expenseToEdit != null;
  double get _amount => double.tryParse(_amountController.text.trim()) ?? 0;

  @override
  void initState() {
    super.initState();
    final e = widget.expenseToEdit;
    _amountController = TextEditingController(text: e == null ? '' : AmountField.plain(e.amount));
    _titleController = TextEditingController(text: e?.title ?? '');
    _notesController = TextEditingController(text: e?.notes ?? '');
    if (e != null) {
      _category = e.category;
      _method = e.paymentMethod;
      _date = e.expenseDate;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    final amount = _amount;
    if (amount <= 0) {
      messenger.showSnackBar(const SnackBar(content: Text('Enter an amount greater than 0')));
      return;
    }
    // A title is optional; the category says enough for most expenses.
    final title = _titleController.text.trim().isEmpty ? _category.label : _titleController.text.trim();
    final notes = _notesController.text.trim().isEmpty ? null : _notesController.text.trim();

    setState(() => _isSaving = true);
    final now = DateTime.now();
    try {
      final repo = ref.read(expenseRepositoryProvider);
      if (_repeat && !isEditing) {
        final ruleId = const Uuid().v4();
        await ref.read(recurringExpenseRepositoryProvider).createWithFirst(
              RecurringExpense(
                id: ruleId,
                title: title,
                amount: amount,
                category: _category,
                paymentMethod: _method,
                notes: notes,
                dayOfMonth: _date.day,
                startDate: _date,
                createdAt: now,
                updatedAt: now,
              ),
              PersonalExpense(
                id: const Uuid().v4(),
                title: title,
                amount: amount,
                category: _category,
                expenseDate: _date,
                paymentMethod: _method,
                notes: notes,
                recurringId: ruleId,
                createdAt: now,
                updatedAt: now,
              ),
            );
        // Started in an earlier month: post the months since then too.
        await ref.read(recurringExpenseRepositoryProvider).postDue(now);
      } else if (isEditing) {
        await repo.updateExpense(widget.expenseToEdit!.copyWith(
          title: title,
          amount: amount,
          category: _category,
          expenseDate: _date,
          paymentMethod: _method,
          notes: notes,
          updatedAt: now,
        ));
      } else {
        await repo.createExpense(PersonalExpense(
          id: const Uuid().v4(),
          title: title,
          amount: amount,
          category: _category,
          expenseDate: _date,
          paymentMethod: _method,
          notes: notes,
          createdAt: now,
          updatedAt: now,
        ));
      }
      if (mounted) Navigator.of(context).pop();
      messenger.showSnackBar(SnackBar(
        content: Text(isEditing
            ? 'Changes saved'
            : _repeat
                ? 'Expense added. It repeats on the ${ordinal(_date.day)} of every month.'
                : 'Expense added'),
      ));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text("Couldn't save. Please try again.")));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _delete() async {
    final e = widget.expenseToEdit!;
    final ok = await showConfirmDialog(
      context,
      title: 'Delete this expense?',
      message: '"${e.title}" will be removed from your expenses.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(expenseRepositoryProvider);
    Navigator.of(context).pop();
    await repo.deleteExpense(e.id);
    messenger.showSnackBar(const SnackBar(content: Text('Expense deleted')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final symbol = ref.watch(currencySymbolProvider);

    Widget label(String text) => Padding(
          padding: const EdgeInsets.only(top: AppSpace.xl, bottom: AppSpace.sm),
          child: Text(text, style: theme.textTheme.labelLarge?.copyWith(color: cs.onSurfaceVariant)),
        );

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(AppSpace.xl, 0, AppSpace.xl, AppSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(isEditing ? 'Edit expense' : 'Add expense', style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpace.lg),
            AmountField(
              controller: _amountController,
              symbol: symbol,
              autofocus: !isEditing,
              onChanged: () => setState(() {}),
            ),
            label('Category'),
            Wrap(
              spacing: AppSpace.sm,
              runSpacing: AppSpace.sm,
              children: [
                for (final c in ExpenseCategoryX.ordered)
                  ChoiceChip(
                    avatar: Icon(c.icon, size: 18),
                    label: Text(c.label),
                    selected: c == _category,
                    onSelected: (_) => setState(() => _category = c),
                  ),
              ],
            ),
            const SizedBox(height: AppSpace.xl),
            TextField(
              controller: _titleController,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Description (optional)',
                hintText: _category.label,
              ),
            ),
            label('Paid with'),
            ChipRow(
              children: [
                for (final m in PaymentMethodX.ordered)
                  ChoiceChip(
                    label: Text(m.label),
                    selected: m == _method,
                    onSelected: (_) => setState(() => _method = m),
                  ),
              ],
            ),
            const SizedBox(height: AppSpace.xl),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Date', prefixIcon: Icon(Icons.event_outlined)),
                child: Text(DateFormatter.formatRelative(_date)),
              ),
            ),
            if (!isEditing)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Repeat every month'),
                subtitle: Text(_repeat
                    ? 'Added automatically on the ${ordinal(_date.day)} of each month'
                    : 'For rent, subscriptions and bills'),
                value: _repeat,
                onChanged: (v) => setState(() => _repeat = v),
              ),
            const SizedBox(height: AppSpace.lg),
            TextField(
              controller: _notesController,
              maxLines: 2,
              minLines: 1,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Notes (optional)'),
            ),
            const SizedBox(height: AppSpace.xl),
            FilledButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: cs.onPrimary))
                  : Text(isEditing ? 'Save changes' : 'Add expense'),
            ),
            if (isEditing) ...[
              const SizedBox(height: AppSpace.sm),
              TextButton.icon(
                onPressed: _delete,
                style: TextButton.styleFrom(foregroundColor: cs.error),
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Delete expense'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
