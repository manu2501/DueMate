import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:duemate/core/constants/app_constants.dart';
import 'package:duemate/core/widgets/confirm_dialog.dart';
import 'package:duemate/core/theme/app_theme.dart';
import 'package:duemate/core/widgets/ui_kit.dart';
import 'package:duemate/core/utils/date_formatter.dart';
import 'package:duemate/core/utils/whatsapp_helper.dart';
import 'package:duemate/data/providers/app_providers.dart';
import 'package:duemate/domain/emi_installments.dart';
import 'package:duemate/domain/entities/credit_card_emi.dart';
import 'package:duemate/domain/entities/person.dart';
import 'package:duemate/features/emis/presentation/screens/add_edit_emi_screen.dart';
import 'package:duemate/features/emis/presentation/widgets/emi_card.dart';
import 'package:duemate/features/emis/presentation/widgets/emi_installment_actions.dart';
import 'package:duemate/features/emis/presentation/widgets/emi_pay_dialog.dart';

/// One EMI: figures, the full schedule with what is actually paid (gaps and
/// missed months included), and its actions. Stays live: paying or marking
/// a month updates it in place.
class EmiDetailsSheet extends ConsumerWidget {
  final CreditCardEmi emi;
  final Person? person;

  const EmiDetailsSheet({
    super.key,
    required this.emi,
    this.person,
  });

  static Future<void> show(BuildContext context, {required CreditCardEmi emi, Person? person}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      useRootNavigator: true,
      builder: (_) => EmiDetailsSheet(emi: emi, person: person),
    );
  }

  /// Asks first, saying exactly what goes: the EMI and every payment it
  /// recorded (your expenses, or the person's ledger and so their balance).
  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, CreditCardEmi emi, Set<int> posted) async {
    final what = emi.isLoan ? 'loan' : 'EMI';
    final total = posted.fold<double>(0, (s, k) => s + emi.getMonthlyInstallmentFor(k));
    final payments = posted.length == 1 ? '1 payment' : '${posted.length} payments';
    final place = emiPostingPlace(emi, person);
    final ok = await showConfirmDialog(
      context,
      title: 'Delete ${emi.itemName}?',
      message: [
        if (posted.isEmpty)
          'The $what and its schedule are deleted. No payments were recorded for it.'
        else ...[
          'The $what, its schedule and its $payments in $place '
              '(${ref.read(displayMoneyProvider)(total)}) are deleted.',
          if (!emi.isForSelf) "${person?.name.split(' ').first ?? 'Their'}'s balance changes to match.",
        ],
        "This can't be undone.",
      ].join(' '),
      confirmLabel: 'Delete $what',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(emiRepositoryProvider);
    Navigator.of(context).pop();
    await repo.deleteEmi(emi.id);
    messenger.showSnackBar(SnackBar(content: Text('${emi.itemName} deleted')));
  }

  Future<void> _pay(BuildContext context, WidgetRef ref, EmiInstallments state) async {
    final messenger = ScaffoldMessenger.of(context);
    final choice = await EmiPayDialog.show(context, state: state, symbol: ref.read(currencySymbolProvider));
    if (choice == null) return;
    final n = await ref
        .read(emiProcessorServiceProvider)
        .payInstallments(state.emi, count: choice.count, paidOn: choice.paidOn);
    final place = emiPostingPlace(state.emi, person);
    messenger.showSnackBar(SnackBar(
      content: Text(switch (n) {
        0 => "Couldn't record the payment",
        1 => 'Installment added to $place',
        _ => '$n installments added to $place',
      }),
    ));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final symbol = ref.watch(currencySymbolProvider);
    final money = ref.watch(displayMoneyProvider);

    // The latest copy, so the sheet follows payments and edits.
    final emi = ref.watch(allEmisProvider).value?.where((e) => e.id == this.emi.id).firstOrNull ?? this.emi;
    final posted = ref.watch(emiPostingsProvider.select((m) => m[emi.id])) ?? const <int>{};
    final state = EmiInstallments.of(emi, posted);
    final today = DateUtils.dateOnly(DateTime.now());

    final done = state.isComplete;
    final next = state.next;
    final isShared = !emi.isForSelf && person != null && person!.id != AppConstants.selfPersonId;
    final relation = EmiCard.relation(emi, person);
    final lastDue = emi.getDueDateForInstallment(emi.totalTenureMonths);
    final canRemind = isShared && !done && (person!.phone?.trim().isNotEmpty ?? false);
    final missed = state.unpaid.where((k) => emi.getDueDateForInstallment(k).isBefore(today)).length;

    Widget figure(String label, String value) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              const SizedBox(height: 2),
              Text(value, style: theme.textTheme.titleMedium),
            ],
          ),
        );

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (ctx, scroll) => ListView(
        controller: scroll,
        padding: EdgeInsets.fromLTRB(
          AppSpace.screenGutter,
          0,
          AppSpace.screenGutter,
          AppSpace.xl + MediaQuery.of(context).padding.bottom,
        ),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconBadge(emi.isLoan ? Icons.account_balance_outlined : Icons.credit_card_outlined, size: 48),
              const SizedBox(width: AppSpace.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(emi.itemName, style: theme.textTheme.titleLarge),
                    Text(
                      [emi.cardName, relation ?? (emi.isLoan ? 'Your loan' : 'Your EMI')].join(' · '),
                      style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.xl),
          Row(
            children: [
              figure('Each month', money(emi.monthlyInstallment, exact: true)),
              figure('Paid', money(state.paidAmount, exact: true)),
              figure('Left', money(state.remainingAmount, exact: true)),
            ],
          ),
          const SizedBox(height: AppSpace.lg),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(value: state.progress, color: done ? cs.outline : cs.primary),
          ),
          const SizedBox(height: AppSpace.sm),
          Text(
            done
                ? 'Completed · all ${emi.totalTenureMonths} paid'
                : '${state.count} of ${emi.totalTenureMonths} paid · ends ${DateFormatter.formatMonthYear(lastDue)}',
            style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          if (missed > 0) ...[
            const SizedBox(height: AppSpace.xs),
            Row(
              children: [
                Icon(Icons.error_outline_rounded, size: 16, color: cs.tertiary),
                const SizedBox(width: AppSpace.xs),
                Text(
                  missed == 1 ? '1 past installment not paid' : '$missed past installments not paid',
                  style: theme.textTheme.bodySmall?.copyWith(color: cs.tertiary),
                ),
              ],
            ),
          ],
          const SectionHeader('Schedule', padding: EdgeInsets.only(top: AppSpace.xl, bottom: AppSpace.xs)),
          Text(
            'Due on day ${emi.dueDayOfMonth} each month. Tap a month to mark it paid or unpaid, or to change its amount.',
            style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpace.md),
          GroupCard(
            margin: EdgeInsets.zero,
            dividerIndent: 64,
            children: [
              for (var k = 1; k <= emi.totalTenureMonths; k++)
                _ScheduleRow(
                  number: k,
                  date: emi.getDueDateForInstallment(k),
                  amount: money(emi.getMonthlyInstallmentFor(k), exact: true),
                  status: _statusOf(state, posted, k, today),
                  isNext: k == next,
                  onTap: () => showEmiInstallmentActions(context, ref, state: state, posted: posted, k: k, person: person),
                  onPay: () => _pay(context, ref, state),
                ),
            ],
          ),
          const SizedBox(height: AppSpace.xl),
          if (canRemind) ...[
            OutlinedButton.icon(
              onPressed: () => WhatsAppHelper.sendWhatsAppMessage(
                phoneNumber: person!.phone,
                message: WhatsAppHelper.generateEmiReminderMessage(emi, person!, currencySymbol: symbol, installment: next),
                context: context,
              ),
              icon: const Icon(Icons.chat_outlined),
              label: Text('Remind ${person!.name.split(' ').first} on WhatsApp'),
            ),
            const SizedBox(height: AppSpace.md),
          ],
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    AddEditEmiScreen.show(context, emi: emi);
                  },
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit'),
                ),
              ),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: TextButton.icon(
                  onPressed: () => _confirmDelete(context, ref, emi, posted),
                  style: TextButton.styleFrom(foregroundColor: cs.error, minimumSize: const Size(0, 52)),
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Delete'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static _Status _statusOf(EmiInstallments state, Set<int> posted, int k, DateTime today) {
    if (state.isPaid(k)) return posted.contains(k) ? _Status.paid : _Status.paidBeforeTracking;
    return state.emi.getDueDateForInstallment(k).isBefore(today) ? _Status.missed : _Status.upcoming;
  }
}

