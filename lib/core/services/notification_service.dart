import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:duemate/core/utils/currency_formatter.dart';
import 'package:duemate/domain/entities/credit_card_emi.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

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
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse details) {
          debugPrint('Notification clicked with payload: ${details.payload}');
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
    if (!enabled) {
      await cancelAllReminders();
    }
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
        9999,
        '🔔 DueMate Notification Test',
        'Smart due date notifications are working perfectly!',
        details,
      );
      return true;
    } catch (e) {
      debugPrint('Error showing test notification: $e');
      return false;
    }
  }

  /// Schedule a due date reminder notification for an active EMI
  Future<void> scheduleEmiDueReminder(
    CreditCardEmi emi, {
    required String personName,
    String currencySymbol = '₹',
  }) async {
    if (!await areNotificationsEnabled()) return;
    await initialize();

    if (emi.isCompleted || !emi.isActive) return;

    final now = DateTime.now();
    // Next due date for this month
    var dueDateTime = DateTime(now.year, now.month, emi.dueDayOfMonth, 9, 0);
    if (dueDateTime.isBefore(now)) {
      dueDateTime = DateTime(now.year, now.month + 1, emi.dueDayOfMonth, 9, 0);
    }

    final id = emi.id.hashCode.abs();
    final monthlyStr = CurrencyFormatter.format(emi.monthlyInstallment, symbol: currencySymbol);

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    try {
      final tzScheduled = tz.TZDateTime.from(dueDateTime, tz.local);

      await _notificationsPlugin.zonedSchedule(
        id,
        '⏰ Upcoming EMI Due: ${emi.itemName}',
        '$personName owes $monthlyStr (${emi.installmentsPaid + 1}/${emi.totalTenureMonths} mo due today)',
        tzScheduled,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      debugPrint('Scheduled notification #$id for ${emi.itemName} at $dueDateTime');
    } catch (e) {
      debugPrint('Fallback scheduling notification for ${emi.itemName}: $e');
    }
  }

  /// Cancel a specific scheduled notification
  Future<void> cancelReminder(int id) async {
    await _notificationsPlugin.cancel(id);
  }

  /// Cancel all scheduled notifications
  Future<void> cancelAllReminders() async {
    await _notificationsPlugin.cancelAll();
  }
}
