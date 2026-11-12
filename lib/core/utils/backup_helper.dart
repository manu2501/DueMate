import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:duemate/core/constants/app_constants.dart';
import 'package:duemate/data/database/app_database.dart';
import 'package:duemate/data/database/tables.dart';
import 'package:duemate/domain/entities/credit_card_emi.dart' as domain;

/// Thrown when a file isn't a DueMate backup or can't be read.
class BackupFormatException implements Exception {
  final String message;
  const BackupFormatException(this.message);
  @override
  String toString() => message;
}

/// A backup file, fully parsed and checked before anything is written, so a
/// bad file never leaves the database half-replaced.
class BackupContents {
  final List<PersonsCompanion> persons;
  final List<TransactionsCompanion> transactions;
  final List<CreditCardEmisCompanion> emis;
  final List<ExpensesCompanion> expenses;
  final List<RecurringExpensesCompanion> recurring;
  final DateTime? exportedAt;

  const BackupContents._(this.persons, this.transactions, this.emis, this.expenses, this.recurring, this.exportedAt);

  /// People in the backup, not counting your own "self" row.
  int get peopleCount => persons.where((p) => p.id.value != _selfId).length;

  static const _selfId = AppConstants.selfPersonId;

  factory BackupContents.parse(String json) {
    final Object? decoded;
    try {
      decoded = jsonDecode(json);
    } on FormatException {
      throw const BackupFormatException("This file isn't a DueMate backup.");
    }
    if (decoded is! Map<String, dynamic> || decoded['persons'] is! List) {
      throw const BackupFormatException("This file isn't a DueMate backup.");
    }
    final app = decoded['app'];
    if (app != null && app != 'DueMate') {
      throw const BackupFormatException("This file isn't a DueMate backup.");
    }
    List<T> rows<T>(String key, T Function(Map<String, dynamic>) parse) =>
        [for (final r in (decoded as Map<String, dynamic>)[key] as List? ?? const []) parse(r as Map<String, dynamic>)];
    try {
      return BackupContents._(
        rows('persons', _person),
        rows('transactions', _transaction),
        rows('creditCardEmis', _emi),
        rows('expenses', _expense),
        rows('recurringExpenses', _recurring), // absent before schema v9
        DateTime.tryParse(decoded['exportedAt'] as String? ?? ''),
      );
    } catch (_) {
      throw const BackupFormatException('This backup is damaged and can\'t be restored.');
    }
  }

  /// Replaces everything on this phone with the backup, in one transaction:
  /// if any row fails, nothing changes.
  Future<void> restoreInto(AppDatabase db) => db.transaction(() async {
        await db.eraseAllData();
        await db.batch((b) {
          // Parents before children (foreign keys).
          b.insertAllOnConflictUpdate(db.persons, persons);
          b.insertAllOnConflictUpdate(db.creditCardEmis, emis);
          b.insertAllOnConflictUpdate(db.transactions, transactions);
          b.insertAllOnConflictUpdate(db.expenses, expenses);
          b.insertAllOnConflictUpdate(db.recurringExpenses, recurring);
        });
      });

  static DateTime _date(Object? v) => DateTime.parse(v as String);
  static DateTime? _dateOrNull(Object? v) => v == null ? null : DateTime.parse(v as String);
  static double _num(Object? v, [double fallback = 0]) => ((v as num?) ?? fallback).toDouble();

  static PersonsCompanion _person(Map<String, dynamic> p) => PersonsCompanion(
        id: Value(p['id'] as String),
        name: Value(p['name'] as String),
        phone: Value(p['phone'] as String?),
        email: Value(p['email'] as String?),
        notes: Value(p['notes'] as String?),
        upiId: Value(p['upiId'] as String?),
        avatarPath: Value(p['avatarPath'] as String?),
        createdAt: Value(_date(p['createdAt'])),
        updatedAt: Value(_date(p['updatedAt'])),
        archivedAt: Value(_dateOrNull(p['archivedAt'])),
      );

