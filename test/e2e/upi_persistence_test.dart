import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:duemate/core/utils/backup_helper.dart';
import 'package:duemate/data/database/app_database.dart' hide Person;
import 'package:duemate/data/repositories/person_repository_impl.dart';
import 'package:duemate/data/repositories/transaction_repository_impl.dart';
import 'package:duemate/domain/entities/person.dart';

import '../helpers/test_db.dart';

void main() {
  final now = DateTime(2026, 11, 1);

  test('a person\'s UPI ID is saved, updated, cleared, and reaches summaries', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final people = PersonRepositoryImpl(db);
    final txs = TransactionRepositoryImpl(db);

    await people.createPerson(Person(id: 'p', name: 'Ravi', upiId: 'ravi@ybl', createdAt: now, updatedAt: now));
    expect((await people.getPersonById('p'))!.upiId, 'ravi@ybl');

    final summaries = await txs.watchPersonSummaries().first;
    expect(summaries.firstWhere((s) => s.person.id == 'p').person.upiId, 'ravi@ybl',
        reason: 'the Give sheet reads it from summaries');
    expect((await txs.watchPersonSummary('p').first)!.person.upiId, 'ravi@ybl');

    final p = (await people.getPersonById('p'))!;
    await people.updatePerson(p.copyWith(upiId: 'ravi@okaxis'));
    expect((await people.getPersonById('p'))!.upiId, 'ravi@okaxis');

    await people.updatePerson(p.copyWith(clearUpiId: true));
    expect((await people.getPersonById('p'))!.upiId, isNull);
  });

  test('upgrading a v7 database adds the UPI ID column and keeps people', () async {
    final dir = await Directory.systemTemp.createTemp('duemate_v7_');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/db.sqlite');

    // Make a current database, then turn it back into v7.
    var db = AppDatabase(NativeDatabase(file));
    await PersonRepositoryImpl(db).createPerson(Person(id: 'p', name: 'Ravi', createdAt: now, updatedAt: now));
    await downgradeToV8(db);
    await db.customStatement('ALTER TABLE persons DROP COLUMN upi_id');
    await db.customStatement('PRAGMA user_version = 7');
    await db.close();

    db = AppDatabase(NativeDatabase(file));
    addTearDown(db.close);
    final people = PersonRepositoryImpl(db);
    final ravi = (await people.getPersonById('p'))!;
    expect(ravi.name, 'Ravi');
    expect(ravi.upiId, isNull);
    await people.updatePerson(ravi.copyWith(upiId: 'ravi@ybl'));
    expect((await people.getPersonById('p'))!.upiId, 'ravi@ybl');
  });

  test('backups restore a person\'s UPI ID, and older backups without it still restore', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    Map<String, dynamic> person(String id, {String? upiId}) => {
          'id': id,
          'name': id,
          'upiId': ?upiId,
          'createdAt': now.toIso8601String(),
          'updatedAt': now.toIso8601String(),
        };
    await BackupHelper.restoreBackup(
      db,
      jsonEncode({
        'persons': [person('with', upiId: 'w@ybl'), person('without')],
      }),
    );
    final people = PersonRepositoryImpl(db);
    expect((await people.getPersonById('with'))!.upiId, 'w@ybl');
    expect((await people.getPersonById('without'))!.upiId, isNull);
  });
}
