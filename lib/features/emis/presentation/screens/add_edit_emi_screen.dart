import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import 'package:duemate/core/utils/date_formatter.dart';
import 'package:duemate/core/widgets/avatar_widget.dart';
import 'package:duemate/core/widgets/person_picker_sheet.dart';
import 'package:duemate/data/providers/app_providers.dart';
import 'package:duemate/domain/entities/credit_card_emi.dart';

class AddEditEmiScreen extends ConsumerStatefulWidget {
  final String? initialPersonId;
  final CreditCardEmi? emiToEdit;

  const AddEditEmiScreen({
    super.key,
    this.initialPersonId,
    this.emiToEdit,
  });

  static Future<bool?> show(BuildContext context, {String? personId, CreditCardEmi? emi}) {
    return Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddEditEmiScreen(
          initialPersonId: personId,
          emiToEdit: emi,
        ),
      ),
    );
  }

  @override
  ConsumerState<AddEditEmiScreen> createState() => _AddEditEmiScreenState();
}

class _AddEditEmiScreenState extends ConsumerState<AddEditEmiScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _itemController;
  late final TextEditingController _cardController;
  late final TextEditingController _totalAmountController;
  late final TextEditingController _monthlyInstallmentController;
  late final TextEditingController _notesController;

  String? _selectedPersonId;
  bool _isPaidByMe = true;
  int _tenureMonths = 6;
  DateTime _startDate = DateTime.now();
  int _dueDayOfMonth = DateTime.now().day;
  bool _isSaving = false;
  bool _manualMonthlyEdit = false;

  final List<String> _bankSuggestions = [
    'HDFC',
    'ICICI',
    'SBI',
    'Axis',
    'Amex',
    'Kotak',
    'OneCard',
  ];

  final List<String> _itemSuggestions = [
    'iPhone',
    'MacBook',
    'Flight Tickets',
    'Smart Watch',
    'TV',
    'Furniture',
  ];

  final List<int> _tenureOptions = [3, 6, 9, 12, 18, 24];

  bool get isEditing => widget.emiToEdit != null;

  @override
  void initState() {
    super.initState();
    final emi = widget.emiToEdit;
    _selectedPersonId = emi?.personId ?? widget.initialPersonId;
    _itemController = TextEditingController(text: emi?.itemName ?? '');
    _cardController = TextEditingController(text: emi?.cardName ?? '');
    _totalAmountController = TextEditingController(
      text: emi != null ? emi.totalAmount.toStringAsFixed(0) : '',
    );
    _monthlyInstallmentController = TextEditingController(
      text: emi != null ? emi.monthlyInstallment.toStringAsFixed(0) : '',
    );
    _notesController = TextEditingController(text: emi?.notes ?? '');

    if (emi != null) {
      _isPaidByMe = emi.isPaidByMe;
      _tenureMonths = emi.totalTenureMonths;
      _startDate = emi.startDate;
      _dueDayOfMonth = emi.dueDayOfMonth;
      _manualMonthlyEdit = true;
    }

    _totalAmountController.addListener(_onTotalAmountChanged);
  }

  @override
  void dispose() {
    _itemController.dispose();
    _cardController.dispose();
    _totalAmountController.removeListener(_onTotalAmountChanged);
    _totalAmountController.dispose();
    _monthlyInstallmentController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _onTotalAmountChanged() {
    if (_manualMonthlyEdit) return;
    final total = double.tryParse(_totalAmountController.text.trim()) ?? 0.0;
    if (total > 0 && _tenureMonths > 0) {
      final monthly = (total / _tenureMonths).roundToDouble();
      _monthlyInstallmentController.text = monthly.toStringAsFixed(0);
    }
  }

  void _recalcMonthly() {
    final total = double.tryParse(_totalAmountController.text.trim()) ?? 0.0;
    if (total > 0 && _tenureMonths > 0) {
      final monthly = (total / _tenureMonths).roundToDouble();
      _monthlyInstallmentController.text = monthly.toStringAsFixed(0);
      setState(() => _manualMonthlyEdit = false);
    }
  }

  Future<void> _pickPerson() async {
    final pickedId = await PersonPickerSheet.show(
      context,
      currentSelectedPersonId: _selectedPersonId,
    );
    if (pickedId != null && mounted) {
      setState(() => _selectedPersonId = pickedId);
    }
  }

  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && mounted) {
      setState(() {
        _startDate = picked;
        _dueDayOfMonth = picked.day;
      });
    }
  }

  Future<void> _saveEmi() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedPersonId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a person')),
      );
      return;
    }

    final totalAmount = double.tryParse(_totalAmountController.text.trim()) ?? 0.0;
    final monthly = double.tryParse(_monthlyInstallmentController.text.trim()) ?? (totalAmount / _tenureMonths);

    if (totalAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid total amount')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final emiRepo = ref.read(emiRepositoryProvider);
      final processor = ref.read(emiProcessorServiceProvider);

      if (isEditing) {
        final current = widget.emiToEdit!;
        final updated = current.copyWith(
          personId: _selectedPersonId!,
          itemName: _itemController.text.trim(),
          cardName: _cardController.text.trim(),
          totalAmount: totalAmount,
          monthlyInstallment: monthly,
          totalTenureMonths: _tenureMonths,
          startDate: _startDate,
          dueDayOfMonth: _dueDayOfMonth,
          isPaidByMe: _isPaidByMe,
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
          updatedAt: DateTime.now(),
        );
        await emiRepo.updateEmi(updated);
      } else {
        final newEmi = CreditCardEmi(
          id: const Uuid().v4(),
          personId: _selectedPersonId!,
          itemName: _itemController.text.trim(),
          cardName: _cardController.text.trim(),
          totalAmount: totalAmount,
          monthlyInstallment: monthly,
          totalTenureMonths: _tenureMonths,
          installmentsPaid: 0,
          startDate: _startDate,
          dueDayOfMonth: _dueDayOfMonth,
          isPaidByMe: _isPaidByMe,
          status: 'active',
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await emiRepo.createEmi(newEmi);
      }

      // Check and process any pending installments right away (e.g. if started in past)
      await processor.processDueInstallments();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isEditing ? 'EMI updated successfully' : 'Credit Card EMI added successfully',
            ),
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving EMI: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final currencySymbol = ref.watch(currencySymbolProvider);
    final personsMap = ref.watch(personsMapProvider);

    final selectedPerson = _selectedPersonId != null ? personsMap[_selectedPersonId] : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditing ? 'Edit Credit Card EMI' : 'Add Credit Card EMI',
          style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveEmi,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    isEditing ? 'Save' : 'Create',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: cs.primary,
                    ),
                  ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            // 1. Person Selector Card
            Text(
              'Shared With',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: _pickPerson,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _selectedPersonId == null ? cs.outlineVariant : cs.primary.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    if (selectedPerson != null) ...[
                      AvatarWidget(
                        name: selectedPerson.name,
                        radius: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              selectedPerson.name,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (selectedPerson.phone != null)
                              Text(
                                selectedPerson.phone!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: _pickPerson,
                        child: const Text('Change'),
                      ),
                    ] else ...[
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.person_add_outlined, color: cs.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Select person to share EMI with',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // 2. Direction Toggle (Who paid with whose card?)
            Text(
              'Card Ownership & Repayment Flow',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _isPaidByMe = true),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _isPaidByMe ? cs.primary.withValues(alpha: 0.1) : cs.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _isPaidByMe ? cs.primary : cs.outlineVariant,
                          width: _isPaidByMe ? 1.5 : 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.credit_card_rounded,
                                size: 18,
                                color: _isPaidByMe ? cs.primary : cs.onSurfaceVariant,
                              ),
                              const Spacer(),
                              if (_isPaidByMe)
                                Icon(Icons.check_circle_rounded, size: 16, color: cs.primary),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'My Card',
                            style: GoogleFonts.dmSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: _isPaidByMe ? cs.primary : cs.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Friend owes me monthly',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _isPaidByMe = false),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: !_isPaidByMe ? cs.error.withValues(alpha: 0.1) : cs.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: !_isPaidByMe ? cs.error : cs.outlineVariant,
                          width: !_isPaidByMe ? 1.5 : 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.payment_rounded,
                                size: 18,
                                color: !_isPaidByMe ? cs.error : cs.onSurfaceVariant,
                              ),
                              const Spacer(),
                              if (!_isPaidByMe)
                                Icon(Icons.check_circle_rounded, size: 16, color: cs.error),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Friend's Card",
                            style: GoogleFonts.dmSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: !_isPaidByMe ? cs.error : cs.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'I owe friend monthly',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // 3. Purchase Item Name & Suggestions
            TextFormField(
              controller: _itemController,
              decoration: InputDecoration(
                labelText: 'Item / Purchase Name *',
                hintText: 'e.g. iPhone 16 Pro, Flight Tickets',
                prefixIcon: const Icon(Icons.shopping_bag_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
              validator: (v) => v == null || v.trim().isEmpty ? 'Please enter item name' : null,
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _itemSuggestions.map((item) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ActionChip(
                      label: Text(item, style: const TextStyle(fontSize: 12)),
                      onPressed: () {
                        _itemController.text = item;
                      },
                      visualDensity: VisualDensity.compact,
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 18),

            // 4. Credit Card Name & Bank Chips
            TextFormField(
              controller: _cardController,
              decoration: InputDecoration(
                labelText: 'Credit Card Name / Bank *',
                hintText: 'e.g. HDFC Millennia, ICICI Amazon Pay',
                prefixIcon: const Icon(Icons.credit_card_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
              validator: (v) => v == null || v.trim().isEmpty ? 'Please enter credit card name' : null,
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _bankSuggestions.map((bank) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ActionChip(
                      label: Text(bank, style: const TextStyle(fontSize: 12)),
                      onPressed: () {
                        if (_cardController.text.trim().isEmpty) {
                          _cardController.text = '$bank Credit Card';
                        } else if (!_cardController.text.contains(bank)) {
                          _cardController.text = '$bank ${_cardController.text}'.trim();
                        }
                      },
                      visualDensity: VisualDensity.compact,
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 18),

            // 5. Total Amount
            TextFormField(
              controller: _totalAmountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: GoogleFonts.dmSans(fontSize: 20, fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                labelText: 'Total Purchase Amount *',
                hintText: '0',
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(left: 14, right: 8),
                  child: Center(
                    widthFactor: 0.0,
                    child: Text(
                      currencySymbol,
                      style: GoogleFonts.dmSans(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Please enter total amount';
                final n = double.tryParse(v.trim());
                if (n == null || n <= 0) return 'Please enter a valid amount';
                return null;
              },
            ),

            const SizedBox(height: 18),

            // 6. Tenure Selection
            Text(
              'Tenure (Months)',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _tenureOptions.map((months) {
                final isSelected = _tenureMonths == months;
                return ChoiceChip(
                  label: Text('$months mo'),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _tenureMonths = months;
                        _recalcMonthly();
                      });
                    }
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: 18),

            // 7. Monthly Installment (Auto-calculated, editable)
            TextFormField(
              controller: _monthlyInstallmentController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) {
                _manualMonthlyEdit = true;
              },
              decoration: InputDecoration(
                labelText: 'Monthly Installment *',
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(left: 14, right: 8),
                  child: Center(
                    widthFactor: 0.0,
                    child: Text(
                      currencySymbol,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                suffixIcon: IconButton(
                  tooltip: 'Reset to standard calculation',
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  onPressed: _recalcMonthly,
                ),
                helperText: 'Auto-calculated. Adjust if your bank charges interest or fees.',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Enter monthly installment';
                final n = double.tryParse(v.trim());
                if (n == null || n <= 0) return 'Invalid monthly amount';
                return null;
              },
            ),

            const SizedBox(height: 18),

            // 8. Start Date & Due Day of Month
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _selectStartDate,
                    borderRadius: BorderRadius.circular(14),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Start Date',
                        prefixIcon: const Icon(Icons.calendar_month_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(
                        DateFormatter.formatDate(_startDate),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _dueDayOfMonth,
                    decoration: InputDecoration(
                      labelText: 'Monthly Due Day',
                      prefixIcon: const Icon(Icons.event_repeat_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    items: List.generate(31, (i) => i + 1).map((day) {
                      return DropdownMenuItem(
                        value: day,
                        child: Text(
                          '${day.toString().padLeft(2, '0')}th of month',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _dueDayOfMonth = val);
                      }
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: Row(
                children: [
                  Icon(Icons.auto_mode_rounded, size: 18, color: cs.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Every month on the ${_dueDayOfMonth.toString().padLeft(2, '0')}th, DueMate will automatically add an installment entry to the ledger.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // 9. Notes
            TextFormField(
              controller: _notesController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Notes (Optional)',
                hintText: 'Order ID, invoice details, bank reference...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),

            const SizedBox(height: 28),

            // 10. Save Button
            FilledButton(
              onPressed: _isSaving ? null : _saveEmi,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      isEditing ? 'Save Changes' : 'Start Monthly EMI Tracking',
                      style: GoogleFonts.dmSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
