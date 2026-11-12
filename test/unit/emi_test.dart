import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:duemate/core/services/emi_processor_service.dart';
import 'package:duemate/data/database/app_database.dart' show AppDatabase;
import 'package:duemate/data/database/tables.dart';
import 'package:duemate/data/repositories/emi_repository_impl.dart';
import 'package:duemate/data/repositories/person_repository_impl.dart';
import 'package:duemate/data/repositories/transaction_repository_impl.dart';
import 'package:duemate/domain/entities/credit_card_emi.dart';
import 'package:duemate/domain/entities/person.dart';

void main() {
  group('CreditCardEmi Entity Unit Tests', () {
    test('Calculates remaining amounts, progress, and status correctly', () {
      final emi = CreditCardEmi(
        id: 'emi-1',
        personId: 'p-1',
        itemName: 'iPhone 16 Pro',
        cardName: 'HDFC Millennia',
        totalAmount: 120000,
        monthlyInstallment: 20000,
        totalTenureMonths: 6,
        installmentsPaid: 2,
        startDate: DateTime(2026, 1, 15),
        dueDayOfMonth: 15,
        isPaidByMe: true,
        createdAt: DateTime(2026, 1, 15),
        updatedAt: DateTime(2026, 1, 15),
      );

      expect(emi.isActive, isTrue);
      expect(emi.isCompleted, isFalse);
      expect(emi.remainingInstallments, equals(4));
      expect(emi.paidAmount, equals(40000));
      expect(emi.remainingAmount, equals(80000));
      expect(emi.progress, closeTo(2 / 6, 0.001));
    });

    test('Calculates installment due dates across months and clamps correctly', () {
      final emi = CreditCardEmi(
        id: 'emi-2',
        personId: 'p-1',
        itemName: 'Flight Tickets',
        cardName: 'SBI Cashback',
        totalAmount: 30000,
        monthlyInstallment: 10000,
        totalTenureMonths: 3,
        installmentsPaid: 0,
        startDate: DateTime(2026, 1, 31),
        dueDayOfMonth: 31,
        isPaidByMe: true,
        createdAt: DateTime(2026, 1, 31),
        updatedAt: DateTime(2026, 1, 31),
      );

      // Installment 1: Jan 31
      final d1 = emi.getDueDateForInstallment(1);
      expect(d1.year, equals(2026));
      expect(d1.month, equals(1));
      expect(d1.day, equals(31));

      // Installment 2: Feb 28 (clamps to last day of Feb in non-leap year 2026)
      final d2 = emi.getDueDateForInstallment(2);
      expect(d2.year, equals(2026));
      expect(d2.month, equals(2));
      expect(d2.day, equals(28));

      // Installment 3: March 31
      final d3 = emi.getDueDateForInstallment(3);
      expect(d3.year, equals(2026));
      expect(d3.month, equals(3));
      expect(d3.day, equals(31));
    });

    test('Handles year boundary rollover for due dates', () {
      final emi = CreditCardEmi(
        id: 'emi-3',
        personId: 'p-1',
        itemName: 'Laptop',
        cardName: 'ICICI Amazon Pay',
        totalAmount: 60000,
        monthlyInstallment: 20000,
        totalTenureMonths: 3,
        installmentsPaid: 0,
        startDate: DateTime(2026, 11, 10),
        dueDayOfMonth: 10,
        isPaidByMe: true,
        createdAt: DateTime(2026, 11, 10),
        updatedAt: DateTime(2026, 11, 10),
      );

      final d1 = emi.getDueDateForInstallment(1);
      expect(d1, equals(DateTime(2026, 11, 10)));

      final d2 = emi.getDueDateForInstallment(2);
      expect(d2, equals(DateTime(2026, 12, 10)));

      final d3 = emi.getDueDateForInstallment(3);
      expect(d3, equals(DateTime(2027, 1, 10)));
    });
  });

  group('EmiProcessorService Unit & Integration Tests', () {
    late AppDatabase db;
    late PersonRepositoryImpl personRepo;
    late TransactionRepositoryImpl txRepo;
    late EmiRepositoryImpl emiRepo;
    late EmiProcessorService processor;

    const personId = 'friend-vikram';

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      personRepo = PersonRepositoryImpl(db);
      txRepo = TransactionRepositoryImpl(db);
      emiRepo = EmiRepositoryImpl(db);
      processor = EmiProcessorService(
        emiRepository: emiRepo,
        transactionRepository: txRepo,
        database: db,
      );

      await personRepo.createPerson(
        Person(
          id: personId,
          name: 'Vikram',
          phone: '+91 99999 11111',
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        ),
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('Automatically generates past-due installments into ledger and updates debt', () async {
      // Create EMI: started on 1st Sept, due on 5th of each month, 3 months tenure of ₹5,000 each.
      final emi = CreditCardEmi(
        id: 'emi-test-1',
        personId: personId,
        itemName: 'Sony Headphones',
        cardName: 'HDFC Regalia',
        totalAmount: 15000,
        monthlyInstallment: 5000,
        totalTenureMonths: 3,
        installmentsPaid: 0,
        startDate: DateTime(2026, 9, 1),
        dueDayOfMonth: 5,
        isPaidByMe: true,
        createdAt: DateTime(2026, 9, 1),
        updatedAt: DateTime(2026, 9, 1),
      );
      await emiRepo.createEmi(emi);

      // Evaluate on 6th October:
      // Installment 1 (Sept 5) and Installment 2 (Oct 5) are due!
      final refDate = DateTime(2026, 10, 6);
      final result = await processor.processDueInstallments(referenceDate: refDate);

      expect(result.installmentsGenerated, equals(2));

      // Verify transactions in ledger
      final txs = await txRepo.watchTransactionsForPerson(personId).first;
      expect(txs.length, equals(2));

      final tx1 = txs.firstWhere((t) => t.installmentNumber == 1);
      expect(tx1.amount, equals(5000));
      expect(tx1.type, equals(TransactionType.moneyGiven));
      expect(tx1.emiId, equals('emi-test-1'));
      expect(tx1.isEmi, isTrue);

      final tx2 = txs.firstWhere((t) => t.installmentNumber == 2);
      expect(tx2.amount, equals(5000));
      expect(tx2.installmentNumber, equals(2));

      // Verify Vikram's ledger balance: Vikram owes ₹10,000
      final summary = await txRepo.watchPersonSummary(personId).first;
      expect(summary!.totalGiven, equals(10000));
      expect(summary.balance, equals(10000));

      // Verify EMI entity was updated
      final updatedEmi = await emiRepo.getEmiById('emi-test-1');
      expect(updatedEmi!.installmentsPaid, equals(2));
      expect(updatedEmi.isCompleted, isFalse);

      // Verify idempotency: running again on same day generates 0 transactions
      final secondRun = await processor.processDueInstallments(referenceDate: refDate);
      expect(secondRun.installmentsGenerated, equals(0));

      final txsAfter = await txRepo.watchTransactionsForPerson(personId).first;
      expect(txsAfter.length, equals(2));
    });

    test('Does not re-post installments the user marked as already paid', () async {
      final emi = CreditCardEmi(
        id: 'emi-prepaid',
        personId: personId,
        itemName: 'Laptop',
        cardName: 'ICICI',
        totalAmount: 40000,
        monthlyInstallment: 10000,
        totalTenureMonths: 4,
        installmentsPaid: 2, // first two paid before tracking started
        startDate: DateTime(2026, 6, 1),
        dueDayOfMonth: 5,
        isPaidByMe: true,
        createdAt: DateTime(2026, 6, 1),
        updatedAt: DateTime(2026, 6, 1),
      );
      await emiRepo.createEmi(emi);

      // By Sept 6 installments 1..4 are due, but 1-2 are pre-paid.
      final refDate = DateTime(2026, 9, 6);
      final result = await processor.processDueInstallments(referenceDate: refDate);
      expect(result.installmentsGenerated, equals(2));

      final txs = await txRepo.watchTransactionsForPerson(personId).first;
      expect(txs.map((t) => t.installmentNumber).toSet(), equals({3, 4}));

      final updated = await emiRepo.getEmiById('emi-prepaid');
      expect(updated!.installmentsPaid, equals(4));
      expect(updated.status, equals('completed'));

      // Idempotent on a second run
      final again = await processor.processDueInstallments(referenceDate: refDate);
      expect(again.installmentsGenerated, equals(0));
    });

    test('paid/remaining amounts honor custom per-month schedule', () {
      final emi = CreditCardEmi(
        id: 'emi-custom',
        personId: personId,
        itemName: 'Item',
        cardName: 'Card',
        totalAmount: 3500,
        monthlyInstallment: 1000,
        totalTenureMonths: 3,
        installmentsPaid: 1,
        startDate: DateTime(2026, 1, 1),
        dueDayOfMonth: 1,
        customScheduleJson: '{"1":1500,"3":1000}',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );
      expect(emi.paidAmount, equals(1500));
      expect(emi.remainingAmount, equals(2000));
    });

    test('Marks EMI as completed when last installment is processed', () async {
      final emi = CreditCardEmi(
        id: 'emi-test-2',
        personId: personId,
        itemName: 'Smart TV',
        cardName: 'Axis Ace',
        totalAmount: 10000,
        monthlyInstallment: 5000,
        totalTenureMonths: 2,
        installmentsPaid: 0,
        startDate: DateTime(2026, 1, 1),
        dueDayOfMonth: 10,
        isPaidByMe: true,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );
      await emiRepo.createEmi(emi);

      // Process as of March 15 (both installments due)
      await processor.processDueInstallments(referenceDate: DateTime(2026, 3, 15));

      final updatedEmi = await emiRepo.getEmiById('emi-test-2');
      expect(updatedEmi!.installmentsPaid, equals(2));
      expect(updatedEmi.isCompleted, isTrue);
      expect(updatedEmi.status, equals('completed'));
    });

    test('Supports early installment posting via postNextInstallment', () async {
      final emi = CreditCardEmi(
        id: 'emi-test-early',
        personId: personId,
        itemName: 'Washing Machine',
        cardName: 'SBI SimplyCLICK',
        totalAmount: 30000,
        monthlyInstallment: 10000,
        totalTenureMonths: 3,
        installmentsPaid: 0,
        startDate: DateTime(2026, 12, 1),
        dueDayOfMonth: 20,
        isPaidByMe: true,
        createdAt: DateTime(2026, 12, 1),
        updatedAt: DateTime(2026, 12, 1),
      );
      await emiRepo.createEmi(emi);

      // Today is before due date, but user posts installment 1 early
      final success = await processor.postNextInstallment(emi);
      expect(success, isTrue);

      final txs = await txRepo.watchTransactionsForPerson(personId).first;
      expect(txs.length, equals(1));
      expect(txs.first.installmentNumber, equals(1));

      final updatedEmi = await emiRepo.getEmiById('emi-test-early');
      expect(updatedEmi!.installmentsPaid, equals(1));
    });

    test('Records paymentReceived when friend card was used for user (user owes friend)', () async {
      final emi = CreditCardEmi(
        id: 'emi-friend-card',
        personId: personId,
        itemName: 'Gaming Console',
        cardName: "Vikram's HDFC Card",
        totalAmount: 40000,
        monthlyInstallment: 20000,
        totalTenureMonths: 2,
        installmentsPaid: 0,
        startDate: DateTime(2026, 5, 1),
        dueDayOfMonth: 10,
        isPaidByMe: false, // Friend paid for user!
        createdAt: DateTime(2026, 5, 1),
        updatedAt: DateTime(2026, 5, 1),
      );
      await emiRepo.createEmi(emi);

      await processor.processDueInstallments(referenceDate: DateTime(2026, 5, 15));

      final txs = await txRepo.watchTransactionsForPerson(personId).first;
      expect(txs.length, equals(1));
      expect(txs.first.type, equals(TransactionType.paymentReceived));
      expect(txs.first.installmentNumber, equals(1));

      // Balance check: since friend paid, user owes friend, so balance is -₹20,000
      final summary = await txRepo.watchPersonSummary(personId).first;
      expect(summary!.balance, equals(-20000));
      expect(summary.isOverpaid, isTrue);
    });
  });
}
