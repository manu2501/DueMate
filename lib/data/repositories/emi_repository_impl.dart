import 'dart:async';
import 'package:drift/drift.dart';
import '../../domain/entities/credit_card_emi.dart' as domain;
import '../../domain/repositories/emi_repository.dart';
import '../database/app_database.dart' as db;

class EmiRepositoryImpl implements EmiRepository {
  final db.AppDatabase _database;

  EmiRepositoryImpl(this._database);

  domain.CreditCardEmi _toDomain(db.CreditCardEmi row) {
    return domain.CreditCardEmi(
      id: row.id,
      personId: row.personId,
      itemName: row.itemName,
      cardName: row.cardName,
      totalAmount: row.totalAmount,
      monthlyInstallment: row.monthlyInstallment,
      totalTenureMonths: row.totalTenureMonths,
      installmentsPaid: row.installmentsPaid,
      startDate: row.startDate,
      dueDayOfMonth: row.dueDayOfMonth,
      isPaidByMe: row.isPaidByMe,
      status: row.status,
      interestRate: row.interestRate,
      interestType: row.interestType,
      kind: row.kind,
      planMode: row.planMode,
      principal: row.principal,
      charges: row.charges,
      customScheduleJson: row.customScheduleJson,
      notes: row.notes,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      lastProcessedDate: row.lastProcessedDate,
    );
  }

  @override
  Stream<List<domain.CreditCardEmi>> watchAllEmis({String? status}) {
    final query = _database.select(_database.creditCardEmis);
    if (status != null) {
      query.where((tbl) => tbl.status.equals(status));
    }
    query.orderBy([
      (tbl) => OrderingTerm.desc(tbl.createdAt),
    ]);
    return query.watch().map((rows) => rows.map(_toDomain).toList());
  }

  @override
  Stream<List<domain.CreditCardEmi>> watchEmisForPerson(String personId) {
    final query = _database.select(_database.creditCardEmis)
      ..where((tbl) => tbl.personId.equals(personId))
      ..orderBy([
        (tbl) => OrderingTerm.desc(tbl.createdAt),
      ]);
    return query.watch().map((rows) => rows.map(_toDomain).toList());
  }

  @override
  Future<List<domain.CreditCardEmi>> getEmisForPerson(String personId) async {
    final query = _database.select(_database.creditCardEmis)
      ..where((tbl) => tbl.personId.equals(personId))
      ..orderBy([
        (tbl) => OrderingTerm.desc(tbl.createdAt),
      ]);
    final rows = await query.get();
    return rows.map(_toDomain).toList();
  }

  @override
  Future<List<domain.CreditCardEmi>> getActiveEmis() async {
    final query = _database.select(_database.creditCardEmis)
      ..where((tbl) => tbl.status.equals('active'))
      ..orderBy([
        (tbl) => OrderingTerm.asc(tbl.startDate),
      ]);
    final rows = await query.get();
    return rows.map(_toDomain).toList();
  }

  @override
  Future<domain.CreditCardEmi?> getEmiById(String id) async {
    final query = _database.select(_database.creditCardEmis)..where((tbl) => tbl.id.equals(id));
    final row = await query.getSingleOrNull();
    return row != null ? _toDomain(row) : null;
  }

  @override
  Future<void> createEmi(domain.CreditCardEmi emi) async {
    await _database.into(_database.creditCardEmis).insert(
          db.CreditCardEmisCompanion.insert(
            id: emi.id,
            personId: emi.personId,
            itemName: emi.itemName,
            cardName: emi.cardName,
            totalAmount: emi.totalAmount,
            monthlyInstallment: emi.monthlyInstallment,
            totalTenureMonths: emi.totalTenureMonths,
            installmentsPaid: Value(emi.installmentsPaid),
            startDate: emi.startDate,
            dueDayOfMonth: emi.dueDayOfMonth,
            isPaidByMe: Value(emi.isPaidByMe),
            status: Value(emi.status),
            interestRate: Value(emi.interestRate),
            interestType: Value(emi.interestType),
            kind: Value(emi.kind),
            planMode: Value(emi.planMode),
            principal: Value(emi.principal),
            charges: Value(emi.charges),
            customScheduleJson: Value(emi.customScheduleJson),
            notes: Value(emi.notes),
            createdAt: emi.createdAt,
            updatedAt: emi.updatedAt,
            lastProcessedDate: Value(emi.lastProcessedDate),
          ),
        );
  }

  @override
  Future<void> updateEmi(domain.CreditCardEmi emi) async {
    await (_database.update(_database.creditCardEmis)..where((tbl) => tbl.id.equals(emi.id))).write(
      db.CreditCardEmisCompanion(
        itemName: Value(emi.itemName),
        cardName: Value(emi.cardName),
        totalAmount: Value(emi.totalAmount),
        monthlyInstallment: Value(emi.monthlyInstallment),
        totalTenureMonths: Value(emi.totalTenureMonths),
        installmentsPaid: Value(emi.installmentsPaid),
        startDate: Value(emi.startDate),
        dueDayOfMonth: Value(emi.dueDayOfMonth),
        isPaidByMe: Value(emi.isPaidByMe),
        status: Value(emi.status),
        interestRate: Value(emi.interestRate),
        interestType: Value(emi.interestType),
        kind: Value(emi.kind),
        planMode: Value(emi.planMode),
        principal: Value(emi.principal),
        charges: Value(emi.charges),
        customScheduleJson: Value(emi.customScheduleJson),
        notes: Value(emi.notes),
        updatedAt: Value(DateTime.now()),
        lastProcessedDate: Value(emi.lastProcessedDate),
      ),
    );
  }

  @override
  Future<void> deleteEmi(String id) async {
    await (_database.delete(_database.creditCardEmis)..where((tbl) => tbl.id.equals(id))).go();
  }
}

