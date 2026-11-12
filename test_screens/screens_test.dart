// Renders every main screen to PNG so the UI can be reviewed without a device.
//
//   flutter test test_screens --update-goldens
//
// Output: test_screens/out/<name>.png (git-ignored). Not part of `flutter test`
// (which only runs test/), and it never fails on pixel diffs; it only writes.
//
// README screenshots (committed, half resolution, docs/screenshots/):
//   flutter test test_screens/screens_test.dart --update-goldens --dart-define=DOCS=true
// ignore_for_file: invalid_use_of_visible_for_testing_member
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:duemate/core/constants/app_constants.dart';
import 'package:duemate/core/navigation/app_router.dart';
import 'package:duemate/data/database/app_database.dart' hide Person, CreditCardEmi, Transaction, RecurringExpense;
import 'package:duemate/data/database/tables.dart';
import 'package:duemate/data/providers/app_providers.dart';
import 'package:duemate/core/services/app_lock_service.dart';
import 'package:duemate/core/widgets/upi_widgets.dart';
import 'package:duemate/data/repositories/emi_repository_impl.dart';
import 'package:duemate/data/repositories/expense_repository_impl.dart';
import 'package:duemate/data/repositories/recurring_expense_repository_impl.dart';
import 'package:duemate/domain/entities/recurring_expense.dart';
import 'package:duemate/features/expenses/presentation/widgets/recurring_expense_sheet.dart';
import 'package:duemate/data/repositories/person_repository_impl.dart';
import 'package:duemate/data/repositories/transaction_repository_impl.dart';
import 'package:duemate/domain/entities/credit_card_emi.dart';
import 'package:duemate/domain/entities/ledger_transaction.dart';
import 'package:duemate/domain/entities/person.dart';

import '../test/helpers/fake_app_lock_service.dart';
import 'package:duemate/domain/entities/personal_expense.dart';
import 'package:duemate/main.dart';

/// Real Roboto + Material Icons from the Flutter SDK (FLUTTER_ROOT is set
/// by `flutter test`).
final _fontDir =
    '${Platform.environment['FLUTTER_ROOT'] ?? 'C:/flutter'}/bin/cache/artifacts/material_fonts/';

/// `--dart-define=DOCS=true` renders the committed README screenshots:
/// half resolution, written to docs/screenshots/.
const _docs = bool.fromEnvironment('DOCS');

Future<void> _loadFonts() async {
  Future<ByteData> f(String name) async =>
      ByteData.sublistView(await File('$_fontDir$name').readAsBytes());
  final roboto = FontLoader('Roboto');
  for (final w in ['regular', 'medium', 'bold', 'light']) {
    roboto.addFont(f('roboto-$w.ttf'));
  }
  await roboto.load();
  await (FontLoader('MaterialIcons')..addFont(f('materialicons-regular.otf'))).load();
}

