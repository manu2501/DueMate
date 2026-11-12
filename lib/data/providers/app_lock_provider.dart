import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:duemate/core/services/app_lock_service.dart';

final appLockServiceProvider = Provider<AppLockService>((ref) {
  return AppLockService();
});

class AppLockEnabledNotifier extends Notifier<bool> {
  static const _key = 'duemate_app_lock_enabled';

  @override
  bool build() {
    _load();
    return false;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_key) ?? false;
  }

  Future<bool> toggleAppLock(bool enable) async {
    if (enable) {
      final lockService = ref.read(appLockServiceProvider);
      final success = await lockService.authenticate(
        reason: 'Verify fingerprint, Face ID, or PIN to enable App Lock',
      );
      if (!success) return false;
    }

    state = enable;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, enable);
    return true;
  }
}

final appLockEnabledProvider = NotifierProvider<AppLockEnabledNotifier, bool>(AppLockEnabledNotifier.new);

class AppIsLockedNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void lock() => state = true;
  void unlock() => state = false;
}

final appIsLockedProvider = NotifierProvider<AppIsLockedNotifier, bool>(AppIsLockedNotifier.new);
