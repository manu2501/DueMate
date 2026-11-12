import 'package:flutter/material.dart';
import 'package:duemate/core/constants/app_constants.dart';
import 'package:duemate/core/utils/date_formatter.dart';
import 'package:duemate/core/widgets/ui_kit.dart';
import 'package:duemate/data/database/tables.dart';
import 'package:duemate/domain/entities/ledger_transaction.dart';
import 'package:duemate/domain/entities/person.dart';

/// One ledger entry as a list row. Money in is green with "+"; money out is
/// neutral ink with "−" (lending isn't bad news).
class TransactionTile extends StatelessWidget {
  final LedgerTransaction transaction;
  final Person? person;
  final String currencySymbol;
  final VoidCallback? onTap;

  /// Hide the person's name, e.g. inside that person's own ledger.
  final bool showPerson;

  /// Hide the date when the list is already grouped by date.
  final bool showDate;

  const TransactionTile({
    super.key,
    required this.transaction,
    this.person,
    this.currencySymbol = '₹',
    this.onTap,
    this.showPerson = true,
    this.showDate = true,
  });

  @override
  Widget build(BuildContext context) {
    final t = transaction;
    final isIn = t.type == TransactionType.paymentReceived;
    final isSelf = person == null || person!.id == AppConstants.selfPersonId;
    final note = t.note?.trim();
    final hasNote = note != null && note.isNotEmpty;

    final String title;
    if (showPerson && !isSelf) {
      title = person!.name;
    } else if (hasNote) {
      title = note;
    } else if (t.isEmi) {
      title = 'EMI installment';
    } else {
      title = isIn ? 'Received' : 'Given';
    }

    final details = <String>[
      if (showPerson && !isSelf && hasNote) note,
      if (t.isEmi) 'EMI ${t.installmentNumber ?? ''}'.trim(),
      t.paymentMethod.label,
      if (t.dueDate != null) 'return by ${DateFormatter.formatShortDate(t.dueDate!)}',
      if (showDate) DateFormatter.formatRelative(t.transactionDate),
    ];

    return ListTile(
      onTap: onTap,
      leading: IconBadge(
        t.isEmi
            ? Icons.event_repeat_outlined
            : isIn
                ? Icons.south_west_rounded
                : Icons.north_east_rounded,
        color: isIn ? MoneyText.colorFor(context, MoneyTone.positive) : null,
      ),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(details.join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: MoneyText(
        t.amount,
        symbol: currencySymbol,
        sign: isIn ? '+' : '−',
        tone: isIn ? MoneyTone.positive : MoneyTone.neutral,
      ),
    );
  }
}
