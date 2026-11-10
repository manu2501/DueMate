import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:duemate/core/constants/app_constants.dart';

class AppPermissionStatus {
  final bool contactsGranted;
  final bool notificationGranted;

  const AppPermissionStatus({
    required this.contactsGranted,
    required this.notificationGranted,
  });

  bool get allGranted => contactsGranted && notificationGranted;
  bool get hasAnyGranted => contactsGranted || notificationGranted;
}

class PermissionManager {
  static const String _kLastRunVersionKey = 'duemate_last_run_version';
  static const String _kHasPromptedPermissionsKey = 'duemate_has_prompted_permissions';

  /// Request all necessary runtime permissions for the app and return clean boolean status
  static Future<AppPermissionStatus> requestAndCheckAll() async {
    await requestAllPermissions();
    return await checkAll();
  }

  /// Request all necessary runtime permissions for the app (Contacts & Notifications)
  static Future<Map<Permission, PermissionStatus>> requestAllPermissions() async {
    try {
      final statuses = await [
        Permission.contacts,
        Permission.notification,
      ].request();
      return statuses;
    } catch (_) {
      return {};
    }
  }

  /// Request only Contacts permission
  static Future<bool> requestContacts() async {
    try {
      final status = await Permission.contacts.request();
      return status.isGranted;
    } catch (_) {
      return false;
    }
  }

  /// Request only Notification permission
  static Future<bool> requestNotifications() async {
    try {
      final status = await Permission.notification.request();
      return status.isGranted;
    } catch (_) {
      return false;
    }
  }

  /// Check current status of all app permissions
  static Future<AppPermissionStatus> checkAll() async {
    try {
      final contacts = await Permission.contacts.isGranted;
      final notification = await Permission.notification.isGranted;
      return AppPermissionStatus(
        contactsGranted: contacts,
        notificationGranted: notification,
      );
    } catch (_) {
      return const AppPermissionStatus(
        contactsGranted: false,
        notificationGranted: false,
      );
    }
  }

  /// Checks if contacts permission is granted
  static Future<bool> hasContactsPermission() async {
    try {
      return await Permission.contacts.isGranted;
    } catch (_) {
      return false;
    }
  }

  /// Checks if notification permission is granted
  static Future<bool> hasNotificationPermission() async {
    try {
      return await Permission.notification.isGranted;
    } catch (_) {
      return false;
    }
  }

  /// Open device app settings if permissions were permanently denied
  static Future<bool> openSettings() async {
    try {
      return await openAppSettings();
    } catch (_) {
      return false;
    }
  }

  /// Checks whether this is the first start of the app or an update of the app.
  /// If so, asks for the permissions that are needed!
  ///
  /// Returns `true` if a permission prompt or check was triggered.
  static Future<bool> checkAndPromptOnStartupOrUpdate(
    BuildContext context, {
    bool force = false,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastRunVersion = prefs.getString(_kLastRunVersionKey);
      final currentVersion = AppConstants.appVersionString;

      final isFirstLaunch = lastRunVersion == null;
      final isAppUpdate = lastRunVersion != null && lastRunVersion != currentVersion;

      if (force || isFirstLaunch || isAppUpdate) {
        // Check current status
        final status = await checkAll();

        // If permissions aren't fully granted, prompt the user with our rationale sheet
        if (!status.allGranted && context.mounted) {
          await showPermissionsSheet(
            context,
            isUpdate: isAppUpdate,
          );
        }

        // Record the current version so we don't badger the user repeatedly
        await prefs.setString(_kLastRunVersionKey, currentVersion);
        await prefs.setBool(_kHasPromptedPermissionsKey, true);
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('Error checking startup/update permissions: $e');
      return false;
    }
  }

  /// Displays a polished bottom sheet asking for the permissions needed by DueMate.
  static Future<void> showPermissionsSheet(
    BuildContext context, {
    bool isUpdate = false,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PermissionsRationaleSheet(isUpdate: isUpdate),
    );
  }
}

class _PermissionsRationaleSheet extends StatefulWidget {
  final bool isUpdate;

  const _PermissionsRationaleSheet({required this.isUpdate});

  @override
  State<_PermissionsRationaleSheet> createState() => _PermissionsRationaleSheetState();
}

class _PermissionsRationaleSheetState extends State<_PermissionsRationaleSheet> {
  bool _isRequesting = false;

  Future<void> _grantPermissions() async {
    setState(() => _isRequesting = true);
    try {
      final statuses = await PermissionManager.requestAllPermissions();
      final contactsOk = statuses[Permission.contacts]?.isGranted ?? false;
      final notifOk = statuses[Permission.notification]?.isGranted ?? false;

      if (mounted) {
        Navigator.of(context).pop();

        final message = (contactsOk && notifOk)
            ? 'All permissions successfully granted!'
            : (contactsOk || notifOk)
                ? 'Permissions updated.'
                : 'Permissions were not granted. You can enable them anytime in Settings.';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: (contactsOk || notifOk)
                ? const Color(0xFF10B981)
                : const Color(0xFFF43F5E),
            content: Text(
              message,
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) setState(() => _isRequesting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Icon Badge
              Center(
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colorScheme.primaryContainer,
                  ),
                  child: Icon(
                    Icons.security_rounded,
                    color: colorScheme.onPrimaryContainer,
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title
              Text(
                widget.isUpdate ? 'App Updated: Permissions Check' : 'Permissions Needed',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),

              // Subtitle
              Text(
                widget.isUpdate
                    ? 'DueMate was updated! Please allow the required permissions below to ensure uninterrupted contact importing and due reminders.'
                    : 'DueMate requires a few permissions to seamlessly manage your personal lending records and due reminders.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),

              // Permissions Cards
              Card(
                elevation: 0,
                color: colorScheme.surfaceContainer,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.contacts_rounded, color: colorScheme.onPrimaryContainer, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Device Contacts',
                              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Easily import borrowers & auto-fill phone numbers without manual entry.',
                              style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),

              Card(
                elevation: 0,
                color: colorScheme.surfaceContainer,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.notifications_active_rounded, color: colorScheme.onSecondaryContainer, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Payment Reminders',
                              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Timely reminders for upcoming dues and follow-ups.',
                              style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Privacy Assurance
              Row(
                children: [
                  Icon(Icons.lock_outline_rounded, color: colorScheme.primary, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '100% Offline & Private: Contacts and records never leave your phone.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Action Buttons
              FilledButton(
                onPressed: _isRequesting ? null : _grantPermissions,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isRequesting
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: colorScheme.onPrimary),
                      )
                    : const Text(
                        'Allow Permissions',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                      ),
              ),
              const SizedBox(height: 8),

              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  foregroundColor: colorScheme.onSurfaceVariant,
                ),
                child: const Text(
                  'Skip for Now',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
