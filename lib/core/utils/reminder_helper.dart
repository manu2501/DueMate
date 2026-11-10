import 'package:share_plus/share_plus.dart';
import 'package:duemate/core/utils/currency_formatter.dart';
import 'package:duemate/core/utils/date_formatter.dart';
import 'package:duemate/domain/entities/person_summary.dart';

class ReminderHelper {
  static String generateReminderText(PersonSummary summary, {String currencySymbol = '₹'}) {
    final personName = summary.person.name;
    final balance = CurrencyFormatter.format(summary.balance.abs(), symbol: currencySymbol);

    if (summary.owesMoney) {
      final lastTx = summary.lastTransaction != null
          ? '\nLast payment recorded: ${DateFormatter.formatDate(summary.lastTransaction!.transactionDate)} (${CurrencyFormatter.format(summary.lastTransaction!.amount, symbol: currencySymbol)})'
          : '';

      return 'Hi $personName,\n\n'
          'This is a friendly reminder that your outstanding balance is $balance.$lastTx\n\n'
          'Summary: Total Given: ${CurrencyFormatter.format(summary.totalGiven, symbol: currencySymbol)} | Total Repaid: ${CurrencyFormatter.format(summary.totalReceived, symbol: currencySymbol)}.\n\n'
          'Shared via DueMate.';
    } else if (summary.isOverpaid) {
      return 'Hi $personName,\n\n'
          'According to our ledger, you have an overpaid balance of $balance.\n\n'
          'Shared via DueMate.';
    } else {
      return 'Hi $personName,\n\n'
          'Our ledger is fully settled with zero balance outstanding! 🎉\n\n'
          'Shared via DueMate.';
    }
  }

  static Future<void> shareReminder(PersonSummary summary, {String currencySymbol = '₹'}) async {
    final text = generateReminderText(summary, currencySymbol: currencySymbol);
    await SharePlus.instance.share(
      ShareParams(
        text: text,
        subject: 'DueMate Balance Reminder - ${summary.person.name}',
      ),
    );
  }
}

