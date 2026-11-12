import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:duemate/core/constants/app_constants.dart';
import 'package:duemate/core/utils/backup_helper.dart';
import 'package:duemate/data/database/app_database.dart' hide Person, CreditCardEmi;
import 'package:duemate/data/database/tables.dart';
import 'package:duemate/data/providers/app_providers.dart';
import 'package:duemate/data/repositories/emi_repository_impl.dart';
import 'package:duemate/data/repositories/expense_repository_impl.dart';
import 'package:duemate/data/repositories/person_repository_impl.dart';
import 'package:duemate/data/repositories/transaction_repository_impl.dart';
import 'package:duemate/domain/entities/credit_card_emi.dart';
import 'package:duemate/domain/entities/ledger_transaction.dart';
import 'package:duemate/domain/entities/person.dart';
import 'package:duemate/domain/entities/personal_expense.dart';
import 'package:duemate/features/settings/presentation/widgets/restore_backup.dart';

import '../helpers/test_db.dart';

final _t = DateTime(2026, 10, 1, 10, 30);

Future<void> _seed(AppDatabase db, {String prefix = ''}) async {
  await PersonRepositoryImpl(db).createPerson(
      Person(id: '${prefix}ravi', name: '${prefix}Ravi', phone: '98765', upiId: 'ravi@ybl', createdAt: _t, updatedAt: _t));
  await TransactionRepositoryImpl(db).addTransaction(LedgerTransaction(
    id: '${prefix}t1',
    personId: '${prefix}ravi',
    type: TransactionType.moneyGiven,
    amount: 1500.5,
    transactionDate: _t,
    paymentMethod: PaymentMethod.upi,
    note: 'Dinner',
    createdAt: _t,
    updatedAt: _t,
  ));
  await EmiRepositoryImpl(db).createEmi(CreditCardEmi(
    id: '${prefix}e1',
    personId: AppConstants.selfPersonId,
    itemName: 'Phone',
    cardName: 'HDFC',
    totalAmount: 12000,
    monthlyInstallment: 1000,
    totalTenureMonths: 12,
    installmentsPaid: 2,
    startDate: _t,
    dueDayOfMonth: 5,
    customScheduleJson: '{"3": 1500}',
    createdAt: _t,
    updatedAt: _t,
  ));
  await ExpenseRepositoryImpl(db).createExpense(PersonalExpense(
    id: '${prefix}x1',
    title: 'Groceries',
    amount: 900,
    category: ExpenseCategory.groceries,
    expenseDate: _t,
    paymentMethod: PaymentMethod.cash,
    createdAt: _t,
    updatedAt: _t,
  ));
}

/// Every row of every table, as comparable strings.
Future<List<String>> _dump(AppDatabase db) async => [
      for (final r in await db.select(db.persons).get()) r.toString(),
      for (final r in await db.select(db.transactions).get()) r.toString(),
      for (final r in await db.select(db.creditCardEmis).get()) r.toString(),
      for (final r in await db.select(db.expenses).get()) r.toString(),
    ];

void main() {
  group('Backup', () {
    late AppDatabase source;
    late AppDatabase target;
    setUp(() {
      source = AppDatabase(NativeDatabase.memory());
      target = AppDatabase(NativeDatabase.memory());
    });
    tearDown(() async {
      await source.close();
      await target.close();
    });

    test('a backup restores to an identical database, replacing what was there', () async {
      await _seed(source);
      await _seed(target, prefix: 'old-');
      final json = await BackupHelper.buildBackupJson(source);

      final restored = await BackupHelper.restoreBackup(target, json);
      expect(restored.peopleCount, 1);
      expect(restored.transactions, hasLength(1));
      expect(await _dump(target), await _dump(source), reason: 'every field round-trips; old data is gone');
    });

    test('a file that is not a backup is refused and changes nothing', () async {
      await _seed(target);
      final before = await _dump(target);
      for (final bad in ['not json', '[]', '{"app": "Other", "persons": []}', '{"app": "DueMate"}']) {
        await expectLater(BackupHelper.restoreBackup(target, bad), throwsA(isA<BackupFormatException>()), reason: bad);
      }
      expect(await _dump(target), before);
    });

    test('a damaged backup is refused before anything is erased', () async {
      await _seed(source);
      await _seed(target, prefix: 'keep-');
      final before = await _dump(target);
      final data = jsonDecode(await BackupHelper.buildBackupJson(source)) as Map<String, dynamic>;
      (data['expenses'] as List).first['amount'] = 'lots';
      await expectLater(
          BackupHelper.restoreBackup(target, jsonEncode(data)), throwsA(isA<BackupFormatException>()));
      expect(await _dump(target), before);
    });
  });

  group('Restore from Settings', () {
    Future<AppDatabase> open(WidgetTester tester, String? file) async {
      SharedPreferences.setMockInitialValues({});
      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() => _seed(db, prefix: 'old-'));
      await tester.pumpWidget(ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          backupFilePickerProvider.overrideWithValue(() async => file),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => TextButton(
                onPressed: () => restoreFromBackup(context, ref),
                child: const Text('restore'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('restore'));
      await tester.pump(const Duration(milliseconds: 300));
      return db;
    }

    Future<String> backupJson(WidgetTester tester) async {
      final src = AppDatabase(NativeDatabase.memory());
      final json = await tester.runAsync(() async {
        await _seed(src);
        final j = await BackupHelper.buildBackupJson(src);
        await src.close();
        return j;
      });
      return json!;
    }

    testWidgets('shows what is in the backup, and replaces data only after confirming', (tester) async {
      final json = await backupJson(tester);
      final db = await open(tester, json);

      expect(find.text('Replace all data?'), findsOneWidget);
      expect(find.textContaining('1 person, 1 entry, 1 EMI and 1 expense'), findsOneWidget);

      await tester.tap(find.text('Replace everything'));
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Backup restored'), findsOneWidget);
      final people = await tester.runAsync(() => db.select(db.persons).get());
      expect(people!.map((p) => p.id), unorderedEquals([AppConstants.selfPersonId, 'ravi']));

      await closeTestDb(tester, db);
    }, timeout: const Timeout(Duration(seconds: 30)));

    testWidgets('cancel keeps the data; a bad file explains itself', (tester) async {
      var db = await open(tester, await backupJson(tester));
      await tester.tap(find.text('Cancel'));
      await tester.pump(const Duration(milliseconds: 300));
      final people = await tester.runAsync(() => db.select(db.persons).get());
      expect(people!.map((p) => p.id), contains('old-ravi'));
      await closeTestDb(tester, db);

      db = await open(tester, 'hello');
      expect(find.text("This file isn't a DueMate backup."), findsOneWidget);
      expect(find.text('Replace all data?'), findsNothing);
      await closeTestDb(tester, db);
    }, timeout: const Timeout(Duration(seconds: 30)));
  });
}
