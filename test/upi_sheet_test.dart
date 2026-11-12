import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:duemate/core/theme/app_theme.dart';
import 'package:duemate/core/widgets/ledger_entry_sheet.dart';
import 'package:duemate/core/widgets/upi_widgets.dart';
import 'package:duemate/data/database/app_database.dart' hide Person;
import 'package:duemate/data/database/tables.dart';
import 'package:duemate/data/providers/app_providers.dart';
import 'package:duemate/data/repositories/person_repository_impl.dart';
import 'package:duemate/domain/entities/person.dart';
import 'helpers/fake_app_lock_service.dart';
import 'helpers/test_db.dart';

/// Opens the Give/Receive sheet for [personId] in a bare app.
Future<AppDatabase> _openSheet(
  WidgetTester tester, {
  required TransactionType type,
  required String personId,
  Map<String, Object> prefs = const {},
  List<Override> overrides = const [],
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final db = AppDatabase(NativeDatabase.memory());
  final now = DateTime(2026, 11, 1);
  await tester.runAsync(() async {
    final people = PersonRepositoryImpl(db);
    await people.createPerson(Person(id: 'ravi', name: 'Ravi', upiId: 'ravi@ybl', createdAt: now, updatedAt: now));
    await people.createPerson(Person(id: 'asha', name: 'Asha', createdAt: now, updatedAt: now));
  });

  await tester.pumpWidget(ProviderScope(
    overrides: [databaseProvider.overrideWithValue(db), ...overrides],
    child: MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () => LedgerEntrySheet.show(context, type: type, personId: personId),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  ));
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(find.text('open'));
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
  expect(find.text('Choose a person'), findsNothing, reason: 'person loaded');
  return db;
}

void main() {
  testWidgets('Receive: without a UPI ID it asks for one, then shows a QR with the amount', (tester) async {
    final db = await _openSheet(tester, type: TransactionType.paymentReceived, personId: 'asha');

    await tester.enterText(find.byType(TextField).first, '1500');
    await tester.pump();
    final qrButton = find.text('Show UPI QR for ₹1,500');
    await tester.ensureVisible(qrButton);
    await tester.tap(qrButton);
    await tester.pump(const Duration(milliseconds: 500));

    // No UPI ID yet: the dialog asks for it and rejects a bad one.
    expect(find.text('Your UPI ID'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextFormField, 'UPI ID'), 'not-an-id');
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.textContaining('Check the UPI ID'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'UPI ID'), 'Me@OKSBI');
    await tester.enterText(find.widgetWithText(TextFormField, 'Name (optional)'), 'Manoj');
    await tester.tap(find.text('Save'));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Scan to pay'), findsOneWidget);
    expect(find.text('₹1,500'), findsOneWidget);
    expect(find.text('me@oksbi'), findsOneWidget);
    final qr = tester.widget<QrImageView>(find.byType(QrImageView));
    expect(qr.semanticsLabel, contains('me@oksbi'));

    final prefs = await tester.runAsync(SharedPreferences.getInstance);
    expect(prefs!.getString('duemate_upi_id'), 'me@oksbi');

    await closeTestDb(tester, db);
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('Give: "Pay with UPI app" only for people with a UPI ID', (tester) async {
    var db = await _openSheet(tester, type: TransactionType.moneyGiven, personId: 'ravi');
    expect(find.text('Pay with UPI app'), findsOneWidget);
    await closeTestDb(tester, db);

    db = await _openSheet(tester, type: TransactionType.moneyGiven, personId: 'asha');
    expect(find.text('Pay with UPI app'), findsNothing);
    await closeTestDb(tester, db);
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('No UPI actions when the currency is not rupees', (tester) async {
    var db = await _openSheet(tester,
        type: TransactionType.paymentReceived, personId: 'asha', prefs: {'duemate_currency_symbol': '\$'});
    expect(find.textContaining('UPI '), findsNothing);
    await closeTestDb(tester, db);

    db = await _openSheet(tester,
        type: TransactionType.moneyGiven, personId: 'ravi', prefs: {'duemate_currency_symbol': '\$'});
    expect(find.textContaining('UPI '), findsNothing);
    await closeTestDb(tester, db);
  }, timeout: const Timeout(Duration(seconds: 30)));

  group('After "Pay with UPI app"', () {
    late List<Uri> launched;
    late bool launchOpens;
    Override launcher() => upiLauncherProvider.overrideWithValue((uri) async {
          launched.add(uri);
          return launchOpens;
        });

    setUp(() {
      launched = [];
      launchOpens = true;
    });

    Future<void> payAndLeave(WidgetTester tester) async {
      await tester.enterText(find.byType(TextField).first, '2000');
      await tester.pump();
      final pay = find.text('Pay ₹2,000 with UPI app');
      await tester.ensureVisible(pay);
      await tester.tap(pay);
      await tester.pump();
      // The UPI app comes to the front.
      for (final s in [AppLifecycleState.inactive, AppLifecycleState.hidden, AppLifecycleState.paused]) {
        tester.binding.handleAppLifecycleStateChanged(s);
      }
      await tester.pump();
    }

    Future<void> comeBack(WidgetTester tester) async {
      for (final s in [AppLifecycleState.hidden, AppLifecycleState.inactive, AppLifecycleState.resumed]) {
        tester.binding.handleAppLifecycleStateChanged(s);
      }
      await tester.pump(const Duration(milliseconds: 300));
    }

    Future<List<String>> ravisEntries(WidgetTester tester, AppDatabase db) async {
      final rows = await tester.runAsync(() => db.select(db.transactions).get());
      return [for (final t in rows!) '${t.personId} ${t.type.name} ${t.amount} ${t.paymentMethod.name}'];
    }

    testWidgets('asks on return; "Yes" records the Give as UPI', (tester) async {
      final db = await _openSheet(tester, type: TransactionType.moneyGiven, personId: 'ravi', overrides: [launcher()]);
      await payAndLeave(tester);
      expect(launched.single.queryParameters, containsPair('pa', 'ravi@ybl'));
      expect(launched.single.queryParameters, containsPair('am', '2000.00'));
      expect(find.text('Did the payment go through?'), findsNothing, reason: 'not while away');

      await comeBack(tester);
      expect(find.text('Did the payment go through?'), findsOneWidget);
      expect(find.textContaining('₹2,000 sent to Ravi'), findsOneWidget);

      await tester.tap(find.text('Yes, record it'));
      await tester.pump(const Duration(milliseconds: 600));
      expect(await ravisEntries(tester, db), ['ravi moneyGiven 2000.0 upi']);
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(find.text('Give money'), findsNothing, reason: 'sheet closed after saving');

      await closeTestDb(tester, db);
    }, timeout: const Timeout(Duration(seconds: 30)));

    testWidgets('"Not yet" records nothing, keeps the sheet, and asks only once', (tester) async {
      final db = await _openSheet(tester, type: TransactionType.moneyGiven, personId: 'ravi', overrides: [launcher()]);
      await payAndLeave(tester);
      await comeBack(tester);
      await tester.tap(find.text('Not yet'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(await ravisEntries(tester, db), isEmpty);
      expect(find.text('Give money'), findsOneWidget);

      // Leaving and coming back again doesn't nag.
      for (final s in [AppLifecycleState.inactive, AppLifecycleState.hidden, AppLifecycleState.paused]) {
        tester.binding.handleAppLifecycleStateChanged(s);
      }
      await comeBack(tester);
      expect(find.text('Did the payment go through?'), findsNothing);

      await closeTestDb(tester, db);
    }, timeout: const Timeout(Duration(seconds: 30)));

    testWidgets('no UPI app: says so and never asks', (tester) async {
      launchOpens = false;
      final db = await _openSheet(tester, type: TransactionType.moneyGiven, personId: 'ravi', overrides: [launcher()]);
      await payAndLeave(tester);
      expect(find.text('No UPI app found on this phone.'), findsOneWidget);
      await comeBack(tester);
      expect(find.text('Did the payment go through?'), findsNothing);
      await closeTestDb(tester, db);
    }, timeout: const Timeout(Duration(seconds: 30)));

    testWidgets('if App Lock is up on return, asks only after unlocking', (tester) async {
      SharedPreferences.setMockInitialValues({AppLockSettingsNotifier.enabledKey: true});
      final prefs = await SharedPreferences.getInstance();
      final lock = FakeAppLockService();
      final db = await _openSheet(
        tester,
        type: TransactionType.moneyGiven,
        personId: 'ravi',
        prefs: {AppLockSettingsNotifier.enabledKey: true},
        overrides: [
          launcher(),
          sharedPreferencesProvider.overrideWithValue(prefs),
          appLockServiceProvider.overrideWithValue(lock),
        ],
      );
      final container = ProviderScope.containerOf(tester.element(find.text('Give money')));
      await tester.runAsync(() => container.read(appLockControllerProvider.notifier).unlock());
      await tester.pump();

      await payAndLeave(tester);
      container.read(appLockControllerProvider.notifier).lockNow(); // as on return with "Immediately"
      await comeBack(tester);
      expect(find.text('Did the payment go through?'), findsNothing, reason: 'not over the lock screen');

      await tester.runAsync(() => container.read(appLockControllerProvider.notifier).unlock());
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Did the payment go through?'), findsOneWidget);

      await closeTestDb(tester, db);
    }, timeout: const Timeout(Duration(seconds: 30)));
  });
}
