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
