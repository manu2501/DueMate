import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:duemate/core/constants/app_constants.dart';
import 'package:duemate/data/database/app_database.dart' hide CreditCardEmi;
import 'package:duemate/data/providers/app_providers.dart';
import 'package:duemate/data/repositories/emi_repository_impl.dart';
import 'package:duemate/domain/emi_reminder_planner.dart';
import 'package:duemate/domain/entities/credit_card_emi.dart';
import 'package:duemate/features/emis/presentation/widgets/emi_details_sheet.dart';
import 'package:duemate/main.dart';

import 'helpers/test_db.dart';

void main() {
  test('reminder payloads carry the EMI id', () {
    final r = EmiReminder(id: 1, emiId: 'emi-42', at: DateTime(2026), title: 't', body: 'b');
    expect(EmiReminder.emiIdFromPayload(r.payload), 'emi-42');
    expect(EmiReminder.emiIdFromPayload('emi:'), isNull);
    expect(EmiReminder.emiIdFromPayload('other'), isNull);
    expect(EmiReminder.emiIdFromPayload(null), isNull);
  });

  Future<AppDatabase> pumpApp(WidgetTester tester, {Stream<String>? taps, String? launchedBy}) async {
    SharedPreferences.setMockInitialValues({'duemate_last_run_version': AppConstants.appVersionString});
    final db = AppDatabase(NativeDatabase.memory());
    final t = DateTime.now();
    await tester.runAsync(() => EmiRepositoryImpl(db).createEmi(CreditCardEmi(
          id: 'emi-1',
          personId: AppConstants.selfPersonId,
          itemName: 'Washing machine',
          cardName: 'SBI',
          totalAmount: 30000,
          monthlyInstallment: 5000,
          totalTenureMonths: 6,
          startDate: DateTime(t.year, t.month + 1, 5),
          dueDayOfMonth: 5,
          createdAt: t,
          updatedAt: t,
        )));
    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        emiReminderTapsProvider.overrideWithValue(taps ?? const Stream.empty()),
        emiReminderLaunchProvider.overrideWithValue(() async => launchedBy),
      ],
      child: const DueMateApp(),
    ));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    return db;
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  testWidgets('tapping a reminder while the app runs opens that EMI', (tester) async {
    final taps = StreamController<String>();
    final db = await pumpApp(tester, taps: taps.stream);
    expect(find.byType(EmiDetailsSheet), findsNothing);

    taps.add('emi-1');
    await settle(tester);
    expect(find.byType(EmiDetailsSheet), findsOneWidget);
    expect(find.descendant(of: find.byType(EmiDetailsSheet), matching: find.textContaining('Washing machine')),
        findsWidgets);

    await taps.close();
    await closeTestDb(tester, db);
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('a reminder that launched the app opens its EMI; a deleted EMI is ignored', (tester) async {
    var db = await pumpApp(tester, launchedBy: 'emi-1');
    await settle(tester);
    expect(find.byType(EmiDetailsSheet), findsOneWidget);
    await closeTestDb(tester, db);

    db = await pumpApp(tester, launchedBy: 'gone');
    await settle(tester);
    expect(find.byType(EmiDetailsSheet), findsNothing);
    await closeTestDb(tester, db);
  }, timeout: const Timeout(Duration(seconds: 30)));
}
