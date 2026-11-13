import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:duemate/core/services/emi_processor_service.dart';
import 'package:duemate/core/theme/app_theme.dart';
import 'package:duemate/data/database/app_database.dart' hide Person, CreditCardEmi;
import 'package:duemate/data/providers/app_providers.dart';
import 'package:duemate/data/repositories/emi_repository_impl.dart';
import 'package:duemate/data/repositories/person_repository_impl.dart';
import 'package:duemate/data/repositories/transaction_repository_impl.dart';
import 'package:duemate/domain/entities/credit_card_emi.dart';
import 'package:duemate/domain/entities/person.dart';
import 'package:duemate/features/emis/presentation/widgets/emi_details_sheet.dart';
import 'helpers/test_db.dart';

void main() {
  testWidgets('Delete asks first, says what goes, and removes the EMI with its ledger entries', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final db = AppDatabase(NativeDatabase.memory());
    final t = DateTime(2026, 7, 1);
    final asha = Person(id: 'p1', name: 'Asha Rao', createdAt: t, updatedAt: t);
    final emi = CreditCardEmi(
      id: 'e1',
      personId: 'p1',
      itemName: 'Laptop',
      cardName: 'ICICI',
      totalAmount: 6000,
      monthlyInstallment: 1000,
      totalTenureMonths: 6,
      startDate: DateTime(2026, 7, 5),
      dueDayOfMonth: 5,
      createdAt: t,
      updatedAt: t,
    );
    await tester.runAsync(() async {
      await PersonRepositoryImpl(db).createPerson(asha);
      final emis = EmiRepositoryImpl(db);
      await emis.createEmi(emi);
      // Two installments posted to Asha's ledger.
      await EmiProcessorService(emiRepository: emis, transactionRepository: TransactionRepositoryImpl(db), database: db)
          .processDueInstallments(referenceDate: DateTime(2026, 8, 10));
    });

    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => EmiDetailsSheet.show(context, emi: emi, person: asha),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    Future<void> settle() async {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
    }

    Future<void> tapDelete() async {
      // The sheet's list builds lazily: scroll down to the button.
      final delete = find.text('Delete');
      await tester.scrollUntilVisible(delete, 300, scrollable: find.byType(Scrollable).last);
      await tester.tap(delete);
      await settle();
    }

    Future<(int, int)> rows() async => (await tester.runAsync(() async => (
          (await db.select(db.creditCardEmis).get()).length,
          (await db.select(db.transactions).get()).length,
        )))!;

    await tester.tap(find.text('open'));
    await settle();

    // Cancel keeps everything.
    await tapDelete();
    expect(find.text('Delete Laptop?'), findsOneWidget);
    expect(find.textContaining("its 2 payments in Asha's ledger (₹2,000) are deleted"), findsOneWidget);
    expect(find.textContaining("Asha's balance changes to match. This can't be undone."), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await settle();
    expect(await rows(), (1, 2));

    // Confirm removes the EMI and both ledger entries.
    await tapDelete();
    await tester.tap(find.text('Delete EMI'));
    await settle();
    expect(await rows(), (0, 0));
    expect(find.text('Laptop deleted'), findsOneWidget);

    await closeTestDb(tester, db);
  }, timeout: const Timeout(Duration(seconds: 30)));
}
