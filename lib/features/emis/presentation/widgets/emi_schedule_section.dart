import 'package:flutter/material.dart';
import 'package:duemate/core/theme/app_theme.dart';
import 'package:duemate/core/utils/date_formatter.dart';

/// First due date and installments already paid, with a nudge when past
/// installments would be back-filled into the ledger. Your own EMIs post
/// every paid installment to expenses, in the month it was due.
class EmiScheduleSection extends StatelessWidget {
  final DateTime firstDueDate;
  final int dueDayOfMonth;
  final TextEditingController paidController;
  final int tenureMonths;
  final int installmentsPaid;

  /// How many installments have already fallen due as of today.
  final int dueSoFar;
  final bool isEditing;

  /// Your own EMI or loan (installments go to expenses).
  final bool isForSelf;
  final VoidCallback onPickDate;

  const EmiScheduleSection({
    super.key,
    required this.firstDueDate,
    required this.dueDayOfMonth,
    required this.paidController,
    required this.tenureMonths,
    required this.installmentsPaid,
    required this.dueSoFar,
    required this.isEditing,
    required this.isForSelf,
    required this.onPickDate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final unpaidDue = dueSoFar - installmentsPaid;
    final border = OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Schedule', style: theme.textTheme.titleSmall),
        const SizedBox(height: AppSpace.sm),
        InkWell(
          onTap: onPickDate,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: 'First due date',
              prefixIcon: const Icon(Icons.event_outlined),
              helperText: 'Due on day $dueDayOfMonth of every month.',
              border: border,
            ),
            child: Text(DateFormatter.formatShortDate(firstDueDate)),
          ),
        ),
        const SizedBox(height: AppSpace.lg),
        TextFormField(
          controller: paidController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Already paid',
            hintText: '0',
            prefixIcon: const Icon(Icons.history_rounded),
            helperText: isForSelf
                ? 'Installments you have paid so far. Each is added to your expenses in the month it was due.'
                : "Installments paid before you started tracking. They won't be added to the ledger.",
            helperMaxLines: 3,
            border: border,
          ),
          validator: (v) {
            final text = (v ?? '').trim();
            final n = int.tryParse(text.isEmpty ? '0' : text);
            if (n == null || n < 0) return 'Enter a valid number';
            if (n > tenureMonths) return 'More than the number of months';
            return null;
          },
        ),
        if (!isEditing && !isForSelf && unpaidDue > 0) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(AppSpace.md),
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
                TextButton(
                  onPressed: () => paidController.text = dueSoFar.toString(),
                  child: const Text('I already paid these'),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
