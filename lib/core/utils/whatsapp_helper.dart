import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:duemate/core/utils/currency_formatter.dart';
import 'package:duemate/core/utils/date_formatter.dart';
import 'package:duemate/domain/entities/credit_card_emi.dart';
import 'package:duemate/domain/entities/person.dart';
import 'package:duemate/domain/entities/person_summary.dart';

class WhatsAppHelper {
  static final _nonDigitsPlusRegex = RegExp(r'[^\d+]');
  static final _indianPhonePrefixRegex = RegExp(r'^[6-9]');

  /// Clean phone number for WhatsApp wa.me API format
  static String cleanPhoneNumber(String rawPhone) {
    String cleaned = rawPhone.replaceAll(_nonDigitsPlusRegex, '');
    if (cleaned.startsWith('+')) {
      return cleaned.substring(1);
    }
    // If standard 10-digit Indian number without country code, prepend 91
    if (cleaned.length == 10 && _indianPhonePrefixRegex.hasMatch(cleaned)) {
      return '91$cleaned';
    }
    return cleaned;
  }

  /// Launch WhatsApp with pre-filled message, or fallback to system Share if unavailable
  static Future<bool> sendWhatsAppMessage({
    required String? phoneNumber,
    required String message,
    BuildContext? context,
  }) async {
    final cleanPhone = phoneNumber != null ? cleanPhoneNumber(phoneNumber) : '';
    final encodedMsg = Uri.encodeComponent(message);

    if (cleanPhone.isNotEmpty) {
      // 1. Try direct whatsapp:// scheme
      final whatsappUri = Uri.parse('whatsapp://send?phone=$cleanPhone&text=$encodedMsg');
      try {
        if (await canLaunchUrl(whatsappUri)) {
          final launched = await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
          if (launched) return true;
        }
      } catch (e) {
        debugPrint('Direct whatsapp:// launch attempt failed: $e');
      }

      // 2. Try wa.me link
      final wameUri = Uri.parse('https://wa.me/$cleanPhone?text=$encodedMsg');
      try {
        if (await canLaunchUrl(wameUri)) {
          final launched = await launchUrl(wameUri, mode: LaunchMode.externalApplication);
          if (launched) return true;
        }
      } catch (e) {
        debugPrint('wa.me launch attempt failed: $e');
      }

      // 3. Try api.whatsapp.com fallback
      final apiUri = Uri.parse('https://api.whatsapp.com/send?phone=$cleanPhone&text=$encodedMsg');
      try {
        if (await canLaunchUrl(apiUri)) {
          final launched = await launchUrl(apiUri, mode: LaunchMode.externalApplication);
          if (launched) return true;
        }
      } catch (e) {
        debugPrint('api.whatsapp.com launch attempt failed: $e');
      }
    }

    // Fallback to standard share sheet if phone number is empty or WhatsApp launch fails
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: message,
          subject: 'DueMate Payment Reminder',
        ),
      );
      return true;
    } catch (e) {
      debugPrint('Share fallback failed: $e');
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open WhatsApp or share sheet.')),
        );
      }
      return false;
    }
  }

  /// Generates a friendly WhatsApp reminder message for a person's ledger balance
  static String generateLedgerReminderMessage(
    PersonSummary summary, {
    String currencySymbol = '₹',
    String? upiId,
  }) {
    final personName = summary.person.name;
    final balanceText = CurrencyFormatter.format(summary.balance.abs(), symbol: currencySymbol);

    if (summary.owesMoney) {
      final lastTxStr = summary.lastTransaction != null
          ? '\n• Last recorded payment: ${DateFormatter.formatDate(summary.lastTransaction!.transactionDate)} (${CurrencyFormatter.format(summary.lastTransaction!.amount, symbol: currencySymbol)})'
          : '';

      return 'Hi $personName 👋,\n\n'
          'This is a friendly payment reminder from DueMate regarding your pending balance of *$balanceText*.$lastTxStr\n\n'
          '📋 *Ledger Summary:*\n'
          '• Total Given: ${CurrencyFormatter.format(summary.totalGiven, symbol: currencySymbol)}\n'
          '• Total Received: ${CurrencyFormatter.format(summary.totalReceived, symbol: currencySymbol)}\n'
          '• Pending Balance: *$balanceText*\n\n'
          '${upiId == null ? '' : '💳 Pay by UPI: *$upiId*\n\n'}'
          'Please let me know once transferred! Thank you 🙏';
    } else if (summary.isOverpaid) {
      return 'Hi $personName 👋,\n\n'
          'According to our DueMate ledger, I owe you *$balanceText*. Please confirm so I can settle it!';
    } else {
      return 'Hi $personName 👋,\n\n'
          'Our DueMate ledger balance is completely settled (₹0 balance)! 🎉';
    }
  }

  /// Generates a WhatsApp reminder message for an active EMI installment
  static String generateEmiReminderMessage(
    CreditCardEmi emi,
    Person person, {
    String currencySymbol = '₹',
  }) {
    final monthlyAmount = CurrencyFormatter.format(emi.monthlyInstallment, symbol: currencySymbol);
    final totalAmount = CurrencyFormatter.format(emi.totalAmount, symbol: currencySymbol);

    final installmentIndex = (emi.installmentsPaid + 1).clamp(1, emi.totalTenureMonths);

    return 'Hi ${person.name} 👋,\n\n'
        'Friendly reminder regarding installment *$installmentIndex of ${emi.totalTenureMonths}* for *${emi.itemName}*.\n\n'
        '💳 *EMI Details:*\n'
        '• Monthly Due: *$monthlyAmount*\n'
        '• Total Amount: $totalAmount\n'
        '• Tenure: $installmentIndex / ${emi.totalTenureMonths} months\n'
        '• Monthly Due Day: ${emi.dueDayOfMonth}th of every month\n\n'
        'Kindly settle at your earliest convenience. Thank you! 🙏\n\n'
        '_Sent via DueMate_';
  }
}
