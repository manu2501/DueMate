import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:duemate/core/constants/app_constants.dart';
import 'package:duemate/core/navigation/app_router.dart';
import 'package:duemate/data/database/app_database.dart';
import 'package:duemate/data/providers/app_providers.dart';
import 'package:duemate/main.dart';

import 'helpers/test_db.dart';

void main() {
  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  /// The app on Settings, scrolled to About.
  Future<(AppDatabase, ProviderContainer)> openSettings(WidgetTester tester, Map<String, Object> prefs) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({'duemate_last_run_version': AppConstants.appVersionString, ...prefs});
    final db = AppDatabase(NativeDatabase.memory());
    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const DueMateApp(),
    ));
    await settle(tester);
    final container = ProviderScope.containerOf(tester.element(find.byType(DueMateApp)));
    container.read(appRouterProvider).push('/settings');
    await settle(tester);
    await tester.scrollUntilVisible(find.text("What's new"), 300, scrollable: find.byType(Scrollable).first);
    await settle(tester);
    return (db, container);
  }

  testWidgets('Settings shows the version; What\'s new lists releases and clears the New badge', (tester) async {
    final (db, container) = await openSettings(tester, {'duemate_seen_release': '1.0.0'});

    expect(find.text(AppConstants.appVersionLabel), findsOneWidget);
    expect(find.text('New'), findsOneWidget, reason: 'updated since the notes were last seen');

    await tester.tap(find.text("What's new"));
    await settle(tester);
    expect(find.text('Version ${AppConstants.appVersion} · installed'), findsOneWidget);
    expect(find.text('Improved'), findsWidgets);
    expect(container.read(seenReleaseProvider), AppConstants.appVersion);

    container.read(appRouterProvider).pop();
    await settle(tester);
    expect(find.text('New'), findsNothing);
    final prefs = await tester.runAsync(SharedPreferences.getInstance);
    expect(prefs!.getString('duemate_seen_release'), AppConstants.appVersion);

    await closeTestDb(tester, db);
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('no badge once this version\'s notes have been seen', (tester) async {
    final (db, _) = await openSettings(tester, {'duemate_seen_release': AppConstants.appVersion});
    expect(find.text("What's new"), findsOneWidget);
    expect(find.text('New'), findsNothing);
    await closeTestDb(tester, db);
  }, timeout: const Timeout(Duration(seconds: 30)));
}
