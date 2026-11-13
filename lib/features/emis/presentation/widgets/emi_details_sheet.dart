import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:duemate/core/constants/app_constants.dart';
import 'package:duemate/core/widgets/confirm_dialog.dart';
import 'package:duemate/core/theme/app_theme.dart';
import 'package:duemate/core/widgets/ui_kit.dart';
import 'package:duemate/core/utils/currency_formatter.dart';
import 'package:duemate/core/utils/date_formatter.dart';
import 'package:duemate/core/utils/whatsapp_helper.dart';
import 'package:duemate/data/providers/app_providers.dart';
import 'package:duemate/domain/entities/credit_card_emi.dart';
import 'package:duemate/domain/entities/person.dart';
import 'package:duemate/features/emis/presentation/screens/add_edit_emi_screen.dart';
import 'package:duemate/features/emis/presentation/widgets/emi_card.dart';
import 'package:duemate/features/emis/presentation/widgets/emi_pay_dialog.dart';

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

  void _editSingleInstallmentAmount(BuildContext context, WidgetRef ref, int installmentNum) {
    final currentVal = emi.getMonthlyInstallmentFor(installmentNum);
    final controller = TextEditingController(text: currentVal.toStringAsFixed(0));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Month $installmentNum amount'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Change what you pay for ${emi.itemName} in month $installmentNum. Other months are unchanged.'),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Amount',
                prefixText: '${ref.read(currencySymbolProvider)} ',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final newAmount = double.tryParse(controller.text.trim());
              if (newAmount == null || newAmount <= 0) return;

              final Map<String, dynamic> scheduleMap = emi.customScheduleJson != null && emi.customScheduleJson!.isNotEmpty
                  ? jsonDecode(emi.customScheduleJson!)
                  : {};
              scheduleMap['$installmentNum'] = newAmount;

              final updatedEmi = emi.copyWith(
                customScheduleJson: jsonEncode(scheduleMap),
                updatedAt: DateTime.now(),
              );

              await ref.read(emiRepositoryProvider).updateEmi(updatedEmi);

              if (ctx.mounted) Navigator.of(ctx).pop();
              if (context.mounted) Navigator.of(context).pop();

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Month $installmentNum set to ${CurrencyFormatter.format(newAmount, symbol: ref.read(currencySymbolProvider))}')),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Delete this schedule?',
      message:
          emi.isForSelf
          ? "The schedule is removed. Installments already in your expenses stay there."
          : "The schedule is removed. Installments already posted to the ledger stay there, so balances don't change.",
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(emiRepositoryProvider);
    Navigator.of(context).pop();
    await repo.deleteEmi(emi.id);
    messenger.showSnackBar(const SnackBar(content: Text('Schedule deleted')));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final symbol = ref.watch(currencySymbolProvider);
    final money = ref.watch(displayMoneyProvider);

    final done = emi.isCompleted;
    final isShared = !emi.isForSelf && person != null && person!.id != AppConstants.selfPersonId;
    final relation = EmiCard.relation(emi, person);
    final lastDue = emi.getDueDateForInstallment(emi.totalTenureMonths);
    final canRemind = isShared && !done && (person!.phone?.trim().isNotEmpty ?? false);

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

    Future<void> recordPayment() async {
      final messenger = ScaffoldMessenger.of(context);
      final choice = await EmiPayDialog.show(context, emi: emi, symbol: symbol);
      if (choice == null) return;
      final n = await ref.read(emiProcessorServiceProvider).payInstallments(emi, count: choice.count, paidOn: choice.paidOn);
      if (context.mounted) Navigator.of(context).pop();
      final where = emi.isForSelf ? 'your expenses' : 'the ledger';
      messenger.showSnackBar(SnackBar(
        content: Text(n == 0 ? "Couldn't record the payment" : (n == 1 ? 'Installment added to $where' : '$n installments added to $where')),
      ));
    }

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
              figure('Each month', money(emi.monthlyInstallment)),
              figure('Paid', money(emi.paidAmount)),
              figure('Left', money(emi.remainingAmount)),
            ],
          ),
          const SizedBox(height: AppSpace.lg),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(value: emi.progress, color: done ? cs.outline : cs.primary),
          ),
          const SizedBox(height: AppSpace.sm),
          Text(
            done
                ? 'Completed · all ${emi.totalTenureMonths} paid'
                : '${emi.installmentsPaid} of ${emi.totalTenureMonths} paid · ends ${DateFormatter.formatMonthYear(lastDue)}',
            style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SectionHeader('Schedule', padding: EdgeInsets.only(top: AppSpace.xl, bottom: AppSpace.xs)),
          Text(
            'Due on day ${emi.dueDayOfMonth} each month. Tap a month to change its amount.',
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
                  amount: money(emi.getMonthlyInstallmentFor(k)),
                  paid: k <= emi.installmentsPaid,
                  isNext: k == emi.installmentsPaid + 1 && !done,
                  onTap: () => _editSingleInstallmentAmount(context, ref, k),
                  onRecordNow: recordPayment,
                ),
            ],
          ),
          const SizedBox(height: AppSpace.xl),
          if (canRemind) ...[
            OutlinedButton.icon(
              onPressed: () => WhatsAppHelper.sendWhatsAppMessage(
                phoneNumber: person!.phone,
                message: WhatsAppHelper.generateEmiReminderMessage(emi, person!, currencySymbol: symbol),
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
                  onPressed: () => _confirmDelete(context, ref),
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
}

class _ScheduleRow extends StatelessWidget {
  final int number;
  final DateTime date;
  final String amount;
  final bool paid;
  final bool isNext;
  final VoidCallback onTap;
  final VoidCallback onRecordNow;

  const _ScheduleRow({
    required this.number,
    required this.date,
    required this.amount,
    required this.paid,
    required this.isNext,
    required this.onTap,
    required this.onRecordNow,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final amountText = Text(
      amount,
      style: theme.textTheme.titleSmall?.copyWith(color: paid ? cs.onSurfaceVariant : cs.onSurface),
    );
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: paid ? cs.primaryContainer : cs.surfaceContainer,
        child: paid
            ? Icon(Icons.check_rounded, size: 18, color: cs.onPrimaryContainer)
            : Text('$number', style: theme.textTheme.labelMedium),
      ),
      title: Text(DateFormatter.formatDate(date)),
      subtitle: Text(paid ? 'Paid' : (isNext ? 'Next' : 'Upcoming')),
      trailing: isNext
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                amountText,
                const SizedBox(width: AppSpace.sm),
                FilledButton.tonal(
                  onPressed: onRecordNow,
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
