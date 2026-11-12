import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:duemate/core/theme/app_theme.dart';
import 'package:duemate/core/widgets/ledger_entry_sheet.dart';
import 'package:duemate/data/database/app_database.dart' hide Person;
import 'package:duemate/data/database/tables.dart';
import 'package:duemate/data/providers/app_providers.dart';
import 'package:duemate/data/repositories/person_repository_impl.dart';
import 'package:duemate/domain/entities/person.dart';
import 'helpers/test_db.dart';

/// Opens the Give/Receive sheet for [personId] in a bare app.
Future<AppDatabase> _openSheet(
  WidgetTester tester, {
  required TransactionType type,
  required String personId,
  Map<String, Object> prefs = const {},
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
    overrides: [databaseProvider.overrideWithValue(db)],
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
}
