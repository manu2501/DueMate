import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:duemate/core/constants/app_constants.dart';
import 'package:duemate/core/widgets/whatsapp_icon.dart';
import 'package:duemate/core/utils/currency_formatter.dart';
import 'package:duemate/core/utils/date_formatter.dart';
import 'package:duemate/core/utils/whatsapp_helper.dart';
import 'package:duemate/data/providers/app_providers.dart';
import 'package:duemate/domain/entities/credit_card_emi.dart';
import 'package:duemate/domain/entities/person.dart';
import 'package:duemate/features/emis/presentation/screens/add_edit_emi_screen.dart';

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
      backgroundColor: Colors.transparent,
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

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this schedule?'),
        content: const Text(
          'The schedule is removed. Installments already posted to the ledger stay there, so balances don\'t change.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () async {
              Navigator.of(ctx).pop(); // dialog
              Navigator.of(context).pop(); // sheet
              await ref.read(emiRepositoryProvider).deleteEmi(emi.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Schedule deleted')),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final currencySymbol = ref.watch(currencySymbolProvider);

    final isCompleted = emi.isCompleted;
    final personName = person?.name ?? 'Friend';

    final isLoan = emi.isLoan;

    final accentColor = isCompleted
        ? cs.primary
        : (isLoan ? const Color(0xFF0D9488) : Theme.of(context).colorScheme.secondary);

    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: EdgeInsets.fromLTRB(20, 0, 20, 24 + bottomPadding),
              children: [
                // Header with icon and title
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        isLoan ? Icons.account_balance_wallet_rounded : Icons.credit_card_rounded,
                        color: accentColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            emi.itemName,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${emi.cardName} • With $personName',
                            style: TextStyle(
                              fontSize: 13,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? cs.primary.withValues(alpha: 0.12)
                            : accentColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isCompleted ? 'COMPLETED' : (isLoan ? 'LOAN EMI' : 'CARD EMI'),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isCompleted ? cs.primary : accentColor,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // Direction & Repayment Card
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: cs.outlineVariant),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        emi.isPaidByMe ? Icons.north_east_rounded : Icons.south_west_rounded,
                        color: emi.isPaidByMe ? cs.primary : cs.error,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          emi.isForSelf
                              ? (isLoan
                                  ? 'Personal Loan Schedule'
                                  : 'Personal Credit Card EMI Schedule')
                              : (isLoan
                                  ? (emi.isPaidByMe
                                      ? 'Shared Loan • $personName repays you in monthly installments'
                                      : 'Shared Loan • You repay $personName in monthly installments')
                                  : (emi.isPaidByMe
                                      ? 'Shared EMI • $personName repays you in monthly installments'
                                      : "Shared EMI • You repay $personName in monthly installments")),
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Progress Bar & Stats
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${emi.installmentsPaid} of ${emi.totalTenureMonths} installments paid',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      '${(emi.progress * 100).toInt()}%',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: cs.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: emi.progress,
                    minHeight: 8,
                    backgroundColor: cs.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation(accentColor),
                  ),
                ),

                const SizedBox(height: 18),

                // Financial Overview 3-column Box
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: cs.outlineVariant),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatColumn(
                        context,
                        'Monthly EMI',
                        CurrencyFormatter.format(emi.monthlyInstallment, symbol: currencySymbol),
                        accentColor,
                      ),
                      Container(width: 1, height: 36, color: cs.outlineVariant),
                      _buildStatColumn(
                        context,
                        'Paid So Far',
                        CurrencyFormatter.format(emi.paidAmount, symbol: currencySymbol),
                        cs.primary,
                      ),
                      Container(width: 1, height: 36, color: cs.outlineVariant),
                      _buildStatColumn(
                        context,
                        'Remaining',
                        CurrencyFormatter.format(emi.remainingAmount, symbol: currencySymbol),
                        emi.remainingAmount > 0 ? cs.error : cs.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Schedule Breakdown Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Installment Schedule',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      'Due ${emi.dueDayOfMonth.toString().padLeft(2, '0')}th of month',
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // List of all monthly installments
                Container(
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: cs.outlineVariant),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: emi.totalTenureMonths,
                    separatorBuilder: (ctx, i) => Divider(
                      height: 1,
                      indent: 48,
                      endIndent: 16,
                      color: cs.outlineVariant.withValues(alpha: 0.6),
                    ),
                    itemBuilder: (ctx, index) {
                      final installmentNum = index + 1;
                      final isPaid = installmentNum <= emi.installmentsPaid;
                      final isNextToPay = installmentNum == emi.installmentsPaid + 1;
                      final dueDate = emi.getDueDateForInstallment(installmentNum);

                      return InkWell(
                        onTap: () => _editSingleInstallmentAmount(context, ref, installmentNum),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: isPaid
                                    ? cs.primary.withValues(alpha: 0.12)
                                    : cs.surfaceContainerHighest,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: isPaid
                                    ? Icon(Icons.check_rounded, size: 18, color: cs.primary)
                                    : Text(
                                        '$installmentNum',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: cs.onSurfaceVariant,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Installment $installmentNum of ${emi.totalTenureMonths}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: isPaid ? cs.onSurface : cs.onSurfaceVariant,
                                    ),
                                  ),
                                  Text(
                                    DateFormatter.formatDate(dueDate),
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  CurrencyFormatter.format(emi.getMonthlyInstallmentFor(installmentNum), symbol: currencySymbol),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: isPaid ? cs.primary : cs.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                if (isPaid)
                                  Text(
                                    emi.isForSelf ? 'Paid to Bank' : 'Recorded in Ledger',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                      color: cs.primary,
                                    ),
                                  )
                                else if (isNextToPay)
                                  SizedBox(
                                    height: 28,
                                    child: FilledButton.icon(
                                      onPressed: () async {
                                        final processor = ref.read(emiProcessorServiceProvider);
                                        final success = await processor.postNextInstallment(emi);
                                        if (context.mounted) {
                                          Navigator.of(context).pop();
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                success
                                                    ? 'Installment $installmentNum recorded!'
                                                    : 'Could not record installment',
                                              ),
                                            ),
                                          );
                                        }
                                      },
                                      icon: const Icon(Icons.bolt_rounded, size: 12),
                                      label: Text(
                                        emi.isForSelf ? 'Post Early' : 'Mark Billed',
                                        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold),
                                      ),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: accentColor,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 8),
                                        visualDensity: VisualDensity.compact,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                    ),
                                  )
                                else
                                  Text(
                                    'Scheduled',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                      color: cs.outline,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                    },
                  ),
                ),

                const SizedBox(height: 20),

                if (!isCompleted && person != null && !emi.isForSelf && person!.id != AppConstants.selfPersonId) ...[
                  OutlinedButton.icon(
                    onPressed: () {
                      final msg = WhatsAppHelper.generateEmiReminderMessage(
                        emi,
                        person!,
                        currencySymbol: currencySymbol,
                      );
                      WhatsAppHelper.sendWhatsAppMessage(
                        phoneNumber: person!.phone,
                        message: msg,
                        context: context,
                      );
                    },
                    icon: const WhatsAppIcon(size: 18),
                    label: Text(
                      'Remind $personName on WhatsApp',
                      style: TextStyle(fontWeight: FontWeight.w600, color: const Color(0xFF25D366)),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF25D366)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          AddEditEmiScreen.show(context, emi: emi);
                        },
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        label: const Text('Edit'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _confirmDelete(context, ref),
                        icon: Icon(Icons.delete_outline, size: 16, color: cs.error),
                        label: Text('Delete', style: TextStyle(color: cs.error)),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: cs.error.withValues(alpha: 0.4)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(BuildContext context, String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}
