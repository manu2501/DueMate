import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:smarava/core/constants/app_constants.dart';
import 'package:smarava/core/utils/currency_formatter.dart';
import 'package:smarava/core/utils/date_formatter.dart';
import 'package:smarava/core/widgets/avatar_widget.dart';
import 'package:smarava/data/database/tables.dart';
import 'package:smarava/data/providers/app_providers.dart';
import 'package:smarava/domain/entities/ledger_transaction.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
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

  Future<void> _selectDate() async {
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
        const SnackBar(content: Text('Please select a person')),
      );
      return;
    }
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an amount greater than 0')),
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
            backgroundColor: const Color(0xFF16A34A),
            content: Text(
              'Received ${CurrencyFormatter.format(amount, symbol: currencySymbol)} from $personName',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving repayment: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currencySymbol = ref.watch(currencySymbolProvider);
    final allPersonsAsync = ref.watch(allPersonSummariesProvider);
    final mediaQuery = MediaQuery.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: mediaQuery.viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Header Row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16A34A).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.arrow_downward_rounded,
                    color: Color(0xFF16A34A),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Receive Payment',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Person Selector
            allPersonsAsync.when(
              data: (summaries) {
                final activeSummaries = summaries.where((s) => !s.person.isArchived).toList();
                if (activeSummaries.isEmpty) {
                  return const Text('No persons available. Add a person first.');
                }

                final selectedSummary = summaries.where((s) => s.person.id == _selectedPersonId).firstOrNull;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: _selectedPersonId,
                      decoration: InputDecoration(
                        labelText: 'Person',
                        prefixIcon: selectedSummary != null
                            ? Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: AvatarWidget(name: selectedSummary.person.name, radius: 14),
                              )
                            : const Icon(Icons.person_outline_rounded),
                      ),
                      items: activeSummaries.map((s) {
                        return DropdownMenuItem<String>(
                          value: s.person.id,
                          child: Row(
                            children: [
                              Text(s.person.name),
                              const Spacer(),
                              Text(
                                s.balance > 0
                                    ? 'Owes ${CurrencyFormatter.format(s.balance, symbol: currencySymbol)}'
                                    : s.balance < 0
                                        ? 'Overpaid ${CurrencyFormatter.format(s.balance.abs(), symbol: currencySymbol)}'
                                        : 'Settled',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: s.balance > 0
                                      ? const Color(0xFFDC2626)
                                      : s.balance < 0
                                          ? const Color(0xFF9333EA)
                                          : const Color(0xFF16A34A),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() => _selectedPersonId = val);
                      },
                    ),

                    if (selectedSummary != null && selectedSummary.balance > 0) ...[
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () => _setAmount(selectedSummary.balance),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF16A34A).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF16A34A).withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.check_circle_outline_rounded, size: 14, color: Color(0xFF16A34A)),
                              const SizedBox(width: 6),
                              Text(
                                'Tap to settle full balance: ${CurrencyFormatter.format(selectedSummary.balance, symbol: currencySymbol)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF16A34A),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (err, _) => Text('Error: $err'),
            ),
            const SizedBox(height: 16),

            // Amount Input Field
            TextField(
              controller: _amountController,
              focusNode: _focusNode,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: const Color(0xFF16A34A),
              ),
              decoration: InputDecoration(
                labelText: 'Amount Received',
                prefixText: '$currencySymbol ',
                prefixStyle: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF16A34A),
                ),
                hintText: '0',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),

            // Quick Preset Amount Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _presetChip('+100', 100),
                  const SizedBox(width: 8),
                  _presetChip('+500', 500),
                  const SizedBox(width: 8),
                  _presetChip('+1,000', 1000),
                  const SizedBox(width: 8),
                  _presetChip('+2,000', 2000),
                  const SizedBox(width: 8),
                  _presetChip('+5,000', 5000),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Date & Payment Method Row
            Row(
              children: [
                // Date Button
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _selectDate,
                    icon: const Icon(Icons.calendar_today_rounded, size: 16),
                    label: Text(
                      DateFormatter.formatRelative(_selectedDate),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Payment Method Selector
                Expanded(
                  child: DropdownButtonFormField<PaymentMethod>(
                    initialValue: _selectedPaymentMethod,
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      labelText: 'Method',
                    ),
                    items: PaymentMethod.values.map((m) {
                      return DropdownMenuItem(
                        value: m,
                        child: Row(
                          children: [
                            Icon(m.icon, size: 16),
                            const SizedBox(width: 8),
                            Text(m.label, style: const TextStyle(fontSize: 13)),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedPaymentMethod = val);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Optional Note
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: 'Note (Optional)',
                hintText: 'e.g. Daily payment, cash deposit, etc.',
                prefixIcon: Icon(Icons.note_alt_outlined, size: 18),
              ),
            ),
            const SizedBox(height: 20),

            // Big Receive Action Button
            FilledButton(
              onPressed: _isSaving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      _currentAmount > 0
                          ? 'Receive ${CurrencyFormatter.format(_currentAmount, symbol: currencySymbol)}'
                          : 'Save Repayment',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _presetChip(String label, double amount) {
    return ActionChip(
      label: Text(label),
      onPressed: () => _addAmount(amount),
      visualDensity: VisualDensity.compact,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }
}
