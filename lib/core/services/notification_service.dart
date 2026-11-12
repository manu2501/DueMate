import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/foundation.dart';
import 'package:duemate/domain/emi_reminder_planner.dart';

class NotificationService implements EmiReminderScheduler {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  final _emiReminderTaps = StreamController<String>.broadcast();

  /// EMI ids from reminders tapped while the app is running.
  Stream<String> get emiReminderTaps => _emiReminderTaps.stream;

  /// The EMI id of the reminder that launched the app, if one did.
  Future<String?> emiReminderThatLaunchedApp() async {
    try {
      final details = await _notificationsPlugin.getNotificationAppLaunchDetails();
      if (details == null || !details.didNotificationLaunchApp) return null;
      return EmiReminder.emiIdFromPayload(details.notificationResponse?.payload);
    } catch (_) {
      return null;
    }
  }

  static const String _kNotificationsEnabledKey = 'duemate_notifications_enabled';
  static const String _channelId = 'duemate_reminders';
  static const String _channelName = 'DueMate Payment Reminders';
  static const String _channelDescription = 'Notifications for upcoming EMI installments & payment due dates.';

  /// Initialize the notification service, channels, and timezone data
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      tz.initializeTimeZones();

      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosInit = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );

      const initSettings = InitializationSettings(
        android: androidInit,
        iOS: iosInit,
      );

      await _notificationsPlugin.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (details) {
          final emiId = EmiReminder.emiIdFromPayload(details.payload);
          if (emiId != null) _emiReminderTaps.add(emiId);
        },
      );

      // Create Android Notification Channel
      const androidChannel = AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.high,
        playSound: true,
      );

      await _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(androidChannel);

      _isInitialized = true;
      debugPrint('NotificationService initialized successfully.');
    } catch (e) {
      debugPrint('Error initializing NotificationService: $e');
    }
  }

  /// Check if notifications are enabled in user settings
  Future<bool> areNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kNotificationsEnabledKey) ?? true;
  }

  /// Toggle notification preference in settings
  Future<void> setNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kNotificationsEnabledKey, enabled);
    // Off: EMI reminders are cancelled. On: the latest plan is scheduled.
    await replaceEmiReminders(_requested);
  }

  /// Request notification permissions from OS if not already granted
  Future<bool> requestPermissions() async {
    try {
      final status = await Permission.notification.request();
      if (status.isGranted) return true;

      final androidPlugin = _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        final granted = await androidPlugin.requestNotificationsPermission();
        return granted ?? false;
      }
      return false;
    } catch (e) {
      debugPrint('Error requesting notification permissions: $e');
      return false;
    }
  }

  /// Triggers an immediate test notification to verify notification setup works
  Future<bool> showTestNotification() async {
    await initialize();

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      await _notificationsPlugin.show(
        id: 9999,
        title: '🔔 DueMate Notification Test',
        body: 'Notifications are working.',
        notificationDetails: details,
      );
      return true;
    } catch (e) {
      debugPrint('Error showing test notification: $e');
      return false;
    }
  }

  List<EmiReminder> _requested = const [];
  List<EmiReminder>? _scheduled;
  Future<void> _applying = Future.value();

  /// Makes the scheduled EMI reminders match [plan] (what
  /// [EmiReminderPlanner] says should be scheduled). Runs one at a time and
  /// does nothing when the plan hasn't changed, so it's cheap to call on
  /// every EMI change.
  @override
  Future<void> replaceEmiReminders(List<EmiReminder> plan) {
    _requested = plan;
    return _applying = _applying.then((_) => _apply());
  }

  Future<void> _apply() async {
    final plan = await areNotificationsEnabled() ? _requested : const <EmiReminder>[];
    if (listEquals(plan, _scheduled)) return;
    await initialize();
    try {
      // Only DueMate's EMI reminders are replaced; anything else stays.
      final pending = await _notificationsPlugin.pendingNotificationRequests();
      for (final p in pending) {
        if (p.payload?.startsWith(EmiReminder.payloadPrefix) ?? false) {
          await _notificationsPlugin.cancel(id: p.id);
        }
      }
      for (final r in plan) {
        await _notificationsPlugin.zonedSchedule(
          id: r.id,
          title: r.title,
          body: r.body,
          payload: r.payload,
          // Keeps the instant: 9:00 local whatever tz.local is set to.
          scheduledDate: tz.TZDateTime.from(r.at, tz.local),
          notificationDetails: _reminderDetails,
          // Inexact: needs no exact-alarm permission; minutes late is fine.
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
      _scheduled = plan;
    } catch (e) {
      debugPrint('Could not schedule EMI reminders: $e');
    }
  }

  static const _reminderDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      // Content stays hidden on a locked screen.
      visibility: NotificationVisibility.private,
    ),
    iOS: DarwinNotificationDetails(),
  );
}

/// Schedules EMI reminders; [NotificationService] in the app, a fake in tests.
abstract interface class EmiReminderScheduler {
  Future<void> replaceEmiReminders(List<EmiReminder> plan);
}
