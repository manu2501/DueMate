import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:duemate/core/constants/app_constants.dart';
import 'package:duemate/core/widgets/person_picker_sheet.dart';
import 'package:duemate/data/providers/app_providers.dart';
import 'package:duemate/domain/emi_calculator.dart';
import 'package:duemate/domain/entities/credit_card_emi.dart';
import 'package:duemate/core/widgets/choice_tile_group.dart';
import 'package:duemate/core/widgets/person_select_field.dart';
import 'package:duemate/core/widgets/suggest_text_field.dart';
import 'package:duemate/features/emis/presentation/widgets/add_edit_emi_suggestions.dart';
import 'package:duemate/features/emis/presentation/widgets/emi_custom_months_dialog.dart';
import 'package:duemate/features/emis/presentation/widgets/emi_schedule_section.dart';
import 'package:duemate/features/emis/presentation/widgets/emi_summary_card.dart';
import 'package:duemate/features/emis/presentation/widgets/emi_tenure_selector.dart';
import 'package:duemate/features/emis/presentation/widgets/emi_type_selector.dart';

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

  /// true: user types a total and we split it. false: user types the EMI.
  bool _splitMode = true;
  late final TextEditingController _emiController;
  double _lastPlanMonthly = 0;
  int _lastMonths = 0;
  bool _customWasReset = false;

  /// GST we added to the charges field, so the chip can take it back out.
  double _gstApplied = 0;
  bool _settingCharges = false;

  List<EmiItemSuggestion> get _itemSuggestions => EmiSuggestionsData.itemSuggestions;
  List<EmiItemSuggestion> get _loanPurposeSuggestions => EmiSuggestionsData.loanPurposeSuggestions;
  List<EmiCardSuggestion> get _cardSuggestions => EmiSuggestionsData.cardSuggestions;
  List<EmiCardSuggestion> get _loanSourceSuggestions => EmiSuggestionsData.loanSourceSuggestions;
  List<int> get _tenureOptions => EmiSuggestionsData.defaultTenureOptions;

  bool get isEditing => widget.emiToEdit != null;

  double get _baseAmount => double.tryParse(_baseAmountController.text.trim()) ?? 0.0;
  double get _charges => double.tryParse(_chargesController.text.trim()) ?? 0.0;
  double get _interestRate => double.tryParse(_interestRateController.text.trim()) ?? 0.0;
  double get _emiInput => double.tryParse(_emiController.text.trim()) ?? 0.0;

  EmiPlan get _plan => _splitMode
      ? EmiCalculator.fromTotal(
          principal: _baseAmount,
          months: _tenureMonths,
          ratePercentPerYear: _interestRate,
          flat: _interestType == 'flat',
          charges: _charges,
        )
      : EmiCalculator.fromMonthly(
          monthly: _emiInput,
          months: _tenureMonths,
          principal: _baseAmount,
          charges: _charges,
        );

  double get _monthlyInstallment => _plan.monthly;

  /// Due date of installment [k] (1-based), clamped to the month's length.
  DateTime _dueDateFor(int k) {
    final first = DateTime(_startDate.year, _startDate.month + (k - 1), 1);
    final lastDay = DateTime(first.year, first.month + 1, 0).day;
    return DateTime(first.year, first.month, _dueDayOfMonth.clamp(1, lastDay));
  }

  /// How many installments have already fallen due as of today.
  int get _dueSoFar {
    final today = DateTime.now();
    final end = DateTime(today.year, today.month, today.day);
    var n = 0;
    for (var k = 1; k <= _tenureMonths; k++) {
      if (_dueDateFor(k).isAfter(end)) break;
      n++;
    }
    return n;
  }

  /// Any custom per-month amounts only make sense for the plan they were
  /// made for; drop them when the plan changes underneath.
  void _syncCustomSchedule() {
    final monthly = _plan.monthly;
    if (_customScheduleMap.isNotEmpty &&
        (monthly != _lastPlanMonthly || _tenureMonths != _lastMonths)) {
      _customScheduleMap = {};
      _customWasReset = true;
    }
    _lastPlanMonthly = monthly;
    _lastMonths = _tenureMonths;
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
    _splitMode = emi == null ? true : emi.isSplitPlan;
    String fmt(double v) =>
        v <= 0 ? '' : (v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(2));
    _baseAmountController = TextEditingController(text: emi == null ? '' : fmt(emi.principal));
    _chargesController = TextEditingController(text: emi == null ? '' : fmt(emi.charges));
    _emiController = TextEditingController(
      text: emi != null && !emi.isSplitPlan ? fmt(emi.monthlyInstallment) : '',
    );
    _interestRateController = TextEditingController(
      text: emi != null && emi.interestRate > 0 ? emi.interestRate.toString() : '',
    );
    _installmentsPaidController = TextEditingController(
      text: emi != null ? emi.installmentsPaid.toString() : '0',
    );
    _notesController = TextEditingController(text: emi?.notes ?? '');

    if (emi != null) {
      _emiType = emi.isLoan ? EmiType.loan : EmiType.creditCard;

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
    _emiController.addListener(_onAmountChanged);
    _chargesController.addListener(_onChargesEdited);
    _interestRateController.addListener(_onAmountChanged);

    if (emi == null) {
      // A purchase made today has its first EMI next month.
      final now = DateTime.now();
      final nextMonth = DateTime(now.year, now.month + 1, 1);
      final lastDay = DateTime(nextMonth.year, nextMonth.month + 1, 0).day;
      _startDate = DateTime(nextMonth.year, nextMonth.month, now.day.clamp(1, lastDay));
      _dueDayOfMonth = now.day;
    }
    _lastPlanMonthly = _plan.monthly;
    _lastMonths = _tenureMonths;
  }

  @override
  void dispose() {
    _tenureController.removeListener(_onTenureChanged);
    _tenureController.dispose();
    _itemController.dispose();
    _cardController.dispose();
    _baseAmountController.removeListener(_onAmountChanged);
    _emiController.removeListener(_onAmountChanged);
    _chargesController.removeListener(_onChargesEdited);
    _interestRateController.removeListener(_onAmountChanged);
    _emiController.dispose();
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
        _syncCustomSchedule();
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

  void _onAmountChanged() {
    setState(_syncCustomSchedule);
  }

  void _onChargesEdited() {
    // Typing in the field means the GST we added is no longer a clean amount.
    if (!_settingCharges) _gstApplied = 0;
    setState(_syncCustomSchedule);
  }

  String _plain(double v) => v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(2);

  /// GST is charged on the fee and the interest, never on the principal.
  void _toggleGst() {
    _settingCharges = true;
    if (_gstApplied > 0) {
      final cleaned = (_charges - _gstApplied).clamp(0.0, double.infinity);
      _chargesController.text = cleaned == 0 ? '' : _plain(cleaned);
      _gstApplied = 0;
    } else {
      final base = _charges + (_splitMode ? _plan.interest : 0);
      final gst = EmiCalculator.gst(feeAndInterest: base);
      if (gst > 0) {
        _chargesController.text = _plain(_charges + gst);
        _gstApplied = gst;
      }
    }
    _settingCharges = false;
    setState(_syncCustomSchedule);
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
        const SnackBar(content: Text('Choose who this EMI is for')),
      );
      return;
    }

    final plan = _plan;

    if (_tenureMonths <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter the number of months')),
      );
      return;
    }

    if (!plan.isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_splitMode ? 'Enter the amount' : 'Enter the monthly EMI')),
      );
      return;
    }

    final totalAmount = plan.totalPayable;
    final monthly = plan.monthly;

    setState(() => _isSaving = true);

    try {
      final emiRepo = ref.read(emiRepositoryProvider);
      final processor = ref.read(emiProcessorServiceProvider);

      final String? finalNotes =
          _notesController.text.trim().isEmpty ? null : _notesController.text.trim();
      final kind = _emiType == EmiType.loan ? 'loan' : 'card';
      final planMode = _splitMode ? 'split' : 'emi';

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
          interestRate: _splitMode ? _interestRate : 0,
          interestType: _interestType,
          kind: kind,
          planMode: planMode,
          principal: _baseAmount,
          charges: _charges,
          customScheduleJson: customScheduleStr,
          clearCustomSchedule: customScheduleStr == null,
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
          interestRate: _splitMode ? _interestRate : 0,
          interestType: _interestType,
          kind: kind,
          planMode: planMode,
          principal: _baseAmount,
          charges: _charges,
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
                  ? 'Changes saved'
                  : (_emiType == EmiType.loan ? 'Loan added' : 'EMI added'),
            ),
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't save the EMI. Please try again.")),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _customizeMonths() async {
    final result = await showEmiCustomMonthsDialog(
      context,
      months: _tenureMonths,
      defaultAmount: _monthlyInstallment,
      current: _customScheduleMap,
      dueDateFor: _dueDateFor,
      currencySymbol: ref.read(currencySymbolProvider),
    );
    if (result == null || !mounted) return;
    setState(() {
      _customScheduleMap = result;
      _customWasReset = false;
      _lastPlanMonthly = _plan.monthly;
      _lastMonths = _tenureMonths;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Month amounts updated')),
    );
  }

  InputDecoration _moneyDecoration(String label, String symbol, {String? helper, String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint ?? '0',
      helperText: helper,
      helperMaxLines: 3,
      prefixText: '$symbol ',
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    );
  }

  List<Widget> _moneySection(BuildContext context, String symbol, bool isLoan) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    const numberKeyboard = TextInputType.numberWithOptions(decimal: true);

    final tenure = EmiTenureSelector(
      controller: _tenureController,
      currentTenureMonths: _tenureMonths,
      presetOptions: _tenureOptions,
      onSelectPreset: (months) {
        _tenureController.text = months.toString();
        setState(() {
          _tenureMonths = months;
          _syncCustomSchedule();
        });
      },
    );

    final chargesField = TextFormField(
      controller: _chargesController,
      keyboardType: numberKeyboard,
      decoration: _moneyDecoration(
        'Charges and fees (optional)',
        symbol,
        helper: _splitMode
            ? 'Processing fee, GST, insurance. Added to the total and spread over the months.'
            : 'One-time fees billed separately. They are not part of the monthly EMI.',
      ),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return null;
        final n = double.tryParse(v.trim());
        return (n == null || n < 0) ? 'Enter a valid amount' : null;
      },
    );

    final gstBase = _charges + (_splitMode ? _plan.interest : 0);
    final gstChip = Align(
      alignment: Alignment.centerLeft,
      child: FilterChip(
        label: Text(_gstApplied > 0
            ? 'GST added (${EmiCalculator.defaultGstPercent.toInt()}%)'
            : 'Add ${EmiCalculator.defaultGstPercent.toInt()}% GST on fee and interest'),
        selected: _gstApplied > 0,
        onSelected: (_gstApplied > 0 || gstBase > 0) ? (_) => _toggleGst() : null,
      ),
    );

    return [
      Text('Amount', style: theme.textTheme.titleSmall),
      const SizedBox(height: 8),
      SegmentedButton<bool>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(
            value: true,
            label: Text('Split a total'),
            icon: Icon(Icons.call_split_rounded, size: 18),
          ),
          ButtonSegment(
            value: false,
            label: Text('I know the EMI'),
            icon: Icon(Icons.payments_outlined, size: 18),
          ),
        ],
        selected: {_splitMode},
        onSelectionChanged: (sel) => setState(() {
          _splitMode = sel.first;
          _gstApplied = 0;
          _syncCustomSchedule();
        }),
      ),
      const SizedBox(height: 6),
      Text(
        _splitMode
            ? "Enter the full amount and we'll work out the monthly EMI."
            : 'Enter the EMI from your bank statement or SMS.',
        style: theme.textTheme.bodySmall?.copyWith(color: muted),
      ),
      const SizedBox(height: 16),
      if (_splitMode) ...[
        TextFormField(
          controller: _baseAmountController,
          keyboardType: numberKeyboard,
          style: theme.textTheme.titleLarge,
          decoration: _moneyDecoration(isLoan ? 'Loan amount' : 'Purchase amount', symbol),
          validator: (v) {
            final n = double.tryParse((v ?? '').trim());
            return (n == null || n <= 0) ? 'Enter the amount' : null;
          },
        ),
        const SizedBox(height: 16),
        tenure,
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextFormField(
                controller: _interestRateController,
                keyboardType: numberKeyboard,
                decoration: InputDecoration(
                  labelText: 'Interest (% a year)',
                  hintText: 'e.g. 12',
                  helperText: 'Empty = no interest',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  final n = double.tryParse(v.trim());
                  return (n == null || n < 0 || n > 100) ? 'Enter 0 to 100' : null;
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _interestType,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Interest type',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
                items: const [
                  DropdownMenuItem(value: 'reducing', child: Text('Reducing balance')),
                  DropdownMenuItem(value: 'flat', child: Text('Flat')),
                ],
                onChanged: (v) => setState(() {
                  _interestType = v ?? 'reducing';
                  _syncCustomSchedule();
                }),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        chargesField,
        const SizedBox(height: 8),
        gstChip,
      ] else ...[
        TextFormField(
          controller: _emiController,
          keyboardType: numberKeyboard,
          style: theme.textTheme.titleLarge,
          decoration: _moneyDecoration('Monthly EMI', symbol),
          validator: (v) {
            final n = double.tryParse((v ?? '').trim());
            return (n == null || n <= 0) ? 'Enter the monthly EMI' : null;
          },
        ),
        const SizedBox(height: 16),
        tenure,
        const SizedBox(height: 16),
        TextFormField(
          controller: _baseAmountController,
          keyboardType: numberKeyboard,
          decoration: _moneyDecoration(
            isLoan ? 'Loan amount (optional)' : 'Purchase amount (optional)',
            symbol,
            helper: 'Lets us show how much extra you pay and the effective interest rate.',
          ),
          validator: (v) {
            if (v == null || v.trim().isEmpty) return null;
            final n = double.tryParse(v.trim());
            return (n == null || n < 0) ? 'Enter a valid amount' : null;
          },
        ),
        const SizedBox(height: 16),
        chargesField,
        const SizedBox(height: 8),
        gstChip,
      ],
    ];
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
              ? (isLoan ? 'Edit loan' : 'Edit card EMI')
              : (isLoan ? 'Add loan' : 'Add card EMI'),
          style: TextStyle(fontWeight: FontWeight.w700),
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
                    isEditing ? 'Save' : 'Add',
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
            // Whose is it, and what kind
            SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: true,
                  label: Text('For myself'),
                  icon: Icon(Icons.person_outline, size: 18),
                ),
                ButtonSegment(
                  value: false,
                  label: Text('With someone'),
                  icon: Icon(Icons.people_outline, size: 18),
                ),
              ],
              selected: {_isForSelf},
              onSelectionChanged: (sel) => setState(() {
                _isForSelf = sel.first;
                if (_isForSelf) {
                  _selectedPersonId = AppConstants.selfPersonId;
                  _isPaidByMe = true;
                } else if (_selectedPersonId == AppConstants.selfPersonId) {
                  _selectedPersonId = null;
                }
              }),
            ),
            const SizedBox(height: 16),
            EmiTypeSelector(
              selectedType: _emiType,
              onChanged: (t) => setState(() => _emiType = t),
            ),
            const SizedBox(height: 20),

            if (!_isForSelf) ...[
              PersonSelectField(
                person: selectedPerson,
                placeholder: isLoan ? 'Choose who the loan is with' : 'Choose who the EMI is shared with',
                onTap: _pickPerson,
              ),
              const SizedBox(height: 16),
              Text(isLoan ? 'Who pays whom?' : 'Whose card is it?', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              ChoiceTileGroup<bool>(
                selected: _isPaidByMe,
                onChanged: (v) => setState(() => _isPaidByMe = v),
                options: [
                  ChoiceOption(
                    value: true,
                    label: isLoan ? 'I lent money' : 'My card',
                    subtitle: isLoan ? 'They repay in installments' : 'They repay me each month',
                    icon: isLoan ? Icons.payments_outlined : Icons.credit_card_rounded,
                  ),
                  ChoiceOption(
                    value: false,
                    label: isLoan ? 'I borrowed' : 'Their card',
                    subtitle: isLoan ? 'I repay in installments' : 'I repay them each month',
                    icon: isLoan ? Icons.handshake_outlined : Icons.payment_rounded,
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],

            // What and from where
            SuggestTextField(
              controller: _itemController,
              label: isLoan ? 'What is the loan for?' : 'What did you buy?',
              hint: isLoan ? 'e.g. Bike loan, emergency' : 'e.g. iPhone 16 Pro, flight tickets',
              prefixIcon: isLoan ? Icons.receipt_long_outlined : Icons.shopping_bag_outlined,
              suggestions: [
                for (final s in isLoan ? _loanPurposeSuggestions : _itemSuggestions) s.asSuggestion,
              ],
              quickPickTitle: 'Common',
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? (isLoan ? 'Enter what the loan is for' : 'Enter what you bought')
                  : null,
            ),
            const SizedBox(height: 20),
            SuggestTextField(
              controller: _cardController,
              label: isLoan ? 'Lender' : 'Card or bank',
              hint: isLoan ? 'e.g. SBI, HDFC, a friend' : 'e.g. HDFC Millennia',
              prefixIcon: isLoan ? Icons.account_balance_outlined : Icons.credit_card_outlined,
              suggestions: [
                for (final s in isLoan ? _loanSourceSuggestions : _cardSuggestions) s.asSuggestion,
              ],
              quickPickTitle: isLoan ? 'Common lenders' : 'Popular cards',
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? (isLoan ? 'Enter the lender' : 'Enter the card or bank')
                  : null,
            ),
            const SizedBox(height: 22),

            // Money: either split a total or type the EMI
            ..._moneySection(context, currencySymbol, isLoan),
            const SizedBox(height: 20),

            // Live result
            EmiSummaryCard(
              plan: _plan,
              isLoan: isLoan,
              splitMode: _splitMode,
              currencySymbol: currencySymbol,
              lastInstallmentDate: _plan.isValid ? _dueDateFor(_plan.months) : null,
              customMonthsCount: _customScheduleMap.length,
              customWasReset: _customWasReset,
              onCustomizeMonths: _customizeMonths,
            ),
            const SizedBox(height: 24),

            // When
            EmiScheduleSection(
              firstDueDate: _startDate,
              dueDayOfMonth: _dueDayOfMonth,
              paidController: _installmentsPaidController,
              tenureMonths: _tenureMonths,
              installmentsPaid: _installmentsPaid,
              dueSoFar: _dueSoFar,
              isEditing: isEditing,
              isForSelf: _isForSelf,
              onPickDate: _selectStartDate,
            ),
            const SizedBox(height: 20),

            // 10. Notes
            TextFormField(
              controller: _notesController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Notes (optional)',
                hintText: isLoan ? 'Loan terms, account number, agreement notes...' : 'Order ID, invoice details, bank reference...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),

            const SizedBox(height: 28),

            // 11. Save Button
            FilledButton(
              onPressed: _isSaving ? null : _saveEmi,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      isEditing ? 'Save changes' : (isLoan ? 'Add loan' : 'Add EMI'),
                      style: TextStyle(
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
