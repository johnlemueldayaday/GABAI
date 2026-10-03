import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:gabay/models/bill_models.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/launcher_icon');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
    );
  }

  int _notificationId(String billId, int daysBefore) {
    return (billId.hashCode * 31 + daysBefore) & 0x7FFFFFFF;
  }

  /// Schedule notifications 7 days before due date, and everyday for 7 days leading to due date.
  Future<void> scheduleBillNotification(Bill bill) async {
    if (bill.isPaid) return;

    final now = DateTime.now();

    for (int daysBefore = 7; daysBefore >= 0; daysBefore--) {
      // Schedule for 9:00 AM on the target reminder date
      final targetDate = DateTime(
        bill.dueDate.year,
        bill.dueDate.month,
        bill.dueDate.day,
        9,
        0,
      ).subtract(Duration(days: daysBefore));

      if (targetDate.isBefore(now)) {
        continue; // Already past this reminder time
      }

      final id = _notificationId(bill.id, daysBefore);
      final daysText = daysBefore == 0
          ? 'is due today!'
          : daysBefore == 1
              ? 'is due tomorrow!'
              : 'is due in $daysBefore days!';

      try {
        await flutterLocalNotificationsPlugin.zonedSchedule(
          id: id,
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
      } catch (e) {
        // Fallback / ignore scheduling failures on unsupported platforms
      }
    }
  }

  Future<void> cancelBillNotification(String billId) async {
    // Cancel all daily scheduled reminders (offsets 0 to 7) as well as legacy id
    await flutterLocalNotificationsPlugin.cancel(id: billId.hashCode);
    for (int daysBefore = 0; daysBefore <= 7; daysBefore++) {
      final id = _notificationId(billId, daysBefore);
      await flutterLocalNotificationsPlugin.cancel(id: id);
    }
  }

  Future<void> rescheduleAllBills(List<Bill> bills) async {
    for (final bill in bills) {
      if (!bill.isPaid) {
        await scheduleBillNotification(bill);
      } else {
        await cancelBillNotification(bill.id);
      }
    }
  }
}
