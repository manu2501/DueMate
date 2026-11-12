import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:duemate/core/utils/date_formatter.dart';
import 'package:duemate/core/widgets/pressable_scale.dart';
import 'package:duemate/data/database/tables.dart';
import 'package:duemate/data/providers/app_providers.dart';
import 'package:duemate/domain/entities/personal_expense.dart';

class AddEditExpenseSheet extends ConsumerStatefulWidget {
  final PersonalExpense? expenseToEdit;

  const AddEditExpenseSheet({super.key, this.expenseToEdit});

  static Future<void> show(BuildContext context, {PersonalExpense? expenseToEdit}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddEditExpenseSheet(expenseToEdit: expenseToEdit),
    );
  }

  @override
  ConsumerState<AddEditExpenseSheet> createState() => _AddEditExpenseSheetState();
}

class _AddEditExpenseSheetState extends ConsumerState<AddEditExpenseSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _amountController;
  late final TextEditingController _notesController;

  ExpenseCategory _selectedCategory = ExpenseCategory.groceries;
  PaymentMethod _selectedPaymentMethod = PaymentMethod.upi;
  DateTime _expenseDate = DateTime.now();
  bool _isSaving = false;

  bool get isEditing => widget.expenseToEdit != null;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.expenseToEdit?.title ?? '');
    _amountController = TextEditingController(
      text: widget.expenseToEdit != null ? widget.expenseToEdit!.amount.toStringAsFixed(0) : '',
    );
    _notesController = TextEditingController(text: widget.expenseToEdit?.notes ?? '');

    if (widget.expenseToEdit != null) {
      _selectedCategory = widget.expenseToEdit!.category;
      _selectedPaymentMethod = widget.expenseToEdit!.paymentMethod;
      _expenseDate = widget.expenseToEdit!.expenseDate;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String _getCategoryName(ExpenseCategory category) {
    switch (category) {
      case ExpenseCategory.groceries:
        return '🛒 Groceries';
      case ExpenseCategory.utilities:
        return '⚡ Utilities';
      case ExpenseCategory.rent:
        return '🏠 Rent';
      case ExpenseCategory.fuel:
        return '⛽ Fuel';
      case ExpenseCategory.food:
        return '🍔 Food';
      case ExpenseCategory.shopping:
        return '🛍️ Shopping';
      case ExpenseCategory.entertainment:
        return '🎬 Entertainment';
      case ExpenseCategory.health:
        return '🏥 Health';
      case ExpenseCategory.other:
        return '📦 Other';
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expenseDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _expenseDate = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter an amount greater than 0')),
      );
      return;
    }

    setState(() => _isSaving = true);
    final now = DateTime.now();

    try {
      final repo = ref.read(expenseRepositoryProvider);
      if (isEditing) {
        final updated = widget.expenseToEdit!.copyWith(
          title: _titleController.text.trim(),
          amount: amount,
          category: _selectedCategory,
          expenseDate: _expenseDate,
          paymentMethod: _selectedPaymentMethod,
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
          updatedAt: now,
        );
        await repo.updateExpense(updated);
      } else {
        final newExpense = PersonalExpense(
          id: const Uuid().v4(),
          title: _titleController.text.trim(),
          amount: amount,
          category: _selectedCategory,
          expenseDate: _expenseDate,
          paymentMethod: _selectedPaymentMethod,
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
          createdAt: now,
          updatedAt: now,
        );
        await repo.createExpense(newExpense);
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEditing ? 'Changes saved' : 'Expense added'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't save. Please try again.")),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final currencySymbol = ref.watch(currencySymbolProvider);
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 24 + bottomPadding),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: cs.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.receipt_rounded, color: Color(0xFFF59E0B), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      isEditing ? 'Edit Personal Expense' : 'Log Personal Expense',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Category Chips
                Text(
                  'Expense Category',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ExpenseCategory.values.map((cat) {
                    final isSelected = cat == _selectedCategory;
                    return ChoiceChip(
                      label: Text(_getCategoryName(cat), style: const TextStyle(fontSize: 12)),
                      selected: isSelected,
                      onSelected: (_) => setState(() {
                        _selectedCategory = cat;
                        if (_titleController.text.isEmpty) {
                          _titleController.text = _getCategoryName(cat).split(' ').sublist(1).join(' ');
                        }
                      }),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 18),

                // Title Input
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    hintText: 'e.g. Grocery Shopping, Electricity Bill',
                    prefixIcon: Icon(Icons.shopping_bag_outlined, size: 20),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Please enter a title' : null,
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 16),

                // Amount Input
                TextFormField(
                  controller: _amountController,
                  decoration: InputDecoration(
                    labelText: 'Amount ($currencySymbol)',
                    hintText: '0',
                    prefixText: '$currencySymbol ',
                    prefixIcon: const Icon(Icons.payments_outlined, size: 20),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Please enter an amount';
                    final parsed = double.tryParse(v.trim());
                    if (parsed == null || parsed <= 0) return 'Enter a valid positive number';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Payment Mode Selector
                DropdownButtonFormField<PaymentMethod>(
                  initialValue: _selectedPaymentMethod,
                  decoration: const InputDecoration(
                    labelText: 'Paid with',
                    prefixIcon: Icon(Icons.account_balance_wallet_outlined, size: 20),
                  ),
                  items: const [
                    DropdownMenuItem(value: PaymentMethod.upi, child: Text('UPI')),
                    DropdownMenuItem(value: PaymentMethod.cash, child: Text('Cash')),
                    DropdownMenuItem(value: PaymentMethod.card, child: Text('Card')),
                    DropdownMenuItem(value: PaymentMethod.bankTransfer, child: Text('Bank transfer')),
                    DropdownMenuItem(value: PaymentMethod.other, child: Text('Other')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedPaymentMethod = val);
                  },
                ),
                const SizedBox(height: 16),

                // Date Picker & Notes
                InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(16),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Date',
                      prefixIcon: Icon(Icons.calendar_today_rounded, size: 20),
                      suffixIcon: Icon(Icons.arrow_drop_down_rounded),
                    ),
                    child: Text(
                      DateFormatter.formatDate(_expenseDate),
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    hintText: 'e.g. Monthly supermarket run',
                    prefixIcon: Icon(Icons.notes_rounded, size: 20),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 24),

                // Submit Button
                PressableScale(
                  onTap: _isSaving ? null : _save,
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    height: 54,
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _isSaving ? null : _save,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFF59E0B),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(
                              isEditing ? 'Save Changes' : 'Log Personal Expense',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
