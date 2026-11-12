import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:duemate/data/database/app_database.dart';
import 'package:duemate/data/providers/app_providers.dart';
import 'package:duemate/main.dart';

void main() {
  testWidgets('DueMate launches directly into Dashboard with 4-tab navigation dock', (WidgetTester tester) async {
    final testDb = AppDatabase(NativeDatabase.memory());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(testDb),
        ],
        child: const DueMateApp(),
      ),
    );

    await tester.pump(const Duration(milliseconds: 500));

    // Verify Direct Startup Dashboard renders with net ledger balance and quick actions
    expect(find.text('Net Ledger Balance'), findsOneWidget);
    expect(find.text('Top Active Dues'), findsOneWidget);
    expect(find.text('Give'), findsOneWidget);
    expect(find.text('Receive'), findsOneWidget);

    // Verify 4-tab floating dock navbar
    expect(find.byTooltip('Dashboard'), findsOneWidget);
    expect(find.byTooltip('Directory'), findsOneWidget);
    expect(find.byTooltip('Expenses'), findsOneWidget);
    expect(find.byTooltip('Transactions'), findsOneWidget);

    // Tap Directory tab
    await tester.tap(find.byTooltip('Directory'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Directory'), findsWidgets);

    // Tap Expenses tab
    await tester.tap(find.byTooltip('Expenses'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('My Expenses & Outflows'), findsOneWidget);

    // Tap Transactions tab
    await tester.tap(find.byTooltip('Transactions'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Transactions & Outflows'), findsOneWidget);

    // Finish all ticking animation controllers & pending microtasks
    await tester.pump(const Duration(seconds: 5));

    await testDb.close();
  });
}
