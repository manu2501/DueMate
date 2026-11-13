import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:duemate/core/theme/app_theme.dart';
import 'package:duemate/core/utils/currency_formatter.dart';
import 'package:duemate/core/utils/date_formatter.dart';
import 'package:duemate/core/widgets/amount_dialog.dart';
import 'package:duemate/core/widgets/confirm_dialog.dart';
import 'package:duemate/data/providers/app_providers.dart';
import 'package:duemate/domain/emi_installments.dart';
import 'package:duemate/domain/entities/credit_card_emi.dart';
import 'package:duemate/domain/entities/person.dart';

/// Where an EMI's payments are recorded, for messages: "your expenses" or
/// "Asha's ledger".
String emiPostingPlace(CreditCardEmi emi, Person? person) =>
    emi.isForSelf ? 'your expenses' : "${person?.name.split(' ').first ?? 'their'}'s ledger";

/// What you can do with one installment: mark it paid (on the day you paid)
/// or unpaid, and change its amount.
Future<void> showEmiInstallmentActions(
  BuildContext context,
  WidgetRef ref, {
  required EmiInstallments state,
  required Set<int> posted,
  required int k,
  Person? person,
}) {
  final emi = state.emi;
  final paid = state.isPaid(k);
  // Shared EMIs: paid before tracking started, so nothing was posted. Those
  // are the earliest unposted numbers, so only the last of them can be
  // unmarked here without shifting the others; "Already paid" in Edit
  // covers the rest.
  final untracked = state.paid.difference(posted);
  final isUntracked = untracked.contains(k);
  final canUnmark = paid && (!isUntracked || k == untracked.reduce((a, b) => a > b ? a : b));
  final place = emiPostingPlace(emi, person);
  final due = emi.getDueDateForInstallment(k);
  final symbol = ref.read(currencySymbolProvider);
  final messenger = ScaffoldMessenger.of(context);
  final processor = ref.read(emiProcessorServiceProvider);
  void say(String text) => messenger.showSnackBar(SnackBar(content: Text(text)));

  Future<void> markUnpaid() async {
    final ok = await showConfirmDialog(
      context,
      title: 'Mark installment $k unpaid?',
      message: [
        isUntracked ? 'It no longer counts as paid.' : 'Its entry is removed from $place.',
        if (!emi.isForSelf && !isUntracked) 'Their balance changes to match.',
        "It won't be added again on its own: tap Pay or mark it paid when it is.",
      ].join(' '),
      confirmLabel: 'Mark unpaid',
    );
    if (!ok) return;
    if (await processor.markUnpaid(emi, k)) say('Installment $k marked unpaid');
  }

  Future<void> markPaid() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      helpText: 'Day you paid installment $k',
      initialDate: due.isAfter(today) ? today : due,
      firstDate: emi.startDate.subtract(const Duration(days: 365)),
      lastDate: today,
    );
    if (picked == null) return;
    if (await processor.markPaid(emi, k, paidOn: picked)) say('Installment $k added to $place');
  }

  Future<void> changeAmount() async {
    final value = await showAmountDialog(
      context,
      title: 'Installment $k amount',
      label: 'Amount',
      initial: emi.getMonthlyInstallmentFor(k),
      symbol: symbol,
    );
    if (value == null) return;
    await processor.setInstallmentAmount(emi, k, value);
    say('Installment $k set to ${CurrencyFormatter.format(value, symbol: symbol)}');
  }

  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    showDragHandle: true,
    builder: (sheet) {
      final theme = Theme.of(sheet);
      final muted = theme.colorScheme.onSurfaceVariant;
      final money = ref.read(displayMoneyProvider);
      void run(Future<void> Function() action) {
        Navigator.of(sheet).pop();
        action();
      }

      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpace.screenGutter, 0, AppSpace.screenGutter, AppSpace.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Installment $k of ${emi.totalTenureMonths}', style: theme.textTheme.titleLarge),
                  Text(
                    [
                      'Due ${DateFormatter.formatDate(due)}',
                      money(emi.getMonthlyInstallmentFor(k)),
                      if (isUntracked) 'paid before tracking' else if (paid) 'paid',
                    ].join(' · '),
                    style: theme.textTheme.bodyMedium?.copyWith(color: muted),
                  ),
                ],
              ),
            ),
            if (!paid)
              ListTile(
                leading: const Icon(Icons.check_circle_outline_rounded),
                title: const Text('Mark as paid'),
                subtitle: Text('Pick the day you paid; it goes to $place'),
                onTap: () => run(markPaid),
              ),
            if (canUnmark)
              ListTile(
                leading: const Icon(Icons.undo_rounded),
                title: const Text('Mark as unpaid'),
                subtitle: Text(isUntracked ? 'No longer counts as paid' : 'Removes it from $place'),
                onTap: () => run(markUnpaid),
              )
            else if (paid)
              ListTile(
                enabled: false,
                leading: const Icon(Icons.undo_rounded),
                title: const Text('Mark as unpaid'),
                subtitle: const Text('Paid before tracking: lower "Already paid" in Edit instead'),
              ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Change amount'),
              subtitle: Text(paid && !isUntracked
                  ? 'For this month only; its entry in $place changes too'
                  : 'For this month only'),
              onTap: () => run(changeAmount),
            ),
            const SizedBox(height: AppSpace.md),
          ],
        ),
      );
    },
  );
}
