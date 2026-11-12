import 'package:flutter_test/flutter_test.dart';
import 'package:duemate/core/constants/app_constants.dart';
import 'package:duemate/data/database/tables.dart';
import 'package:duemate/domain/emi_reminder_planner.dart';
import 'package:duemate/domain/entities/ledger_transaction.dart';
import 'package:duemate/domain/loan_dues.dart';

var _n = 0;
LedgerTransaction _give(double amount, DateTime on, {DateTime? due, String person = 'ravi'}) => LedgerTransaction(
      id: 'g${_n++}',
      personId: person,
      type: TransactionType.moneyGiven,
      amount: amount,
      transactionDate: on,
      paymentMethod: PaymentMethod.upi,
      dueDate: due,
      createdAt: on,
      updatedAt: on,
    );

LedgerTransaction _got(double amount, DateTime on, {String person = 'ravi'}) => LedgerTransaction(
      id: 'r${_n++}',
      personId: person,
      type: TransactionType.paymentReceived,
      amount: amount,
      transactionDate: on,
      paymentMethod: PaymentMethod.upi,
      createdAt: on,
      updatedAt: on,
    );

void main() {
  final d = DateTime.new;

  group('LoanDues.outstanding', () {
    test('a dated loan is due in full until repaid', () {
      expect(LoanDues.outstanding([_give(5000, d(2026, 11, 1), due: d(2026, 12, 15))]), [DueBack(d(2026, 12, 15), 5000)]);
    });

    test('repayments pay off the oldest loans first; only the unpaid part is due', () {
      final txs = [
        _give(3000, d(2026, 9, 1)), // no date
        _give(5000, d(2026, 10, 1), due: d(2026, 11, 1)),
        _give(2000, d(2026, 11, 1), due: d(2026, 12, 1)),
        _got(4000, d(2026, 10, 20)), // clears the 3000, then 1000 of the 5000
      ];
      expect(LoanDues.outstanding(txs), [DueBack(d(2026, 11, 1), 4000), DueBack(d(2026, 12, 1), 2000)]);
    });

    test('fully repaid dated loans are no longer due; same dates are merged', () {
      expect(LoanDues.outstanding([_give(1000, d(2026, 10, 1), due: d(2026, 11, 1)), _got(1000, d(2026, 10, 5))]), isEmpty);
      expect(
        LoanDues.outstanding([
          _give(1000, d(2026, 10, 1), due: d(2026, 11, 1, 18)),
          _give(500, d(2026, 10, 2), due: d(2026, 11, 1)),
        ]),
        [DueBack(d(2026, 11, 1), 1500)],
      );
    });

    test('overdue amounts as of a day', () {
      final s = LoanDueStatus([DueBack(d(2026, 11, 1), 4000), DueBack(d(2026, 12, 1), 2000)]);
      expect(s.isOverdue(d(2026, 11, 1)), isFalse, reason: 'due today is not overdue yet');
      expect(s.isOverdue(d(2026, 11, 2)), isTrue);
      expect(s.overdueAmount(d(2026, 12, 2)), 6000);
    });

    test('byPerson skips your own EMIs and people without dated loans', () {
      final map = LoanDues.byPerson([
        _give(1000, d(2026, 10, 1), due: d(2026, 11, 1)),
        _give(700, d(2026, 10, 1), person: 'asha'),
        _give(9000, d(2026, 10, 1), due: d(2026, 11, 1), person: AppConstants.selfPersonId),
      ]);
      expect(map.keys, ['ravi']);
    });
  });

  group('LoanReminderPlanner', () {
    final now = d(2026, 11, 12, 12);
    String money(double a) => '₹${a.toStringAsFixed(0)}';

    test('the day before each upcoming date; nothing for overdue ones', () {
      final plan = LoanReminderPlanner.plan(
        {
          'ravi': LoanDueStatus([DueBack(d(2026, 11, 1), 4000), DueBack(d(2026, 12, 1), 2000)]),
        },
        now: now,
        nameOf: (_) => 'Ravi',
        amountText: money,
      );
      expect(plan.single.at, d(2026, 11, 30, 9));
      expect(plan.single.title, '₹2000 due back from Ravi tomorrow');
      expect(plan.single.target, const PersonTarget('ravi'));
    });

    test('no amount while amounts are hidden; at most three dates per person', () {
      final dues = LoanDueStatus([for (var m = 1; m <= 5; m++) DueBack(d(2027, m, 10), 100)]);
      final plan = LoanReminderPlanner.plan({'ravi': dues}, now: now, nameOf: (_) => 'Ravi');
      expect(plan, hasLength(LoanReminderPlanner.perPerson));
      expect(plan.first.title, 'Money due back from Ravi tomorrow');
      expect(plan.map((r) => r.id).toSet(), hasLength(3));
    });
  });
}
