import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:duemate/core/constants/app_constants.dart';
import 'package:duemate/core/utils/display_money.dart';
import 'package:duemate/data/database/app_database.dart' hide Person, Transaction;
import 'package:duemate/data/database/tables.dart';
import 'package:duemate/data/providers/app_providers.dart';
import 'package:duemate/data/repositories/person_repository_impl.dart';
import 'package:duemate/data/repositories/transaction_repository_impl.dart';
import 'package:duemate/domain/entities/ledger_transaction.dart';
import 'package:duemate/domain/entities/person.dart';
import 'package:duemate/main.dart';

void main() {
  group('DisplayMoney', () {
    test('shows the amount when not hidden', () {
      const m = DisplayMoney(symbol: '₹', hidden: false);
      expect(m(1500), '₹1,500');
    });

    test('masks every amount the same way when hidden', () {
      const m = DisplayMoney(symbol: '₹', hidden: true);
      expect(m(5), m(1234567));
      expect(m(5), contains(DisplayMoney.mask));
      expect(m.compact(250000), contains(DisplayMoney.mask));
    });
  });

  testWidgets(
    'Hide amounts on Home masks balances app-wide and is remembered',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'duemate_last_run_version': AppConstants.appVersionString,
      });
      final db = AppDatabase(NativeDatabase.memory());
      final now = DateTime.now();
      await tester.runAsync(() async {
        await PersonRepositoryImpl(db)
            .createPerson(Person(id: 'p1', name: 'Asha', createdAt: now, updatedAt: now));
        await TransactionRepositoryImpl(db).addTransaction(LedgerTransaction(
          id: 't1',
          personId: 'p1',
          type: TransactionType.moneyGiven,
          amount: 500,
          transactionDate: now,
          paymentMethod: PaymentMethod.cash,
          createdAt: now,
          updatedAt: now,
        ));
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: const DueMateApp(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.textContaining('500'), findsWidgets, reason: 'balance visible before hiding');

      await tester.tap(find.byTooltip('Hide amounts'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('500'), findsNothing, reason: 'no amount on Home once hidden');
      expect(find.textContaining(DisplayMoney.mask), findsWidgets);
      final prefs = await tester.runAsync(SharedPreferences.getInstance);
      expect(prefs!.getBool('duemate_hide_balances'), isTrue);

      // Other screens follow the same setting.
      await tester.tap(find.byTooltip('People'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Asha'), findsOneWidget);
      expect(find.textContaining('500'), findsNothing, reason: 'People hides balances too');

      // And back.
      await tester.tap(find.byTooltip('Home'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.byTooltip('Show amounts'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('500'), findsWidgets);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
      await tester.runAsync(() => db.close());
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );
}
