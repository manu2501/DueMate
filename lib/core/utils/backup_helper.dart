import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:smarava/data/database/app_database.dart';
import 'package:smarava/data/database/tables.dart';

class BackupHelper {
  static Future<void> exportBackup(AppDatabase db) async {
    final persons = await db.select(db.persons).get();
    final transactions = await db.select(db.transactions).get();

    final backupData = {
      'app': 'DueMate',
      'version': 1,
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
                'createdAt': t.createdAt.toIso8601String(),
                'updatedAt': t.updatedAt.toIso8601String(),
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
                createdAt: Value(createdAt),
                updatedAt: Value(updatedAt),
              ),
            );
      }
    });

    return transactionsJson.length;
  }
}

