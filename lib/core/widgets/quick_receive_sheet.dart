import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:duemate/core/constants/app_constants.dart';
import 'package:duemate/core/utils/currency_formatter.dart';
import 'package:duemate/core/utils/date_formatter.dart';
import 'package:duemate/core/widgets/avatar_widget.dart';
import 'package:duemate/core/widgets/person_picker_sheet.dart';
import 'package:duemate/data/database/tables.dart';
import 'package:duemate/data/providers/app_providers.dart';
import 'package:duemate/domain/entities/ledger_transaction.dart';
import 'package:duemate/domain/entities/person_summary.dart';

class QuickReceiveSheet extends ConsumerStatefulWidget {
  final String? initialPersonId;

  const QuickReceiveSheet({
    super.key,
    this.initialPersonId,
  });

  static Future<void> show(BuildContext context, {String? personId}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => QuickReceiveSheet(initialPersonId: personId),
    );
  }

  @override
  ConsumerState<QuickReceiveSheet> createState() => _QuickReceiveSheetState();
}

class _QuickReceiveSheetState extends ConsumerState<QuickReceiveSheet> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final _focusNode = FocusNode();

  String? _selectedPersonId;
  PaymentMethod _selectedPaymentMethod = PaymentMethod.upi;
  DateTime _selectedDate = DateTime.now();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedPersonId = widget.initialPersonId;

    if (widget.initialPersonId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  double get _currentAmount {
    return double.tryParse(_amountController.text.trim()) ?? 0.0;
  }

  void _addAmount(double add) {
    final current = _currentAmount;
    final updated = current + add;
    _amountController.text = updated % 1 == 0 ? updated.toInt().toString() : updated.toStringAsFixed(2);
    setState(() {});
  }

  void _setAmount(double amount) {
    _amountController.text = amount % 1 == 0 ? amount.toInt().toString() : amount.toStringAsFixed(2);
    setState(() {});
  }

  Future<void> _openPersonPicker() async {
    _focusNode.unfocus();
    final pickedId = await PersonPickerSheet.show(
      context,
      currentSelectedPersonId: _selectedPersonId,
    );

    if (pickedId != null && mounted) {
      setState(() => _selectedPersonId = pickedId);
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted) _focusNode.requestFocus();
      });
    }
  }

  Future<void> _selectDate() async {
    _focusNode.unfocus();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _save() async {
    final amount = _currentAmount;
    if (_selectedPersonId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a person first')),
      );
      return;
    }
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter an amount greater than 0')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final now = DateTime.now();
      final tx = LedgerTransaction(
        id: const Uuid().v4(),
        personId: _selectedPersonId!,
        type: TransactionType.paymentReceived,
        amount: amount,
        transactionDate: DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
          now.hour,
          now.minute,
          now.second,
        ),
        paymentMethod: _selectedPaymentMethod,
        note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
        createdAt: now,
        updatedAt: now,
      );

      await ref.read(transactionRepositoryProvider).addTransaction(tx);

      if (mounted) {
        final personsMap = ref.read(personsMapProvider);
        final personName = personsMap[_selectedPersonId]?.name ?? 'Person';
        final currencySymbol = ref.read(currencySymbolProvider);

        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Received ${CurrencyFormatter.format(amount, symbol: currencySymbol)} from $personName',
            ),
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
    final allPersonsAsync = ref.watch(allPersonSummariesProvider);
    final viewInsets = MediaQuery.of(context).viewInsets;

    PersonSummary? selectedSummary;
    if (_selectedPersonId != null) {
      selectedSummary = allPersonsAsync.asData?.value
          .where((s) => s.person.id == _selectedPersonId)
          .firstOrNull;
    }

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.south_west_rounded, color: cs.primary, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Receive Payment',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),

            Divider(height: 1, color: cs.outlineVariant),

            // Form Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Person Selector
                    if (selectedSummary == null)
                      InkWell(
                        onTap: _openPersonPicker,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: cs.surfaceContainer,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: cs.primary.withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.person_add_rounded, color: cs.primary, size: 18),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Select Person...',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              ),
                              Icon(Icons.keyboard_arrow_down_rounded, color: cs.onSurfaceVariant),
                            ],
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainer,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                AvatarWidget(name: selectedSummary.person.name, radius: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        selectedSummary.person.name,
                                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                                      ),
                                      Text(
                                        selectedSummary.balance > 0
                                            ? 'Outstanding: ${CurrencyFormatter.format(selectedSummary.balance, symbol: currencySymbol)}'
                                            : 'All dues settled',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: selectedSummary.balance > 0 ? cs.error : cs.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                TextButton(
                                  onPressed: _openPersonPicker,
                                  child: const Text('Change'),
                                ),
                              ],
                            ),
                            if (selectedSummary.balance > 0) ...[
                              const SizedBox(height: 10),
                              InkWell(
                                onTap: () => _setAmount(selectedSummary!.balance),
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: cs.primary.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.bolt_rounded, size: 16, color: cs.primary),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          'Settle full balance: ${CurrencyFormatter.format(selectedSummary.balance, symbol: currencySymbol)}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: cs.primary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                    const SizedBox(height: 20),

                    // Amount Input
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainer,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Text(
                            currencySymbol,
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w600,
                              color: cs.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _amountController,
                              focusNode: _focusNode,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 32,
                                letterSpacing: -0.5,
                              ),
                              decoration: InputDecoration(
                                hintText: '0',
                                hintStyle: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 32,
                                  color: cs.outline,
                                ),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                filled: false,
                                contentPadding: EdgeInsets.zero,
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          if (_amountController.text.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              onPressed: () {
                                _amountController.clear();
                                setState(() {});
                              },
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Presets
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _presetChip('+100', 100, cs),
                          const SizedBox(width: 8),
                          _presetChip('+500', 500, cs),
                          const SizedBox(width: 8),
                          _presetChip('+1,000', 1000, cs),
                          const SizedBox(width: 8),
                          _presetChip('+2,000', 2000, cs),
                          const SizedBox(width: 8),
                          _presetChip('+5,000', 5000, cs),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Payment Method
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: PaymentMethod.values.map((method) {
                          final isSelected = method == _selectedPaymentMethod;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: ChoiceChip(
                              label: Text(method.label),
                              selected: isSelected,
                              onSelected: (_) => setState(() => _selectedPaymentMethod = method),
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Date & Note
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: _selectDate,
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: cs.surfaceContainer,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.calendar_today_rounded, size: 16, color: cs.primary),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      DateFormatter.formatRelative(_selectedDate),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _noteController,
                            decoration: const InputDecoration(
                              hintText: 'Note (optional)',
                              prefixIcon: Icon(Icons.notes_rounded, size: 16),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Submit
                    SizedBox(
                      height: 52,
                      child: FilledButton(
                        onPressed: _isSaving ? null : _save,
                        child: _isSaving
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: cs.onPrimary),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.south_west_rounded, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    _currentAmount > 0
                                        ? 'Receive ${CurrencyFormatter.format(_currentAmount, symbol: currencySymbol)}'
                                        : 'Record payment',
                                  ),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _presetChip(String label, double value, ColorScheme cs) {
    return ActionChip(
      label: Text(label),
      onPressed: () => _addAmount(value),
    );
  }
}
