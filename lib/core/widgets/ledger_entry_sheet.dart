import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:duemate/core/constants/app_constants.dart';
import 'package:duemate/core/theme/app_theme.dart';
import 'package:duemate/core/utils/currency_formatter.dart';
import 'package:duemate/core/utils/date_formatter.dart';
import 'package:duemate/core/utils/display_money.dart';
import 'package:duemate/core/widgets/amount_field.dart';
import 'package:duemate/core/widgets/avatar_widget.dart';
import 'package:duemate/core/widgets/confirm_dialog.dart';
import 'package:duemate/core/widgets/person_picker_sheet.dart';
import 'package:duemate/core/widgets/return_by_field.dart';
import 'package:duemate/core/widgets/upi_widgets.dart';
import 'package:duemate/data/database/tables.dart';
import 'package:duemate/data/providers/app_providers.dart';
import 'package:duemate/domain/entities/ledger_transaction.dart';
import 'package:duemate/domain/entities/person_summary.dart';

/// Bottom sheet that records one ledger entry: money given or received.
/// [QuickGiveSheet] and [QuickReceiveSheet] are thin entry points to this.
class LedgerEntrySheet extends ConsumerStatefulWidget {
  final TransactionType type;
  final String? initialPersonId;

  const LedgerEntrySheet({
    super.key,
    required this.type,
    this.initialPersonId,
  });

  static Future<void> show(
    BuildContext context, {
    required TransactionType type,
    String? personId,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LedgerEntrySheet(type: type, initialPersonId: personId),
    );
  }

  @override
  ConsumerState<LedgerEntrySheet> createState() => _LedgerEntrySheetState();
}

class _LedgerEntrySheetState extends ConsumerState<LedgerEntrySheet> with WidgetsBindingObserver {
  static const _presets = [100.0, 500.0, 1000.0, 2000.0, 5000.0];

  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final _focusNode = FocusNode();

  String? _selectedPersonId;
  PaymentMethod _paymentMethod = PaymentMethod.upi;
  DateTime _date = DateTime.now();

  /// Give only: when it should be back.
  DateTime? _dueDate;
  bool _isSaving = false;

  /// Who "Pay with UPI app" was opened for; cleared once we've asked.
  String? _upiPayee;

