import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smarava/core/constants/app_constants.dart';
import 'package:smarava/core/utils/permission_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PermissionManager Startup & Update Tests', () {
    testWidgets('Renders permissions rationale sheet on initial start', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => PermissionManager.showPermissionsSheet(context, isUpdate: false),
                  child: const Text('Open Sheet'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      // Verify sheet UI components
      expect(find.text('Permissions Needed'), findsOneWidget);
      expect(find.text('Device Contacts'), findsOneWidget);
      expect(find.text('Payment Reminders'), findsOneWidget);
      expect(find.text('Allow Permissions'), findsOneWidget);
      expect(find.text('Skip for Now'), findsOneWidget);

      // Tap "Skip for Now" to dismiss
      await tester.tap(find.text('Skip for Now'));
      await tester.pumpAndSettle();

      expect(find.text('Permissions Needed'), findsNothing);
    });

    testWidgets('Renders update-specific messaging when app is updated', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => PermissionManager.showPermissionsSheet(context, isUpdate: true),
                  child: const Text('Open Update Sheet'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Update Sheet'));
      await tester.pumpAndSettle();

      expect(find.text('App Updated: Permissions Check'), findsOneWidget);
      expect(
        find.textContaining('DueMate was updated! Please allow the required permissions below'),
        findsOneWidget,
      );
      expect(find.text('Allow Permissions'), findsOneWidget);
    });

    test('Detects first launch and updates last run version', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      expect(prefs.getString('duemate_last_run_version'), isNull);

      // Simulate first run
      final currentVersion = AppConstants.appVersionString;
      await prefs.setString('duemate_last_run_version', currentVersion);

      expect(prefs.getString('duemate_last_run_version'), equals(currentVersion));
    });

    test('Detects app update when last run version differs from current version', () async {
      SharedPreferences.setMockInitialValues({
        'duemate_last_run_version': 'v0.9.0+1',
      });
      final prefs = await SharedPreferences.getInstance();

      final previousVersion = prefs.getString('duemate_last_run_version');
      final currentVersion = AppConstants.appVersionString;

      final isAppUpdate = previousVersion != null && previousVersion != currentVersion;
      expect(isAppUpdate, isTrue);

      // After update flow finishes
      await prefs.setString('duemate_last_run_version', currentVersion);
      expect(prefs.getString('duemate_last_run_version'), equals(currentVersion));
    });

    test('Does not flag update when last run version matches current version', () async {
      final currentVersion = AppConstants.appVersionString;
      SharedPreferences.setMockInitialValues({
        'duemate_last_run_version': currentVersion,
      });
      final prefs = await SharedPreferences.getInstance();

      final previousVersion = prefs.getString('duemate_last_run_version');
      final isFirstLaunch = previousVersion == null;
      final isAppUpdate = previousVersion != null && previousVersion != currentVersion;

      expect(isFirstLaunch, isFalse);
      expect(isAppUpdate, isFalse);
    });
  });
}

