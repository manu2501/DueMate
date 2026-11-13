import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:duemate/core/services/app_lock_service.dart';
import 'package:duemate/data/providers/app_providers.dart';

import '../helpers/fake_app_lock_service.dart';

/// `local_auth` stand-in: returns [result] or throws [error].
class _FakeLocalAuth implements LocalAuthentication {
  _FakeLocalAuth({this.result = true, this.error});
  final bool result;
  final Object? error;

  @override
  Future<bool> authenticate({
    required String localizedReason,
    Iterable<dynamic> authMessages = const [],
    bool biometricOnly = false,
    bool sensitiveTransaction = true,
    bool persistAcrossBackgrounding = false,
  }) async {
    if (error != null) throw error!;
    return result;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppLockService', () {
    Future<AppLockAuthResult> run({bool result = true, Object? error}) =>
        AppLockService(auth: _FakeLocalAuth(result: result, error: error)).authenticate(reason: 'r');

    test('maps success and plain failure', () async {
      expect(await run(), AppLockAuthResult.success);
      expect(await run(result: false), AppLockAuthResult.cancelled);
    });

    test('catches LocalAuthException (local_auth 3.x) and maps its code', () async {
      Future<AppLockAuthResult> code(LocalAuthExceptionCode c) => run(error: LocalAuthException(code: c));
      expect(await code(LocalAuthExceptionCode.userCanceled), AppLockAuthResult.cancelled);
      expect(await code(LocalAuthExceptionCode.systemCanceled), AppLockAuthResult.cancelled);
      expect(await code(LocalAuthExceptionCode.noCredentialsSet), AppLockAuthResult.noScreenLock);
      expect(await code(LocalAuthExceptionCode.temporaryLockout), AppLockAuthResult.lockedOut);
      expect(await code(LocalAuthExceptionCode.biometricLockout), AppLockAuthResult.lockedOut);
      expect(await code(LocalAuthExceptionCode.uiUnavailable), AppLockAuthResult.unavailable);
      expect(await code(LocalAuthExceptionCode.deviceError), AppLockAuthResult.unavailable);
    });

    test('catches PlatformException', () async {
      expect(await run(error: PlatformException(code: 'x')), AppLockAuthResult.unavailable);
    });

    test('only failures that need explaining get a message', () {
      expect(appLockMessage(AppLockAuthResult.success), isNull);
      expect(appLockMessage(AppLockAuthResult.cancelled), isNull);
      expect(appLockMessage(AppLockAuthResult.noScreenLock), contains('screen lock'));
      expect(appLockMessage(AppLockAuthResult.lockedOut), isNotNull);
      expect(appLockMessage(AppLockAuthResult.unavailable), isNotNull);
    });
  });

  group('AppLockController', () {
    late FakeAppLockService service;
    late DateTime now;

    Future<ProviderContainer> make({bool enabled = true, AppLockDelay delay = AppLockDelay.immediately}) async {
      SharedPreferences.setMockInitialValues({
        AppLockSettingsNotifier.enabledKey: enabled,
        AppLockSettingsNotifier.delayKey: delay.name,
      });
      final prefs = await SharedPreferences.getInstance();
      service = FakeAppLockService();
      now = DateTime(2026, 1, 1, 12);
      final c = ProviderContainer(overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        appLockServiceProvider.overrideWithValue(service),
        appLockClockProvider.overrideWithValue(() => now),
      ]);
      addTearDown(c.dispose);
      return c;
    }

    AppLockController ctl(ProviderContainer c) => c.read(appLockControllerProvider.notifier);
    AppLockState st(ProviderContainer c) => c.read(appLockControllerProvider);

    void leave(ProviderContainer c) {
      ctl(c).onLifecycleChanged(AppLifecycleState.inactive);
      ctl(c).onLifecycleChanged(AppLifecycleState.hidden);
      ctl(c).onLifecycleChanged(AppLifecycleState.paused);
    }

    void comeBack(ProviderContainer c) {
      ctl(c).onLifecycleChanged(AppLifecycleState.hidden);
      ctl(c).onLifecycleChanged(AppLifecycleState.inactive);
      ctl(c).onLifecycleChanged(AppLifecycleState.resumed);
    }

    test('cold start is locked from the first read when App Lock is on', () async {
      final c = await make();
      expect(st(c).locked, isTrue);
      expect(service.hiddenInRecents, isTrue);
    });

    test('cold start is unlocked when App Lock is off, and lifecycle is ignored', () async {
      final c = await make(enabled: false);
      expect(st(c).locked, isFalse);
      leave(c);
      comeBack(c);
      expect(st(c).covered, isFalse);
    });

    test('unlock succeeds and leaving relocks with "immediately"', () async {
      final c = await make();
      expect(await ctl(c).unlock(), AppLockAuthResult.success);
      expect(st(c).locked, isFalse);

      leave(c);
      expect(st(c).obscured, isTrue, reason: 'covered for the recents thumbnail');
      comeBack(c);
      expect(st(c).locked, isTrue);
      expect(st(c).obscured, isFalse);
    });

    test('a lock delay only relocks after that long in the background', () async {
      final c = await make(delay: AppLockDelay.minute1);
      await ctl(c).unlock();

      leave(c);
      now = now.add(const Duration(seconds: 30));
      comeBack(c);
      expect(st(c).locked, isFalse);

      leave(c);
      now = now.add(const Duration(minutes: 1));
      comeBack(c);
      expect(st(c).locked, isTrue);
    });

    test('brief inactive (notification shade) covers, then uncovers without locking', () async {
      final c = await make();
      await ctl(c).unlock();
      ctl(c).onLifecycleChanged(AppLifecycleState.inactive);
      expect(st(c).obscured, isTrue);
      ctl(c).onLifecycleChanged(AppLifecycleState.resumed);
      expect(st(c).covered, isFalse);
    });

    test('the PIN screen pausing the app during unlock does not relock it', () async {
      final c = await make();
      service.next = AppLockAuthResult.success;
      final pending = ctl(c).unlock();
      // The system PIN activity pauses and resumes the app mid-prompt.
      leave(c);
      comeBack(c);
      await pending;
      ctl(c).onLifecycleChanged(AppLifecycleState.resumed);
      expect(st(c).locked, isFalse);
    });

    test('coming back while already locked asks again', () async {
      final c = await make();
      final before = st(c).promptRequest;
      leave(c);
      comeBack(c);
      expect(st(c).locked, isTrue);
      expect(st(c).promptRequest, before + 1);
    });

    test('cancelling a prompt and resuming does not ask again on its own', () async {
      final c = await make();
      service.next = AppLockAuthResult.cancelled;
      final before = st(c).promptRequest;
      await ctl(c).unlock();
      ctl(c).onLifecycleChanged(AppLifecycleState.resumed);
      expect(st(c).promptRequest, before);
      expect(st(c).locked, isTrue);
    });

    test('screen lock removed from the phone: App Lock turns itself off instead of locking out', () async {
      final c = await make();
      service.next = AppLockAuthResult.noScreenLock;
      expect(await ctl(c).unlock(), AppLockAuthResult.noScreenLock);
      expect(st(c).locked, isFalse);
      expect(c.read(appLockSettingsProvider).enabled, isFalse);
      expect(service.hiddenInRecents, isFalse);
    });

    test('lockout keeps the app locked', () async {
      final c = await make();
      service.next = AppLockAuthResult.lockedOut;
      expect(await ctl(c).unlock(), AppLockAuthResult.lockedOut);
      expect(st(c).locked, isTrue);
    });

    test('turning on and off both require verification', () async {
      final c = await make(enabled: false);

      service.next = AppLockAuthResult.cancelled;
      expect(await ctl(c).setEnabled(true), AppLockAuthResult.cancelled);
      expect(c.read(appLockSettingsProvider).enabled, isFalse);

      service.next = AppLockAuthResult.noScreenLock;
      expect(await ctl(c).setEnabled(true), AppLockAuthResult.noScreenLock);
      expect(c.read(appLockSettingsProvider).enabled, isFalse);

      service.next = AppLockAuthResult.success;
      expect(await ctl(c).setEnabled(true), AppLockAuthResult.success);
      expect(c.read(appLockSettingsProvider).enabled, isTrue);
      expect(st(c).locked, isFalse, reason: 'turning it on does not lock you out of Settings');

      service.next = AppLockAuthResult.cancelled;
      expect(await ctl(c).setEnabled(false), AppLockAuthResult.cancelled);
      expect(c.read(appLockSettingsProvider).enabled, isTrue);

      service.next = AppLockAuthResult.success;
      expect(await ctl(c).setEnabled(false), AppLockAuthResult.success);
      expect(c.read(appLockSettingsProvider).enabled, isFalse);
      expect((await SharedPreferences.getInstance()).getBool(AppLockSettingsNotifier.enabledKey), isFalse);
    });

    test('turning off is allowed without verification when the phone has no screen lock', () async {
      final c = await make();
      service.next = AppLockAuthResult.noScreenLock;
      expect(await ctl(c).setEnabled(false), AppLockAuthResult.success);
      expect(c.read(appLockSettingsProvider).enabled, isFalse);
    });

    test('showing hidden amounts requires verification (not when the phone has no screen lock)', () async {
      final c = await make(enabled: false);
      await c.read(hideBalancesProvider.notifier).set(true);

      service.next = AppLockAuthResult.cancelled;
      expect(await ctl(c).revealAmounts(), AppLockAuthResult.cancelled);
      expect(c.read(hideBalancesProvider), isTrue);

      service.next = AppLockAuthResult.lockedOut;
      expect(await ctl(c).revealAmounts(), AppLockAuthResult.lockedOut);
      expect(c.read(hideBalancesProvider), isTrue);

      service.next = AppLockAuthResult.success;
      expect(await ctl(c).revealAmounts(), AppLockAuthResult.success);
      expect(c.read(hideBalancesProvider), isFalse);

      await c.read(hideBalancesProvider.notifier).set(true);
      service.next = AppLockAuthResult.noScreenLock;
      expect(await ctl(c).revealAmounts(), AppLockAuthResult.success);
      expect(c.read(hideBalancesProvider), isFalse);
    });

    test('lock delay is persisted', () async {
      final c = await make();
      await c.read(appLockSettingsProvider.notifier).setDelay(AppLockDelay.minutes5);
      expect((await SharedPreferences.getInstance()).getString(AppLockSettingsNotifier.delayKey), 'minutes5');
    });
  });
}
