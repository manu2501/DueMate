import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:duemate/data/database/app_database.dart';
import 'package:duemate/data/database/tables.dart';

class BackupHelper {
  static Future<void> exportBackup(AppDatabase db) async {
    final persons = await db.select(db.persons).get();
    final transactions = await db.select(db.transactions).get();
    final emis = await db.select(db.creditCardEmis).get();
    final expenses = await db.select(db.expenses).get();

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
                'createdAt': x.createdAt.toIso8601String(),
                'updatedAt': x.updatedAt.toIso8601String(),
              })
          .toList(),
    };

    final jsonString = const JsonEncoder.withIndent('  ').convert(backupData);
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/duemate_backup_${DateTime.now().millisecondsSinceEpoch}.json');
    await file.writeAsString(jsonString);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/json')],
        text: 'DueMate Full Database Backup',
        subject: 'DueMate Backup',
      ),
    );
  }

  static Future<int> restoreBackup(AppDatabase db, String jsonString) async {
    final Map<String, dynamic> data = jsonDecode(jsonString);
    final personsJson = data['persons'] as List<dynamic>? ?? [];
    final transactionsJson = data['transactions'] as List<dynamic>? ?? [];
    final emisJson = data['creditCardEmis'] as List<dynamic>? ?? [];
    final expensesJson = data['expenses'] as List<dynamic>? ?? [];

    await db.transaction(() async {
      for (final p in personsJson) {
        final id = p['id'] as String;
        final name = p['name'] as String;
        final phone = p['phone'] as String?;
        final email = p['email'] as String?;
        final notes = p['notes'] as String?;
        final avatarPath = p['avatarPath'] as String?;
        final createdAt = DateTime.parse(p['createdAt'] as String);
        final updatedAt = DateTime.parse(p['updatedAt'] as String);
        final archivedAt = p['archivedAt'] != null ? DateTime.parse(p['archivedAt'] as String) : null;

        await db.into(db.persons).insertOnConflictUpdate(
              PersonsCompanion(
                id: Value(id),
                name: Value(name),
                phone: Value(phone),
                email: Value(email),
                notes: Value(notes),
                avatarPath: Value(avatarPath),
                createdAt: Value(createdAt),
                updatedAt: Value(updatedAt),
                archivedAt: Value(archivedAt),
              ),
            );
      }

      for (final t in transactionsJson) {
        final id = t['id'] as String;
        final personId = t['personId'] as String;
        final type = TransactionType.values[t['type'] as int];
        final amount = (t['amount'] as num).toDouble();
        final transactionDate = DateTime.parse(t['transactionDate'] as String);
        final paymentMethod = PaymentMethod.values[t['paymentMethod'] as int];
        final note = t['note'] as String?;
        final createdAt = DateTime.parse(t['createdAt'] as String);
        final updatedAt = DateTime.parse(t['updatedAt'] as String);

        await db.into(db.transactions).insertOnConflictUpdate(
              TransactionsCompanion(
                id: Value(id),
                personId: Value(personId),
                type: Value(type),
                amount: Value(amount),
                transactionDate: Value(transactionDate),
                paymentMethod: Value(paymentMethod),
                note: Value(note),
                emiId: Value(t['emiId'] as String?),
                installmentNumber: Value(t['installmentNumber'] as int?),
                isSettled: Value((t['isSettled'] as bool?) ?? false),
                createdAt: Value(createdAt),
                updatedAt: Value(updatedAt),
              ),
            );
      }

      // EMIs must be restored after persons (foreign key) — absent in v1 backups.
      for (final e in emisJson) {
        await db.into(db.creditCardEmis).insertOnConflictUpdate(
              CreditCardEmisCompanion(
                id: Value(e['id'] as String),
                personId: Value(e['personId'] as String),
                itemName: Value(e['itemName'] as String),
                cardName: Value(e['cardName'] as String),
                totalAmount: Value((e['totalAmount'] as num).toDouble()),
                monthlyInstallment: Value((e['monthlyInstallment'] as num).toDouble()),
                totalTenureMonths: Value(e['totalTenureMonths'] as int),
                installmentsPaid: Value((e['installmentsPaid'] as int?) ?? 0),
                startDate: Value(DateTime.parse(e['startDate'] as String)),
                dueDayOfMonth: Value(e['dueDayOfMonth'] as int),
                isPaidByMe: Value((e['isPaidByMe'] as bool?) ?? true),
                status: Value((e['status'] as String?) ?? 'active'),
                interestRate: Value(((e['interestRate'] as num?) ?? 0).toDouble()),
                interestType: Value((e['interestType'] as String?) ?? 'reducing'),
                customScheduleJson: Value(e['customScheduleJson'] as String?),
                notes: Value(e['notes'] as String?),
                createdAt: Value(DateTime.parse(e['createdAt'] as String)),
                updatedAt: Value(DateTime.parse(e['updatedAt'] as String)),
                lastProcessedDate: Value(
                  e['lastProcessedDate'] != null ? DateTime.parse(e['lastProcessedDate'] as String) : null,
                ),
              ),
            );
      }

      for (final x in expensesJson) {
        await db.into(db.expenses).insertOnConflictUpdate(
              ExpensesCompanion(
                id: Value(x['id'] as String),
                title: Value(x['title'] as String),
                amount: Value((x['amount'] as num).toDouble()),
                category: Value(ExpenseCategory.values[x['category'] as int]),
                expenseDate: Value(DateTime.parse(x['expenseDate'] as String)),
                paymentMethod: Value(PaymentMethod.values[x['paymentMethod'] as int]),
                notes: Value(x['notes'] as String?),
                createdAt: Value(DateTime.parse(x['createdAt'] as String)),
                updatedAt: Value(DateTime.parse(x['updatedAt'] as String)),
              ),
            );
      }
    });

    return transactionsJson.length;
  }
}

