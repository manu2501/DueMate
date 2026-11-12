import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import 'package:duemate/core/constants/app_constants.dart';
import 'package:duemate/core/utils/currency_formatter.dart';
import 'package:duemate/core/utils/date_formatter.dart';
import 'package:duemate/core/widgets/avatar_widget.dart';
import 'package:duemate/core/widgets/person_picker_sheet.dart';
import 'package:duemate/data/providers/app_providers.dart';
import 'package:duemate/domain/entities/credit_card_emi.dart';
import 'package:duemate/features/emis/presentation/widgets/add_edit_emi_suggestions.dart';
import 'package:duemate/features/emis/presentation/widgets/emi_breakdown_card.dart';
import 'package:duemate/features/emis/presentation/widgets/emi_tenure_selector.dart';
import 'package:duemate/features/emis/presentation/widgets/emi_type_selector.dart';

enum EmiType {
  creditCard,
  loan,
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
    return Navigator.of(context, rootNavigator: true).push<bool>(
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
  late final TextEditingController _interestRateController;
  late final TextEditingController _installmentsPaidController;
  late final TextEditingController _notesController;
  late final TextEditingController _tenureController;

  EmiType _emiType = EmiType.creditCard;
  bool _isForSelf = true;
  String? _selectedPersonId;
  bool _isPaidByMe = true;
  int _tenureMonths = 6;
  int _installmentsPaid = 0;
  String _interestType = 'reducing';
  DateTime _startDate = DateTime.now();
  int _dueDayOfMonth = DateTime.now().day;
  bool _isSaving = false;
  Map<int, double> _customScheduleMap = {};

  List<EmiItemSuggestion> get _itemSuggestions => EmiSuggestionsData.itemSuggestions;
  List<EmiItemSuggestion> get _loanPurposeSuggestions => EmiSuggestionsData.loanPurposeSuggestions;
  List<EmiCardSuggestion> get _cardSuggestions => EmiSuggestionsData.cardSuggestions;
  List<EmiCardSuggestion> get _loanSourceSuggestions => EmiSuggestionsData.loanSourceSuggestions;
  List<int> get _tenureOptions => EmiSuggestionsData.defaultTenureOptions;

  bool get isEditing => widget.emiToEdit != null;

  double get _baseAmount => double.tryParse(_baseAmountController.text.trim()) ?? 0.0;
  double get _charges => double.tryParse(_chargesController.text.trim()) ?? 0.0;
  double get _interestRate => double.tryParse(_interestRateController.text.trim()) ?? 0.0;

  double get _calculatedInterest {
    if (_baseAmount <= 0 || _interestRate <= 0 || _tenureMonths <= 0) return 0.0;
    if (_interestType == 'flat') {
      return (_baseAmount * (_interestRate / 100.0) * (_tenureMonths / 12.0)).roundToDouble();
    } else {
      final r = (_interestRate / 12.0) / 100.0;
      final powFactor = math.pow(1 + r, _tenureMonths);
      final emi = _baseAmount * r * powFactor / (powFactor - 1);
      final totalPayable = emi * _tenureMonths;
      return (totalPayable - _baseAmount).clamp(0.0, double.infinity).roundToDouble();
    }
  }

  double get _totalPayable => _baseAmount + _charges + _calculatedInterest;

  double get _monthlyInstallment {
    if (_totalPayable <= 0 || _tenureMonths <= 0) return 0.0;
    final raw = _totalPayable / _tenureMonths;
    return double.parse(raw.toStringAsFixed(2));
  }

  @override
  void initState() {
    super.initState();
    final emi = widget.emiToEdit;

    if (emi != null) {
      _isForSelf = emi.isForSelf;
      _selectedPersonId = emi.personId;
      _interestType = emi.interestType;
      if (emi.customScheduleJson != null && emi.customScheduleJson!.isNotEmpty) {
        try {
          final Map<String, dynamic> parsed = jsonDecode(emi.customScheduleJson!);
          _customScheduleMap = parsed.map((k, v) => MapEntry(int.parse(k), (v as num).toDouble()));
        } catch (_) {}
      }
    } else if (widget.initialPersonId != null && widget.initialPersonId != AppConstants.selfPersonId) {
      _isForSelf = false;
      _selectedPersonId = widget.initialPersonId;
    } else {
      _isForSelf = true;
      _selectedPersonId = AppConstants.selfPersonId;
    }
    _itemController = TextEditingController(text: emi?.itemName ?? '');
    _cardController = TextEditingController(text: emi?.cardName ?? '');
    _baseAmountController = TextEditingController(
      text: emi != null ? emi.totalAmount.toStringAsFixed(0) : '',
    );
    _chargesController = TextEditingController(text: '');
    _interestRateController = TextEditingController(
      text: emi != null && emi.interestRate > 0 ? emi.interestRate.toString() : '',
    );
    _installmentsPaidController = TextEditingController(
      text: emi != null ? emi.installmentsPaid.toString() : '0',
    );
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
      _installmentsPaid = emi.installmentsPaid;
      _startDate = emi.startDate;
      _dueDayOfMonth = emi.dueDayOfMonth;
    }

    _tenureController = TextEditingController(text: _tenureMonths.toString());
    _tenureController.addListener(_onTenureChanged);
    _installmentsPaidController.addListener(_onInstallmentsPaidChanged);

    _baseAmountController.addListener(_onAmountChanged);
    _chargesController.addListener(_onAmountChanged);
    _interestRateController.addListener(_onAmountChanged);
    _itemController.addListener(_onTextChanged);
    _cardController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _tenureController.removeListener(_onTenureChanged);
    _tenureController.dispose();
    _itemController.removeListener(_onTextChanged);
    _cardController.removeListener(_onTextChanged);
    _itemController.dispose();
    _cardController.dispose();
    _baseAmountController.removeListener(_onAmountChanged);
    _chargesController.removeListener(_onAmountChanged);
    _interestRateController.removeListener(_onAmountChanged);
    _baseAmountController.dispose();
    _chargesController.dispose();
    _interestRateController.dispose();
    _installmentsPaidController.removeListener(_onInstallmentsPaidChanged);
    _installmentsPaidController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _onTenureChanged() {
    final parsed = int.tryParse(_tenureController.text.trim()) ?? 0;
    if (_tenureMonths != parsed) {
      setState(() {
        _tenureMonths = parsed;
      });
    }
  }

  void _onInstallmentsPaidChanged() {
    final parsed = int.tryParse(_installmentsPaidController.text.trim()) ?? 0;
    if (_installmentsPaid != parsed) {
      setState(() {
        _installmentsPaid = parsed;
      });
    }
  }

  void _onTextChanged() {
    setState(() {});
  }

  void _onAmountChanged() {
    setState(() {});
  }

  void _applyQuickCharge(double add) {
    final current = _charges;
    final updated = current + add;
    _chargesController.text = updated % 1 == 0 ? updated.toInt().toString() : updated.toStringAsFixed(2);
    _onAmountChanged();
  }

  void _applyGstCharge(double percent) {
    if (_baseAmount <= 0) return;
    final gst = (_baseAmount * (percent / 100.0)).roundToDouble();
    final updated = _charges + gst;
    _chargesController.text = updated.toStringAsFixed(0);
    _onAmountChanged();
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

    final targetPersonId = _isForSelf ? AppConstants.selfPersonId : _selectedPersonId;

    if (!_isForSelf && (targetPersonId == null || targetPersonId == AppConstants.selfPersonId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a contact')),
      );
      return;
    }

    final totalAmount = _totalPayable;
    final monthly = _monthlyInstallment;

    if (_tenureMonths <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid tenure in months')),
      );
      return;
    }

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

      final customScheduleStr = _customScheduleMap.isNotEmpty
          ? jsonEncode(_customScheduleMap.map((k, v) => MapEntry(k.toString(), v)))
          : null;

      if (isEditing) {
        final current = widget.emiToEdit!;
        final updated = current.copyWith(
          personId: targetPersonId!,
          itemName: _itemController.text.trim(),
          cardName: _cardController.text.trim(),
          totalAmount: totalAmount,
          monthlyInstallment: monthly,
          totalTenureMonths: _tenureMonths,
          installmentsPaid: _installmentsPaid,
          startDate: _startDate,
          dueDayOfMonth: _dueDayOfMonth,
          isPaidByMe: _isForSelf ? true : _isPaidByMe,
          interestRate: _interestRate,
          interestType: _interestType,
          customScheduleJson: customScheduleStr,
          notes: finalNotes,
          updatedAt: DateTime.now(),
        );
        await emiRepo.updateEmi(updated);
      } else {
        final newEmi = CreditCardEmi(
          id: const Uuid().v4(),
          personId: targetPersonId!,
          itemName: _itemController.text.trim(),
          cardName: _cardController.text.trim(),
          totalAmount: totalAmount,
          monthlyInstallment: monthly,
          totalTenureMonths: _tenureMonths,
          installmentsPaid: _installmentsPaid,
          startDate: _startDate,
          dueDayOfMonth: _dueDayOfMonth,
          isPaidByMe: _isForSelf ? true : _isPaidByMe,
          status: 'active',
          interestRate: _interestRate,
          interestType: _interestType,
          customScheduleJson: customScheduleStr,
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

  void _showCustomizeMonthlyAmountsDialog(BuildContext context) {
    final controllers = <int, TextEditingController>{};
    for (int i = 1; i <= _tenureMonths; i++) {
      final currentVal = _customScheduleMap[i] ?? _monthlyInstallment;
      controllers[i] = TextEditingController(
        text: currentVal % 1 == 0 ? currentVal.toInt().toString() : currentVal.toStringAsFixed(2),
      );
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.edit_calendar_rounded, color: Theme.of(context).colorScheme.primary, size: 20),
            ),
            const SizedBox(width: 10),
            const Text('Customize Monthly EMI Split'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Edit individual installment amounts for specific months (e.g. Month 1 fee or custom payment split).',
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 12),
                ...List.generate(_tenureMonths, (idx) {
                  final monthNum = idx + 1;
                  final dueDate = DateTime(_startDate.year, _startDate.month + idx, _dueDayOfMonth);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: TextField(
                      controller: controllers[monthNum],
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Month $monthNum (${DateFormatter.formatShortDate(dueDate)})',
                        prefixText: '₹ ',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final newMap = <int, double>{};
              for (int i = 1; i <= _tenureMonths; i++) {
                final val = double.tryParse(controllers[i]?.text.trim() ?? '') ?? _monthlyInstallment;
                newMap[i] = val;
              }
              setState(() {
                _customScheduleMap = newMap;
              });
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Customized monthly installment schedule applied')),
              );
            },
            child: const Text('Apply Monthly Amounts'),
          ),
        ],
      ),
    );
  }

  Widget _buildOwnershipSelector(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () {
                setState(() {
                  _isForSelf = true;
                  _selectedPersonId = AppConstants.selfPersonId;
                  _isPaidByMe = true;
                });
              },
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _isForSelf ? cs.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.person_rounded,
                      size: 16,
                      color: _isForSelf ? cs.onPrimary : cs.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'For Myself',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _isForSelf ? cs.onPrimary : cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: () {
                setState(() {
                  _isForSelf = false;
                  if (_selectedPersonId == AppConstants.selfPersonId) {
                    _selectedPersonId = null;
                  }
                });
              },
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: !_isForSelf ? cs.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.people_rounded,
                      size: 16,
                      color: !_isForSelf ? cs.onPrimary : cs.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'For Someone Else',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: !_isForSelf ? cs.onPrimary : cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
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
            // Ownership Selector: For Myself vs For Someone Else
            _buildOwnershipSelector(context),
            const SizedBox(height: 16),

            // Category Selector: Credit Card vs Loan
            EmiTypeSelector(
              selectedType: _emiType,
              onChanged: (newType) {
                setState(() {
                  _emiType = newType;
                });
              },
            ),

            const SizedBox(height: 20),

            // 1. Person Selector Card (Only shown if For Someone Else is selected)
            if (!_isForSelf) ...[
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
            ],

            const SizedBox(height: 20),

            // 2. Direction Toggle (Only shown when For Someone Else is selected)
            if (!_isForSelf) ...[
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
                              isLoan ? 'Contact repays in installments' : 'Contact repays monthly installment',
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
                              isLoan ? 'I repay in monthly installments' : 'I repay monthly installment',
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
            ],

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
                    ? <EmiItemSuggestion>[]
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
                    ? <EmiCardSuggestion>[]
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
                          _onAmountChanged();
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

            const SizedBox(height: 16),

            // Interest Rate & Mode Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.percent_rounded, size: 18, color: cs.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Interest Rate & Calculation',
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: cs.onSurface),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _interestRateController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'Interest Rate (% p.a.)',
                            hintText: 'e.g. 12.0',
                            suffixText: '% p.a.',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _interestType,
                          decoration: InputDecoration(
                            labelText: 'Interest Mode',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'reducing', child: Text('Reducing Bal.', style: TextStyle(fontSize: 12.5))),
                            DropdownMenuItem(value: 'flat', child: Text('Flat Rate', style: TextStyle(fontSize: 12.5))),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _interestType = val);
                          },
                        ),
                      ),
                    ],
                  ),

                  if (_calculatedInterest > 0) ...[
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Calculated Interest:',
                          style: GoogleFonts.inter(fontSize: 11.5, color: cs.onSurfaceVariant),
                        ),
                        Text(
                          '+${CurrencyFormatter.format(_calculatedInterest, symbol: currencySymbol)}',
                          style: GoogleFonts.dmSans(fontSize: 13.5, fontWeight: FontWeight.w800, color: cs.error),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 18),

            // 7. Tenure Selection (Months)
            EmiTenureSelector(
              controller: _tenureController,
              currentTenureMonths: _tenureMonths,
              presetOptions: _tenureOptions,
              onSelectPreset: (months) {
                _tenureController.text = months.toString();
                setState(() {
                  _tenureMonths = months;
                });
              },
            ),

            const SizedBox(height: 12),

            // Per-Month Customization Action Button
            OutlinedButton.icon(
              onPressed: () => _showCustomizeMonthlyAmountsDialog(context),
              icon: Icon(Icons.edit_calendar_rounded, size: 18, color: cs.primary),
              label: Text(
                _customScheduleMap.isNotEmpty
                    ? 'Edit Custom Monthly Amounts (${_customScheduleMap.length} customized)'
                    : 'Customize Per-Month Installment Amounts',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),

            const SizedBox(height: 18),

            // 8. Installments Already Paid
            TextFormField(
              controller: _installmentsPaidController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Installments Already Paid',
                hintText: '0',
                prefixIcon: const Icon(Icons.history_rounded, size: 20),
                helperText: 'Enter if migrating an existing loan (e.g., 3 out of 12 already paid).',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
              validator: (v) {
                final n = int.tryParse(v?.trim() ?? '0');
                if (n == null || n < 0) return 'Valid number required';
                if (n > _tenureMonths) return 'Cannot exceed total tenure';
                return null;
              },
            ),

            const SizedBox(height: 18),

            // Live EMI Split Breakdown Card
            EmiBreakdownCard(
              isLoan: isLoan,
              baseAmount: _baseAmount,
              charges: _charges,
              totalPayable: _totalPayable,
              monthlyInstallment: _monthlyInstallment,
              tenureMonths: _tenureMonths,
              currencySymbol: currencySymbol,
            ),

            const SizedBox(height: 16),

            // Monthly Installment Card
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
                              'Auto-calculated based on tenure & charges',
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
