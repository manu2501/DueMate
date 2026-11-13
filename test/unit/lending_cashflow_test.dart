import 'package:flutter_test/flutter_test.dart';
import 'package:duemate/core/constants/app_constants.dart';
import 'package:duemate/data/database/tables.dart';
import 'package:duemate/domain/entities/ledger_transaction.dart';
import 'package:duemate/domain/lending_cashflow.dart';

LedgerTransaction _tx(String person, TransactionType type, double amount, DateTime date) => LedgerTransaction(
      id: '$person$amount$date',
      personId: person,
      type: type,
      amount: amount,
      transactionDate: date,
      paymentMethod: PaymentMethod.upi,
      createdAt: date,
      updatedAt: date,
    );

void main() {
  const give = TransactionType.moneyGiven;
  const got = TransactionType.paymentReceived;
  final txs = [
    _tx('ravi', give, 5000, DateTime(2026, 3, 2)),
    _tx('ravi', got, 2000, DateTime(2026, 3, 28)),
    _tx('asha', give, 1000, DateTime(2026, 3, 15)),
    _tx('asha', got, 1000, DateTime(2026, 11, 1)),
    _tx('ravi', give, 700, DateTime(2025, 12, 31)), // other year
    _tx(AppConstants.selfPersonId, give, 6658, DateTime(2026, 3, 5)), // own EMI: not lending
  ];

  test('sums lent and collected per month for the year, leaving out your own EMIs', () {
    final m = LendingCashflow.byMonth(txs, 2026);
    expect(m, hasLength(12));
    expect((m[2].lent, m[2].collected, m[2].net), (6000.0, 2000.0, -4000.0));
    expect((m[10].lent, m[10].collected, m[10].net), (0.0, 1000.0, 1000.0));
    expect(m[0].isEmpty, isTrue);
    expect(LendingCashflow.byMonth(txs, 2025)[11].lent, 700);
  });

  test('years with lending, plus the current one, oldest first', () {
    expect(LendingCashflow.years(txs, 2027), [2025, 2026, 2027]);
    expect(LendingCashflow.years([_tx(AppConstants.selfPersonId, give, 1, DateTime(2020))], 2026), [2026]);
  });
}
