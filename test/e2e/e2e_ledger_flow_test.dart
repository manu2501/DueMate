import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';
import 'package:duemate/core/constants/app_constants.dart';
import 'package:duemate/data/database/app_database.dart' hide Person, CreditCardEmi, Transaction;
import 'package:duemate/data/database/tables.dart';
import 'package:duemate/data/repositories/emi_repository_impl.dart';
import 'package:duemate/data/repositories/person_repository_impl.dart';
import 'package:duemate/data/repositories/transaction_repository_impl.dart';
import 'package:duemate/domain/entities/credit_card_emi.dart';
import 'package:duemate/domain/entities/ledger_transaction.dart';
import 'package:duemate/domain/entities/person.dart';

void main() {
  late AppDatabase db;
  late PersonRepositoryImpl personRepo;
  late TransactionRepositoryImpl txRepo;
  late EmiRepositoryImpl emiRepo;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    personRepo = PersonRepositoryImpl(db);
    txRepo = TransactionRepositoryImpl(db);
    emiRepo = EmiRepositoryImpl(db);

    // Seed self_person_me record for foreign key validation
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await db.customStatement(
      "INSERT OR IGNORE INTO persons (id, name, created_at, updated_at) "
      "VALUES ('${AppConstants.selfPersonId}', 'Myself (Personal)', $nowSec, $nowSec)",
    );
  });

  tearDown(() async {
    await db.close();
  });

  test('E2E Flow 1: Create Contact, Record Money Given & Payment Received', () async {
    final now = DateTime.now();
    final person = Person(
      id: const Uuid().v4(),
      name: 'John Doe',
      phone: '+91 98765 43210',
      createdAt: now,
      updatedAt: now,
    );

    await personRepo.createPerson(person);

    // Record Money Given: ₹5,000
    final tx1 = LedgerTransaction(
      id: const Uuid().v4(),
      personId: person.id,
      type: TransactionType.moneyGiven,
      amount: 5000.0,
      transactionDate: now,
      paymentMethod: PaymentMethod.upi,
      note: 'Dinner & Movie Advance',
      createdAt: now,
      updatedAt: now,
    );
    await txRepo.addTransaction(tx1);

    // Verify balance: +₹5,000 (Owes user)
    var summary = await txRepo.watchPersonSummary(person.id).first;
    expect(summary!.balance, equals(5000.0));
    expect(summary.owesMoney, isTrue);

    // Record Payment Received: ₹2,000
    final tx2 = LedgerTransaction(
      id: const Uuid().v4(),
      personId: person.id,
      type: TransactionType.paymentReceived,
      amount: 2000.0,
      transactionDate: now,
      paymentMethod: PaymentMethod.upi,
      note: 'Partial Repayment via PhonePe',
      createdAt: now,
      updatedAt: now,
    );
    await txRepo.addTransaction(tx2);

    // Verify balance: +₹3,000 remaining
    summary = await txRepo.watchPersonSummary(person.id).first;
    expect(summary!.balance, equals(3000.0));
  });

  test('E2E Flow 2: Create Self EMI (For Myself) with foreign key validation', () async {
    final now = DateTime.now();

    // Create EMI for self using AppConstants.selfPersonId ('self_person_me')
    final selfEmi = CreditCardEmi(
      id: const Uuid().v4(),
      personId: AppConstants.selfPersonId,
      itemName: 'MacBook Air M3',
      cardName: 'HDFC Regalia Credit Card',
      totalAmount: 114000.0,
      monthlyInstallment: 9500.0,
      totalTenureMonths: 12,
      installmentsPaid: 0,
      startDate: now,
      dueDayOfMonth: 15,
      isPaidByMe: true,
      status: 'active',
      createdAt: now,
      updatedAt: now,
    );

    await emiRepo.createEmi(selfEmi);

    final emis = await emiRepo.getActiveEmis();
    expect(emis.length, equals(1));
    expect(emis.first.itemName, equals('MacBook Air M3'));
    expect(emis.first.isForSelf, isTrue);
    expect(emis.first.personId, equals(AppConstants.selfPersonId));
  });

  test('Erase all data removes everything except the self row', () async {
    final now = DateTime.now();
    final person = Person(id: 'p1', name: 'Asha', createdAt: now, updatedAt: now);
    await personRepo.createPerson(person);
    await txRepo.addTransaction(LedgerTransaction(
      id: 't1',
      personId: 'p1',
      type: TransactionType.moneyGiven,
      amount: 100,
      transactionDate: now,
      paymentMethod: PaymentMethod.cash,
      createdAt: now,
      updatedAt: now,
    ));
    await emiRepo.createEmi(CreditCardEmi(
      id: 'e1',
      personId: AppConstants.selfPersonId,
      itemName: 'Phone',
      cardName: 'Card',
      totalAmount: 1200,
      monthlyInstallment: 100,
      totalTenureMonths: 12,
      startDate: now.add(const Duration(days: 30)),
      dueDayOfMonth: 1,
      createdAt: now,
      updatedAt: now,
    ));
    await db.customStatement(
      "INSERT INTO expenses (id, title, amount, category, expense_date, payment_method, created_at, updated_at) "
      "VALUES ('x1', 'Tea', 20, 0, 0, 0, 0, 0)",
    );

    await db.eraseAllData();

    expect(await db.select(db.transactions).get(), isEmpty);
    expect(await db.select(db.creditCardEmis).get(), isEmpty);
    expect(await db.select(db.expenses).get(), isEmpty, reason: 'expenses used to survive an erase');
    final persons = await db.select(db.persons).get();
    expect(persons.map((p) => p.id), [AppConstants.selfPersonId]);
  });
}