  bool get _isGive => widget.type == TransactionType.moneyGiven;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _selectedPersonId = widget.initialPersonId;
    if (widget.initialPersonId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _amountController.dispose();
    _noteController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  double get _amount => double.tryParse(_amountController.text.trim()) ?? 0.0;

  void _setAmount(double value) {
    _amountController.text =
        AmountField.plain(value);
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
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  String? get _note {
    final n = _noteController.text.trim();
    return n.isEmpty ? null : n;
  }

  Future<void> _showUpiQr() async {
    _focusNode.unfocus();
    setState(() => _paymentMethod = PaymentMethod.upi);
    await UpiQrSheet.show(context, ref, amount: _amount, note: _note);
  }

  Future<void> _payWithUpi(String name, String upiId) async {
    if (_amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter an amount first')));
      return;
    }
    _focusNode.unfocus();
    setState(() => _paymentMethod = PaymentMethod.upi);
    // Set before launching: the app may be paused before the launch returns.
    _upiPayee = name;
    final opened = await payWithUpiApp(context, ref, payeeId: upiId, payeeName: name, amount: _amount, note: _note);
    if (!opened) _upiPayee = null;
  }

  /// UPI apps don't report back, so once the user is back in DueMate (and
  /// past App Lock, if it kicked in) ask whether the payment went through.
  /// Yes records the Give exactly as filled in.
  Future<void> _askAboutUpiPayment() async {
    final payee = _upiPayee;
    if (payee == null || !mounted) return;
    if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) return;
    if (ref.read(appLockControllerProvider).locked) return; // asked again on unlock
    _upiPayee = null;
    final money = CurrencyFormatter.format(_amount, symbol: ref.read(currencySymbolProvider));
    final paid = await showConfirmDialog(
      context,
      title: 'Did the payment go through?',
      message: 'If your UPI app shows $money sent to $payee, record it now.',
      confirmLabel: 'Yes, record it',
      cancelLabel: 'Not yet',
    );
    if (paid && mounted) await _save();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _askAboutUpiPayment();
  }

  /// UPI shortcut (rupees only): your QR when receiving; a UPI app when
  /// giving to someone whose UPI ID is saved.
  Widget? _upiAction(PersonSummary? selected, String symbol) {
    final amount = _amount > 0 ? ' ${CurrencyFormatter.format(_amount, symbol: symbol)}' : '';
    if (!_isGive) {
      return OutlinedButton.icon(
        onPressed: _showUpiQr,
        icon: const Icon(Icons.qr_code_2_rounded),
        label: Text(amount.isEmpty ? 'Show UPI QR' : 'Show UPI QR for$amount'),
      );
    }
    final payee = selected?.person;
    final upiId = payee?.upiId;
    if (payee == null || upiId == null || upiId.isEmpty) return null;
    return OutlinedButton.icon(
      onPressed: () => _payWithUpi(payee.name, upiId),
      icon: const Icon(Icons.open_in_new_rounded),
      label: Text('Pay$amount with UPI app'),
    );
  }

  Future<void> _save() async {
    final amount = _amount;
    final messenger = ScaffoldMessenger.of(context);
    if (_selectedPersonId == null) {
      messenger.showSnackBar(const SnackBar(content: Text('Choose a person first')));
      return;
    }
    if (amount <= 0) {
      messenger.showSnackBar(const SnackBar(content: Text('Enter an amount greater than 0')));
      return;
    }

    setState(() => _isSaving = true);
    try {
      final now = DateTime.now();
      final note = _noteController.text.trim();
      await ref.read(transactionRepositoryProvider).addTransaction(
            LedgerTransaction(
              id: const Uuid().v4(),
              personId: _selectedPersonId!,
              type: widget.type,
              amount: amount,
              // Keep the picked day, but use the current time so ordering
              // within a day matches entry order.
              transactionDate: DateTime(
                  _date.year, _date.month, _date.day, now.hour, now.minute, now.second),
              paymentMethod: _paymentMethod,
              dueDate: _isGive ? _dueDate : null,
              note: note.isEmpty ? null : note,
              createdAt: now,
              updatedAt: now,
            ),
          );

      if (!mounted) return;
      final name = ref.read(personsMapProvider)[_selectedPersonId]?.name ?? 'them';
      final money = CurrencyFormatter.format(amount, symbol: ref.read(currencySymbolProvider));
      Navigator.of(context).pop();
      messenger.showSnackBar(SnackBar(
        content: Text(_isGive ? 'Gave $money to $name' : 'Received $money from $name'),
      ));
    } catch (_) {
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text("Couldn't save. Please try again.")),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Back from the UPI app but App Lock was up: ask once it's unlocked.
    ref.listen(appLockControllerProvider.select((s) => s.locked), (_, locked) {
      if (!locked) _askAboutUpiPayment();
    });

    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final ledger = LedgerColors.of(context);
    final accent = _isGive ? ledger.cashOut : ledger.cashIn;
    final symbol = ref.watch(currencySymbolProvider);
    final summaries = ref.watch(allPersonSummariesProvider).asData?.value;

    final PersonSummary? selected = _selectedPersonId == null
        ? null
        : summaries?.where((s) => s.person.id == _selectedPersonId).firstOrNull;

    final upiAction = ref.watch(upiAvailableProvider) ? _upiAction(selected, symbol) : null;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Header(
              title: _isGive ? 'Give money' : 'Receive money',
              icon: _isGive ? Icons.north_east_rounded : Icons.south_west_rounded,
              accent: accent,
            ),
            Divider(height: 1, color: cs.outlineVariant),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _PersonPanel(
                      summary: selected,
                      isGive: _isGive,
                      symbol: symbol,
                      money: ref.watch(displayMoneyProvider),
                      accent: accent,
                      onPick: _openPersonPicker,
                      onSettle: _setAmount,
                    ),
                    const SizedBox(height: 20),
                    AmountField(
                      controller: _amountController,
                      focusNode: _focusNode,
                      symbol: symbol,
                      accent: accent,
                      onChanged: () => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final p in _presets)
                          ActionChip(
                            label: Text('+${CurrencyFormatter.format(p, symbol: '').trim()}'),
                            onPressed: () => _setAmount(_amount + p),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final method in PaymentMethod.values)
                          ChoiceChip(
                            label: Text(method.label),
                            selected: method == _paymentMethod,
                            onSelected: (_) => setState(() => _paymentMethod = method),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 2,
                          child: InkWell(
                            onTap: _selectDate,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Date',
                                prefixIcon: Icon(Icons.event_outlined),
                              ),
                              child: Text(
                                DateFormatter.formatRelative(_date),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpace.md),
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: _noteController,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: const InputDecoration(labelText: 'Note (optional)'),
                          ),
                        ),
                      ],
                    ),
                    if (_isGive) ...[
                      const SizedBox(height: AppSpace.lg),
                      ReturnByField(value: _dueDate, from: _date, onChanged: (d) => setState(() => _dueDate = d)),
                    ],
                    const SizedBox(height: 24),
                    if (upiAction != null) ...[
                      upiAction,
                      const SizedBox(height: AppSpace.md),
                    ],
                    SizedBox(
                      height: 52,
                      child: FilledButton.icon(
                        onPressed: _isSaving ? null : _save,
                        icon: _isSaving
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: cs.onPrimary),
                              )
                            : Icon(_isGive ? Icons.north_east_rounded : Icons.south_west_rounded,
                                size: 18),
                        label: Text(
                          _amount > 0
                              ? '${_isGive ? 'Give' : 'Receive'} ${CurrencyFormatter.format(_amount, symbol: symbol)}'
                              : (_isGive ? 'Record money given' : 'Record payment'),
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
}

