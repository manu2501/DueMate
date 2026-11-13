import 'package:flutter/material.dart';
import 'package:duemate/core/theme/app_theme.dart';
import 'package:duemate/core/utils/currency_formatter.dart';
import 'package:duemate/core/utils/date_formatter.dart';
import 'package:duemate/domain/entities/credit_card_emi.dart';

/// What the user chose in [EmiPayDialog].
typedef EmiPayment = ({int count, DateTime paidOn});

/// Records the next installment(s) as paid, including paying ahead of the
/// due date: how many, and the day you paid.
class EmiPayDialog extends StatefulWidget {
  final CreditCardEmi emi;
  final String symbol;

  const EmiPayDialog({super.key, required this.emi, required this.symbol});

  static Future<EmiPayment?> show(BuildContext context, {required CreditCardEmi emi, required String symbol}) =>
      showDialog<EmiPayment>(context: context, builder: (_) => EmiPayDialog(emi: emi, symbol: symbol));

  @override
  State<EmiPayDialog> createState() => _EmiPayDialogState();
}

class _EmiPayDialogState extends State<EmiPayDialog> {
  int _count = 1;
  DateTime _paidOn = DateUtils.dateOnly(DateTime.now());

  CreditCardEmi get emi => widget.emi;
  int get _first => emi.installmentsPaid + 1;
  int get _last => _first + _count - 1;

  double get _total {
    var sum = 0.0;
    for (var k = _first; k <= _last; k++) {
      sum += emi.getMonthlyInstallmentFor(k);
    }
    return sum;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _paidOn,
      firstDate: emi.startDate.subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _paidOn = picked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final remaining = emi.remainingInstallments;
    final months = _count == 1
        ? 'Installment $_first · due ${DateFormatter.formatDate(emi.getDueDateForInstallment(_first))}'
        : 'Installments $_first–$_last · ${DateFormatter.formatMonthYear(emi.getDueDateForInstallment(_first))} to '
            '${DateFormatter.formatMonthYear(emi.getDueDateForInstallment(_last))}';

    return AlertDialog(
      title: const Text('Record payment'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Paying ahead? Choose how many months you paid. They will not be added again on their due dates.',
            style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpace.lg),
          Row(
            children: [
              Expanded(child: Text('Months paid', style: theme.textTheme.titleSmall)),
              IconButton.outlined(
                tooltip: 'Fewer',
                onPressed: _count > 1 ? () => setState(() => _count--) : null,
                icon: const Icon(Icons.remove_rounded),
              ),
              SizedBox(
                width: 40,
                child: Text('$_count', textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
              ),
              IconButton.outlined(
                tooltip: 'More',
                onPressed: _count < remaining ? () => setState(() => _count++) : null,
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.xs),
          Text(months, style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
          const SizedBox(height: AppSpace.md),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event_outlined),
            title: const Text('Paid on'),
            subtitle: Text(DateFormatter.formatDate(_paidOn)),
            trailing: const Icon(Icons.edit_calendar_outlined),
            onTap: _pickDate,
          ),
          const Divider(),
          Row(
            children: [
              Expanded(child: Text('Total', style: theme.textTheme.titleSmall)),
              // A confirmation of what is being recorded: always the real number.
              Text(CurrencyFormatter.format(_total, symbol: widget.symbol), style: theme.textTheme.titleMedium),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.of(context).pop<EmiPayment>((count: _count, paidOn: _paidOn)),
          child: const Text('Record'),
        ),
      ],
    );
  }
}
