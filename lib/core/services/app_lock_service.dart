import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// What happened when the user was asked to verify it's them.
enum AppLockAuthResult {
  success,

  /// The user (or the system) dismissed the prompt. Not an error worth a message.
  cancelled,

  /// The phone has no screen lock, so there's nothing to verify against.
  noScreenLock,

  /// Too many failed attempts; the phone blocks verification for a while.
  lockedOut,

  /// Anything else: hardware busy, no UI to show the prompt on, plugin errors.
  unavailable,
}

/// Wraps `local_auth` (fingerprint, face, or the phone's PIN/pattern/password)
/// and the native window flags App Lock needs. Never throws.
class AppLockService {
  final LocalAuthentication _auth;
  final MethodChannel _channel;

  AppLockService({LocalAuthentication? auth, MethodChannel? channel})
      : _auth = auth ?? LocalAuthentication(),
        _channel = channel ?? const MethodChannel('duemate/app_lock');

  /// Shows the system prompt. Biometrics are offered first; the phone's
  /// PIN/pattern/password is always allowed as a fallback.
  Future<AppLockAuthResult> authenticate({required String reason}) async {
    try {
      final ok = await _auth.authenticate(localizedReason: reason);
      return ok ? AppLockAuthResult.success : AppLockAuthResult.cancelled;
    } on LocalAuthException catch (e) {
      return resultForCode(e.code);
    } on PlatformException {
      return AppLockAuthResult.unavailable;
    } on MissingPluginException {
      return AppLockAuthResult.unavailable;
    }
  }

  @visibleForTesting
  static AppLockAuthResult resultForCode(LocalAuthExceptionCode code) {
    switch (code) {
      case LocalAuthExceptionCode.userCanceled:
      case LocalAuthExceptionCode.systemCanceled:
      case LocalAuthExceptionCode.timeout:
      case LocalAuthExceptionCode.userRequestedFallback:
      case LocalAuthExceptionCode.authInProgress:
        return AppLockAuthResult.cancelled;
      case LocalAuthExceptionCode.noCredentialsSet:
        return AppLockAuthResult.noScreenLock;
      case LocalAuthExceptionCode.temporaryLockout:
      case LocalAuthExceptionCode.biometricLockout:
        return AppLockAuthResult.lockedOut;
      default:
        return AppLockAuthResult.unavailable;
    }
  }

  /// Keeps the app's content out of the recent-apps thumbnail (Android 13+;
  /// older versions rely on the in-app privacy cover).
  Future<void> setHideInRecents(bool hide) async {
    try {
      await _channel.invokeMethod<void>('setHideInRecents', hide);
    } on PlatformException {
      // Not fatal: the in-app cover still hides content.
    } on MissingPluginException {
      // Tests and non-Android platforms.
    }
  }
}

/// User-facing explanation for a failed verification, or null when nothing
/// needs saying (success, or the user dismissed the prompt themselves).
String? appLockMessage(AppLockAuthResult result) {
  switch (result) {
    case AppLockAuthResult.success:
    case AppLockAuthResult.cancelled:
      return null;
    case AppLockAuthResult.noScreenLock:
      return 'Set a screen lock on your phone first (PIN, pattern or password), then try again.';
    case AppLockAuthResult.lockedOut:
      return 'Too many attempts. Unlock your phone with its PIN, pattern or password, or wait a moment, then try again.';
    case AppLockAuthResult.unavailable:
      return "Couldn't check it's you. Try again.";
  }
}
