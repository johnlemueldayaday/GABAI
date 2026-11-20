import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:gabay/models/bill_models.dart';
import 'package:gabay/services/notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const notificationChannel = MethodChannel(
    'dexterous.com/flutter/local_notifications',
  );
  const timezoneChannel = MethodChannel('flutter_timezone');
  final calls = <MethodCall>[];

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      ..setMockMethodCallHandler(notificationChannel, (call) async {
        calls.add(call);
        if (call.method == 'canScheduleExactNotifications') return false;
        return true;
      })
      ..setMockMethodCallHandler(
        timezoneChannel,
        (call) async => 'Asia/Manila',
      );
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      ..setMockMethodCallHandler(notificationChannel, null)
      ..setMockMethodCallHandler(timezoneChannel, null);
  });

  test(
    'shows transaction alerts without exact alarms and schedules bill reminders',
    () async {
      final service = NotificationService();
      await service.showTransactionNotification(
        title: 'Spent ₱1,234.50 from Cash',
        body: 'Your wallet balance is now ₱5,678.90',
      );

      final notificationCall = calls.singleWhere(
        (call) => call.method == 'show',
      );
      final notificationArguments =
          notificationCall.arguments as Map<dynamic, dynamic>;
      expect(notificationArguments['title'], 'Spent ₱1,234.50 from Cash');
      expect(
        notificationArguments['body'],
        'Your wallet balance is now ₱5,678.90',
      );
      expect(
        calls.where((call) => call.method == 'requestExactAlarmsPermission'),
        isEmpty,
      );

      final dueDate = DateTime.now().add(const Duration(days: 30));
      final bill = Bill(
        id: 'rent-reminder',
        type: 'Rent',
        amount: 12000,
        dueDate: dueDate,
      );

      await service.scheduleBillNotification(bill);
      final firstIds = calls
          .where((call) => call.method == 'zonedSchedule')
          .map((call) => (call.arguments as Map<dynamic, dynamic>)['id'])
          .toList();
      expect(firstIds, hasLength(10));
      expect(firstIds.toSet(), hasLength(10));
      final dueDayTimes =
          calls
              .where((call) => call.method == 'zonedSchedule')
              .map((call) => call.arguments as Map<dynamic, dynamic>)
              .where(
                (arguments) =>
                    arguments['body'] ==
                    'Rent of ₱12000.00 is due today!',
              )
              .map(
                (arguments) =>
                    (arguments['scheduledDateTimeISO8601'] as String)
                        .substring(11, 16),
              )
              .toSet();
      expect(dueDayTimes, {'09:00', '15:00', '20:00'});

      await service.scheduleBillNotification(bill);
      final allSchedules = calls
          .where((call) => call.method == 'zonedSchedule')
          .map((call) => (call.arguments as Map<dynamic, dynamic>)['id'])
          .toList();

      expect(allSchedules.sublist(10), firstIds);
      expect(
        calls.where((call) => call.method == 'requestNotificationsPermission'),
        hasLength(1),
      );
      expect(
        calls.where((call) => call.method == 'requestExactAlarmsPermission'),
        hasLength(1),
      );

      await service.scheduleBillNotification(bill.copyWith(isPaid: true));
      final cancellationIds = calls
          .where((call) => call.method == 'cancel')
          .map((call) => (call.arguments as Map<dynamic, dynamic>)['id'])
          .toList();
      expect(cancellationIds, hasLength(30));
      expect(cancellationIds.skip(20).toSet(), containsAll(firstIds));
    },
  );

  test('notifyTransaction formats expense notification correctly', () async {
    final service = NotificationService();
    await service.notifyTransaction(
      type: 'EXPENSE',
      amount: 99.00,
      accountName: 'GCash',
      newBalance: 250.60,
      accountId: 'gcash-1',
      transactionId: 'txn-1',
    );

    final call = calls.lastWhere((call) => call.method == 'show');
    final args = call.arguments as Map<dynamic, dynamic>;
    expect(args['title'], 'Expense logged! ₱99.00 from GCash');
    expect(args['body'], 'Your GCash balance is now ₱250.60');
    expect(args['payload'], contains('gcash-1'));
  });

  test('notifyTransaction formats income notification with thousands separator', () async {
    final service = NotificationService();
    await service.notifyTransaction(
      type: 'INCOME',
      amount: 5000.00,
      accountName: 'BPI',
      newBalance: 18786.00,
      description: 'Freelance Project',
      accountId: 'bpi-1',
      transactionId: 'txn-2',
    );

    final call = calls.lastWhere((call) => call.method == 'show');
    final args = call.arguments as Map<dynamic, dynamic>;
    expect(args['title'], 'Income logged! ₱5,000.00 from Freelance Project');
    expect(args['body'], 'Your Total balance is now ₱18,786.00');
  });
}
