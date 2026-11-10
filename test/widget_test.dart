import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smarava/data/database/app_database.dart';
import 'package:smarava/data/providers/app_providers.dart';
import 'package:smarava/main.dart';

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

    // Verify bottom navigation bar destinations on dashboard
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Ledger'), findsOneWidget);
    expect(find.text('Reports'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);

    await testDb.close();
  });
}
