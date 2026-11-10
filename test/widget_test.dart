import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smarava/data/database/app_database.dart';
import 'package:smarava/data/providers/app_providers.dart';
import 'package:smarava/main.dart';

void main() {
  testWidgets('DueMate app renders dashboard with bottom navigation', (WidgetTester tester) async {
    final testDb = AppDatabase(NativeDatabase.memory());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(testDb),
        ],
        child: const DueMateApp(),
      ),
    );

    // Initial pump and a couple frames for async streams to settle
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Verify app title appears
    expect(find.text('DueMate'), findsWidgets);

    // Verify bottom navigation bar destinations
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('People'), findsOneWidget);
    expect(find.text('Reports'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);

    await testDb.close();
  });
}
