/// App Lock: settings, plus the controller that decides when the app is
/// locked or covered.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:duemate/core/services/app_lock_service.dart';
import 'package:duemate/data/providers/settings_providers.dart';

final appLockServiceProvider = Provider<AppLockService>((ref) => AppLockService());

/// Injectable clock for the lock-delay logic.
final appLockClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// How long DueMate may sit in the background before it asks again.
enum AppLockDelay {
  immediately(Duration.zero, 'Immediately'),
  seconds30(Duration(seconds: 30), 'After 30 seconds'),
  minute1(Duration(minutes: 1), 'After 1 minute'),
  minutes5(Duration(minutes: 5), 'After 5 minutes');

  const AppLockDelay(this.duration, this.label);
  final Duration duration;
  final String label;
}

@immutable
class AppLockSettings {
  final bool enabled;
  final AppLockDelay delay;

  const AppLockSettings({this.enabled = false, this.delay = AppLockDelay.immediately});

  AppLockSettings copyWith({bool? enabled, AppLockDelay? delay}) =>
      AppLockSettings(enabled: enabled ?? this.enabled, delay: delay ?? this.delay);

  @override
  bool operator ==(Object other) =>
      other is AppLockSettings && other.enabled == enabled && other.delay == delay;

  @override
  int get hashCode => Object.hash(enabled, delay);
}

class AppLockSettingsNotifier extends PrefsNotifier<AppLockSettings> {
  static const enabledKey = 'duemate_app_lock_enabled';
  static const delayKey = 'duemate_app_lock_delay';

  @override
  AppLockSettings get initial => const AppLockSettings();

  @override
  AppLockSettings read(SharedPreferences prefs) => AppLockSettings(
        enabled: prefs.getBool(enabledKey) ?? false,
        delay: AppLockDelay.values.firstWhere(
          (d) => d.name == prefs.getString(delayKey),
          orElse: () => AppLockDelay.immediately,
        ),
      );

  /// Persists the switch. Verification is the controller's job
  /// ([AppLockController.setEnabled]); call that from UI.
  Future<void> setEnabled(bool enabled) async {
    state = state.copyWith(enabled: enabled);
    await (await prefs()).setBool(enabledKey, enabled);
  }

  Future<void> setDelay(AppLockDelay delay) async {
    state = state.copyWith(delay: delay);
    await putString(delayKey, delay.name);
  }
}

final appLockSettingsProvider =
    NotifierProvider<AppLockSettingsNotifier, AppLockSettings>(AppLockSettingsNotifier.new);

@immutable
class AppLockState {
  /// The lock screen is up; the user must verify to continue.
  final bool locked;

  /// The app isn't in front (or is on its way out): a plain cover hides its
  /// content from the recent-apps thumbnail.
  final bool obscured;

  /// Bumped when an already-locked app comes back to the foreground, so the
  /// lock screen asks again without the user tapping.
  final int promptRequest;

  const AppLockState({this.locked = false, this.obscured = false, this.promptRequest = 0});

  bool get covered => locked || obscured;

  AppLockState copyWith({bool? locked, bool? obscured, int? promptRequest}) => AppLockState(
        locked: locked ?? this.locked,
        obscured: obscured ?? this.obscured,
        promptRequest: promptRequest ?? this.promptRequest,
      );

  @override
  bool operator ==(Object other) =>
      other is AppLockState &&
      other.locked == locked &&
      other.obscured == obscured &&
      other.promptRequest == promptRequest;

  @override
  int get hashCode => Object.hash(locked, obscured, promptRequest);
}

/// Decides when DueMate is locked.
///
/// - Starts locked on a cold start when App Lock is on.
/// - Records when the app leaves the foreground; on return, locks if it was
///   away for at least the chosen delay.
/// - Ignores lifecycle changes caused by its own prompt: the fingerprint
///   dialog and the phone's PIN screen both pause the app, and treating that
///   as "left the app" would re-lock right after a successful unlock.
class AppLockController extends Notifier<AppLockState> {
  DateTime? _backgroundedAt;
  bool _authenticating = false;

