import 'package:duemate/core/services/app_lock_service.dart';

/// Scripted [AppLockService]: hands out [next] for each prompt and counts prompts.
class FakeAppLockService implements AppLockService {
  AppLockAuthResult next = AppLockAuthResult.success;
  int prompts = 0;
  bool? hiddenInRecents;

  @override
  Future<AppLockAuthResult> authenticate({required String reason}) async {
    prompts++;
    return next;
  }

  @override
  Future<void> setHideInRecents(bool hide) async => hiddenInRecents = hide;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
