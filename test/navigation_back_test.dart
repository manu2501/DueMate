import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:duemate/core/constants/app_constants.dart';
import 'package:duemate/data/database/app_database.dart' hide CreditCardEmi;
import 'package:duemate/data/repositories/emi_repository_impl.dart';
import 'package:duemate/domain/entities/credit_card_emi.dart';
import 'package:duemate/data/providers/app_providers.dart';
import 'package:duemate/features/people/presentation/screens/add_edit_person_screen.dart';
import 'package:duemate/features/people/presentation/screens/people_screen.dart';
import 'package:duemate/main.dart';

void main() {
  testWidgets(
    'System back on a form opened over a tab closes only the form',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'duemate_last_run_version': AppConstants.appVersionString,
      });
      final db = AppDatabase(NativeDatabase.memory());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: const DueMateApp(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.byTooltip('People'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(PeopleScreen), findsOneWidget);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(AddEditPersonScreen), findsOneWidget);

      // Android back press. Before the fix the tab shell swallowed this and
      // jumped to Home while the form stayed on screen ("stuck").
      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(AddEditPersonScreen), findsNothing);
      expect(find.byType(PeopleScreen), findsOneWidget,
          reason: 'back from the form must land on People, not Home');

      // Back on a non-Home tab still returns Home.
      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(PeopleScreen), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
      await tester.runAsync(() => db.close());
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  testWidgets(
    'EMIs & cards on Home opens the EMI view of Expenses',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'duemate_last_run_version': AppConstants.appVersionString,
      });
      final db = AppDatabase(NativeDatabase.memory());
      final now = DateTime.now();
      await tester.runAsync(() => EmiRepositoryImpl(db).createEmi(CreditCardEmi(
            id: 'e1',
            personId: AppConstants.selfPersonId,
            itemName: 'Phone',
            cardName: 'HDFC',
            totalAmount: 1200,
            monthlyInstallment: 100,
            totalTenureMonths: 12,
            startDate: DateTime(now.year, now.month + 1, 5),
            dueDayOfMonth: 5,
            createdAt: now,
            updatedAt: now,
          )));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: const DueMateApp(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('EMIs & cards'), findsOneWidget);
      await tester.tap(find.text('1 active'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Landed on Expenses with the EMI view selected (its FAB adds an EMI).
      expect(find.text('Add EMI or loan'), findsOneWidget);
      expect(find.text('Phone'), findsWidgets);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
      await tester.runAsync(() => db.close());
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );
}