  AppLockService get _service => ref.read(appLockServiceProvider);
  AppLockSettings get _settings => ref.read(appLockSettingsProvider);

  @override
  AppLockState build() {
    final settings = ref.read(appLockSettingsProvider);
    _service.setHideInRecents(settings.enabled);
    ref.listen(appLockSettingsProvider.select((s) => s.enabled), (previous, enabled) {
      _service.setHideInRecents(enabled);
      if (!enabled) {
        _backgroundedAt = null;
        state = const AppLockState();
      }
    });
    return AppLockState(locked: settings.enabled);
  }

  void onLifecycleChanged(AppLifecycleState lifecycle) {
    if (!_settings.enabled || _authenticating) return;
    final now = ref.read(appLockClockProvider)();
    switch (lifecycle) {
      case AppLifecycleState.inactive:
        state = state.copyWith(obscured: true);
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _backgroundedAt ??= now;
        state = state.copyWith(obscured: true);
      case AppLifecycleState.resumed:
        final since = _backgroundedAt;
        _backgroundedAt = null;
        if (since == null) {
          // Only briefly inactive (notification shade, share chooser, a
          // system dialog): just lift the cover.
          state = state.copyWith(obscured: false);
        } else if (state.locked) {
          state = state.copyWith(obscured: false, promptRequest: state.promptRequest + 1);
        } else {
          final away = now.difference(since);
          state = state.copyWith(obscured: false, locked: away >= _settings.delay.duration);
        }
    }
  }

  /// Locks right away (e.g. for the screenshot harness).
  void lockNow() {
    if (_settings.enabled) state = state.copyWith(locked: true);
  }

  Future<AppLockAuthResult> _authenticate(String reason) async {
    if (_authenticating) return AppLockAuthResult.cancelled;
    _authenticating = true;
    try {
      return await _service.authenticate(reason: reason);
    } finally {
      _authenticating = false;
      _backgroundedAt = null;
    }
  }

  /// Asks the user to verify and unlocks on success. If the phone no longer
  /// has a screen lock there is nothing to verify against, so App Lock is
  /// turned off rather than locking the user out of their data for good.
  Future<AppLockAuthResult> unlock() async {
    final result = await _authenticate('Unlock DueMate');
    if (result == AppLockAuthResult.success) {
      state = const AppLockState();
    } else if (result == AppLockAuthResult.noScreenLock) {
      await ref.read(appLockSettingsProvider.notifier).setEnabled(false);
      state = const AppLockState();
    }
    return result;
  }

  /// Shows hidden amounts again, after the user verifies it's them, so a
  /// phone handed over with amounts hidden can't simply be un-hidden. Phones
  /// without a screen lock have nothing to verify with and are let through.
  Future<AppLockAuthResult> revealAmounts() async {
    final result = await _authenticate('Confirm it\'s you to show amounts');
    final allowed = result == AppLockAuthResult.success || result == AppLockAuthResult.noScreenLock;
    if (!allowed) return result;
    await ref.read(hideBalancesProvider.notifier).set(false);
    return AppLockAuthResult.success;
  }

  /// Turns App Lock on or off; both directions ask the user to verify first.
  /// Turning it off is allowed without verification only when the phone has
  /// no screen lock left to verify with.
  Future<AppLockAuthResult> setEnabled(bool enabled) async {
    if (enabled == _settings.enabled) return AppLockAuthResult.success;
    final result = await _authenticate(
      enabled ? 'Confirm it\'s you to turn on App Lock' : 'Confirm it\'s you to turn off App Lock',
    );
    final allowed = result == AppLockAuthResult.success ||
        (!enabled && result == AppLockAuthResult.noScreenLock);
    if (!allowed) return result;
    await ref.read(appLockSettingsProvider.notifier).setEnabled(enabled);
    return AppLockAuthResult.success;
  }
}

final appLockControllerProvider =
    NotifierProvider<AppLockController, AppLockState>(AppLockController.new);
