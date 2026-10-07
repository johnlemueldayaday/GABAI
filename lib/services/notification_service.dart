import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:gabay/models/bill_models.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _permissionsGranted = false;

  Future<void> init() async {
    if (_initialized) return;

    tz.initializeTimeZones();
    final localTimezone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(localTimezone.identifier));

    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/launcher_icon'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );

    await flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
    );
    _initialized = true;
  }

  Future<void> _ensurePermissions() async {
    if (_permissionsGranted) return;

    if (defaultTargetPlatform == TargetPlatform.android) {
      final androidPlugin = flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final notificationsGranted =
          await androidPlugin?.requestNotificationsPermission() ?? false;
      final exactAlarmsGranted =
          await androidPlugin?.requestExactAlarmsPermission() ?? false;
      if (!notificationsGranted || !exactAlarmsGranted) {
        throw StateError(
          'Allow notifications and exact alarms in Android settings to receive bill reminders.',
        );
      }
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      final iosPlugin = flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      final granted =
          await iosPlugin?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
      if (!granted) {
        throw StateError(
          'Allow notifications in iOS Settings to receive bill reminders.',
        );
      }
    }

    _permissionsGranted = true;
  }

  int _notificationId(String billId, int daysBefore) {
    var hash = 0x811C9DC5;
    for (final codeUnit in billId.codeUnits) {
      hash = ((hash ^ codeUnit) * 0x01000193) & 0x7FFFFFFF;
    }
    return (hash * 8 + daysBefore) & 0x7FFFFFFF;
  }

  /// Schedules reminders at 9:00 a.m. each day during the seven days before a
  /// due date, plus on the due date itself.
  Future<void> scheduleBillNotification(Bill bill) async {
    if (bill.isPaid) {
      await cancelBillNotification(bill.id);
      return;
    }

    await init();
    await _ensurePermissions();
    await cancelBillNotification(bill.id);

    final now = DateTime.now();
    for (var daysBefore = 7; daysBefore >= 0; daysBefore--) {
      final targetDate = DateTime(
        bill.dueDate.year,
        bill.dueDate.month,
        bill.dueDate.day,
        9,
      ).subtract(Duration(days: daysBefore));

      if (targetDate.isBefore(now)) continue;

      final daysText = switch (daysBefore) {
        0 => 'is due today!',
        1 => 'is due tomorrow!',
        _ => 'is due in $daysBefore days!',
      };

      await flutterLocalNotificationsPlugin.zonedSchedule(
        id: _notificationId(bill.id, daysBefore),
        title: 'Upcoming ${bill.isIncome ? 'Income' : 'Bill'}: ${bill.type}',
        body: '${bill.type} of ₱${bill.amount.toStringAsFixed(2)} $daysText',
        scheduledDate: tz.TZDateTime.from(targetDate, tz.local),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'bill_reminders',
            'Bill Reminders',
            channelDescription: 'Daily reminders for upcoming bills and income',
            importance: Importance.max,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    }
  }

  Future<void> cancelBillNotification(String billId) async {
    await init();
    for (var daysBefore = 0; daysBefore <= 7; daysBefore++) {
      await flutterLocalNotificationsPlugin.cancel(
        id: _notificationId(billId, daysBefore),
      );
    }
  }

  Future<void> rescheduleAllBills(List<Bill> bills) async {
    if (bills.any((bill) => !bill.isPaid)) {
      await init();
      await _ensurePermissions();
    }

    for (final bill in bills) {
      await scheduleBillNotification(bill);
    }
  }
}
