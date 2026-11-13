import 'package:flutter/material.dart';
import 'package:duemate/core/theme/app_theme.dart';
import 'package:duemate/core/utils/currency_formatter.dart';
import 'package:duemate/core/utils/date_formatter.dart';
import 'package:duemate/domain/emi_installments.dart';
import 'package:duemate/domain/entities/credit_card_emi.dart';

/// What the user chose in [EmiPayDialog].
typedef EmiPayment = ({int count, DateTime paidOn});

/// Records the next installment(s) as paid, including paying ahead of the
/// due date: how many, and the day you paid. Takes the earliest unpaid
/// installments, so a gap left unpaid is filled first.
class EmiPayDialog extends StatefulWidget {
  final EmiInstallments state;
  final String symbol;

  const EmiPayDialog({super.key, required this.state, required this.symbol});

  static Future<EmiPayment?> show(BuildContext context, {required EmiInstallments state, required String symbol}) =>
      showDialog<EmiPayment>(context: context, builder: (_) => EmiPayDialog(state: state, symbol: symbol));

  @override
  State<EmiPayDialog> createState() => _EmiPayDialogState();
}

class _EmiPayDialogState extends State<EmiPayDialog> {
  int _count = 1;
  DateTime _paidOn = DateUtils.dateOnly(DateTime.now());

  CreditCardEmi get emi => widget.state.emi;
  late final List<int> _unpaid = widget.state.unpaid.toList();
  List<int> get _chosen => _unpaid.take(_count).toList();
  int get _first => _chosen.first;
  int get _last => _chosen.last;

  double get _total => _chosen.fold(0, (s, k) => s + emi.getMonthlyInstallmentFor(k));

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
    final remaining = _unpaid.length;
    final contiguous = _last - _first + 1 == _count;
    final months = _count == 1
        ? 'Installment $_first · due ${DateFormatter.formatDate(emi.getDueDateForInstallment(_first))}'
        : contiguous
            ? 'Installments $_first–$_last · ${DateFormatter.formatMonthYear(emi.getDueDateForInstallment(_first))} to '
                '${DateFormatter.formatMonthYear(emi.getDueDateForInstallment(_last))}'
            : 'Installments ${_chosen.take(_count - 1).join(', ')} and $_last';

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
