import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:duemate/core/constants/app_constants.dart';
import 'package:duemate/core/theme/app_theme.dart';
import 'package:duemate/data/database/app_database.dart' hide Person, Transaction;
import 'package:duemate/data/database/tables.dart';
import 'package:duemate/data/providers/app_providers.dart';
import 'package:duemate/data/repositories/expense_repository_impl.dart';
import 'package:duemate/data/repositories/person_repository_impl.dart';
import 'package:duemate/data/repositories/transaction_repository_impl.dart';
import 'package:duemate/domain/entities/ledger_transaction.dart';
import 'package:duemate/domain/entities/person.dart';
import 'package:duemate/domain/entities/personal_expense.dart';
import 'package:duemate/main.dart';

import 'helpers/test_db.dart';

/// Every main screen, with data, against Flutter's accessibility guidelines:
/// tap targets big enough (48dp) and every tap target labelled for screen
/// readers, in both themes. Text contrast is checked on the theme's colour
/// pairs instead: Flutter's screen-sampling contrast check misreads test
/// renders (text is drawn as solid blocks) and reports false failures.
void main() {
  double contrast(Color a, Color b) {
    final (x, y) = (a.computeLuminance(), b.computeLuminance());
    return (x > y ? x + 0.05 : y + 0.05) / (x > y ? y + 0.05 : x + 0.05);
  }

  for (final (name, theme) in [('light', AppTheme.light()), ('dark', AppTheme.dark())]) {
    test('Text colours are readable on their backgrounds ($name)', () {
      final cs = theme.colorScheme;
      final ledger = theme.extension<LedgerColors>()!;
      final surfaces = {
        'surface': cs.surface,
        'surfaceContainerLow': cs.surfaceContainerLow,
        'surfaceContainer': cs.surfaceContainer,
        'surfaceContainerHigh': cs.surfaceContainerHigh,
      };
      final texts = {
        'onSurface': cs.onSurface,
        'onSurfaceVariant': cs.onSurfaceVariant,
        'primary': cs.primary,
        'tertiary': cs.tertiary,
        'error': cs.error,
        'owedToYou': ledger.owedToYou,
        'youOwe': ledger.youOwe,
        'cashOut': ledger.cashOut,
        'settled': ledger.settled,
      };
      final pairs = [
        for (final t in texts.entries)
          for (final s in surfaces.entries) ('${t.key} on ${s.key}', t.value, s.value),
        ('onPrimary on primary', cs.onPrimary, cs.primary),
        ('onPrimaryContainer on primaryContainer', cs.onPrimaryContainer, cs.primaryContainer),
        ('onSecondaryContainer on secondaryContainer', cs.onSecondaryContainer, cs.secondaryContainer),
        ('onTertiaryContainer on tertiaryContainer', cs.onTertiaryContainer, cs.tertiaryContainer),
        ('onErrorContainer on errorContainer', cs.onErrorContainer, cs.errorContainer),
      ];
      final failures = [
        for (final (label, fg, bg) in pairs)
          if (contrast(fg, bg) < 4.5) '$label: ${contrast(fg, bg).toStringAsFixed(2)}',
      ];
      expect(failures, isEmpty, reason: 'WCAG AA needs 4.5:1 for body text');
    });
  }

  Future<AppDatabase> seed(WidgetTester tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    final now = DateTime.now();
    await tester.runAsync(() async {
      await PersonRepositoryImpl(db)
          .createPerson(Person(id: 'p1', name: 'Asha', phone: '9876543210', createdAt: now, updatedAt: now));
      final txs = TransactionRepositoryImpl(db);
      LedgerTransaction tx(String id, TransactionType type, double amount) => LedgerTransaction(
            id: id,
            personId: 'p1',
            type: type,
            amount: amount,
            transactionDate: now,
            paymentMethod: PaymentMethod.upi,
            createdAt: now,
            updatedAt: now,
          );
      await txs.addTransaction(tx('t1', TransactionType.moneyGiven, 5000));
      await txs.addTransaction(tx('t2', TransactionType.paymentReceived, 1500));
      await ExpenseRepositoryImpl(db).createExpense(PersonalExpense(
        id: 'e1',
        title: 'Groceries',
        amount: 850,
        category: ExpenseCategory.values.first,
        expenseDate: now,
        paymentMethod: PaymentMethod.cash,
        createdAt: now,
        updatedAt: now,
      ));
    });
    return db;
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
  }

  Future<void> checkGuidelines(WidgetTester tester, String screen) async {
    for (final (name, guideline) in [
      ('tap target size', androidTapTargetGuideline),
      ('labelled tap targets', labeledTapTargetGuideline),
    ]) {
      final result = await guideline.evaluate(tester);
      expect(result.passed, isTrue, reason: '$screen — $name:\n${result.reason}');
    }
  }

  for (final dark in [false, true]) {
    testWidgets('Main screens meet accessibility guidelines (${dark ? 'dark' : 'light'})', (tester) async {
      SharedPreferences.setMockInitialValues({
        'duemate_last_run_version': AppConstants.appVersionString,
        'duemate_theme_mode': dark ? 'dark' : 'light',
      });
      final handle = tester.ensureSemantics();
      final db = await seed(tester);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: const DueMateApp(),
        ),
      );
      await settle(tester);
      await checkGuidelines(tester, 'Home');

      for (final tab in ['People', 'Expenses', 'Activity']) {
        await tester.tap(find.byTooltip(tab));
        await settle(tester);
        await checkGuidelines(tester, tab);
      }

      await tester.tap(find.byTooltip('People'));
      await settle(tester);
      await tester.tap(find.text('Asha'));
      await settle(tester);
      await checkGuidelines(tester, 'Person');

      Future<void> back() async {
        await tester.binding.handlePopRoute();
        await settle(tester);
      }

      await back();
      await tester.tap(find.byTooltip('Home'));
      await settle(tester);
      for (final sheet in ['Give', 'Expense']) {
        await tester.tap(find.widgetWithText(FilledButton, sheet));
        await settle(tester);
        await checkGuidelines(tester, '$sheet sheet');
        await back();
      }

      await tester.tap(find.byTooltip('Settings'));
      await settle(tester);
      await checkGuidelines(tester, 'Settings');
      await back();

      await tester.tap(find.byTooltip('Expenses'));
      await settle(tester);
      await tester.tap(find.byTooltip('Trends and categories'));
      await settle(tester);
      await checkGuidelines(tester, 'Spending trends');
      await back();

      handle.dispose();
      await closeTestDb(tester, db);
    }, timeout: const Timeout(Duration(seconds: 60)));
  }

  testWidgets('Amounts tell screen readers which way the money moves', (tester) async {
    SharedPreferences.setMockInitialValues({
      'duemate_last_run_version': AppConstants.appVersionString,
    });
    final handle = tester.ensureSemantics();
    final db = await seed(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const DueMateApp(),
      ),
    );
    await settle(tester);

    await tester.tap(find.byTooltip('Activity'));
    await settle(tester);
    expect(find.bySemanticsLabel(RegExp(r'received ₹1,500')), findsWidgets);
    expect(find.bySemanticsLabel(RegExp(r'given ₹5,000')), findsWidgets);

    await tester.tap(find.byTooltip('Expenses'));
    await settle(tester);
    expect(find.bySemanticsLabel(RegExp(r'spent ₹850')), findsWidgets);

    handle.dispose();
    await closeTestDb(tester, db);
  }, timeout: const Timeout(Duration(seconds: 60)));
}
