import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:duemate/core/utils/backup_helper.dart';
import 'package:duemate/core/utils/date_formatter.dart';
import 'package:duemate/data/database/app_database.dart' hide RecurringExpense;
import 'package:duemate/data/database/tables.dart';
import 'package:duemate/data/repositories/expense_repository_impl.dart';
import 'package:duemate/data/repositories/recurring_expense_repository_impl.dart';
import 'package:duemate/domain/entities/personal_expense.dart';
import 'package:duemate/domain/entities/recurring_expense.dart';

import '../helpers/test_db.dart';

RecurringExpense _rule({int day = 5, DateTime? start, DateTime? lastPosted, double amount = 18000}) {
  final t = DateTime(2026, 1, 1);
  return RecurringExpense(
    id: 'rent',
    title: 'Rent',
    amount: amount,
    category: ExpenseCategory.rent,
    paymentMethod: PaymentMethod.bankTransfer,
    dayOfMonth: day,
    startDate: start ?? DateTime(2026, 8, day),
    lastPostedDate: lastPosted,
    createdAt: t,
    updatedAt: t,
  );
}

PersonalExpense _first(RecurringExpense r) => PersonalExpense(
      id: 'first',
      title: r.title,
      amount: r.amount,
      category: r.category,
      expenseDate: r.startDate,
      paymentMethod: r.paymentMethod,
      createdAt: r.createdAt,
      updatedAt: r.updatedAt,
    );

void main() {
  group('RecurringExpense schedule', () {
    test('every month from the start up to today, not yet posted, oldest first', () {
      final r = _rule(start: DateTime(2026, 8, 5));
      expect(r.dueDates(DateTime(2026, 11, 4)), [DateTime(2026, 8, 5), DateTime(2026, 9, 5), DateTime(2026, 10, 5)]);
      expect(r.dueDates(DateTime(2026, 11, 5, 8)), hasLength(4), reason: 'today counts');
      expect(_rule(lastPosted: DateTime(2026, 10, 5)).dueDates(DateTime(2026, 11, 20)), [DateTime(2026, 11, 5)]);
      expect(_rule(start: DateTime(2026, 12, 5)).dueDates(DateTime(2026, 11, 20)), isEmpty);
    });

    test('the 31st clamps to short months; the year rolls over', () {
      final r = _rule(day: 31, start: DateTime(2026, 12, 31));
      expect(r.dueDates(DateTime(2027, 4, 30)), [
        DateTime(2026, 12, 31),
        DateTime(2027, 1, 31),
        DateTime(2027, 2, 28),
        DateTime(2027, 3, 31),
        DateTime(2027, 4, 30),
      ]);
    });

    test('next date', () {
      final r = _rule(start: DateTime(2026, 8, 5));
      expect(r.nextDate(DateTime(2026, 11, 4)), DateTime(2026, 11, 5));
      expect(r.nextDate(DateTime(2026, 11, 5)), DateTime(2026, 12, 5));
      expect(_rule(start: DateTime(2027, 3, 5)).nextDate(DateTime(2026, 11, 20)), DateTime(2027, 3, 5));
    });

    test('ordinals', () {
      expect([1, 2, 3, 4, 11, 12, 13, 21, 22, 23, 31].map(ordinal),
          ['1st', '2nd', '3rd', '4th', '11th', '12th', '13th', '21st', '22nd', '23rd', '31st']);
    });
  });

  group('RecurringExpenseRepository', () {
    late AppDatabase db;
    late RecurringExpenseRepositoryImpl repo;
    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      repo = RecurringExpenseRepositoryImpl(db);
    });
    tearDown(() => db.close());

    Future<List<String>> expenses() async => [
          for (final e in await ExpenseRepositoryImpl(db).getAllExpenses())
            '${e.expenseDate.month}/${e.expenseDate.day} ${e.amount} ${e.recurringId}',
        ];

    test('the first occurrence counts as posted; later months post once', () async {
      final r = _rule(start: DateTime(2026, 8, 5));
      await repo.createWithFirst(r, _first(r));
      expect(await expenses(), ['8/5 18000.0 rent']);

      expect(await repo.postDue(DateTime(2026, 10, 20)), 2);
      expect(await repo.postDue(DateTime(2026, 10, 20)), 0, reason: 'never posts twice');
      expect(await expenses(), ['10/5 18000.0 rent', '9/5 18000.0 rent', '8/5 18000.0 rent']);
    });

    test('a new amount applies from now on; stopping keeps past expenses', () async {
      final r = _rule(start: DateTime(2026, 8, 5));
      await repo.createWithFirst(r, _first(r));
      await repo.updateAmount('rent', 20000);
      await repo.postDue(DateTime(2026, 9, 5));
      expect(await expenses(), ['9/5 20000.0 rent', '8/5 18000.0 rent']);

      await repo.delete('rent');
      expect(await repo.watchAll().first, isEmpty);
      expect(await repo.postDue(DateTime(2027)), 0);
      expect(await expenses(), hasLength(2));
    });

    test('erase all data removes rules too', () async {
      final r = _rule();
      await repo.createWithFirst(r, _first(r));
      await db.eraseAllData();
      expect(await repo.watchAll().first, isEmpty);
    });

    test('backups carry rules and which expense came from which rule', () async {
      final r = _rule(start: DateTime(2026, 8, 5));
      await repo.createWithFirst(r, _first(r));
      final json = await BackupHelper.buildBackupJson(db);

      final target = AppDatabase(NativeDatabase.memory());
      addTearDown(target.close);
      await BackupHelper.restoreBackup(target, json);
      final restored = await RecurringExpenseRepositoryImpl(target).watchAll().first;
      expect(restored.single.lastPostedDate, DateTime(2026, 8, 5));
      expect((await ExpenseRepositoryImpl(target).getAllExpenses()).single.recurringId, 'rent');
    });
  });

  test('upgrading a v8 database adds recurring expenses and keeps expenses', () async {
    final dir = await Directory.systemTemp.createTemp('duemate_v8_');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/db.sqlite');

    var db = AppDatabase(NativeDatabase(file));
    final r = _rule(start: DateTime(2026, 8, 5));
    await ExpenseRepositoryImpl(db).createExpense(_first(r));
    await downgradeToV8(db);
    await db.close();

    db = AppDatabase(NativeDatabase(file));
    addTearDown(db.close);
    expect((await ExpenseRepositoryImpl(db).getAllExpenses()).single.recurringId, isNull);
    final repo = RecurringExpenseRepositoryImpl(db);
    await repo.createWithFirst(r, _first(r).copyWith(id: 'second'));
    expect(await repo.postDue(DateTime(2026, 9, 5)), 1);
  });
}
