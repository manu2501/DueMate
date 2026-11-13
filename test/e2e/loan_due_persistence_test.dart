import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:duemate/data/database/app_database.dart' hide Person;
import 'package:duemate/data/database/tables.dart';
import 'package:duemate/data/repositories/person_repository_impl.dart';
import 'package:duemate/data/repositories/transaction_repository_impl.dart';
import 'package:duemate/domain/entities/ledger_transaction.dart';
import 'package:duemate/domain/entities/person.dart';

import '../helpers/test_db.dart';

void main() {
  final t = DateTime(2026, 11, 1);
  LedgerTransaction give({DateTime? due}) => LedgerTransaction(
        id: 'g',
        personId: 'p',
        type: TransactionType.moneyGiven,
        amount: 5000,
        transactionDate: t,
        paymentMethod: PaymentMethod.upi,
        dueDate: due,
        createdAt: t,
        updatedAt: t,
      );

  test('a "return by" date is saved, changed and cleared', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await PersonRepositoryImpl(db).createPerson(Person(id: 'p', name: 'Ravi', createdAt: t, updatedAt: t));
    final repo = TransactionRepositoryImpl(db);
    await repo.addTransaction(give(due: DateTime(2026, 12, 15)));
    expect((await repo.getTransactionsForPerson('p')).single.dueDate, DateTime(2026, 12, 15));

    final tx = (await repo.getTransactionsForPerson('p')).single;
    await repo.updateTransaction(tx.copyWith(dueDate: DateTime(2027, 1, 5)));
    expect((await repo.getTransactionsForPerson('p')).single.dueDate, DateTime(2027, 1, 5));
    await repo.updateTransaction(tx.copyWith(clearDueDate: true));
    expect((await repo.getTransactionsForPerson('p')).single.dueDate, isNull);
  });

  test('upgrading a v9 database adds "return by" and keeps entries', () async {
    final dir = await Directory.systemTemp.createTemp('duemate_v9_');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/db.sqlite');

    var db = AppDatabase(NativeDatabase(file));
    await PersonRepositoryImpl(db).createPerson(Person(id: 'p', name: 'Ravi', createdAt: t, updatedAt: t));
    await TransactionRepositoryImpl(db).addTransaction(give());
    await downgradeToV9(db);
    await db.close();

    db = AppDatabase(NativeDatabase(file));
    addTearDown(db.close);
    final repo = TransactionRepositoryImpl(db);
    final tx = (await repo.getTransactionsForPerson('p')).single;
    expect((tx.amount, tx.dueDate), (5000.0, null));
    await repo.updateTransaction(tx.copyWith(dueDate: DateTime(2026, 12, 1)));
    expect((await repo.getTransactionsForPerson('p')).single.dueDate, DateTime(2026, 12, 1));
  });
}