Future<void> _seed(AppDatabase db) async {
  final people = PersonRepositoryImpl(db);
  final tx = TransactionRepositoryImpl(db);
  final emis = EmiRepositoryImpl(db);
  final expenses = ExpenseRepositoryImpl(db);
  final now = DateTime.now();
  DateTime ago(int days) => now.subtract(Duration(days: days));

  Person p(String id, String name, String? phone, int days) =>
      Person(
        id: id,
        name: name,
        phone: phone,
        upiId: id == 'rahul' ? 'rahul.sharma@okhdfcbank' : null,
        createdAt: ago(days),
        updatedAt: ago(days),
      );
  for (final person in [
    p('rahul', 'Rahul Sharma', '+91 98765 43210', 90),
    p('priya', 'Priya Nair', '+91 91234 56780', 60),
    p('arjun', 'Arjun Mehta', null, 40),
    p('meera', 'Meera Iyer', '+91 99887 76655', 20),
  ]) {
    await people.createPerson(person);
  }

  var n = 0;
  Future<void> t(String person, TransactionType type, double amount, int days, String note,
      [PaymentMethod m = PaymentMethod.upi]) async {
    await tx.addTransaction(LedgerTransaction(
      id: 't${n++}',
      personId: person,
      type: type,
      amount: amount,
      transactionDate: ago(days),
      paymentMethod: m,
      note: note,
      createdAt: ago(days),
      updatedAt: ago(days),
    ));
  }

  const give = TransactionType.moneyGiven;
  const got = TransactionType.paymentReceived;
  await t('rahul', give, 15000, 45, 'Rent advance');
  await t('rahul', got, 2500, 12, 'Part payment');
  await t('priya', got, 3000, 8, 'Concert tickets she paid for', PaymentMethod.cash);
  await t('arjun', give, 1200, 30, 'Dinner split');
  await t('arjun', got, 1200, 25, 'Settled dinner');
  await t('meera', give, 800, 2, 'Cab fare');

  await emis.createEmi(CreditCardEmi(
    id: 'emi-phone',
    personId: AppConstants.selfPersonId,
    itemName: 'iPhone 16',
    cardName: 'HDFC Millennia',
    totalAmount: 79900,
    monthlyInstallment: 6658.33,
    totalTenureMonths: 12,
    installmentsPaid: 3,
    startDate: DateTime(now.year, now.month - 2, 5),
    dueDayOfMonth: 5,
    kind: 'card',
    planMode: 'split',
    principal: 79900,
    createdAt: ago(70),
    updatedAt: ago(70),
  ));
  await emis.createEmi(CreditCardEmi(
    id: 'emi-laptop',
    personId: 'rahul',
    itemName: 'Laptop',
    cardName: 'ICICI Amazon Pay',
    totalAmount: 54000,
    monthlyInstallment: 9000,
    totalTenureMonths: 6,
    installmentsPaid: 1,
    startDate: DateTime(now.year, now.month, 20),
    dueDayOfMonth: 20,
    isPaidByMe: true,
    kind: 'card',
    planMode: 'emi',
    createdAt: ago(40),
    updatedAt: ago(40),
  ));

  var e = 0;
  Future<void> x(String title, double amount, ExpenseCategory c, int days) =>
      expenses.createExpense(PersonalExpense(
        id: 'x${e++}',
        title: title,
        amount: amount,
        category: c,
        expenseDate: DateTime(now.year, now.month, (now.day - days).clamp(1, 28)),
        paymentMethod: PaymentMethod.upi,
        createdAt: now,
        updatedAt: now,
      ));
  await x('Groceries', 2340, ExpenseCategory.groceries, 1);
  await x('Electricity bill', 1890, ExpenseCategory.utilities, 3);
  await x('Petrol', 1500, ExpenseCategory.fuel, 5);
  await x('Dinner out', 1200, ExpenseCategory.food, 6);
  // Rent repeats every month: shows under "Repeats every month".
  final rentDay = DateTime(now.year, now.month, (now.day - 9).clamp(1, 28));
  final rent = RecurringExpense(
    id: 'rent',
    title: 'Rent',
    amount: 18000,
    category: ExpenseCategory.rent,
    paymentMethod: PaymentMethod.bankTransfer,
    dayOfMonth: rentDay.day,
    startDate: rentDay,
    createdAt: now,
    updatedAt: now,
  );
  await RecurringExpenseRepositoryImpl(db).createWithFirst(
    rent,
    PersonalExpense(
      id: 'x-rent',
      title: 'Rent',
      amount: 18000,
      category: ExpenseCategory.rent,
      expenseDate: rentDay,
      paymentMethod: PaymentMethod.bankTransfer,
      createdAt: now,
      updatedAt: now,
    ),
  );
}

