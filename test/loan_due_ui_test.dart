import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:duemate/core/constants/app_constants.dart';
import 'package:duemate/core/navigation/app_router.dart';
import 'package:duemate/core/widgets/ledger_entry_sheet.dart';
import 'package:duemate/data/database/app_database.dart' hide Person;
import 'package:duemate/data/database/tables.dart';
import 'package:duemate/data/providers/app_providers.dart';
import 'package:duemate/data/repositories/person_repository_impl.dart';
import 'package:duemate/data/repositories/transaction_repository_impl.dart';
import 'package:duemate/domain/entities/ledger_transaction.dart';
import 'package:duemate/domain/entities/person.dart';
import 'package:duemate/main.dart';

import 'helpers/test_db.dart';

void main() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  Future<AppDatabase> seeded(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'duemate_last_run_version': AppConstants.appVersionString});
    final db = AppDatabase(NativeDatabase.memory());
    await tester.runAsync(() async {
      final people = PersonRepositoryImpl(db);
      final txs = TransactionRepositoryImpl(db);
      for (final (id, name, due) in [
        ('late', 'Late Larry', today.subtract(const Duration(days: 3))),
        ('soon', 'Soon Sara', today.add(const Duration(days: 1))),
      ]) {
        await people.createPerson(Person(id: id, name: name, createdAt: now, updatedAt: now));
        await txs.addTransaction(LedgerTransaction(
          id: 'g-$id',
          personId: id,
          type: TransactionType.moneyGiven,
          amount: 4000,
          transactionDate: today.subtract(const Duration(days: 20)),
          paymentMethod: PaymentMethod.cash,
          dueDate: due,
          createdAt: now,
          updatedAt: now,
        ));
      }
    });
    return db;
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  testWidgets('People shows when money is due back, and the Overdue filter finds who is late', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    final db = await seeded(tester);
    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const DueMateApp(),
    ));
    await settle(tester);
    ProviderScope.containerOf(tester.element(find.byType(DueMateApp))).read(appRouterProvider).go('/people');
    await settle(tester);

    expect(find.textContaining('overdue since'), findsOneWidget);
    expect(find.textContaining('due back tomorrow'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Overdue'));
    await settle(tester);
    expect(find.text('Late Larry'), findsOneWidget);
    expect(find.text('Soon Sara'), findsNothing);

    await closeTestDb(tester, db);
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('Give: "Return by 1 week" is saved with the entry', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    final db = await seeded(tester);
    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => LedgerEntrySheet.show(context, type: TransactionType.moneyGiven, personId: 'soon'),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await settle(tester);

    await tester.enterText(find.byType(TextField).first, '1500');
    final week = find.widgetWithText(ChoiceChip, '1 week');
    await tester.ensureVisible(week);
    await tester.tap(week);
    await tester.pump();
    final save = find.widgetWithText(FilledButton, 'Give ₹1,500');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await settle(tester);

    final txs = await tester.runAsync(() => TransactionRepositoryImpl(db).getTransactionsForPerson('soon'));
    final saved = txs!.firstWhere((t) => t.amount == 1500);
    expect(saved.dueDate, today.add(const Duration(days: 7)));

    await closeTestDb(tester, db);
  }, timeout: const Timeout(Duration(seconds: 30)));
}
