import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:duemate/core/constants/app_constants.dart';
import 'package:duemate/data/database/app_database.dart';
import 'package:duemate/data/providers/app_providers.dart';
import 'package:duemate/main.dart';

void main() {
  testWidgets('DueMate launches directly into Dashboard with 4-tab navigation bar', (WidgetTester tester) async {
    // No platform channels in tests: provide prefs in-memory and mark this
    // version as already seen so the dashboard doesn't open the permissions
    // sheet (which would need permission_handler's native side).
    SharedPreferences.setMockInitialValues({
      'duemate_last_run_version': AppConstants.appVersionString,
    });
    final testDb = AppDatabase(NativeDatabase.memory());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(testDb),
        ],
        child: const DueMateApp(),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Verify Direct Startup Dashboard renders with net ledger balance and quick actions
    expect(find.text('Net Ledger Balance'), findsOneWidget);
    expect(find.text('Largest balances'), findsOneWidget);
    expect(find.text('Give'), findsOneWidget);
    expect(find.text('Receive'), findsOneWidget);

    // Verify 4-tab navigation bar
    expect(find.byTooltip('Home'), findsOneWidget);
    expect(find.byTooltip('People'), findsOneWidget);
    expect(find.byTooltip('Expenses'), findsOneWidget);
    expect(find.byTooltip('Activity'), findsOneWidget);

    // Tap Directory tab
    await tester.tap(find.byTooltip('People'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('People'), findsWidgets);

    // Tap Expenses tab
    await tester.tap(find.byTooltip('Expenses'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Expenses'), findsWidgets);

    // Tap Transactions tab
    await tester.tap(find.byTooltip('Activity'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Activity'), findsWidgets);

    // Finish all ticking animation controllers & pending microtasks
    await tester.pump(const Duration(seconds: 5));

    // Tear down the widget tree so stream subscriptions are cancelled. Drift
    // schedules the actual stream cleanup on timers created in this fake-async
    // zone, so they must be pumped before close() — otherwise close() waits on
    // them forever and the test hangs.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
    await tester.runAsync(() => testDb.close());
    // Fail fast instead of hanging if teardown ever regresses.
  }, timeout: const Timeout(Duration(seconds: 30)));
}
