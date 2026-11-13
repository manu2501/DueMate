import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:duemate/data/database/app_database.dart';

/// Tears down a widget test that used an in-memory [db]. The order matters:
/// unmount the tree so Drift streams are cancelled, pump so Drift's cleanup
/// timers (created in the fake-async zone) run, then close for real. Closing
/// without pumping first hangs forever.
Future<void> closeTestDb(WidgetTester tester, AppDatabase db) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 1));
  await tester.runAsync(db.close);
}

/// Turns a current database back into schema v8 (before recurring expenses),
/// for upgrade tests.
Future<void> downgradeToV8(AppDatabase db) async {
  await downgradeToV9(db);
  await db.customStatement('DROP TABLE recurring_expenses');
  await db.customStatement('ALTER TABLE expenses DROP COLUMN recurring_id');
  await db.customStatement('PRAGMA user_version = 8');
}

/// Turns a current database back into schema v10 (before EMI expenses).
Future<void> downgradeToV10(AppDatabase db) async {
  await db.customStatement('DROP INDEX IF EXISTS idx_expenses_emi_id');
  await db.customStatement('ALTER TABLE expenses DROP COLUMN emi_id');
  await db.customStatement('ALTER TABLE expenses DROP COLUMN installment_number');
  await db.customStatement('PRAGMA user_version = 10');
}

/// Turns a current database back into schema v9 (before loan due dates).
Future<void> downgradeToV9(AppDatabase db) async {
  await downgradeToV10(db);
  await db.customStatement('ALTER TABLE transactions DROP COLUMN due_date');
  await db.customStatement('PRAGMA user_version = 9');
}