  static TransactionsCompanion _transaction(Map<String, dynamic> t) => TransactionsCompanion(
        id: Value(t['id'] as String),
        personId: Value(t['personId'] as String),
        type: Value(TransactionType.values[t['type'] as int]),
        amount: Value(_num(t['amount'])),
        transactionDate: Value(_date(t['transactionDate'])),
        paymentMethod: Value(PaymentMethod.values[t['paymentMethod'] as int]),
        note: Value(t['note'] as String?),
        emiId: Value(t['emiId'] as String?),
        installmentNumber: Value(t['installmentNumber'] as int?),
        isSettled: Value((t['isSettled'] as bool?) ?? false),
        dueDate: Value(_dateOrNull(t['dueDate'])),
        createdAt: Value(_date(t['createdAt'])),
        updatedAt: Value(_date(t['updatedAt'])),
      );

  // EMIs are absent from v1 backups; fields added later have defaults.
  static CreditCardEmisCompanion _emi(Map<String, dynamic> e) => CreditCardEmisCompanion(
        id: Value(e['id'] as String),
        personId: Value(e['personId'] as String),
        itemName: Value(e['itemName'] as String),
        cardName: Value(e['cardName'] as String),
        totalAmount: Value(_num(e['totalAmount'])),
        monthlyInstallment: Value(_num(e['monthlyInstallment'])),
        totalTenureMonths: Value(e['totalTenureMonths'] as int),
        installmentsPaid: Value((e['installmentsPaid'] as int?) ?? 0),
        startDate: Value(_date(e['startDate'])),
        dueDayOfMonth: Value(e['dueDayOfMonth'] as int),
        isPaidByMe: Value((e['isPaidByMe'] as bool?) ?? true),
        status: Value((e['status'] as String?) ?? 'active'),
        interestRate: Value(_num(e['interestRate'])),
        interestType: Value((e['interestType'] as String?) ?? 'reducing'),
        kind: Value((e['kind'] as String?) ??
            domain.CreditCardEmi.inferKind(
              cardName: (e['cardName'] as String?) ?? '',
              itemName: (e['itemName'] as String?) ?? '',
              notes: e['notes'] as String?,
            )),
        planMode: Value((e['planMode'] as String?) ?? 'emi'),
        principal: Value(_num(e['principal'])),
        charges: Value(_num(e['charges'])),
        customScheduleJson: Value(e['customScheduleJson'] as String?),
        notes: Value(e['notes'] as String?),
        createdAt: Value(_date(e['createdAt'])),
        updatedAt: Value(_date(e['updatedAt'])),
        lastProcessedDate: Value(_dateOrNull(e['lastProcessedDate'])),
      );

  static ExpensesCompanion _expense(Map<String, dynamic> x) => ExpensesCompanion(
        id: Value(x['id'] as String),
        title: Value(x['title'] as String),
        amount: Value(_num(x['amount'])),
        category: Value(ExpenseCategory.values[x['category'] as int]),
        expenseDate: Value(_date(x['expenseDate'])),
        paymentMethod: Value(PaymentMethod.values[x['paymentMethod'] as int]),
        notes: Value(x['notes'] as String?),
        recurringId: Value(x['recurringId'] as String?),
        createdAt: Value(_date(x['createdAt'])),
        updatedAt: Value(_date(x['updatedAt'])),
      );

  static RecurringExpensesCompanion _recurring(Map<String, dynamic> r) => RecurringExpensesCompanion(
        id: Value(r['id'] as String),
        title: Value(r['title'] as String),
        amount: Value(_num(r['amount'])),
        category: Value(ExpenseCategory.values[r['category'] as int]),
        paymentMethod: Value(PaymentMethod.values[r['paymentMethod'] as int]),
        notes: Value(r['notes'] as String?),
        dayOfMonth: Value(r['dayOfMonth'] as int),
        startDate: Value(_date(r['startDate'])),
        lastPostedDate: Value(_dateOrNull(r['lastPostedDate'])),
        createdAt: Value(_date(r['createdAt'])),
        updatedAt: Value(_date(r['updatedAt'])),
      );
}

