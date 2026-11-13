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

  group('RepaymentRecord', () {
    final today = d(2026, 11, 13);
    RepaymentRecord of(List<LedgerTransaction> txs) => RepaymentRecord.of(txs, today);

    test('nothing judged without dated loans', () {
      final r = of([_give(5000, d(2026, 9, 1)), _got(5000, d(2026, 10, 1))]);
      expect((r.judged, r.onTimeShare), (0, null));
    });

    test('paid off on or before the date is on time; after it is late', () {
      expect(of([_give(5000, d(2026, 9, 1), due: d(2026, 10, 1)), _got(5000, d(2026, 10, 1))]),
          const RepaymentRecord(onTime: 1));
      expect(of([_give(5000, d(2026, 9, 1), due: d(2026, 10, 1)), _got(5000, d(2026, 10, 2))]),
          const RepaymentRecord(late: 1));
    });

    test('unpaid past its date is missed; unpaid with the date ahead (or today) is not judged', () {
      expect(of([_give(5000, d(2026, 9, 1), due: d(2026, 11, 12))]), const RepaymentRecord(missed: 1));
      expect(of([_give(5000, d(2026, 9, 1), due: today)]).judged, 0);
      expect(of([_give(5000, d(2026, 9, 1), due: d(2026, 12, 1))]).judged, 0);
    });

    test('part paid by the date and the rest after is late, dated by the last repayment', () {
      final r = of([
        _give(5000, d(2026, 9, 1), due: d(2026, 10, 1)),
        _got(3000, d(2026, 9, 20)),
        _got(2000, d(2026, 10, 5)),
      ]);
      expect(r, const RepaymentRecord(late: 1));
    });

    test('repayments go to the oldest loan first, dated or not', () {
      // The first ₹2,000 clears the older undated loan; the dated one is
      // only paid off by the November repayment, after its date.
      final r = of([
        _give(2000, d(2026, 8, 1)),
        _give(3000, d(2026, 9, 1), due: d(2026, 10, 1)),
        _got(2000, d(2026, 9, 15)),
        _got(3000, d(2026, 11, 1)),
      ]);
      expect(r, const RepaymentRecord(late: 1));
    });

    test('one repayment can clear several loans; counts each', () {
      final r = of([
        _give(1000, d(2026, 9, 1), due: d(2026, 9, 30)),
        _give(1000, d(2026, 9, 5), due: d(2026, 10, 30)),
        _give(1000, d(2026, 9, 10), due: d(2026, 11, 10)),
        _got(2500, d(2026, 9, 25)),
      ]);
      // #1, #2 paid on 25 Sep (on time); #3 half paid and past 10 Nov: missed.
      expect(r, const RepaymentRecord(onTime: 2, missed: 1));
      expect(r.onTimeShare, closeTo(2 / 3, 1e-9));
    });

    test('money received before the loan counts from the loan date', () {
      final r = of([_got(5000, d(2026, 8, 1)), _give(5000, d(2026, 9, 1), due: d(2026, 9, 30))]);
      expect(r, const RepaymentRecord(onTime: 1));
    });

    test('agrees with LoanDues on what is still unpaid', () {
      final txs = [
        _give(4000, d(2026, 9, 1), due: d(2026, 10, 1)),
        _give(2000, d(2026, 10, 1), due: d(2026, 12, 1)),
        _got(4500, d(2026, 10, 20)),
      ];
      // #1 paid off late; #2 partly paid, date ahead: not judged, still due.
      expect(of(txs), const RepaymentRecord(late: 1));
      expect(LoanDues.outstanding(txs), [DueBack(d(2026, 12, 1), 1500)]);
    });
  });
}
