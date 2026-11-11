import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import 'package:duemate/core/utils/currency_formatter.dart';
import 'package:duemate/core/utils/date_formatter.dart';
import 'package:duemate/core/widgets/avatar_widget.dart';
import 'package:duemate/core/widgets/person_picker_sheet.dart';
import 'package:duemate/data/providers/app_providers.dart';
import 'package:duemate/domain/entities/credit_card_emi.dart';

class _ItemSuggestion {
  final String label;
  final String fillValue;
  final IconData icon;

  const _ItemSuggestion(this.label, this.fillValue, this.icon);
}

class _CardSuggestion {
  final String name;
  final String fillValue;
  final IconData icon;
  final Color color;

  const _CardSuggestion(this.name, this.fillValue, this.icon, this.color);
}

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
  late final TextEditingController _baseAmountController;
  late final TextEditingController _chargesController;
  late final TextEditingController _monthlyInstallmentController;
  late final TextEditingController _notesController;

  String? _selectedPersonId;
  bool _isPaidByMe = true;
  int _tenureMonths = 6;
  DateTime _startDate = DateTime.now();
  int _dueDayOfMonth = DateTime.now().day;
  bool _isSaving = false;
  bool _manualMonthlyEdit = false;

  final List<_ItemSuggestion> _itemSuggestions = const [
    _ItemSuggestion('iPhone / Mobile', 'iPhone', Icons.phone_iphone_rounded),
    _ItemSuggestion('MacBook / Laptop', 'MacBook Laptop', Icons.laptop_mac_rounded),
    _ItemSuggestion('iPad / Tablet', 'iPad Tablet', Icons.tablet_mac_rounded),
    _ItemSuggestion('Smartwatch', 'Smartwatch', Icons.watch_rounded),
    _ItemSuggestion('Headphones', 'Headphones', Icons.headphones_rounded),
    _ItemSuggestion('Smart TV', 'Smart TV', Icons.tv_rounded),
    _ItemSuggestion('Air Conditioner', 'Air Conditioner', Icons.ac_unit_rounded),
    _ItemSuggestion('Refrigerator', 'Refrigerator', Icons.kitchen_rounded),
    _ItemSuggestion('Washing Machine', 'Washing Machine', Icons.local_laundry_service_rounded),
    _ItemSuggestion('Flight Tickets', 'Flight Tickets', Icons.flight_takeoff_rounded),
    _ItemSuggestion('Hotel / Stay', 'Hotel Booking', Icons.hotel_rounded),
    _ItemSuggestion('Camera / Gadget', 'Camera', Icons.photo_camera_rounded),
    _ItemSuggestion('Bike / Scooter', 'Two Wheeler', Icons.two_wheeler_rounded),
    _ItemSuggestion('Furniture / Sofa', 'Furniture', Icons.chair_rounded),
    _ItemSuggestion('Jewelry / Gold', 'Jewelry', Icons.diamond_rounded),
    _ItemSuggestion('Medical / Dental', 'Medical Treatment', Icons.local_hospital_rounded),
    _ItemSuggestion('Course / Study', 'Education Course', Icons.school_rounded),
    _ItemSuggestion('Microwave / Oven', 'Microwave Oven', Icons.microwave_rounded),
    _ItemSuggestion('Gaming / PS5', 'Gaming Console', Icons.sports_esports_rounded),
    _ItemSuggestion('Shopping / Clothes', 'Shopping', Icons.shopping_bag_outlined),
  ];

  final List<_CardSuggestion> _cardSuggestions = const [
    _CardSuggestion('HDFC Bank', 'HDFC Credit Card', Icons.account_balance_rounded, Color(0xFF004C8F)),
    _CardSuggestion('ICICI Bank', 'ICICI Credit Card', Icons.credit_card_rounded, Color(0xFFB02A30)),
    _CardSuggestion('SBI Card', 'SBI Credit Card', Icons.credit_score_rounded, Color(0xFF0A66C2)),
    _CardSuggestion('Axis Bank', 'Axis Credit Card', Icons.account_balance_wallet_rounded, Color(0xFF97144D)),
    _CardSuggestion('Kotak', 'Kotak Credit Card', Icons.account_balance_rounded, Color(0xFFED1C24)),
    _CardSuggestion('Amex', 'Amex Credit Card', Icons.credit_card_rounded, Color(0xFF0077A6)),
    _CardSuggestion('OneCard', 'OneCard', Icons.style_rounded, Color(0xFF1E293B)),
    _CardSuggestion('IndusInd', 'IndusInd Credit Card', Icons.account_balance_rounded, Color(0xFF8B1D24)),
    _CardSuggestion('RBL Bank', 'RBL Credit Card', Icons.credit_card_rounded, Color(0xFF0B3B60)),
    _CardSuggestion('IDFC FIRST', 'IDFC FIRST Card', Icons.account_balance_rounded, Color(0xFF861F41)),
    _CardSuggestion('Federal Bank', 'Federal Credit Card', Icons.account_balance_rounded, Color(0xFF002B49)),
    _CardSuggestion('Standard Chartered', 'StanChart Card', Icons.credit_card_rounded, Color(0xFF009933)),
    _CardSuggestion('Bank of Baroda', 'BOB Credit Card', Icons.account_balance_rounded, Color(0xFFE84E1B)),
    _CardSuggestion('HSBC', 'HSBC Credit Card', Icons.account_balance_rounded, Color(0xFFDB0011)),
    _CardSuggestion('AU Small Finance', 'AU Bank Card', Icons.credit_card_rounded, Color(0xFF6B21A8)),
    _CardSuggestion('Yes Bank', 'Yes Bank Card', Icons.account_balance_rounded, Color(0xFF005A9C)),
    _CardSuggestion('PNB', 'PNB Credit Card', Icons.account_balance_rounded, Color(0xFF9A1B2F)),
    _CardSuggestion('Canara Bank', 'Canara Bank Card', Icons.account_balance_rounded, Color(0xFF00529B)),
    _CardSuggestion('Union Bank', 'Union Bank Card', Icons.account_balance_rounded, Color(0xFF003366)),
  ];

  final List<int> _tenureOptions = [3, 6, 9, 12, 18, 24, 36];

  bool get isEditing => widget.emiToEdit != null;

  double get _baseAmount => double.tryParse(_baseAmountController.text.trim()) ?? 0.0;
  double get _charges => double.tryParse(_chargesController.text.trim()) ?? 0.0;
  double get _totalPayable => _baseAmount + _charges;

  @override
  void initState() {
    super.initState();
    final emi = widget.emiToEdit;
    _selectedPersonId = emi?.personId ?? widget.initialPersonId;
    _itemController = TextEditingController(text: emi?.itemName ?? '');
    _cardController = TextEditingController(text: emi?.cardName ?? '');
    _baseAmountController = TextEditingController(
      text: emi != null ? emi.totalAmount.toStringAsFixed(0) : '',
    );
    _chargesController = TextEditingController(text: '');
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

    _baseAmountController.addListener(_onAmountOrChargesChanged);
    _chargesController.addListener(_onAmountOrChargesChanged);
  }

  @override
  void dispose() {
    _itemController.dispose();
    _cardController.dispose();
    _baseAmountController.removeListener(_onAmountOrChargesChanged);
    _chargesController.removeListener(_onAmountOrChargesChanged);
    _baseAmountController.dispose();
    _chargesController.dispose();
    _monthlyInstallmentController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _onAmountOrChargesChanged() {
    setState(() {});
    if (_manualMonthlyEdit) return;

    if (_totalPayable > 0 && _tenureMonths > 0) {
      final monthly = (_totalPayable / _tenureMonths).roundToDouble();
      _monthlyInstallmentController.text = monthly.toStringAsFixed(0);
    }
  }

  void _recalcMonthly() {
    if (_totalPayable > 0 && _tenureMonths > 0) {
      final monthly = (_totalPayable / _tenureMonths).roundToDouble();
      _monthlyInstallmentController.text = monthly.toStringAsFixed(0);
      setState(() => _manualMonthlyEdit = false);
    }
  }

  void _applyQuickCharge(double add) {
    final current = _charges;
    final updated = current + add;
    _chargesController.text = updated % 1 == 0 ? updated.toInt().toString() : updated.toStringAsFixed(2);
    _manualMonthlyEdit = false;
    _onAmountOrChargesChanged();
  }

  void _applyGstCharge(double percent) {
    if (_baseAmount <= 0) return;
    final gst = (_baseAmount * (percent / 100.0)).roundToDouble();
    final updated = _charges + gst;
    _chargesController.text = updated.toStringAsFixed(0);
    _manualMonthlyEdit = false;
    _onAmountOrChargesChanged();
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

    final totalAmount = _totalPayable;
    final monthly = double.tryParse(_monthlyInstallmentController.text.trim()) ?? (totalAmount / _tenureMonths);

    if (totalAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final emiRepo = ref.read(emiRepositoryProvider);
      final processor = ref.read(emiProcessorServiceProvider);

      String? finalNotes = _notesController.text.trim().isEmpty ? null : _notesController.text.trim();
      if (_charges > 0) {
        final breakdown = 'Base: ₹${_baseAmount.toStringAsFixed(0)} + Charges: ₹${_charges.toStringAsFixed(0)}';
        finalNotes = finalNotes != null ? '$finalNotes\n($breakdown)' : breakdown;
      }

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
          notes: finalNotes,
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
          notes: finalNotes,
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

            // 3. Purchase Item Name & Suggestion Chips with Icons
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
            Text(
              'Quick Item Suggestions:',
              style: GoogleFonts.inter(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _itemSuggestions.map((item) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      avatar: Icon(item.icon, size: 16, color: cs.primary),
                      label: Text(item.label, style: const TextStyle(fontSize: 12)),
                      onPressed: () {
                        _itemController.text = item.fillValue;
                      },
                      visualDensity: VisualDensity.compact,
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 20),

            // 4. Credit Card Name & Bank Chips with Signature Icons & Colors
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
            Text(
              'Popular Banks & Cards:',
              style: GoogleFonts.inter(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _cardSuggestions.map((bank) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      avatar: CircleAvatar(
                        radius: 8,
                        backgroundColor: bank.color.withValues(alpha: 0.15),
                        child: Icon(bank.icon, size: 12, color: bank.color),
                      ),
                      label: Text(
                        bank.name,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: bank.color),
                      ),
                      onPressed: () {
                        if (_cardController.text.trim().isEmpty) {
                          _cardController.text = bank.fillValue;
                        } else if (!_cardController.text.contains(bank.name)) {
                          _cardController.text = '${bank.name} ${_cardController.text}'.trim();
                        }
                      },
                      visualDensity: VisualDensity.compact,
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 22),

            // 5. Purchase / Base Amount Field
            TextFormField(
              controller: _baseAmountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: GoogleFonts.dmSans(fontSize: 20, fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                labelText: 'Purchase / Base Amount *',
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
                if (v == null || v.trim().isEmpty) return 'Please enter purchase amount';
                final n = double.tryParse(v.trim());
                if (n == null || n <= 0) return 'Please enter a valid amount';
                return null;
              },
            ),

            const SizedBox(height: 16),

            // 6. Additional Charges / Bank Fees / Interest / GST
            TextFormField(
              controller: _chargesController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Additional Charges / Bank Fees / Interest (Optional)',
                hintText: '0',
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(left: 14, right: 8),
                  child: Center(
                    widthFactor: 0.0,
                    child: Text(
                      '+ $currencySymbol',
                      style: TextStyle(fontWeight: FontWeight.w700, color: cs.error),
                    ),
                  ),
                ),
                suffixIcon: _charges > 0
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _chargesController.clear();
                          _manualMonthlyEdit = false;
                          _onAmountOrChargesChanged();
                        },
                      )
                    : null,
                helperText: 'Processing fee, bank interest, or GST incurred for this EMI.',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),

            const SizedBox(height: 8),

            // Quick fee addition chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.add, size: 14),
                    label: const Text('+₹199 Fee', style: TextStyle(fontSize: 11)),
                    onPressed: () => _applyQuickCharge(199),
                    visualDensity: VisualDensity.compact,
                  ),
                  const SizedBox(width: 6),
                  ActionChip(
                    avatar: const Icon(Icons.add, size: 14),
                    label: const Text('+₹499 Fee', style: TextStyle(fontSize: 11)),
                    onPressed: () => _applyQuickCharge(499),
                    visualDensity: VisualDensity.compact,
                  ),
                  const SizedBox(width: 6),
                  ActionChip(
                    avatar: const Icon(Icons.add, size: 14),
                    label: const Text('+₹999 Fee', style: TextStyle(fontSize: 11)),
                    onPressed: () => _applyQuickCharge(999),
                    visualDensity: VisualDensity.compact,
                  ),
                  const SizedBox(width: 6),
                  ActionChip(
                    avatar: const Icon(Icons.percent_rounded, size: 14),
                    label: const Text('+18% GST', style: TextStyle(fontSize: 11)),
                    onPressed: () => _applyGstCharge(18),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // 7. Tenure Selection (Months)
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

            // Live EMI Split Breakdown Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.purple.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.purple.withValues(alpha: 0.25)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Base Amount:',
                        style: GoogleFonts.inter(fontSize: 12.5, color: cs.onSurfaceVariant),
                      ),
                      Text(
                        CurrencyFormatter.format(_baseAmount, symbol: currencySymbol),
                        style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  if (_charges > 0) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Additional Charges:',
                          style: GoogleFonts.inter(fontSize: 12.5, color: cs.error),
                        ),
                        Text(
                          '+ ${CurrencyFormatter.format(_charges, symbol: currencySymbol)}',
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: cs.error,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Payable:',
                        style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                      Text(
                        CurrencyFormatter.format(_totalPayable, symbol: currencySymbol),
                        style: GoogleFonts.dmSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: cs.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Auto Monthly Split ($_tenureMonths months):',
                        style: GoogleFonts.inter(fontSize: 12.5, color: cs.onSurfaceVariant),
                      ),
                      Text(
                        '${CurrencyFormatter.format(_totalPayable > 0 ? (_totalPayable / _tenureMonths) : 0, symbol: currencySymbol)} / mo',
                        style: GoogleFonts.dmSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Colors.purple,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // 8. Monthly Installment (Auto-calculated, editable)
            TextFormField(
              controller: _monthlyInstallmentController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) {
                _manualMonthlyEdit = true;
              },
              decoration: InputDecoration(
                labelText: 'Monthly Installment (What gets recorded each month) *',
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
                  tooltip: 'Reset to auto-calculated split',
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  onPressed: _recalcMonthly,
                ),
                helperText: 'Automatically computed as Total ÷ Months. Editable if bank charges differ.',
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

            // 9. Start Date & Due Day of Month
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
                      'Every month on the ${_dueDayOfMonth.toString().padLeft(2, '0')}th, DueMate will automatically add an installment of ${CurrencyFormatter.format(double.tryParse(_monthlyInstallmentController.text.trim()) ?? (_totalPayable / _tenureMonths), symbol: currencySymbol)} to the ledger.',
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

            // 10. Notes
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

            // 11. Save Button
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
