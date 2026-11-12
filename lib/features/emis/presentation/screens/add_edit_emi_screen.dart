import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:duemate/core/constants/app_constants.dart';
import 'package:duemate/core/theme/app_theme.dart';
import 'package:duemate/core/utils/currency_formatter.dart';
import 'package:duemate/core/utils/date_formatter.dart';
import 'package:duemate/core/widgets/avatar_widget.dart';
import 'package:duemate/core/widgets/person_picker_sheet.dart';
import 'package:duemate/data/providers/app_providers.dart';
import 'package:duemate/domain/emi_calculator.dart';
import 'package:duemate/domain/entities/credit_card_emi.dart';
import 'package:duemate/features/emis/presentation/widgets/add_edit_emi_suggestions.dart';
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
    _itemController.addListener(_onTextChanged);
    _cardController.addListener(_onTextChanged);

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
    _itemController.removeListener(_onTextChanged);
    _cardController.removeListener(_onTextChanged);
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

  void _onTextChanged() {
    setState(() {});
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
            const Text('Uneven months'),
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
                  'Set a different amount for specific months, for example when the first month includes a fee.',
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 12),
                ...List.generate(_tenureMonths, (idx) {
                  final monthNum = idx + 1;
                  final dueDate = _dueDateFor(monthNum);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: TextField(
                      controller: controllers[monthNum],
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Month $monthNum (${DateFormatter.formatShortDate(dueDate)})',
                        prefixText: '${ref.read(currencySymbolProvider)} ',
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
                const SnackBar(content: Text('Month amounts updated')),
              );
            },
            child: const Text('Apply'),
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
                      'For myself',
                      style: TextStyle(
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
                      'For someone else',
                      style: TextStyle(
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

  Widget _summaryCard(BuildContext context, String symbol, bool isLoan) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final muted = cs.onSurfaceVariant;
    final plan = _plan;
    String money(double v) => CurrencyFormatter.format(v, symbol: symbol);

    Widget row(String label, String value, {bool strong = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(child: Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: muted))),
              const SizedBox(width: 12),
              Text(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: strong ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        );

    final rate = (!_splitMode && plan.isValid)
        ? EmiCalculator.impliedAnnualRate(
            principal: plan.principal,
            monthly: plan.monthly,
            months: plan.months,
          )
        : null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Monthly EMI', style: theme.textTheme.labelLarge?.copyWith(color: muted)),
          const SizedBox(height: 2),
          if (!plan.isValid)
            Text(
              _splitMode
                  ? 'Enter the amount and months to see the EMI.'
                  : 'Enter the EMI and months to see the total.',
              style: theme.textTheme.bodyMedium?.copyWith(color: muted),
            )
          else ...[
            Text(
              '${money(plan.monthly)} × ${plan.months} months',
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            Divider(height: 1, color: cs.outlineVariant),
            const SizedBox(height: 8),
            if (plan.principal > 0) row(isLoan ? 'Loan amount' : 'Amount', money(plan.principal)),
            if (_splitMode && plan.interest > 0) row('Interest', money(plan.interest)),
            if (plan.charges > 0)
              row(
                plan.chargesInsideEmi ? 'Charges (spread over the EMIs)' : 'Charges (billed separately)',
                money(plan.charges),
              ),
            row(
              plan.chargesInsideEmi ? 'Total to pay' : 'EMIs add up to',
              money(plan.totalPayable),
              strong: plan.chargesInsideEmi,
            ),
            if (!plan.chargesInsideEmi && plan.charges > 0)
              row('Total cost with charges', money(plan.totalCost), strong: true),
            if (plan.extraCost != null && plan.extraCost! > 0)
              row('Extra over the amount', money(plan.extraCost!)),
            if (rate != null) row('Effective interest', '≈ ${rate.toStringAsFixed(1)}% a year'),
            row('Last installment', DateFormatter.formatShortDate(_dueDateFor(plan.months))),
          ],
          if (plan.isValid) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => _showCustomizeMonthlyAmountsDialog(context),
              icon: const Icon(Icons.edit_calendar_outlined, size: 18),
              label: Text(
                _customScheduleMap.isNotEmpty
                    ? 'Uneven months (${_customScheduleMap.length} set)'
                    : 'Make some months different',
              ),
            ),
          ],
          if (_customWasReset)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Your per-month amounts were cleared because the plan changed.',
                style: theme.textTheme.bodySmall?.copyWith(color: cs.error),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _scheduleSection(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final dueNow = _dueSoFar;
    final unpaidDue = dueNow - _installmentsPaid;

    return [
      Text('Schedule', style: theme.textTheme.titleSmall),
      const SizedBox(height: 8),
      InkWell(
        onTap: _selectStartDate,
        borderRadius: BorderRadius.circular(14),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: 'First due date',
            prefixIcon: const Icon(Icons.event_outlined),
            helperText: 'Due on day $_dueDayOfMonth of every month.',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: Text(DateFormatter.formatShortDate(_startDate)),
        ),
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _installmentsPaidController,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: 'Already paid',
          hintText: '0',
          prefixIcon: const Icon(Icons.history_rounded),
          helperText: "Installments paid before you started tracking. They won't be added to the ledger.",
          helperMaxLines: 3,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
        validator: (v) {
          final n = int.tryParse(v?.trim().isEmpty ?? true ? '0' : v!.trim());
          if (n == null || n < 0) return 'Enter a valid number';
          if (n > _tenureMonths) return 'More than the number of months';
          return null;
        },
      ),
      if (!isEditing && unpaidDue > 0) ...[
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                unpaidDue == 1
                    ? '1 installment is already due, so it will be added to the ledger when you save.'
                    : '$unpaidDue installments are already due, so they will be added to the ledger when you save.',
                style: theme.textTheme.bodySmall?.copyWith(color: muted),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => _installmentsPaidController.text = dueNow.toString(),
                  child: const Text('I already paid these'),
                ),
              ),
            ],
          ),
        ),
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
                isLoan ? 'Loan with' : 'EMI with',
                style: TextStyle(
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
                isLoan ? 'Who pays whom?' : 'Whose card is it?',
                style: TextStyle(
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
                              isLoan ? 'I lent money' : 'My card',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: _isPaidByMe ? cs.primary : cs.onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isLoan ? 'Contact repays in installments' : 'Contact repays monthly installment',
                              style: TextStyle(
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
                              isLoan ? 'I borrowed' : "Their card",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: !_isPaidByMe ? cs.error : cs.onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isLoan ? 'I repay in monthly installments' : 'I repay monthly installment',
                              style: TextStyle(
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
                labelText: isLoan ? 'What is the loan for?' : 'What did you buy?',
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
                                style: TextStyle(
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
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
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
                      style: TextStyle(
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
                labelText: isLoan ? 'Lender' : 'Card or bank',
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
                                style: TextStyle(
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
                                    style: TextStyle(
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
                      style: TextStyle(
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

            // Money: either split a total or type the EMI
            ..._moneySection(context, currencySymbol, isLoan),
            const SizedBox(height: 20),

            // Live result
            _summaryCard(context, currencySymbol, isLoan),
            const SizedBox(height: 24),

            // When
            ..._scheduleSection(context),
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
