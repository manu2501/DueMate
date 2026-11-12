import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:duemate/core/constants/app_constants.dart';
import 'package:duemate/data/database/app_database.dart' hide CreditCardEmi, Person;
import 'package:duemate/data/providers/app_providers.dart';
import 'package:duemate/core/navigation/app_router.dart';
import 'package:duemate/data/repositories/emi_repository_impl.dart';
import 'package:duemate/data/repositories/person_repository_impl.dart';
import 'package:duemate/domain/entities/person.dart';
import 'package:duemate/domain/reminder.dart';
import 'package:duemate/domain/entities/credit_card_emi.dart';
import 'package:duemate/features/emis/presentation/widgets/emi_details_sheet.dart';
import 'package:duemate/main.dart';

import 'helpers/test_db.dart';

void main() {
  test('reminder payloads say what to open', () {
    final r = Reminder(id: 1, target: const EmiTarget('emi-42'), at: DateTime(2026), title: 't', body: 'b');
    expect(ReminderTarget.parse(r.payload), const EmiTarget('emi-42'));
    expect(ReminderTarget.parse(const PersonTarget('p1').payload), const PersonTarget('p1'));
    expect(ReminderTarget.parse('emi:'), isNull);
    expect(ReminderTarget.parse('other'), isNull);
    expect(ReminderTarget.parse(null), isNull);
    expect(Reminder.isReminderPayload('loan:p1'), isTrue);
    expect(Reminder.isReminderPayload('something else'), isFalse);
  });

  Future<AppDatabase> pumpApp(WidgetTester tester, {Stream<ReminderTarget>? taps, ReminderTarget? launchedBy}) async {
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
        reminderTapsProvider.overrideWithValue(taps ?? const Stream.empty()),
        reminderLaunchProvider.overrideWithValue(() async => launchedBy),
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
    final taps = StreamController<ReminderTarget>();
    final db = await pumpApp(tester, taps: taps.stream);
    expect(find.byType(EmiDetailsSheet), findsNothing);

    taps.add(const EmiTarget('emi-1'));
    await settle(tester);
    expect(find.byType(EmiDetailsSheet), findsOneWidget);
    expect(find.descendant(of: find.byType(EmiDetailsSheet), matching: find.textContaining('Washing machine')),
        findsWidgets);

    await taps.close();
    await closeTestDb(tester, db);
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('a money-due-back reminder opens that person', (tester) async {
    final taps = StreamController<ReminderTarget>();
    final db = await pumpApp(tester, taps: taps.stream);
    final t = DateTime.now();
    await tester.runAsync(() => PersonRepositoryImpl(db).createPerson(Person(id: 'p1', name: 'Ravi', createdAt: t, updatedAt: t)));
    taps.add(const PersonTarget('p1'));
    await settle(tester);
    final router = ProviderScope.containerOf(tester.element(find.byType(DueMateApp))).read(appRouterProvider);
    expect(router.routerDelegate.currentConfiguration.last.matchedLocation, '/people/p1');

    taps.add(const PersonTarget('deleted'));
    await settle(tester);
    expect(router.routerDelegate.currentConfiguration.last.matchedLocation, '/people/p1', reason: 'unknown person: ignored');

    await taps.close();
    await closeTestDb(tester, db);
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('a reminder that launched the app opens its EMI; a deleted EMI is ignored', (tester) async {
    var db = await pumpApp(tester, launchedBy: const EmiTarget('emi-1'));
    await settle(tester);
    expect(find.byType(EmiDetailsSheet), findsOneWidget);
    await closeTestDb(tester, db);

    db = await pumpApp(tester, launchedBy: const EmiTarget('gone'));
    await settle(tester);
    expect(find.byType(EmiDetailsSheet), findsNothing);
    await closeTestDb(tester, db);
  }, timeout: const Timeout(Duration(seconds: 30)));
}
