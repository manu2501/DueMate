import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:duemate/data/database/app_database.dart' show AppDatabase;
import 'package:duemate/data/database/tables.dart';
import 'package:duemate/data/repositories/person_repository_impl.dart';
import 'package:duemate/data/repositories/transaction_repository_impl.dart';
import 'package:duemate/domain/entities/ledger_transaction.dart';
import 'package:duemate/domain/entities/person.dart';

void main() {
  late AppDatabase db;
  late PersonRepositoryImpl personRepo;
  late TransactionRepositoryImpl txRepo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    personRepo = PersonRepositoryImpl(db);
    txRepo = TransactionRepositoryImpl(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('Creates person and calculates derived balances from transactions', () async {
    final now = DateTime.now();
    const personId = 'rahul-123';

    // 1. Create Person (Rahul)
    await personRepo.createPerson(
      Person(
        id: personId,
        name: 'Rahul Kumar',
        phone: '+91 98765 43210',
        createdAt: now,
        updatedAt: now,
      ),
    );

    // Initial check: no transactions
    var summary = await txRepo.watchPersonSummary(personId).first;
    expect(summary, isNotNull);
    expect(summary!.totalGiven, 0);
    expect(summary.totalReceived, 0);
    expect(summary.balance, 0);
    expect(summary.hasNoTransactions, true);

    // 2. Give Money: ₹10,000
    await txRepo.addTransaction(
      LedgerTransaction(
        id: 'tx-1',
        personId: personId,
        type: TransactionType.moneyGiven,
        amount: 10000,
        transactionDate: now,
        paymentMethod: PaymentMethod.bankTransfer,
        note: 'Emergency loan',
        createdAt: now,
        updatedAt: now,
      ),
    );

    summary = await txRepo.watchPersonSummary(personId).first;
    expect(summary!.totalGiven, 10000);
    expect(summary.totalReceived, 0);
    expect(summary.balance, 10000);
    expect(summary.owesMoney, true);
    expect(summary.isSettled, false);

    // 3. Receive Partial Payment: ₹1,000
    await txRepo.addTransaction(
      LedgerTransaction(
        id: 'tx-2',
        personId: personId,
        type: TransactionType.paymentReceived,
        amount: 1000,
        transactionDate: now,
        paymentMethod: PaymentMethod.upi,
        note: 'Daily payment',
        createdAt: now,
        updatedAt: now,
      ),
    );

    summary = await txRepo.watchPersonSummary(personId).first;
    expect(summary!.totalGiven, 10000);
    expect(summary.totalReceived, 1000);
    expect(summary.balance, 9000); // 10000 - 1000 = 9000
    expect(summary.owesMoney, true);

    // 4. Multiple loans to the same person: +₹5,000
    await txRepo.addTransaction(
      LedgerTransaction(
        id: 'tx-3',
        personId: personId,
        type: TransactionType.moneyGiven,
        amount: 5000,
        transactionDate: now,
        paymentMethod: PaymentMethod.upi,
        note: 'Additional loan',
        createdAt: now,
        updatedAt: now,
      ),
    );

    summary = await txRepo.watchPersonSummary(personId).first;
    expect(summary!.totalGiven, 15000);
    expect(summary.totalReceived, 1000);
    expect(summary.balance, 14000);

    // 5. Full settlement: Repay remaining ₹14,000
    await txRepo.addTransaction(
      LedgerTransaction(
        id: 'tx-4',
        personId: personId,
        type: TransactionType.paymentReceived,
        amount: 14000,
        transactionDate: now,
        paymentMethod: PaymentMethod.cash,
        note: 'Full settlement',
        createdAt: now,
        updatedAt: now,
      ),
    );

    summary = await txRepo.watchPersonSummary(personId).first;
    expect(summary!.totalGiven, 15000);
    expect(summary.totalReceived, 15000);
    expect(summary.balance, 0);
    expect(summary.isSettled, true);
    expect(summary.owesMoney, false);

    // 6. Overpayment case: Person pays extra ₹500
    await txRepo.addTransaction(
      LedgerTransaction(
        id: 'tx-5',
        personId: personId,
        type: TransactionType.paymentReceived,
        amount: 500,
        transactionDate: now,
        paymentMethod: PaymentMethod.upi,
        note: 'Extra repayment',
        createdAt: now,
        updatedAt: now,
      ),
    );

    summary = await txRepo.watchPersonSummary(personId).first;
    expect(summary!.totalGiven, 15000);
    expect(summary.totalReceived, 15500);
    expect(summary.balance, -500);
    expect(summary.isOverpaid, true);

    // 7. Overall Ledger Summary verification
    final ledgerSummary = await txRepo.watchLedgerSummary().first;
    expect(ledgerSummary.totalGiven, 15000);
    expect(ledgerSummary.totalReceived, 15500);
    expect(ledgerSummary.totalOutstanding, -500);
  });
}
