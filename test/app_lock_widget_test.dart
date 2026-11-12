import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:duemate/core/constants/app_constants.dart';
import 'package:duemate/core/navigation/app_router.dart';
import 'package:duemate/core/services/app_lock_service.dart';
import 'package:duemate/data/database/app_database.dart';
import 'package:duemate/data/providers/app_providers.dart';
import 'package:duemate/main.dart';

import 'helpers/fake_app_lock_service.dart';

void main() {
  testWidgets('App Lock: locked on cold start, back does not pop hidden pages, unlock reveals them',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'duemate_last_run_version': AppConstants.appVersionString,
      AppLockSettingsNotifier.enabledKey: true,
    });
    final prefs = await SharedPreferences.getInstance();
    final service = FakeAppLockService()..next = AppLockAuthResult.cancelled;
    final db = AppDatabase(NativeDatabase.memory());

    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        sharedPreferencesProvider.overrideWithValue(prefs),
        appLockServiceProvider.overrideWithValue(service),
      ],
      child: const DueMateApp(),
    ));
    await tester.pump();

    // Locked from the very first frame, and the prompt was shown by itself.
    expect(find.text('DueMate is locked'), findsOneWidget);
    expect(service.prompts, 1);
    // The ledger behind is not exposed to accessibility services.
    expect(find.bySemanticsLabel('Home'), findsNothing);

    // Cancelled: still locked, no error message (the user chose to cancel).
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('DueMate is locked'), findsOneWidget);
    expect(find.text('Unlock'), findsOneWidget);

    // Open a page behind the lock, then press back: it must stay open.
    final router = ProviderScope.containerOf(tester.element(find.byType(DueMateApp))).read(appRouterProvider);
    router.push('/settings');
    await tester.pump(const Duration(milliseconds: 500));
    String location() => router.routerDelegate.currentConfiguration.last.matchedLocation;
    final settingsTitle = find.widgetWithText(AppBar, 'Settings');
    expect(location(), '/settings');
    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(milliseconds: 500));
    expect(location(), '/settings', reason: 'back while locked must not pop the page behind');

    // A lockout explains itself.
    service.next = AppLockAuthResult.lockedOut;
    await tester.tap(find.text('Unlock'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('Too many attempts'), findsOneWidget);

    service.next = AppLockAuthResult.success;
    await tester.tap(find.text('Unlock'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('DueMate is locked'), findsNothing);
    expect(settingsTitle, findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
    await tester.runAsync(() => db.close());
  }, timeout: const Timeout(Duration(seconds: 30)));
}
