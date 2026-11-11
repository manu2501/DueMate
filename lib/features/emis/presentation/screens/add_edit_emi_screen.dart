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

enum EmiType {
  creditCard,
  loan,
}

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
  late final TextEditingController _notesController;

  EmiType _emiType = EmiType.creditCard;
  String? _selectedPersonId;
  bool _isPaidByMe = true;
  int _tenureMonths = 6;
  DateTime _startDate = DateTime.now();
  int _dueDayOfMonth = DateTime.now().day;
  bool _isSaving = false;

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

  final List<_ItemSuggestion> _loanPurposeSuggestions = const [
    _ItemSuggestion('Personal Loan', 'Personal Loan', Icons.person_outline_rounded),
    _ItemSuggestion('Emergency Loan', 'Emergency Loan', Icons.health_and_safety_outlined),
    _ItemSuggestion('Education Loan', 'Education Loan', Icons.school_rounded),
    _ItemSuggestion('Vehicle / Bike', 'Vehicle Loan', Icons.two_wheeler_rounded),
    _ItemSuggestion('Business Loan', 'Business Loan', Icons.storefront_rounded),
    _ItemSuggestion('Home / Rent Loan', 'Home Rent Loan', Icons.home_outlined),
    _ItemSuggestion('Cash Advance', 'Cash Advance', Icons.payments_outlined),
    _ItemSuggestion('Medical Loan', 'Medical Loan', Icons.local_hospital_rounded),
    _ItemSuggestion('Wedding Loan', 'Wedding Loan', Icons.celebration_rounded),
    _ItemSuggestion('Travel Loan', 'Travel Loan', Icons.flight_takeoff_rounded),
    _ItemSuggestion('Gadget Loan', 'Gadget Loan', Icons.devices_other_rounded),
    _ItemSuggestion('Salary Advance', 'Salary Advance', Icons.work_outline_rounded),
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

  final List<_CardSuggestion> _loanSourceSuggestions = const [
    _CardSuggestion('Cash Loan', 'Cash Loan', Icons.payments_rounded, Color(0xFF059669)),
    _CardSuggestion('Bank Transfer', 'Bank Transfer Loan', Icons.account_balance_rounded, Color(0xFF0284C7)),
    _CardSuggestion('UPI Transfer', 'UPI Loan', Icons.qr_code_rounded, Color(0xFF7C3AED)),
    _CardSuggestion('SBI Loan', 'SBI Personal Loan', Icons.account_balance_rounded, Color(0xFF0A66C2)),
    _CardSuggestion('HDFC Loan', 'HDFC Personal Loan', Icons.account_balance_rounded, Color(0xFF004C8F)),
    _CardSuggestion('ICICI Loan', 'ICICI Personal Loan', Icons.account_balance_rounded, Color(0xFFB02A30)),
    _CardSuggestion('Axis Bank', 'Axis Bank Loan', Icons.account_balance_wallet_rounded, Color(0xFF97144D)),
    _CardSuggestion('Kotak Loan', 'Kotak Loan', Icons.account_balance_rounded, Color(0xFFED1C24)),
    _CardSuggestion('NBFC / FinTech', 'FinTech Loan', Icons.domain_rounded, Color(0xFFD97706)),
    _CardSuggestion('Cheque Loan', 'Cheque Loan', Icons.receipt_long_rounded, Color(0xFF475569)),
    _CardSuggestion('Peer to Peer', 'P2P Loan', Icons.handshake_rounded, Color(0xFF0D9488)),
  ];

  final List<int> _tenureOptions = [3, 6, 9, 12, 18, 24, 36];

  bool get isEditing => widget.emiToEdit != null;

  double get _baseAmount => double.tryParse(_baseAmountController.text.trim()) ?? 0.0;
  double get _charges => double.tryParse(_chargesController.text.trim()) ?? 0.0;
  double get _totalPayable => _baseAmount + _charges;
  double get _monthlyInstallment {
    if (_totalPayable <= 0 || _tenureMonths <= 0) return 0.0;
    final raw = _totalPayable / _tenureMonths;
    return double.parse(raw.toStringAsFixed(2));
  }

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
    _notesController = TextEditingController(text: emi?.notes ?? '');

    if (emi != null) {
      final isLoan = emi.cardName.toLowerCase().contains('loan') ||
          emi.itemName.toLowerCase().contains('loan') ||
          emi.cardName.toLowerCase().contains('cash') ||
          emi.cardName.toLowerCase().contains('transfer') ||
          (emi.notes?.toLowerCase().contains('loan') ?? false);
      _emiType = isLoan ? EmiType.loan : EmiType.creditCard;

      _isPaidByMe = emi.isPaidByMe;
      _tenureMonths = emi.totalTenureMonths;
      _startDate = emi.startDate;
      _dueDayOfMonth = emi.dueDayOfMonth;
    }

    _baseAmountController.addListener(_onAmountOrChargesChanged);
    _chargesController.addListener(_onAmountOrChargesChanged);
    _itemController.addListener(_onTextChanged);
    _cardController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _itemController.removeListener(_onTextChanged);
    _cardController.removeListener(_onTextChanged);
    _itemController.dispose();
    _cardController.dispose();
    _baseAmountController.removeListener(_onAmountOrChargesChanged);
    _chargesController.removeListener(_onAmountOrChargesChanged);
    _baseAmountController.dispose();
    _chargesController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    setState(() {});
  }

  void _onAmountOrChargesChanged() {
    setState(() {});
  }

  void _applyQuickCharge(double add) {
    final current = _charges;
    final updated = current + add;
    _chargesController.text = updated % 1 == 0 ? updated.toInt().toString() : updated.toStringAsFixed(2);
    _onAmountOrChargesChanged();
  }

  void _applyGstCharge(double percent) {
    if (_baseAmount <= 0) return;
    final gst = (_baseAmount * (percent / 100.0)).roundToDouble();
    final updated = _charges + gst;
    _chargesController.text = updated.toStringAsFixed(0);
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
    final monthly = _monthlyInstallment;

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
      final List<String> notesParts = [];
      if (_emiType == EmiType.loan) {
        notesParts.add('[Loan EMI]');
      }
      if (_charges > 0) {
        notesParts.add('Base: ₹${_baseAmount.toStringAsFixed(0)} + Charges: ₹${_charges.toStringAsFixed(0)}');
      }
      if (notesParts.isNotEmpty) {
        final prefix = notesParts.join(' • ');
        finalNotes = finalNotes != null ? '$prefix\n$finalNotes' : prefix;
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
              isEditing
                  ? (_emiType == EmiType.loan ? 'Loan EMI updated' : 'Card EMI updated')
                  : (_emiType == EmiType.loan ? 'Loan EMI tracking started' : 'Credit Card EMI tracking started'),
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
    final isLoan = _emiType == EmiType.loan;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditing
              ? (isLoan ? 'Edit Loan EMI' : 'Edit Credit Card EMI')
              : (isLoan ? 'Add Loan EMI' : 'Add Credit Card EMI'),
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
            // Category Selector: Credit Card vs Loan
            Container(
              decoration: BoxDecoration(
                color: cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cs.outlineVariant),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _emiType = EmiType.creditCard;
                        });
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: !isLoan ? cs.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.credit_card_rounded,
                              size: 18,
                              color: !isLoan ? Colors.white : cs.onSurfaceVariant,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Credit Card EMI',
                              style: GoogleFonts.dmSans(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: !isLoan ? Colors.white : cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _emiType = EmiType.loan;
                        });
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: isLoan ? const Color(0xFF0D9488) : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.account_balance_wallet_rounded,
                              size: 18,
                              color: isLoan ? Colors.white : cs.onSurfaceVariant,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Loan / Cash EMI',
                              style: GoogleFonts.dmSans(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: isLoan ? Colors.white : cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 1. Person Selector Card
            Text(
              isLoan ? 'Loan Shared With' : 'Shared With',
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
                          color: (isLoan ? const Color(0xFF0D9488) : cs.primary).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.person_add_outlined,
                          color: isLoan ? const Color(0xFF0D9488) : cs.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          isLoan ? 'Select borrower or lender' : 'Select person to share EMI with',
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

            // 2. Direction Toggle (Who paid with whose card / Who gave loan?)
            Text(
              isLoan ? 'Lending & Repayment Flow' : 'Card Ownership & Repayment Flow',
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
                                isLoan ? Icons.payments_outlined : Icons.credit_card_rounded,
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
                            isLoan ? 'I Lent Money' : 'My Card',
                            style: GoogleFonts.dmSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: _isPaidByMe ? cs.primary : cs.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isLoan ? 'Friend repays me monthly' : 'Friend owes me monthly',
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
                                isLoan ? Icons.handshake_outlined : Icons.payment_rounded,
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
                            isLoan ? 'I Borrowed' : "Friend's Card",
                            style: GoogleFonts.dmSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: !_isPaidByMe ? cs.error : cs.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isLoan ? 'I repay friend monthly' : 'I owe friend monthly',
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

            // 3. Purchase Item / Loan Purpose Name
            TextFormField(
              controller: _itemController,
              decoration: InputDecoration(
                labelText: isLoan ? 'Loan Purpose / Title *' : 'Item / Purchase Name *',
                hintText: isLoan ? 'e.g. Personal Loan, Bike Loan, Emergency' : 'e.g. iPhone 16 Pro, Flight Tickets',
                prefixIcon: Icon(isLoan ? Icons.receipt_long_outlined : Icons.shopping_bag_outlined),
                suffixIcon: _itemController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () => _itemController.clear(),
                      )
                    : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
              validator: (v) => v == null || v.trim().isEmpty
                  ? (isLoan ? 'Please enter loan title' : 'Please enter item name')
                  : null,
            ),
            Builder(
              builder: (context) {
                final itemQuery = _itemController.text.trim().toLowerCase();
                final itemSource = isLoan ? _loanPurposeSuggestions : _itemSuggestions;
                final itemMatches = itemQuery.isEmpty
                    ? <_ItemSuggestion>[]
                    : itemSource.where((item) =>
                        item.label.toLowerCase().contains(itemQuery) ||
                        item.fillValue.toLowerCase().contains(itemQuery)).toList();

                final isExact = itemMatches.any((m) => m.fillValue.toLowerCase() == itemQuery);

                if (itemQuery.isNotEmpty && itemMatches.isNotEmpty && !isExact) {
                  return Container(
                    margin: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                          child: Row(
                            children: [
                              Icon(Icons.auto_awesome, size: 14, color: isLoan ? const Color(0xFF0D9488) : cs.primary),
                              const SizedBox(width: 6),
                              Text(
                                'Suggestions matching "$itemQuery":',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        ...itemMatches.take(5).map((match) => InkWell(
                          onTap: () {
                            _itemController.text = match.fillValue;
                            _itemController.selection = TextSelection.fromPosition(
                              TextPosition(offset: match.fillValue.length),
                            );
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            child: Row(
                              children: [
                                Icon(match.icon, size: 18, color: isLoan ? const Color(0xFF0D9488) : cs.primary),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    match.label,
                                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                                  ),
                                ),
                                Icon(Icons.north_west_rounded, size: 14, color: cs.onSurfaceVariant),
                              ],
                            ),
                          ),
                        )),
                      ],
                    ),
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Text(
                      isLoan ? 'Quick Loan Suggestions:' : 'Quick Item Suggestions:',
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
                        children: itemSource.map((item) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ActionChip(
                              avatar: Icon(
                                item.icon,
                                size: 16,
                                color: isLoan ? const Color(0xFF0D9488) : cs.primary,
                              ),
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
                  ],
                );
              },
            ),

            const SizedBox(height: 20),

            // 4. Source / Bank / Lender Field
            TextFormField(
              controller: _cardController,
              decoration: InputDecoration(
                labelText: isLoan ? 'Lender / Source / Payment Mode *' : 'Credit Card Name / Bank *',
                hintText: isLoan ? 'e.g. Bank Transfer, Cash, SBI, HDFC' : 'e.g. HDFC Millennia, ICICI Amazon Pay',
                prefixIcon: Icon(isLoan ? Icons.account_balance_outlined : Icons.credit_card_outlined),
                suffixIcon: _cardController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () => _cardController.clear(),
                      )
                    : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
              validator: (v) => v == null || v.trim().isEmpty
                  ? (isLoan ? 'Please enter loan source or lender' : 'Please enter credit card name')
                  : null,
            ),
            Builder(
              builder: (context) {
                final cardQuery = _cardController.text.trim().toLowerCase();
                final cardSource = isLoan ? _loanSourceSuggestions : _cardSuggestions;
                final cardMatches = cardQuery.isEmpty
                    ? <_CardSuggestion>[]
                    : cardSource.where((b) =>
                        b.name.toLowerCase().contains(cardQuery) ||
                        b.fillValue.toLowerCase().contains(cardQuery)).toList();

                final isExact = cardMatches.any((m) => m.fillValue.toLowerCase() == cardQuery);

                if (cardQuery.isNotEmpty && cardMatches.isNotEmpty && !isExact) {
                  return Container(
                    margin: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                          child: Row(
                            children: [
                              Icon(Icons.auto_awesome, size: 14, color: isLoan ? const Color(0xFF0D9488) : cs.primary),
                              const SizedBox(width: 6),
                              Text(
                                isLoan ? 'Matching loan sources:' : 'Matching banks & cards:',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        ...cardMatches.take(5).map((bank) => InkWell(
                          onTap: () {
                            _cardController.text = bank.fillValue;
                            _cardController.selection = TextSelection.fromPosition(
                              TextPosition(offset: bank.fillValue.length),
                            );
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 10,
                                  backgroundColor: bank.color.withValues(alpha: 0.15),
                                  child: Icon(bank.icon, size: 12, color: bank.color),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    bank.fillValue,
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: bank.color,
                                    ),
                                  ),
                                ),
                                Icon(Icons.north_west_rounded, size: 14, color: cs.onSurfaceVariant),
                              ],
                            ),
                          ),
                        )),
                      ],
                    ),
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Text(
                      isLoan ? 'Common Loan Sources & Banks:' : 'Popular Banks & Cards:',
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
                        children: cardSource.map((bank) {
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
                  ],
                );
              },
            ),

            const SizedBox(height: 22),

            // 5. Principal / Base Amount Field
            TextFormField(
              controller: _baseAmountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: GoogleFonts.dmSans(fontSize: 20, fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                labelText: isLoan ? 'Loan Principal Amount *' : 'Purchase / Base Amount *',
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
                if (v == null || v.trim().isEmpty) {
                  return isLoan ? 'Please enter loan amount' : 'Please enter purchase amount';
                }
                final n = double.tryParse(v.trim());
                if (n == null || n <= 0) return 'Please enter a valid amount';
                return null;
              },
            ),

            const SizedBox(height: 16),

            // 6. Additional Charges / Interest / Fees
            TextFormField(
              controller: _chargesController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: isLoan ? 'Interest / Processing Fee / Extra Charges' : 'Additional Charges / Bank Fees / Interest',
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
                          _onAmountOrChargesChanged();
                        },
                      )
                    : null,
                helperText: isLoan
                    ? 'Total interest or processing fees incurred over the tenure.'
                    : 'Processing fee, bank interest, or GST incurred for this EMI.',
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
                color: (isLoan ? const Color(0xFF0D9488) : Colors.purple).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: (isLoan ? const Color(0xFF0D9488) : Colors.purple).withValues(alpha: 0.25),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isLoan ? 'Principal Loan:' : 'Base Amount:',
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
                          isLoan ? 'Interest / Extra Charges:' : 'Additional Charges:',
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
                        isLoan ? 'Total Repayable:' : 'Total Payable:',
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
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 8. Monthly Installment Card (Non-editable, standout card with great UI)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isLoan
                      ? [
                          const Color(0xFF0D9488).withValues(alpha: 0.14),
                          const Color(0xFF0D9488).withValues(alpha: 0.04),
                        ]
                      : [
                          cs.primary.withValues(alpha: 0.14),
                          cs.primary.withValues(alpha: 0.04),
                        ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: (isLoan ? const Color(0xFF0D9488) : cs.primary).withValues(alpha: 0.35),
                  width: 1.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: (isLoan ? const Color(0xFF0D9488) : cs.primary).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.calendar_month_rounded,
                          size: 18,
                          color: isLoan ? const Color(0xFF0D9488) : cs.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isLoan ? 'MONTHLY REPAYMENT' : 'MONTHLY INSTALLMENT',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                                color: isLoan ? const Color(0xFF0D9488) : cs.primary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Auto-calculated based on tenure',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.lock_rounded, size: 12, color: cs.onSurfaceVariant),
                            const SizedBox(width: 4),
                            Text(
                              'Auto-Split',
                              style: GoogleFonts.inter(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        CurrencyFormatter.format(_monthlyInstallment, symbol: currencySymbol),
                        style: GoogleFonts.dmSans(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: isLoan ? const Color(0xFF0D9488) : cs.primary,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '/ month',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: cs.surface.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 15,
                          color: isLoan ? const Color(0xFF0D9488) : cs.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _totalPayable > 0
                                ? '${CurrencyFormatter.format(_totalPayable, symbol: currencySymbol)} total ÷ $_tenureMonths months • Automatically added on day $_dueDayOfMonth'
                                : 'Enter amount above to view monthly split',
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              color: cs.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
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
                      'Every month on the ${_dueDayOfMonth.toString().padLeft(2, '0')}th, DueMate will automatically add an installment of ${CurrencyFormatter.format(_monthlyInstallment, symbol: currencySymbol)} to the ledger.',
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
                hintText: isLoan ? 'Loan terms, account number, agreement notes...' : 'Order ID, invoice details, bank reference...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),

            const SizedBox(height: 28),

            // 11. Save Button
            FilledButton(
              onPressed: _isSaving ? null : _saveEmi,
              style: FilledButton.styleFrom(
                backgroundColor: isLoan ? const Color(0xFF0D9488) : cs.primary,
                foregroundColor: Colors.white,
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
                      isEditing
                          ? (isLoan ? 'Save Loan Changes' : 'Save EMI Changes')
                          : (isLoan ? 'Start Monthly Loan Tracking' : 'Start Monthly EMI Tracking'),
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
