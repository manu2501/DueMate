import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

class AppLockService {
  final LocalAuthentication _auth;

  AppLockService({LocalAuthentication? auth}) : _auth = auth ?? LocalAuthentication();

  /// Checks if hardware biometrics or device PIN/pattern unlock is supported
  Future<bool> isBiometricsAvailable() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      return canCheck || isSupported;
    } on PlatformException {
      return false;
    }
  }

  /// Triggers fingerprint, Face ID, or device PIN unlock prompt
  Future<bool> authenticate({
    String reason = 'Unlock DueMate to access your financial ledger',
  }) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
      );
    } on PlatformException {
      return false;
    }
  }
}
