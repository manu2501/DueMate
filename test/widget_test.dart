import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:duemate/data/database/app_database.dart';
import 'package:duemate/data/providers/app_providers.dart';
import 'package:duemate/main.dart';

void main() {
  testWidgets('DueMate app renders welcome animation and transitions to dashboard', (WidgetTester tester) async {
    final testDb = AppDatabase(NativeDatabase.memory());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(testDb),
        ],
        child: const DueMateApp(),
      ),
    );

    // Initial pump for welcome animation
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Verify Welcome screen renders
    expect(find.text('Get Started'), findsOneWidget);

    // Tap "Get Started" button to enter Dashboard
    await tester.tap(find.text('Get Started'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Verify dashboard renders with new floating dock navigation
    expect(find.text('DueMate'), findsWidgets);
    expect(find.text('Settlement Progress'), findsOneWidget);
    expect(find.text('Top Dues'), findsOneWidget);
    expect(find.text('They owe you'), findsOneWidget);
    expect(find.text('You owe'), findsOneWidget);
    expect(find.byTooltip('Dashboard'), findsOneWidget);
    expect(find.byTooltip('Directory'), findsOneWidget);
    expect(find.byTooltip('Reports'), findsOneWidget);
    expect(find.byTooltip('Notifications'), findsNothing);

    // Tap on Directory tab to leave dashboard
    await tester.tap(find.byTooltip('Directory'));
    await tester.pumpAndSettle();
    expect(find.text('Search people or notes...'), findsOneWidget);

    // Simulate system back button: should navigate back to Dashboard
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    // Verify we are back on Dashboard, not closing app
    expect(find.text('Settlement Progress'), findsOneWidget);
    expect(find.text('Top Dues'), findsOneWidget);

    await testDb.close();
  });
}
