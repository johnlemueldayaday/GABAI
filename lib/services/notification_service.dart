import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:gabay/config/app_theme.dart';
import 'package:gabay/models/bill_models.dart';
import 'package:gabay/pages/bills.dart';
import 'package:gabay/pages/wallet.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  static const _additionalDueReminderHours = [15, 20];
  factory NotificationService() => _instance;
  NotificationService._internal();

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _notificationPermissionsGranted = false;
  bool _exactAlarmPermissionGranted = false;

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
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        _handleNotificationResponse(response);
      },
    );

    final launchDetails =
        await flutterLocalNotificationsPlugin.getNotificationAppLaunchDetails();
    if (launchDetails != null &&
        launchDetails.didNotificationLaunchApp &&
        launchDetails.notificationResponse != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleNotificationResponse(launchDetails.notificationResponse!);
      });
    }

    _initialized = true;
  }

  void _handleNotificationResponse(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      if (data['type'] == 'transaction') {
        navigatorKey.currentState?.push(
          MaterialPageRoute(builder: (_) => const WalletPage()),
        );
      } else if (data['type'] == 'bill_calendar') {
        navigatorKey.currentState?.push(
          MaterialPageRoute(builder: (_) => const BillsPage()),
        );
      }
    } catch (e) {
      debugPrint('Error handling notification tap payload: $e');
    }
  }

  Future<bool> requestNotificationPermissions({BuildContext? context}) async {
    bool granted = false;
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final iosPlugin = flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      granted =
          await iosPlugin?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      final androidPlugin = flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      granted =
          await androidPlugin?.requestNotificationsPermission() ?? false;
    }
    _notificationPermissionsGranted = granted;

    if (!granted && context != null && context.mounted) {
      await showPermissionDeniedDialog(context);
    }
    return granted;
  }

  static Future<void> showPermissionDeniedDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.notifications_off_outlined, color: kPrimary),
            const SizedBox(width: 8),
            Text(
              'Notifications Off',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Text(
          'Allow notifications in Settings so GABAI can show real-time transaction banners whenever you log an expense or income.',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            color: kTextCharcoal,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Not Now',
              style: GoogleFonts.plusJakartaSans(
                color: kMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings();
            },
            child: Text(
              'Open Settings',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _ensureNotificationPermissions() async {
    if (_notificationPermissionsGranted) return;
    if (defaultTargetPlatform == TargetPlatform.android) {
      final androidPlugin = flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final granted =
          await androidPlugin?.requestNotificationsPermission() ?? false;
      if (!granted) {
        throw StateError(
          'Allow notifications in Android settings to receive transaction alerts.',
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
          'Allow notifications in iOS Settings to receive transaction alerts.',
        );
      }
    }

    _notificationPermissionsGranted = true;
  }

  Future<void> _ensureExactAlarmPermission() async {
    if (_exactAlarmPermissionGranted ||
        defaultTargetPlatform != TargetPlatform.android) {
      _exactAlarmPermissionGranted = true;
      return;
    }

    final androidPlugin = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    var granted = await androidPlugin?.canScheduleExactNotifications() ?? true;
    if (!granted) {
      granted = await androidPlugin?.requestExactAlarmsPermission() ?? false;
    }
    if (!granted) {
      throw StateError(
        'Allow exact alarms in Android settings to receive bill reminders.',
      );
    }

    _exactAlarmPermissionGranted = true;
  }

  Future<void> _ensurePermissions() async {
    await _ensureNotificationPermissions();
    await _ensureExactAlarmPermission();
  }

  Future<void> showTransactionNotification({
    required String title,
    required String body,
  }) async {
    await init();
    await _ensureNotificationPermissions();
    await flutterLocalNotificationsPlugin.show(
      id: DateTime.now().microsecondsSinceEpoch & 0x7FFFFFFF,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'transaction_alerts',
          'Transaction Alerts',
          channelDescription: 'Notifications after GAB logs a transaction',
          importance: Importance.max,
          priority: Priority.high,
          enableVibration: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBanner: true,
          presentList: true,
          presentSound: true,
        ),
      ),
    );
  }

  /// Sends an immediate local notification when a transaction (expense or income) is saved.
  Future<void> notifyTransaction({
    required String type,
    required double amount,
    required String accountName,
    required double newBalance,
    String? description,
    String? accountId,
    String? transactionId,
  }) async {
    await init();
    await _ensureNotificationPermissions();

    final isIncome = type.toUpperCase() == 'INCOME';
    final formatter = NumberFormat('#,##0.00', 'en_US');
    final formattedAmount = '₱${formatter.format(amount)}';
    final formattedBalance = '₱${formatter.format(newBalance)}';

    final String title;
    final String body;
    if (isIncome) {
      final source = (description != null && description.trim().isNotEmpty)
          ? description.trim()
          : accountName;
      title = 'Income logged! $formattedAmount from $source';
      body = 'Your Total balance is now $formattedBalance';
    } else {
      title = 'Expense logged! $formattedAmount from $accountName';
      body = 'Your $accountName balance is now $formattedBalance';
    }

    final payload = jsonEncode({
      'type': 'transaction',
      'transactionType': type,
      'accountId': accountId,
      'accountName': accountName,
      'transactionId': transactionId,
    });

    final threadId =
        'account_${(accountId ?? accountName).toLowerCase().replaceAll(RegExp(r'\s+'), '_')}';

    await flutterLocalNotificationsPlugin.show(
      id: DateTime.now().microsecondsSinceEpoch & 0x7FFFFFFF,
      title: title,
      body: body,
      payload: payload,
      notificationDetails: NotificationDetails(
        android: const AndroidNotificationDetails(
          'transaction_alerts',
          'Transaction Alerts',
          channelDescription: 'Notifications shown when a transaction is logged',
          importance: Importance.max,
          priority: Priority.high,
          enableVibration: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBanner: true,
          presentList: true,
          presentSound: true,
          presentBadge: true,
          interruptionLevel: InterruptionLevel.active,
          threadIdentifier: threadId,
        ),
      ),
    );
  }

  /// Sends an immediate local notification when a bill is added to calendar.
  Future<void> notifyBillAddedToCalendar({
    required String billName,
    required double amount,
    String? billId,
  }) async {
    await init();
    await _ensureNotificationPermissions();

    final formatter = NumberFormat('#,##0.00', 'en_US');
    final formattedAmount = '₱${formatter.format(amount)}';

    final title = '📆 $billName Added to Calendar!';
    final body = 'Amount : $formattedAmount';

    final payload = jsonEncode({
      'type': 'bill_calendar',
      'billId': billId,
      'billName': billName,
    });

    final threadId =
        'bill_${billName.toLowerCase().replaceAll(RegExp(r'\s+'), '_')}';

    await flutterLocalNotificationsPlugin.show(
      id: DateTime.now().microsecondsSinceEpoch & 0x7FFFFFFF,
      title: title,
      body: body,
      payload: payload,
      notificationDetails: NotificationDetails(
        android: const AndroidNotificationDetails(
          'transaction_alerts',
          'Transaction Alerts',
          channelDescription: 'Notifications shown when a transaction or entry is logged',
          importance: Importance.max,
          priority: Priority.high,
          enableVibration: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBanner: true,
          presentList: true,
          presentSound: true,
          presentBadge: true,
          interruptionLevel: InterruptionLevel.active,
          threadIdentifier: threadId,
        ),
      ),
    );
  }

  int _notificationId(String billId, int daysBefore) {
    var hash = 0x811C9DC5;
    for (final codeUnit in billId.codeUnits) {
      hash = ((hash ^ codeUnit) * 0x01000193) & 0x7FFFFFFF;
    }
    return (hash * 8 + daysBefore) & 0x7FFFFFFF;
  }

  int _additionalDueReminderId(String billId, int hour) =>
      _notificationId('$billId:due:$hour', 0);

  /// Schedules 9:00 a.m. reminders for the week before a bill, with additional
  /// 3:00 p.m. and 8:00 p.m. reminders on its due date.
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

      if (!targetDate.isBefore(now)) {
        await _scheduleBillReminder(
          bill: bill,
          targetDate: targetDate,
          notificationId: _notificationId(bill.id, daysBefore),
          daysBefore: daysBefore,
        );
      }

      if (daysBefore != 0 || bill.isIncome) continue;

      for (final hour in _additionalDueReminderHours) {
        final additionalReminder = DateTime(
          bill.dueDate.year,
          bill.dueDate.month,
          bill.dueDate.day,
          hour,
        );
        if (additionalReminder.isBefore(now)) continue;
        await _scheduleBillReminder(
          bill: bill,
          targetDate: additionalReminder,
          notificationId: _additionalDueReminderId(bill.id, hour),
          daysBefore: 0,
        );
      }
    }
  }

  Future<void> _scheduleBillReminder({
    required Bill bill,
    required DateTime targetDate,
    required int notificationId,
    required int daysBefore,
  }) async {
    final daysText = switch (daysBefore) {
      0 => 'is due today!',
      1 => 'is due tomorrow!',
      _ => 'is due in $daysBefore days!',
    };

    await flutterLocalNotificationsPlugin.zonedSchedule(
      id: notificationId,
      title: 'Upcoming ${bill.isIncome ? 'Income' : 'Bill'}: ${bill.type}',
      body:
          '${bill.type} of ₱${NumberFormat('#,##0.00', 'en_US').format(bill.amount)} $daysText',
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

  Future<void> cancelBillNotification(String billId) async {
    await init();
    for (var daysBefore = 0; daysBefore <= 7; daysBefore++) {
      await flutterLocalNotificationsPlugin.cancel(
        id: _notificationId(billId, daysBefore),
      );
    }
    for (final hour in _additionalDueReminderHours) {
      await flutterLocalNotificationsPlugin.cancel(
        id: _additionalDueReminderId(billId, hour),
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
