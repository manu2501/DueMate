import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:duemate/core/theme/app_theme.dart';
import 'package:duemate/data/database/app_database.dart';
import 'package:duemate/data/providers/app_providers.dart';
import 'package:duemate/features/expenses/presentation/screens/expenses_screen.dart';

import 'helpers/test_db.dart';

void main() {
  testWidgets('add an expense that repeats, see it listed, then stop it', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    final db = AppDatabase(NativeDatabase.memory());
    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MaterialApp(theme: AppTheme.light(), home: const ExpensesScreen()),
    ));
    Future<void> settle() async {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
    }

    await settle();
    expect(find.text('Repeats every month'), findsNothing);

    await tester.tap(find.byType(FloatingActionButton));
    await settle();
    await tester.enterText(find.byType(TextField).first, '499');
    await tester.enterText(find.widgetWithText(TextField, 'Description (optional)'), 'Music subscription');
    final repeat = find.widgetWithText(SwitchListTile, 'Repeat every month');
    await tester.ensureVisible(repeat);
    await tester.tap(repeat);
    await tester.pump();
    expect(find.textContaining('Added automatically on the ${DateTime.now().day}'), findsOneWidget);
    final save = find.widgetWithText(FilledButton, 'Add expense').last; // the sheet's, over the empty state
    await tester.ensureVisible(save);
    await tester.tap(save);
    await settle();

    expect(find.text('Repeats every month'), findsOneWidget);
    // The rule sits in its own collapsed card, apart from what was spent.
    expect(find.text('Music subscription'), findsOneWidget, reason: "only this month's expense until opened");
    expect(find.textContaining('1 bill · '), findsOneWidget);
    expect(find.text("This month's expenses"), findsOneWidget);
    expect(find.textContaining(' · Monthly · '), findsOneWidget, reason: 'the expense says it repeats');
    await tester.tap(find.text('Repeats every month'));
    await settle();
    expect(find.text('Music subscription'), findsNWidgets(2), reason: 'the rule, and this month\'s expense');

    await tester.tap(find.text('Music subscription').first);
    await settle();
    await tester.tap(find.text('Stop repeating'));
    await settle();
    await tester.tap(find.widgetWithText(FilledButton, 'Stop repeating'));
    await settle();

    expect(find.text('Repeats every month'), findsNothing);
    expect(find.text('Music subscription'), findsOneWidget, reason: 'the expense it added stays');

    await closeTestDb(tester, db);
  }, timeout: const Timeout(Duration(seconds: 30)));
}
