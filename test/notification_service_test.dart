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
    'schedules stable idle-safe reminders after requesting Android access',
    () async {
      final service = NotificationService();
      final bill = Bill(
        id: 'rent-reminder',
        type: 'Rent',
        amount: 12000,
        dueDate: DateTime(2026, 11, 10),
      );

      await service.scheduleBillNotification(bill);
      final firstIds = calls
          .where((call) => call.method == 'zonedSchedule')
          .map((call) => (call.arguments as Map<dynamic, dynamic>)['id'])
          .toList();
      await service.scheduleBillNotification(bill);
      final allSchedules = calls
          .where((call) => call.method == 'zonedSchedule')
          .map((call) => (call.arguments as Map<dynamic, dynamic>)['id'])
          .toList();

      expect(firstIds, hasLength(8));
      expect(allSchedules.sublist(8), firstIds);
      expect(
        calls.where((call) => call.method == 'requestNotificationsPermission'),
        hasLength(1),
      );
      expect(
        calls.where((call) => call.method == 'requestExactAlarmsPermission'),
        hasLength(1),
      );
    },
  );
}
