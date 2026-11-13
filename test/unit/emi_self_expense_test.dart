import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:duemate/core/constants/app_constants.dart';
import 'package:duemate/core/services/emi_processor_service.dart';
import 'package:duemate/data/database/app_database.dart' as db;
import 'package:duemate/data/database/tables.dart';
import 'package:duemate/data/repositories/emi_repository_impl.dart';
import 'package:duemate/data/repositories/expense_repository_impl.dart';
import 'package:duemate/data/repositories/transaction_repository_impl.dart';
import 'package:duemate/domain/entities/credit_card_emi.dart';

import '../helpers/test_db.dart';

/// Your own EMIs and loans post to expenses, in the month each was paid.
void main() {
  late db.AppDatabase database;
  late EmiRepositoryImpl emiRepo;
  late ExpenseRepositoryImpl expenseRepo;
  late EmiProcessorService processor;

  setUp(() {
    database = db.AppDatabase(NativeDatabase.memory());
    emiRepo = EmiRepositoryImpl(database);
    expenseRepo = ExpenseRepositoryImpl(database);
    processor = EmiProcessorService(
      emiRepository: emiRepo,
      transactionRepository: TransactionRepositoryImpl(database),
      database: database,
    );
  });

  tearDown(() => database.close());

  // 6 × ₹5,000, due on the 5th, first due 5 July 2026.
  CreditCardEmi homeLoan({int paid = 0, String status = 'active'}) => CreditCardEmi(
        id: 'loan-1',
        personId: AppConstants.selfPersonId,
        itemName: 'Home loan',
        cardName: 'SBI',
        kind: 'loan',
        totalAmount: 30000,
        monthlyInstallment: 5000,
        totalTenureMonths: 6,
        installmentsPaid: paid,
        status: status,
        startDate: DateTime(2026, 7, 5),
        dueDayOfMonth: 5,
        createdAt: DateTime(2026, 7, 1),
        updatedAt: DateTime(2026, 7, 1),
      );

  Future<Map<int, DateTime>> postedDates() async => {
        for (final e in await expenseRepo.getAllExpenses())
          if (e.emiId == 'loan-1') e.installmentNumber!: e.expenseDate,
      };

  test('due installments become EMI expenses in their own months, not ledger entries', () async {
    await emiRepo.createEmi(homeLoan());
    final result = await processor.processDueInstallments(referenceDate: DateTime(2026, 9, 10));

    expect(result.installmentsGenerated, 3);
    expect(await postedDates(), {
      1: DateTime(2026, 7, 5),
      2: DateTime(2026, 8, 5),
      3: DateTime(2026, 9, 5),
    });
    final expenses = await expenseRepo.getAllExpenses();
    expect(expenses.every((e) => e.category == ExpenseCategory.emi && e.amount == 5000), isTrue);
    expect(expenses.first.paymentMethod, PaymentMethod.bankTransfer);
    expect(await database.select(database.transactions).get(), isEmpty);
    expect((await emiRepo.getEmiById('loan-1'))!.installmentsPaid, 3);

    // Idempotent.
    expect((await processor.processDueInstallments(referenceDate: DateTime(2026, 9, 10))).installmentsGenerated, 0);
  });

  test('installments marked paid on the form are posted in their months; ahead ones on today', () async {
    // Started 4 months ago, 3 paid so far.
    await emiRepo.createEmi(homeLoan(paid: 3));
    await processor.processDueInstallments(referenceDate: DateTime(2026, 8, 20));
    // Only 2 were due by 20 Aug; the 3rd was paid ahead.
    expect(await postedDates(), {
      1: DateTime(2026, 7, 5),
      2: DateTime(2026, 8, 5),
      3: DateTime(2026, 8, 20),
    });
    expect((await emiRepo.getEmiById('loan-1'))!.installmentsPaid, 3);

    // On 6 Sept, #3 is already paid; nothing new until October.
    expect((await processor.processDueInstallments(referenceDate: DateTime(2026, 9, 6))).installmentsGenerated, 0);
  });

  test('paying ahead records the next months on the day paid, and they are not posted again', () async {
    await emiRepo.createEmi(homeLoan());
    await processor.processDueInstallments(referenceDate: DateTime(2026, 7, 10)); // #1
    final paidOn = DateTime(2026, 7, 15);
    final emi = (await emiRepo.getEmiById('loan-1'))!;
    expect(await processor.payInstallments(emi, count: 2, paidOn: paidOn), 2);

    expect(await postedDates(), {1: DateTime(2026, 7, 5), 2: paidOn, 3: paidOn});
    expect((await emiRepo.getEmiById('loan-1'))!.installmentsPaid, 3);

    expect((await processor.processDueInstallments(referenceDate: DateTime(2026, 9, 5))).installmentsGenerated, 0);
    final oct = await processor.processDueInstallments(referenceDate: DateTime(2026, 10, 5));
    expect(oct.installmentsGenerated, 1);
    expect((await postedDates())[4], DateTime(2026, 10, 5));
  });

  test('paying the last installments completes the loan; deleting one reopens it', () async {
    await emiRepo.createEmi(homeLoan());
    final emi = (await emiRepo.getEmiById('loan-1'))!;
    expect(await processor.payInstallments(emi, count: 10, paidOn: DateTime(2026, 7, 1)), 6);
    expect((await emiRepo.getEmiById('loan-1'))!.isCompleted, isTrue);

    final last = (await expenseRepo.getAllExpenses()).firstWhere((e) => e.installmentNumber == 6);
    await expenseRepo.deleteExpense(last.id);
    final reopened = (await emiRepo.getEmiById('loan-1'))!;
    expect(reopened.installmentsPaid, 5);
    expect(reopened.status, 'active');
  });

  test('a finished loan still posts installments marked paid on the form', () async {
    await emiRepo.createEmi(homeLoan(paid: 6, status: 'completed'));
    await processor.processDueInstallments(referenceDate: DateTime(2027, 1, 10));
    expect((await postedDates()).length, 6);
    expect((await postedDates())[6], DateTime(2026, 12, 5));
  });

  test('installments posted to the old self ledger move into expenses', () async {
    await emiRepo.createEmi(homeLoan(paid: 1));
    await database.into(database.transactions).insert(db.TransactionsCompanion.insert(
          id: 'old-tx',
          personId: AppConstants.selfPersonId,
          type: TransactionType.moneyGiven,
          amount: 5000,
          transactionDate: DateTime(2026, 7, 5),
          paymentMethod: PaymentMethod.card,
          note: const Value('EMI 1/6: Home loan (SBI)'),
          emiId: const Value('loan-1'),
          installmentNumber: const Value(1),
          createdAt: DateTime(2026, 7, 5),
          updatedAt: DateTime(2026, 7, 5),
        ));

    await database.moveSelfEmiPostingsToExpenses();

    expect(await database.select(database.transactions).get(), isEmpty);
    final moved = await expenseRepo.getExpenseById('old-tx');
    expect(moved!.title, 'Home loan');
    expect(moved.category, ExpenseCategory.emi);
    expect(moved.expenseDate, DateTime(2026, 7, 5));
    expect(moved.installmentNumber, 1);
    expect(moved.notes, 'EMI 1/6 · SBI');

    // Not posted twice afterwards.
    expect((await processor.processDueInstallments(referenceDate: DateTime(2026, 7, 10))).installmentsGenerated, 0);
  });

  test('upgrading a v10 database moves your EMI installments into expenses', () async {
    final dir = await Directory.systemTemp.createTemp('duemate_v10_');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/db.sqlite');

    var old = db.AppDatabase(NativeDatabase(file));
    await EmiRepositoryImpl(old).createEmi(homeLoan());
    await old.into(old.transactions).insert(db.TransactionsCompanion.insert(
          id: 'old-tx',
          personId: AppConstants.selfPersonId,
          type: TransactionType.moneyGiven,
          amount: 5000,
          transactionDate: DateTime(2026, 7, 5),
          paymentMethod: PaymentMethod.card,
          emiId: const Value('loan-1'),
          installmentNumber: const Value(1),
          createdAt: DateTime(2026, 7, 5),
          updatedAt: DateTime(2026, 7, 5),
        ));
    await downgradeToV10(old);
    await old.close();

    old = db.AppDatabase(NativeDatabase(file));
    addTearDown(old.close);
    expect(await old.select(old.transactions).get(), isEmpty);
    final moved = await (old.select(old.expenses)..where((e) => e.id.equals('old-tx'))).getSingle();
    expect((moved.category, moved.emiId, moved.installmentNumber), (ExpenseCategory.emi, 'loan-1', 1));
  });

  test('shared EMIs still post to the ledger, not expenses', () async {
    await database.into(database.persons).insert(db.PersonsCompanion.insert(
          id: 'p1',
          name: 'Asha',
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        ));
    await emiRepo.createEmi(homeLoan().copyWith(personId: 'p1', kind: 'card'));
    await processor.processDueInstallments(referenceDate: DateTime(2026, 7, 10));
    expect(await expenseRepo.getAllExpenses(), isEmpty);
    expect((await database.select(database.transactions).get()).single.personId, 'p1');
  });

  group('editing an EMI', () {
    final oct10 = DateTime(2026, 10, 10);

    Future<CreditCardEmi> processedLoan() async {
      await emiRepo.createEmi(homeLoan());
      await processor.processDueInstallments(referenceDate: oct10); // #1–#4 due
      return (await emiRepo.getEmiById('loan-1'))!;
    }

    test('lowering paid from 4 to 3 removes the 4th and it stays unpaid', () async {
      final emi = await processedLoan();
      expect(emi.installmentsPaid, 4);

      await processor.applyEdit(emi, emi.copyWith(installmentsPaid: 3), now: oct10);
      await processor.processDueInstallments(referenceDate: oct10);

      expect((await postedDates()).keys, unorderedEquals([1, 2, 3]));
      expect((await emiRepo.getEmiById('loan-1'))!.installmentsPaid, 3);

      // The next due date still posts: assumes paid through it.
      await processor.processDueInstallments(referenceDate: DateTime(2026, 11, 5));
      expect((await emiRepo.getEmiById('loan-1'))!.installmentsPaid, 4);
    });

    test('moving the start date re-dates the installments already posted', () async {
      final emi = await processedLoan();
      final edited = emi.copyWith(startDate: DateTime(2026, 8, 12), dueDayOfMonth: 12, installmentsPaid: 2);
      await processor.applyEdit(emi, edited, now: oct10);
      await processor.processDueInstallments(referenceDate: oct10);

      expect(await postedDates(), {1: DateTime(2026, 8, 12), 2: DateTime(2026, 9, 12)});
      expect((await emiRepo.getEmiById('loan-1'))!.installmentsPaid, 2);
    });

    test('raising paid adds the missing installments; new amount and name apply to all', () async {
      final emi = await processedLoan();
      await processor.applyEdit(
        emi,
        emi.copyWith(installmentsPaid: 5, monthlyInstallment: 5500, itemName: 'Car loan'),
        now: oct10,
      );
      await processor.processDueInstallments(referenceDate: oct10);

      final expenses = await expenseRepo.getAllExpenses();
      expect(expenses.length, 5);
      expect(expenses.every((e) => e.amount == 5500 && e.title == 'Car loan'), isTrue);
      expect((await postedDates())[5], oct10, reason: 'not due yet: paid ahead, dated today');
    });

    test('lowering a finished loan reopens it', () async {
      await emiRepo.createEmi(homeLoan());
      await processor.processDueInstallments(referenceDate: DateTime(2027, 1, 10));
      final done = (await emiRepo.getEmiById('loan-1'))!;
      expect(done.isCompleted, isTrue);

      await processor.applyEdit(done, done.copyWith(installmentsPaid: 5), now: DateTime(2027, 1, 10));
      final reopened = (await emiRepo.getEmiById('loan-1'))!;
      expect((reopened.installmentsPaid, reopened.status), (5, 'active'));
      expect((await postedDates()).length, 5);
    });

    test('shared: lowering paid removes the ledger entry', () async {
      await database.into(database.persons).insert(db.PersonsCompanion.insert(
            id: 'p1',
            name: 'Asha',
            createdAt: DateTime(2026, 1, 1),
            updatedAt: DateTime(2026, 1, 1),
          ));
      await emiRepo.createEmi(homeLoan().copyWith(personId: 'p1', kind: 'card'));
      await processor.processDueInstallments(referenceDate: oct10);
      final emi = (await emiRepo.getEmiById('loan-1'))!;
      expect(emi.installmentsPaid, 4);

      await processor.applyEdit(emi, emi.copyWith(installmentsPaid: 3), now: oct10);
      await processor.processDueInstallments(referenceDate: oct10);

      final txs = await database.select(database.transactions).get();
      expect(txs.map((t) => t.installmentNumber), unorderedEquals([1, 2, 3]));
      expect((await emiRepo.getEmiById('loan-1'))!.installmentsPaid, 3);
    });
  });

  group('one installment', () {
    final oct10 = DateTime(2026, 10, 10);

    Future<CreditCardEmi> loan() async => (await emiRepo.getEmiById('loan-1'))!;

    /// #1–#4 posted on their due dates, as of 10 Oct.
    Future<CreditCardEmi> fourPaid() async {
      await emiRepo.createEmi(homeLoan());
      await processor.processDueInstallments(referenceDate: oct10);
      return loan();
    }

    Future<db.Person> asha() async {
      await database.into(database.persons).insert(db.PersonsCompanion.insert(
            id: 'p1',
            name: 'Asha',
            createdAt: DateTime(2026, 1, 1),
            updatedAt: DateTime(2026, 1, 1),
          ));
      return (await database.select(database.persons).get()).firstWhere((p) => p.id == 'p1');
    }

    test('marking a middle one unpaid removes its expense and leaves a gap that stays', () async {
      expect(await processor.markUnpaid(await fourPaid(), 2), isTrue);
      expect((await postedDates()).keys, unorderedEquals([1, 3, 4]));
      expect((await loan()).installmentsPaid, 3);

      // Not re-added on its own; the next due date still posts.
      await processor.processDueInstallments(referenceDate: oct10);
      expect((await postedDates()).keys, unorderedEquals([1, 3, 4]));
      await processor.processDueInstallments(referenceDate: DateTime(2026, 11, 5));
      expect((await postedDates()).keys, unorderedEquals([1, 3, 4, 5]));
      expect((await loan()).installmentsPaid, 4);
    });

    test('marking one paid posts it on the day chosen, or its due date', () async {
      await processor.markUnpaid(await fourPaid(), 2);
      await processor.markUnpaid(await loan(), 3);

      expect(await processor.markPaid(await loan(), 3, paidOn: DateTime(2026, 10, 9)), isTrue);
      expect(await processor.markPaid(await loan(), 2), isTrue);
      expect(await postedDates(), {
        1: DateTime(2026, 7, 5),
        2: DateTime(2026, 8, 5), // its due date: already past
        3: DateTime(2026, 10, 9),
        4: DateTime(2026, 10, 5),
      });
      expect((await loan()).installmentsPaid, 4);
    });

    test('marking twice, or out of range, changes nothing', () async {
      final emi = await fourPaid();
      expect(await processor.markPaid(emi, 1), isFalse);
      expect(await processor.markPaid(emi, 0), isFalse);
      expect(await processor.markPaid(emi, 7), isFalse);
      expect(await processor.markUnpaid(emi, 5), isFalse);
      expect((await postedDates()).length, 4);
      expect((await loan()).installmentsPaid, 4);
    });

    test('a stale copy from the screen is re-read, not written back', () async {
      final stale = await fourPaid();
      await processor.markUnpaid(stale, 4);
      await processor.markUnpaid(stale, 3); // stale still says 4 paid
      expect((await loan()).installmentsPaid, 2);
    });

    test('Pay fills a gap first, then the next months', () async {
      await processor.markUnpaid(await fourPaid(), 2);
      final paidOn = DateTime(2026, 10, 11);
      expect(await processor.payInstallments(await loan(), count: 2, paidOn: paidOn), 2);
      final dates = await postedDates();
      expect(dates.keys, unorderedEquals([1, 2, 3, 4, 5]));
      expect((dates[2], dates[5]), (paidOn, paidOn));
    });

    test('unmarking the last one reopens a finished loan', () async {
      await emiRepo.createEmi(homeLoan());
      await processor.processDueInstallments(referenceDate: DateTime(2027, 1, 10));
      expect((await loan()).isCompleted, isTrue);

      await processor.markUnpaid(await loan(), 6);
      final reopened = await loan();
      expect((reopened.installmentsPaid, reopened.status), (5, 'active'));
    });

    test('a new amount for a paid month updates its expense; for an unpaid one, only the plan', () async {
      final emi = await fourPaid();
      await processor.setInstallmentAmount(emi, 2, 6200);
      await processor.setInstallmentAmount(await loan(), 5, 4800);

      final expenses = await expenseRepo.getAllExpenses();
      expect(expenses.firstWhere((e) => e.installmentNumber == 2).amount, 6200);
      expect(expenses.where((e) => e.amount != 5000).length, 1);
      final updated = await loan();
      expect((updated.getMonthlyInstallmentFor(2), updated.getMonthlyInstallmentFor(5)), (6200.0, 4800.0));
      expect(updated.installmentsPaid, 4, reason: 'the edit must not undo the paid count');
    });

    test('shared: unmarking removes the ledger entry and the balance follows', () async {
      await asha();
      await emiRepo.createEmi(homeLoan().copyWith(personId: 'p1', kind: 'card'));
      await processor.processDueInstallments(referenceDate: oct10);
      final txRepo = TransactionRepositoryImpl(database);
      expect((await txRepo.watchPersonSummary('p1').first)!.balance, 20000);

      await processor.markUnpaid(await loan(), 3);
      expect((await txRepo.watchPersonSummary('p1').first)!.balance, 15000);
      expect((await loan()).installmentsPaid, 3);
    });

    test('shared: one paid before tracking just stops counting (no entry to remove)', () async {
      await asha();
      // 2 paid before tracking; #3 and #4 posted by the processor.
      await emiRepo.createEmi(homeLoan(paid: 2).copyWith(personId: 'p1', kind: 'card'));
      await processor.processDueInstallments(referenceDate: oct10);
      expect((await database.select(database.transactions).get()).length, 2);

      await processor.markUnpaid(await loan(), 2);
      expect((await loan()).installmentsPaid, 3);
      expect((await database.select(database.transactions).get()).length, 2);
      expect((await processor.installments(await loan())).paid, {1, 3, 4});
    });

    test('deleting an EMI entry from the ledger counts it as unpaid', () async {
      await asha();
      await emiRepo.createEmi(homeLoan().copyWith(personId: 'p1', kind: 'card'));
      await processor.processDueInstallments(referenceDate: DateTime(2027, 1, 10));
      expect((await loan()).isCompleted, isTrue);

      final txs = await database.select(database.transactions).get();
      await TransactionRepositoryImpl(database).deleteTransaction(txs.firstWhere((t) => t.installmentNumber == 2).id);
      final after = await loan();
      expect((after.installmentsPaid, after.status), (5, 'active'));
      expect((await processor.installments(after)).next, 2);
    });
  });

  group('deleting an EMI', () {
    Future<void> addAsha() => database.into(database.persons).insert(db.PersonsCompanion.insert(
          id: 'p1',
          name: 'Asha',
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        ));

    test('yours: its expenses go with it; other expenses stay', () async {
      await emiRepo.createEmi(homeLoan());
      await processor.processDueInstallments(referenceDate: DateTime(2026, 10, 10));
      await database.into(database.expenses).insert(db.ExpensesCompanion.insert(
            id: 'groceries',
            title: 'Groceries',
            amount: 900,
            category: ExpenseCategory.groceries,
            expenseDate: DateTime(2026, 10, 1),
            paymentMethod: PaymentMethod.upi,
            createdAt: DateTime(2026, 10, 1),
            updatedAt: DateTime(2026, 10, 1),
          ));

      await emiRepo.deleteEmi('loan-1');

      expect(await emiRepo.getEmiById('loan-1'), isNull);
      expect((await expenseRepo.getAllExpenses()).map((e) => e.id), ['groceries']);
    });

    test('shared: its ledger entries go with it and the balance follows; other entries stay', () async {
      await addAsha();
      final txRepo = TransactionRepositoryImpl(database);
      await database.into(database.transactions).insert(db.TransactionsCompanion.insert(
            id: 'lent',
            personId: 'p1',
            type: TransactionType.moneyGiven,
            amount: 2000,
            transactionDate: DateTime(2026, 9, 1),
            paymentMethod: PaymentMethod.upi,
            createdAt: DateTime(2026, 9, 1),
            updatedAt: DateTime(2026, 9, 1),
          ));
      await emiRepo.createEmi(homeLoan().copyWith(personId: 'p1', kind: 'card'));
      await processor.processDueInstallments(referenceDate: DateTime(2026, 10, 10));
      expect((await txRepo.watchPersonSummary('p1').first)!.balance, 22000);

      await emiRepo.deleteEmi('loan-1');

      expect((await database.select(database.transactions).get()).map((t) => t.id), ['lent']);
      expect((await txRepo.watchPersonSummary('p1').first)!.balance, 2000);
    });
  });
}
