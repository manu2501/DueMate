import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:duemate/core/services/app_lock_service.dart';
import 'package:duemate/data/providers/app_providers.dart';

/// Hides or shows amounts app-wide. Hiding is instant; showing them again
/// asks the user to verify it's them (fingerprint, face or screen lock).
Future<void> setAmountsHidden(BuildContext context, WidgetRef ref, bool hide) async {
  if (hide) {
    await ref.read(hideBalancesProvider.notifier).set(true);
    return;
  }
  final messenger = ScaffoldMessenger.maybeOf(context);
  final result = await ref.read(appLockControllerProvider.notifier).revealAmounts();
  final message = appLockMessage(result);
  if (message != null) messenger?.showSnackBar(SnackBar(content: Text(message)));
}
