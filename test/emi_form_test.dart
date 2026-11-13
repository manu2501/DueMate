import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:duemate/core/theme/app_theme.dart';
import 'package:duemate/data/database/app_database.dart' hide CreditCardEmi, Person, Transaction;
import 'package:duemate/data/providers/app_providers.dart';
import 'package:duemate/data/repositories/emi_repository_impl.dart';
import 'package:duemate/domain/entities/credit_card_emi.dart';
import 'package:duemate/features/emis/presentation/screens/add_edit_emi_screen.dart';
import 'helpers/test_db.dart';

Future<AppDatabase> _openForm(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  // Tall screen so the whole ListView is built and every field is findable.
  tester.view.physicalSize = const Size(900, 6000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final db = AppDatabase(NativeDatabase.memory());
  await tester.pumpWidget(
    ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => AddEditEmiScreen.show(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  return db;
}

Future<void> _fill(WidgetTester tester, String label, String text) async {
  final field = find.widgetWithText(TextFormField, label);
  expect(field, findsOneWidget, reason: 'field "$label" should exist');
  await tester.ensureVisible(field);
  await tester.enterText(field, text);
  await tester.pump();
}

/// Opens "More options" (interest or original amount, fees, notes).
Future<void> _openMore(WidgetTester tester) async {
  final more = find.text('More options');
  await tester.ensureVisible(more);
  await tester.tap(more);
  await tester.pump();
}

Future<CreditCardEmi> _saveAndLoad(WidgetTester tester, AppDatabase db) async {
  await tester.tap(find.widgetWithText(FilledButton, 'Add EMI'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  final emis = await tester.runAsync(() => EmiRepositoryImpl(db).getActiveEmis());
  expect(emis, hasLength(1), reason: 'the EMI should have been saved');
  return emis!.single;
}

void main() {
  testWidgets(
    'Split a total: amount + interest-free + charges become one EMI',
    (tester) async {
      final db = await _openForm(tester);

      await _fill(tester, 'What did you buy?', 'Laptop');
      await _fill(tester, 'Card or bank', 'HDFC');
      await _fill(tester, 'Purchase amount', '12000');
      await _fill(tester, 'Number of months', '12');
      // Optional details stay folded away until asked for.
      expect(find.widgetWithText(TextFormField, 'Charges and fees (optional)'), findsNothing);
      await _openMore(tester);
      await _fill(tester, 'Charges and fees (optional)', '600');

      // (12000 + 600) / 12
      expect(find.textContaining('1,050'), findsWidgets);
      expect(find.textContaining('× 12 months'), findsOneWidget);

      final emi = await _saveAndLoad(tester, db);
      expect(emi.planMode, 'split');
      expect(emi.kind, 'card');
      expect(emi.principal, 12000);
      expect(emi.charges, 600);
      expect(emi.totalAmount, 12600);
      expect(emi.monthlyInstallment, 1050);
      expect(emi.totalTenureMonths, 12);

      await closeTestDb(tester, db);
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  testWidgets(
    'I know the EMI: typed EMI is kept exactly, charges stay separate',
    (tester) async {
      final db = await _openForm(tester);

      await tester.tap(find.text('I know the EMI'));
      await tester.pump();

      await _fill(tester, 'What did you buy?', 'Phone');
      await _fill(tester, 'Card or bank', 'ICICI');
      await _fill(tester, 'Monthly EMI', '9500');
      await _fill(tester, 'Number of months', '12');
      await _openMore(tester);
      await _fill(tester, 'Purchase amount (optional)', '100000');
      await _fill(tester, 'Charges and fees (optional)', '1000');

      expect(find.textContaining('Effective interest'), findsOneWidget);
      expect(find.textContaining('Total cost with charges'), findsOneWidget);

      final emi = await _saveAndLoad(tester, db);
      expect(emi.planMode, 'emi');
      expect(emi.monthlyInstallment, 9500);
      expect(emi.totalAmount, 114000); // installments only; charges separate
      expect(emi.principal, 100000);
      expect(emi.charges, 1000);

      await closeTestDb(tester, db);
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  testWidgets(
    'Editing and saving without changes does not change the amounts',
    (tester) async {
      // Regression: the old form re-added interest to the stored total on
      // every edit, inflating the EMI each time it was opened.
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(900, 6000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final db = AppDatabase(NativeDatabase.memory());
      final repo = EmiRepositoryImpl(db);
      final now = DateTime.now();
      await tester.runAsync(() => repo.createEmi(CreditCardEmi(
            id: 'e1',
            personId: 'self_person_me',
            itemName: 'Laptop',
            cardName: 'HDFC',
            totalAmount: 106619,
            monthlyInstallment: 8884.92,
            totalTenureMonths: 12,
            startDate: DateTime(now.year, now.month + 1, 5),
            dueDayOfMonth: 5,
            interestRate: 12,
            kind: 'card',
            planMode: 'split',
            principal: 100000,
            charges: 0,
            createdAt: now,
            updatedAt: now,
          )));
      final original = (await tester.runAsync(() => repo.getEmiById('e1')))!;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => AddEditEmiScreen.show(context, emi: original),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final after = (await tester.runAsync(() => repo.getEmiById('e1')))!;
      expect(after.principal, 100000);
      expect(after.totalAmount, closeTo(106619, 2));
      expect(after.monthlyInstallment, closeTo(8884.92, 0.1));

      await closeTestDb(tester, db);
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );
}