class BackupHelper {
  /// The whole database as backup JSON (format version 2).
  static Future<String> buildBackupJson(AppDatabase db) async {
    final (persons, transactions, emis, expenses, recurring) = await (
      db.select(db.persons).get(),
      db.select(db.transactions).get(),
      db.select(db.creditCardEmis).get(),
      db.select(db.expenses).get(),
      db.select(db.recurringExpenses).get(),
    ).wait;

    final backupData = {
      'app': 'DueMate',
      'version': 2,
      'exportedAt': DateTime.now().toIso8601String(),
      'persons': persons
          .map((p) => {
                'id': p.id,
                'name': p.name,
                'phone': p.phone,
                'email': p.email,
                'notes': p.notes,
                'upiId': p.upiId,
                'avatarPath': p.avatarPath,
                'createdAt': p.createdAt.toIso8601String(),
                'updatedAt': p.updatedAt.toIso8601String(),
                'archivedAt': p.archivedAt?.toIso8601String(),
              })
          .toList(),
      'transactions': transactions
          .map((t) => {
                'id': t.id,
                'personId': t.personId,
                'type': t.type.index,
                'amount': t.amount,
                'transactionDate': t.transactionDate.toIso8601String(),
                'paymentMethod': t.paymentMethod.index,
                'note': t.note,
                'emiId': t.emiId,
                'installmentNumber': t.installmentNumber,
                'isSettled': t.isSettled,
                'dueDate': t.dueDate?.toIso8601String(),
                'createdAt': t.createdAt.toIso8601String(),
                'updatedAt': t.updatedAt.toIso8601String(),
              })
          .toList(),
      'creditCardEmis': emis
          .map((e) => {
                'id': e.id,
                'personId': e.personId,
                'itemName': e.itemName,
                'cardName': e.cardName,
                'totalAmount': e.totalAmount,
                'monthlyInstallment': e.monthlyInstallment,
                'totalTenureMonths': e.totalTenureMonths,
                'installmentsPaid': e.installmentsPaid,
                'startDate': e.startDate.toIso8601String(),
                'dueDayOfMonth': e.dueDayOfMonth,
                'isPaidByMe': e.isPaidByMe,
                'status': e.status,
                'interestRate': e.interestRate,
                'interestType': e.interestType,
                'kind': e.kind,
                'planMode': e.planMode,
                'principal': e.principal,
                'charges': e.charges,
                'customScheduleJson': e.customScheduleJson,
                'notes': e.notes,
                'createdAt': e.createdAt.toIso8601String(),
                'updatedAt': e.updatedAt.toIso8601String(),
                'lastProcessedDate': e.lastProcessedDate?.toIso8601String(),
              })
          .toList(),
      'expenses': expenses
          .map((x) => {
                'id': x.id,
                'title': x.title,
                'amount': x.amount,
                'category': x.category.index,
                'expenseDate': x.expenseDate.toIso8601String(),
                'paymentMethod': x.paymentMethod.index,
                'notes': x.notes,
                'recurringId': x.recurringId,
                'createdAt': x.createdAt.toIso8601String(),
                'updatedAt': x.updatedAt.toIso8601String(),
              })
          .toList(),
      'recurringExpenses': recurring
          .map((r) => {
                'id': r.id,
                'title': r.title,
                'amount': r.amount,
                'category': r.category.index,
                'paymentMethod': r.paymentMethod.index,
                'notes': r.notes,
                'dayOfMonth': r.dayOfMonth,
                'startDate': r.startDate.toIso8601String(),
                'lastPostedDate': r.lastPostedDate?.toIso8601String(),
                'createdAt': r.createdAt.toIso8601String(),
                'updatedAt': r.updatedAt.toIso8601String(),
              })
          .toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(backupData);
  }

  static Future<void> exportBackup(AppDatabase db) async {
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/duemate_backup_${DateTime.now().millisecondsSinceEpoch}.json');
    await file.writeAsString(await buildBackupJson(db));

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/json')],
        text: 'DueMate Full Database Backup',
        subject: 'DueMate Backup',
      ),
    );
  }

  /// Parses [jsonString] and replaces all data with it. Throws
  /// [BackupFormatException] (database untouched) for a bad file.
  static Future<BackupContents> restoreBackup(AppDatabase db, String jsonString) async {
    final contents = BackupContents.parse(jsonString);
    await contents.restoreInto(db);
    return contents;
  }
}
