import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smarava/core/constants/app_constants.dart';
import 'package:smarava/core/widgets/bento_card.dart';

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
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF18181B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0x28FFFFFF) : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            // Top Drag Handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black26,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Icon Badge
            Center(
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  border: Border.all(
                    color: const Color(0xFF10B981).withValues(alpha: 0.35),
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.security_rounded,
                  color: Color(0xFF10B981),
                  size: 32,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Title
            Text(
              widget.isUpdate ? 'App Updated: Permissions Check' : 'Permissions Needed',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),

            // Subtitle
            Text(
              widget.isUpdate
                  ? 'DueMate was updated! Please allow the required permissions below to ensure uninterrupted contact importing and due reminders.'
                  : 'DueMate requires a few permissions to seamlessly manage your personal lending records and due reminders.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                height: 1.4,
                color: Color(0xFFA1A1AA),
              ),
            ),
            const SizedBox(height: 20),

            // Permissions Bento Cards
            BentoCard(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.contacts_rounded, color: Color(0xFF10B981), size: 22),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Device Contacts',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Easily import borrowers & auto-fill phone numbers without manual entry.',
                          style: TextStyle(fontSize: 12, color: Color(0xFF71717A)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            BentoCard(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.notifications_active_rounded, color: Color(0xFF6366F1), size: 22),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Payment Reminders',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Timely reminders for upcoming dues and follow-ups.',
                          style: TextStyle(fontSize: 12, color: Color(0xFF71717A)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Privacy Assurance
            Row(
              children: [
                const Icon(Icons.lock_outline_rounded, color: Color(0xFF10B981), size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '100% Offline & Private: Contacts and records never leave your phone.',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF64748B),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),

            // Action Buttons
            ElevatedButton(
              onPressed: _isRequesting ? null : _grantPermissions,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: const Color(0xFF09090B),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: _isRequesting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF09090B)),
                    )
                  : const Text(
                      'Allow Permissions',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                    ),
            ),
            const SizedBox(height: 10),

            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Skip for Now',
                style: TextStyle(
                  color: Color(0xFF71717A),
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  }
}