void main() {
  setUpAll(_loadFonts);

  for (final dark in [false, true]) {
    final suffix = dark ? '_dark' : '';
    testWidgets('screens$suffix', (tester) async {
      SharedPreferences.setMockInitialValues({
        'duemate_last_run_version': AppConstants.appVersionString,
        'duemate_theme_mode': dark ? 'dark' : 'light',
        'duemate_upi_id': 'arjun.mehta@oksbi',
        'duemate_upi_name': 'Arjun Mehta',
      });
      // Same logical size (≈411×891 dp) either way; docs mode halves the pixels.
      tester.view.physicalSize = _docs ? const Size(540, 1170) : const Size(1080, 2340);
      tester.view.devicePixelRatio = _docs ? 1.3125 : 2.625;
      addTearDown(tester.view.reset);

      final db = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() => _seed(db));

      await tester.pumpWidget(ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          // No biometric prompt in tests: every unlock attempt is "cancelled".
          appLockServiceProvider.overrideWithValue(FakeAppLockService()..next = AppLockAuthResult.cancelled),
          // No UPI app in tests: pretend one opened.
          upiLauncherProvider.overrideWithValue((_) async => true),
        ],
        child: const DueMateApp(),
      ));

      Future<void> settle() async {
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 300));
        }
      }

      Future<void> shot(String name) async {
        await settle();
        final path = _docs ? '../docs/screenshots/$name$suffix.png' : 'out/$name$suffix.png';
        await expectLater(find.byType(MaterialApp), matchesGoldenFile(path));
      }

      final router = ProviderScope.containerOf(tester.element(find.byType(DueMateApp)))
          .read(appRouterProvider);
      Future<void> go(String path) async {
        router.go(path);
        await settle();
      }

      await shot('01_home');
      await go('/people');
      await shot('02_people');
      await go('/people/rahul');
      await shot('03_person');
      await go('/expenses');
      await shot('04_expenses');
      await tester.tap(find.text('Rent').first);
      await shot('21_recurring');
      Navigator.of(tester.element(find.byType(RecurringExpenseSheet))).pop();
      await settle();
      await go('/reports');
      await shot('05_activity');
      await go('/settings');
      await shot('06_settings');
      await go('/add-emi');
      await shot('07_add_emi');
      Future<void> home() async {
        await go('/');
        // Close any sheet left open.
        final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
        nav.popUntil((r) => r.isFirst);
        await settle();
      }

      await home();
      await tester.tap(find.text('Give').first);
      await shot('08_give_sheet');

      await home();
      await tester.tap(find.text('Expense').first);
      await shot('09_expense_sheet');

      await home();
      await go('/expenses?tab=emis');
      await shot('10_expenses_emis');

      await go('/expense-charts');
      await shot('11_charts');
      await go('/lending-trends');
      await shot('20_lending_trends');

      await go('/add-person');
      await shot('12_add_person');

      await home();
      await tester.tap(find.text('iPhone 16').first);
      await shot('13_emi_details');

      await home();
      await go('/people/rahul');
      await tester.tap(find.text('Part payment').first);
      await shot('14_tx_details');

      await home();
      await tester.tap(find.byTooltip('Hide amounts'));
      await shot('15_home_hidden');
      // Showing amounts asks for verification; set it directly here.
      final container = ProviderScope.containerOf(tester.element(find.byType(DueMateApp)));
      await tester.runAsync(() => container.read(hideBalancesProvider.notifier).set(false));
      await settle();

      // UPI: Give to someone with a UPI ID, then your QR from Receive.
      await go('/people/rahul');
      await tester.tap(find.text('Give').first);
      await settle();
      await tester.enterText(find.byType(TextField).first, '2000');
      await shot('17_give_upi');
      // Paid in the UPI app and came back: DueMate asks whether it went through.
      final pay = find.textContaining('with UPI app');
      await tester.ensureVisible(pay);
      await tester.tap(pay);
      await tester.pump();
      for (final s in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(s);
      }
      await shot('19_upi_paid');
      await tester.tap(find.text('Not yet'));
      await settle();
      await home();
      await go('/people/rahul');
      await tester.tap(find.text('Receive').first);
      await settle();
      await tester.enterText(find.byType(TextField).first, '2500');
      await settle();
      final qrButton = find.textContaining('Show UPI QR');
      await tester.ensureVisible(qrButton);
      await tester.tap(qrButton);
      await shot('18_upi_qr');
      await home();

      // App Lock: turned on directly (the switch would prompt), then locked.
      await tester.runAsync(() => container.read(appLockSettingsProvider.notifier).setEnabled(true));
      container.read(appLockControllerProvider.notifier).lockNow();
      await shot('16_app_lock');

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
      await tester.runAsync(() => db.close());
    }, timeout: const Timeout(Duration(seconds: 90)));
  }
}
