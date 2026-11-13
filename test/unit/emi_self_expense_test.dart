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
}
