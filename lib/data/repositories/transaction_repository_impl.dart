import 'dart:async';
import 'package:drift/drift.dart';
import '../../domain/entities/ledger_summary.dart';
import '../../domain/entities/ledger_transaction.dart';
import '../../domain/entities/person.dart' as domain;
import '../../domain/entities/person_summary.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../database/app_database.dart' as db;
import '../database/tables.dart';

class TransactionRepositoryImpl implements TransactionRepository {
  final db.AppDatabase _database;

  TransactionRepositoryImpl(this._database);

  LedgerTransaction _toDomain(db.Transaction row) {
    return LedgerTransaction(
      id: row.id,
      personId: row.personId,
      type: row.type,
      amount: row.amount,
      transactionDate: row.transactionDate,
      paymentMethod: row.paymentMethod,
      note: row.note,
      emiId: row.emiId,
      installmentNumber: row.installmentNumber,
      isSettled: row.isSettled,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  @override
  Stream<List<LedgerTransaction>> watchAllTransactions({int? limit}) {
    final query = _database.select(_database.transactions)
      ..orderBy([
        (tbl) => OrderingTerm.desc(tbl.transactionDate),
        (tbl) => OrderingTerm.desc(tbl.createdAt),
      ]);
    if (limit != null) {
      query.limit(limit);
    }
    return query.watch().map((rows) => rows.map(_toDomain).toList());
  }

  @override
  Stream<List<LedgerTransaction>> watchTransactionsForPerson(String personId) {
    final query = _database.select(_database.transactions)
      ..where((tbl) => tbl.personId.equals(personId))
      ..orderBy([
        (tbl) => OrderingTerm.desc(tbl.transactionDate),
        (tbl) => OrderingTerm.desc(tbl.createdAt),
      ]);
    return query.watch().map((rows) => rows.map(_toDomain).toList());
  }

  @override
  Future<List<LedgerTransaction>> getTransactionsForPerson(String personId) async {
    final query = _database.select(_database.transactions)
      ..where((tbl) => tbl.personId.equals(personId))
      ..orderBy([
        (tbl) => OrderingTerm.desc(tbl.transactionDate),
        (tbl) => OrderingTerm.desc(tbl.createdAt),
      ]);
    final rows = await query.get();
    return rows.map(_toDomain).toList();
  }

  @override
  Future<LedgerTransaction?> getTransactionById(String id) async {
    final query = _database.select(_database.transactions)..where((tbl) => tbl.id.equals(id));
    final row = await query.getSingleOrNull();
    return row != null ? _toDomain(row) : null;
  }

  @override
  Future<void> addTransaction(LedgerTransaction transaction) async {
    await _database.transaction(() async {
      await _database.into(_database.transactions).insert(
            db.TransactionsCompanion.insert(
              id: transaction.id,
              personId: transaction.personId,
              type: transaction.type,
              amount: transaction.amount,
              transactionDate: transaction.transactionDate,
              paymentMethod: transaction.paymentMethod,
              note: Value(transaction.note),
              emiId: Value(transaction.emiId),
              installmentNumber: Value(transaction.installmentNumber),
              isSettled: Value(transaction.isSettled),
              createdAt: transaction.createdAt,
              updatedAt: transaction.updatedAt,
            ),
          );

      // Update person's updatedAt timestamp
      await (_database.update(_database.persons)..where((tbl) => tbl.id.equals(transaction.personId))).write(
        db.PersonsCompanion(
          updatedAt: Value(DateTime.now()),
        ),
      );
    });
  }

  @override
  Future<void> updateTransaction(LedgerTransaction transaction) async {
    await _database.transaction(() async {
      await (_database.update(_database.transactions)..where((tbl) => tbl.id.equals(transaction.id))).write(
        db.TransactionsCompanion(
          type: Value(transaction.type),
          amount: Value(transaction.amount),
          transactionDate: Value(transaction.transactionDate),
          paymentMethod: Value(transaction.paymentMethod),
          note: Value(transaction.note),
          emiId: Value(transaction.emiId),
          installmentNumber: Value(transaction.installmentNumber),
          isSettled: Value(transaction.isSettled),
          updatedAt: Value(DateTime.now()),
        ),
      );

      // Update person's updatedAt timestamp
      await (_database.update(_database.persons)..where((tbl) => tbl.id.equals(transaction.personId))).write(
        db.PersonsCompanion(
          updatedAt: Value(DateTime.now()),
        ),
      );
    });
  }

  @override
  Future<void> deleteTransaction(String id) async {
    await _database.transaction(() async {
      final tx = await getTransactionById(id);
      await (_database.delete(_database.transactions)..where((tbl) => tbl.id.equals(id))).go();

      if (tx != null) {
        await (_database.update(_database.persons)..where((tbl) => tbl.id.equals(tx.personId))).write(
          db.PersonsCompanion(
            updatedAt: Value(DateTime.now()),
          ),
        );
      }
    });
  }

  @override
  Stream<LedgerSummary> watchLedgerSummary() {
    final personsStream = (_database.select(_database.persons)..where((tbl) => tbl.archivedAt.isNull())).watch();
    final transactionsStream = _database.select(_database.transactions).watch();

    return _combineLatest2(personsStream, transactionsStream, (persons, transactions) {
      double totalGiven = 0;
      double totalReceived = 0;

      // Map to track per-person balance
      final personBalances = <String, double>{};
      final personGiven = <String, double>{};
      final personReceived = <String, double>{};

      for (final tx in transactions) {
        if (tx.type == TransactionType.moneyGiven) {
          totalGiven += tx.amount;
          personGiven[tx.personId] = (personGiven[tx.personId] ?? 0) + tx.amount;
        } else {
          totalReceived += tx.amount;
          personReceived[tx.personId] = (personReceived[tx.personId] ?? 0) + tx.amount;
        }
      }

      int activeCount = 0;
      int settledCount = 0;

      for (final p in persons) {
        final g = personGiven[p.id] ?? 0;
        final r = personReceived[p.id] ?? 0;
        final bal = g - r;
        personBalances[p.id] = bal;

        if (bal > 0.0001) {
          activeCount++;
        } else if (bal.abs() <= 0.0001 && (g > 0 || r > 0)) {
          settledCount++;
        }
      }

      return LedgerSummary(
        totalGiven: totalGiven,
        totalReceived: totalReceived,
        totalOutstanding: totalGiven - totalReceived,
        activePeopleCount: activeCount,
        settledPeopleCount: settledCount,
        totalPeopleCount: persons.length,
      );
    });
  }

  @override
  Stream<List<PersonSummary>> watchPersonSummaries({bool includeArchived = false}) {
    final personQuery = _database.select(_database.persons);
    if (!includeArchived) {
      personQuery.where((tbl) => tbl.archivedAt.isNull());
    }
    final personsStream = personQuery.watch();
    final transactionsStream = (_database.select(_database.transactions)
          ..orderBy([
            (tbl) => OrderingTerm.desc(tbl.transactionDate),
            (tbl) => OrderingTerm.desc(tbl.createdAt),
          ]))
        .watch();

    return _combineLatest2(personsStream, transactionsStream, (persons, transactions) {
      // Group transactions by personId
      final txMap = <String, List<db.Transaction>>{};
      for (final tx in transactions) {
        txMap.putIfAbsent(tx.personId, () => []).add(tx);
      }

      final summaries = <PersonSummary>[];
      for (final p in persons) {
        final txList = txMap[p.id] ?? [];
        double given = 0;
        double received = 0;

        for (final tx in txList) {
          if (tx.type == TransactionType.moneyGiven) {
            given += tx.amount;
          } else {
            received += tx.amount;
          }
        }

        final balance = given - received;
        final lastTx = txList.isNotEmpty ? _toDomain(txList.first) : null;

        summaries.add(
          PersonSummary(
            person: domain.Person(
              id: p.id,
              name: p.name,
              phone: p.phone,
              email: p.email,
              notes: p.notes,
              upiId: p.upiId,
              avatarPath: p.avatarPath,
              createdAt: p.createdAt,
              updatedAt: p.updatedAt,
              archivedAt: p.archivedAt,
            ),
            totalGiven: given,
            totalReceived: received,
            balance: balance,
            lastTransaction: lastTx,
            transactionCount: txList.length,
          ),
        );
      }

      return summaries;
    });
  }

  @override
  Stream<PersonSummary?> watchPersonSummary(String personId) {
    final personStream = (_database.select(_database.persons)..where((tbl) => tbl.id.equals(personId))).watchSingleOrNull();
    final txStream = (_database.select(_database.transactions)
          ..where((tbl) => tbl.personId.equals(personId))
          ..orderBy([
            (tbl) => OrderingTerm.desc(tbl.transactionDate),
            (tbl) => OrderingTerm.desc(tbl.createdAt),
          ]))
        .watch();

    return _combineLatest2(personStream, txStream, (p, txList) {
      if (p == null) return null;

      double given = 0;
      double received = 0;

      for (final tx in txList) {
        if (tx.type == TransactionType.moneyGiven) {
          given += tx.amount;
        } else {
          received += tx.amount;
        }
      }

      final balance = given - received;
      final lastTx = txList.isNotEmpty ? _toDomain(txList.first) : null;

      return PersonSummary(
        person: domain.Person(
          id: p.id,
          name: p.name,
          phone: p.phone,
          email: p.email,
          notes: p.notes,
          upiId: p.upiId,
          avatarPath: p.avatarPath,
          createdAt: p.createdAt,
          updatedAt: p.updatedAt,
          archivedAt: p.archivedAt,
        ),
        totalGiven: given,
        totalReceived: received,
        balance: balance,
        lastTransaction: lastTx,
        transactionCount: txList.length,
      );
    });
  }

  Stream<R> _combineLatest2<A, B, R>(
    Stream<A> streamA,
    Stream<B> streamB,
    R Function(A a, B b) combiner,
  ) {
    late StreamController<R> controller;
    A? lastA;
    B? lastB;
    bool hasA = false;
    bool hasB = false;
    StreamSubscription<A>? subA;
    StreamSubscription<B>? subB;

    controller = StreamController<R>(
      onListen: () {
        subA = streamA.listen(
          (a) {
            lastA = a;
            hasA = true;
            if (hasB) {
              controller.add(combiner(lastA as A, lastB as B));
            }
          },
          onError: controller.addError,
        );
        subB = streamB.listen(
          (b) {
            lastB = b;
            hasB = true;
            if (hasA) {
              controller.add(combiner(lastA as A, lastB as B));
            }
          },
          onError: controller.addError,
        );
      },
      onCancel: () {
        subA?.cancel();
        subB?.cancel();
      },
    );
    return controller.stream;
  }
}

