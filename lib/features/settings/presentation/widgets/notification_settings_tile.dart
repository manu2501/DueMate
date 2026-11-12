import 'package:flutter/material.dart';
import 'package:duemate/core/services/notification_service.dart';

class NotificationSettingsTile extends StatefulWidget {
  const NotificationSettingsTile({super.key});

  @override
  State<NotificationSettingsTile> createState() => _NotificationSettingsTileState();
}

class _NotificationSettingsTileState extends State<NotificationSettingsTile> {
  bool _enabled = true;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    final status = await NotificationService().areNotificationsEnabled();
    if (mounted) setState(() => _enabled = status);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Column(
      children: [
        SwitchListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          secondary: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.notifications_active_rounded, color: cs.primary, size: 20),
          ),
          title: Text(
            'Due Date Notifications',
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            'Reminders for upcoming EMI payments',
            style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          value: _enabled,
          onChanged: (val) async {
            if (val) {
              final granted = await NotificationService().requestPermissions();
              if (!granted && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Notification permission is disabled in system settings.')),
                );
              }
            }
            await NotificationService().setNotificationsEnabled(val);
            setState(() => _enabled = val);
          },
        ),
        Divider(height: 1, indent: 64, endIndent: 20, color: cs.outlineVariant),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.notifications_outlined, color: Color(0xFF10B981), size: 20),
          ),
          title: Text(
            'Test Notification Alert',
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            'Trigger an immediate test push notification',
            style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          trailing: const Icon(Icons.play_arrow_rounded),
          onTap: () async {
            final ok = await NotificationService().showTestNotification();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    ok
                        ? 'Test notification sent! Check your notification shade.'
                        : 'Failed to send test notification. Check system permissions.',
                  ),
                ),
              );
            }
          },
        ),
      ],
    );
  }
}
