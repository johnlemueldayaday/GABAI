import 'package:flutter_test/flutter_test.dart';
import 'package:gabay/models/finance_models.dart';
import 'package:gabay/services/bai_assistant.dart';
import 'package:gabay/services/future_event_storage.dart';
import 'package:gabay/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SettingsService().load();
  });

  test('due car loan event is prompted as an outgoing payment', () async {
    final today = DateTime.now();
    await FutureEventStorage.saveEvents([
      FutureEvent(
        id: 'car-loan-due',
        amount: 1000,
        category: 'Car Loan',
        description: 'Car Loan',
        scheduledDate: DateTime(today.year, today.month, today.day),
      ),
    ]);

    final reply = await BaiAssistant().getAsyncGreeting();

    expect(reply.text, contains('Did you pay your Car Loan?'));
    expect(reply.text, isNot(contains('Did you receive your Car Loan?')));
  });

  test(
    'daily allocation commands handle common wording and misspellings',
    () async {
      const commands = [
        'my daily spending is 500',
        'my daily allocation is 500',
        'my budget everyday is 500',
        'my daliy spendng is 500',
        'budget ko 500 kada araw',
        '500 my budget everyday',
      ];

      for (final command in commands) {
        final reply = await BaiAssistant().handle(command);
        expect(SettingsService().dailySpendingAllocation, 500, reason: command);
        expect(reply.text, contains('per day'), reason: command);
      }
    },
  );

  test('monthly amount is converted to a 30-day daily allocation', () async {
    final reply = await BaiAssistant().handle('my monthly spend is 2000');

    expect(
      SettingsService().dailySpendingAllocation,
      closeTo(2000 / 30, 0.001),
    );
    expect(reply.text, contains('per month divided across 30 days'));
  });

  test('past spending statements do not change the daily allocation', () async {
    final reply = await BaiAssistant().handle('I spent 500 today');

    expect(SettingsService().dailySpendingAllocation, 172.30);
    expect(
      reply.text,
      isNot(contains('Updated your daily spending allocation')),
    );
  });

  test(
    'allocation updates do not notify app-wide settings listeners',
    () async {
      final settings = SettingsService();
      var settingsNotified = false;
      var allocationNotified = false;
      void onSettingsChanged() => settingsNotified = true;
      void onAllocationChanged() => allocationNotified = true;

      settings.addListener(onSettingsChanged);
      settings.dailySpendingAllocationNotifier.addListener(onAllocationChanged);
      await settings.setDailySpendingAllocation(500);
      settings.removeListener(onSettingsChanged);
      settings.dailySpendingAllocationNotifier.removeListener(
        onAllocationChanged,
      );

      expect(settingsNotified, isFalse);
      expect(allocationNotified, isTrue);
    },
  );
}