enum _Status { paid, paidBeforeTracking, missed, upcoming }

class _ScheduleRow extends StatelessWidget {
  final int number;
  final DateTime date;
  final String amount;
  final _Status status;

  /// The earliest unpaid installment: gets the Pay button.
  final bool isNext;
  final VoidCallback onTap;
  final VoidCallback onPay;

  const _ScheduleRow({
    required this.number,
    required this.date,
    required this.amount,
    required this.status,
    required this.isNext,
    required this.onTap,
    required this.onPay,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final paid = status == _Status.paid || status == _Status.paidBeforeTracking;
    final missed = status == _Status.missed;
    final amountText = Text(
      amount,
      style: theme.textTheme.titleSmall?.copyWith(color: paid ? cs.onSurfaceVariant : cs.onSurface),
    );
    final label = switch (status) {
      _Status.paid => 'Paid',
      _Status.paidBeforeTracking => 'Paid before tracking',
      // Overdue is the warning colour with an icon, never red.
      _Status.missed => 'Not paid',
      _Status.upcoming => isNext ? 'Next' : 'Upcoming',
    };
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: paid ? cs.primaryContainer : cs.surfaceContainer,
        child: paid
            ? Icon(Icons.check_rounded, size: 18, color: cs.onPrimaryContainer)
            : missed
                ? Icon(Icons.error_outline_rounded, size: 18, color: cs.tertiary)
                : Text('$number', style: theme.textTheme.labelMedium),
      ),
      title: Text(DateFormatter.formatDate(date)),
      subtitle: Text(label, style: missed ? TextStyle(color: cs.tertiary) : null),
      trailing: isNext
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                amountText,
                const SizedBox(width: AppSpace.sm),
                FilledButton.tonal(
                  onPressed: onPay,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
                  ),
                  child: const Text('Pay'),
                ),
              ],
            )
          : amountText,
    );
  }
}
