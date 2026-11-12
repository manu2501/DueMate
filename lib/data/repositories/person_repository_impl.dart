import 'package:drift/drift.dart';
import '../../domain/entities/person.dart' as domain;
import '../../domain/repositories/person_repository.dart';
import '../database/app_database.dart' as db;

class PersonRepositoryImpl implements PersonRepository {
  final db.AppDatabase _database;

  PersonRepositoryImpl(this._database);

  domain.Person _toDomain(db.Person row) {
    return domain.Person(
      id: row.id,
      name: row.name,
      phone: row.phone,
      email: row.email,
      notes: row.notes,
      upiId: row.upiId,
      avatarPath: row.avatarPath,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      archivedAt: row.archivedAt,
    );
  }

  @override
  Stream<List<domain.Person>> watchAllPersons({bool includeArchived = false}) {
    final query = _database.select(_database.persons);
    if (!includeArchived) {
      query.where((tbl) => tbl.archivedAt.isNull());
    }
    query.orderBy([
      (tbl) => OrderingTerm.asc(tbl.name),
    ]);
    return query.watch().map((rows) => rows.map(_toDomain).toList());
  }

  @override
  Stream<domain.Person?> watchPersonById(String id) {
    final query = _database.select(_database.persons)..where((tbl) => tbl.id.equals(id));
    return query.watchSingleOrNull().map((row) => row != null ? _toDomain(row) : null);
  }

  @override
  Future<List<domain.Person>> getAllPersons({bool includeArchived = false}) async {
    final query = _database.select(_database.persons);
    if (!includeArchived) {
      query.where((tbl) => tbl.archivedAt.isNull());
    }
    query.orderBy([
      (tbl) => OrderingTerm.asc(tbl.name),
    ]);
    final rows = await query.get();
    return rows.map(_toDomain).toList();
  }

  @override
  Future<domain.Person?> getPersonById(String id) async {
    final query = _database.select(_database.persons)..where((tbl) => tbl.id.equals(id));
    final row = await query.getSingleOrNull();
    return row != null ? _toDomain(row) : null;
  }

  @override
  Future<void> createPerson(domain.Person person) async {
    await _database.into(_database.persons).insert(
          db.PersonsCompanion.insert(
            id: person.id,
            name: person.name,
            phone: Value(person.phone),
            email: Value(person.email),
            notes: Value(person.notes),
            upiId: Value(person.upiId),
            avatarPath: Value(person.avatarPath),
            createdAt: person.createdAt,
            updatedAt: person.updatedAt,
            archivedAt: Value(person.archivedAt),
          ),
        );
  }

  @override
  Future<void> updatePerson(domain.Person person) async {
    await (_database.update(_database.persons)..where((tbl) => tbl.id.equals(person.id))).write(
      db.PersonsCompanion(
        name: Value(person.name),
        phone: Value(person.phone),
        email: Value(person.email),
        notes: Value(person.notes),
        upiId: Value(person.upiId),
        avatarPath: Value(person.avatarPath),
        updatedAt: Value(DateTime.now()),
        archivedAt: Value(person.archivedAt),
      ),
    );
  }

  @override
  Future<void> archivePerson(String id) async {
    final now = DateTime.now();
    await (_database.update(_database.persons)..where((tbl) => tbl.id.equals(id))).write(
      db.PersonsCompanion(
        archivedAt: Value(now),
        updatedAt: Value(now),
      ),
    );
  }

  @override
  Future<void> unarchivePerson(String id) async {
    final now = DateTime.now();
    await (_database.update(_database.persons)..where((tbl) => tbl.id.equals(id))).write(
      db.PersonsCompanion(
        archivedAt: const Value(null),
        updatedAt: Value(now),
      ),
    );
  }

  @override
  Future<void> deletePerson(String id) async {
    await _database.transaction(() async {
      await (_database.delete(_database.transactions)..where((tbl) => tbl.personId.equals(id))).go();
      await (_database.delete(_database.persons)..where((tbl) => tbl.id.equals(id))).go();
    });
  }
}

