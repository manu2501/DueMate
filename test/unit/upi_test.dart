import 'package:flutter_test/flutter_test.dart';
import 'package:duemate/core/utils/reminder_helper.dart';
import 'package:duemate/core/utils/whatsapp_helper.dart';
import 'package:duemate/domain/entities/person.dart';
import 'package:duemate/domain/entities/person_summary.dart';
import 'package:duemate/domain/upi.dart';

void main() {
  group('Upi.isValidId', () {
    test('accepts common UPI IDs', () {
      for (final id in ['ravi@okhdfcbank', 'ravi.kumar-1@ybl', '9876543210@paytm', 'a_b@upi', ' Ravi@OKSBI ']) {
        expect(Upi.isValidId(id), isTrue, reason: id);
      }
    });

    test('rejects things that are not UPI IDs', () {
      for (final id in ['', 'ravi', '@ybl', 'ravi@', 'ravi@@ybl', 'ra vi@ybl', 'ravi@1bank', 'r@ybl']) {
        expect(Upi.isValidId(id), isFalse, reason: id);
      }
    });

    test('optional validator allows empty and explains bad input', () {
      expect(Upi.validateOptionalId(null), isNull);
      expect(Upi.validateOptionalId('  '), isNull);
      expect(Upi.validateOptionalId('ravi@ybl'), isNull);
      expect(Upi.validateOptionalId('ravi'), contains('UPI ID'));
    });

    test('normalizes case and spaces', () {
      expect(Upi.normalizeId('  Ravi@OKSBI '), 'ravi@oksbi');
    });
  });

  group('Upi.payUri', () {
    test('builds a upi://pay link with every field', () {
      final uri = Upi.payUri(payeeId: 'Ravi@YBL', payeeName: 'Ravi Kumar', amount: 1500, note: 'Dinner split');
      expect(uri.scheme, 'upi');
      expect(uri.host, 'pay');
      expect(uri.queryParameters, {
        'pa': 'ravi@ybl',
        'pn': 'Ravi Kumar',
        'am': '1500.00',
        'cu': 'INR',
        'tn': 'Dinner split',
      });
      expect(uri.toString(), contains('pn=Ravi%20Kumar'), reason: 'spaces as %20, not +');
    });

    test('leaves the amount out when none is given, so the payer types it', () {
      expect(Upi.payUri(payeeId: 'ravi@ybl').queryParameters.containsKey('am'), isFalse);
      expect(Upi.payUri(payeeId: 'ravi@ybl', amount: 0).queryParameters.containsKey('am'), isFalse);
    });

    test('rounds the amount to paise and drops empty name and note', () {
      final q = Upi.payUri(payeeId: 'ravi@ybl', payeeName: ' ', amount: 99.999, note: '').queryParameters;
      expect(q['am'], '100.00');
      expect(q.containsKey('pn'), isFalse);
      expect(q.containsKey('tn'), isFalse);
    });

    test('encodes special characters and clips long text', () {
      final q = Upi.payUri(payeeId: 'ravi@ybl', note: 'Rent & bills = ${'x' * 80}').queryParameters;
      expect(q['tn']!.startsWith('Rent & bills = '), isTrue);
      expect(q['tn']!.length, 50);
    });
  });

  group('Reminders', () {
    final now = DateTime(2026, 11, 1);
    final summary = PersonSummary(
      person: Person(id: 'p', name: 'Asha', createdAt: now, updatedAt: now),
      totalGiven: 2000,
      totalReceived: 500,
      balance: 1500,
      lastTransaction: null,
      transactionCount: 2,
    );

    test('WhatsApp reminder includes your UPI ID only when given', () {
      expect(WhatsAppHelper.generateLedgerReminderMessage(summary, upiId: 'me@ybl'), contains('Pay by UPI: *me@ybl*'));
      expect(WhatsAppHelper.generateLedgerReminderMessage(summary), isNot(contains('UPI')));
    });

    test('shared text reminder includes your UPI ID only when given', () {
      expect(ReminderHelper.generateReminderText(summary, upiId: 'me@ybl'), contains('Pay by UPI: me@ybl'));
      expect(ReminderHelper.generateReminderText(summary), isNot(contains('UPI')));
    });
  });
}