class _Header extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color accent;

  const _Header({required this.title, required this.icon, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(icon, color: accent, size: 18),
          ),
          const SizedBox(width: 12),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const Spacer(),
          IconButton(
            tooltip: 'Close',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

/// Who the entry is with, their balance, and a one-tap "settle" amount when
/// this entry would clear what's outstanding.
class _PersonPanel extends StatelessWidget {
  final PersonSummary? summary;
  final bool isGive;
  final String symbol;
  final DisplayMoney money;
  final Color accent;
  final VoidCallback onPick;
  final ValueChanged<double> onSettle;

  const _PersonPanel({
    required this.summary,
    required this.isGive,
    required this.symbol,
    required this.money,
    required this.accent,
    required this.onPick,
    required this.onSettle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final ledger = LedgerColors.of(context);
    final s = summary;

    if (s == null) {
      return InkWell(
        onTap: onPick,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: cs.surfaceContainer,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Row(
            children: [
              Icon(Icons.person_add_alt_outlined, color: accent, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Choose a person',
                    style: theme.textTheme.bodyLarge?.copyWith(color: cs.onSurfaceVariant)),
              ),
              Icon(Icons.keyboard_arrow_down_rounded, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      );
    }

    final balance = s.balance;
    final String status;
    final Color statusColor;
    if (balance > 0.0001) {
      status = 'Owes you ${money(balance)}';
      statusColor = ledger.owedToYou;
    } else if (balance < -0.0001) {
      status = 'You owe ${money(-balance)}';
      statusColor = ledger.youOwe;
    } else {
      status = 'Settled';
      statusColor = cs.onSurfaceVariant;
    }

    // Receiving can clear what they owe; giving can clear what you owe.
    final settleAmount = isGive ? (balance < 0 ? -balance : 0.0) : (balance > 0 ? balance : 0.0);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        children: [
          Row(
            children: [
              AvatarWidget(name: s.person.name, radius: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.person.name, style: theme.textTheme.titleSmall),
                    Text(status, style: theme.textTheme.labelMedium?.copyWith(color: statusColor)),
                  ],
                ),
              ),
              TextButton(onPressed: onPick, child: const Text('Change')),
            ],
          ),
          if (settleAmount > 0) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: ActionChip(
                avatar: Icon(Icons.done_all_rounded, size: 16, color: accent),
                label: Text(isGive
                    ? 'Pay back all ${money(settleAmount)}'
                    : 'Settle full balance ${money(settleAmount)}'),
                onPressed: () => onSettle(settleAmount),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
