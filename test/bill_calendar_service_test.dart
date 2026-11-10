import 'package:device_calendar/device_calendar.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gabay/models/bill_models.dart';
import 'package:gabay/services/bill_calendar_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('plugins.builttoroam.com/device_calendar');
  late DeviceCalendarPlugin plugin;
  final calls = <MethodCall>[];

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    plugin = DeviceCalendarPlugin.private();
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return switch (call.method) {
            'hasPermissions' => true,
            'retrieveCalendars' =>
              '[{"id":"default-calendar","isReadOnly":false,"isDefault":true}]',
            'createOrUpdateEvent' => 'event-id',
            'deleteEvent' || 'deleteEventInstance' => true,
            _ => null,
          };
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('maps bill frequencies to native calendar recurrence rules', () {
    expect(BillCalendarService.recurrenceRuleForFrequency('Once'), isNull);
    expect(
      BillCalendarService.recurrenceRuleForFrequency(
        'Everyday',
      )?.recurrenceFrequency,
      RecurrenceFrequency.Daily,
    );
    expect(
      BillCalendarService.recurrenceRuleForFrequency(
        'Weekly',
      )?.recurrenceFrequency,
      RecurrenceFrequency.Weekly,
    );
    expect(
      BillCalendarService.recurrenceRuleForFrequency('Quarterly')?.interval,
      3,
    );
    expect(
      BillCalendarService.recurrenceRuleForFrequency('Bi-monthly')?.interval,
      2,
    );
  });

  test(
    'creates an OS calendar event and does not duplicate it on sync',
    () async {
      final service = BillCalendarService(plugin: plugin);
      final bill = Bill(
        id: 'rent',
        type: 'Rent',
        amount: 1200,
        dueDate: DateTime(2026, 11, 1),
        frequency: 'Monthly',
      );

      await service.syncBill(bill);
      await service.syncBill(bill);

      final createCalls = calls
          .where((call) => call.method == 'createOrUpdateEvent')
          .toList();
      expect(createCalls, hasLength(1));
      final event = createCalls.single.arguments as Map<dynamic, dynamic>;
      expect(event['calendarId'], 'default-calendar');
      expect(event['eventTitle'], 'Bill: Rent');
      expect(event['eventStartDate'], isNotNull);
      expect(
        (event['recurrenceRule']
            as Map<dynamic, dynamic>)['recurrenceFrequency'],
        RecurrenceFrequency.Monthly.index,
      );
      expect(event['reminders'], [
        {'minutes': 0},
      ]);
    },
  );

  test('paid recurring bill removes only its due-date occurrence', () async {
    final service = BillCalendarService(plugin: plugin);
    final bill = Bill(
      id: 'salary',
      type: 'Salary',
      amount: 30000,
      dueDate: DateTime(2026, 11, 15),
      frequency: 'Monthly',
      isIncome: true,
    );

    await service.syncBill(bill);
    await service.syncBill(bill.copyWith(isPaid: true));

    expect(
      calls.where((call) => call.method == 'deleteEventInstance'),
      hasLength(1),
    );
    expect(calls.where((call) => call.method == 'deleteEvent'), isEmpty);
    expect(
      calls.where((call) => call.method == 'createOrUpdateEvent'),
      hasLength(1),
    );
  });

  test('does not sync calendar events without permission', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == 'hasPermissions' ||
              call.method == 'requestPermissions') {
            return false;
          }
          return null;
        });

    final service = BillCalendarService(plugin: plugin);
    await expectLater(
      service.syncBill(
        Bill(
          id: 'water',
          type: 'Water',
          amount: 500,
          dueDate: DateTime(2026, 11, 20),
        ),
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('Allow GABAI to access your calendar'),
        ),
      ),
    );
    expect(calls.any((call) => call.method == 'createOrUpdateEvent'), isFalse);
  });
}
