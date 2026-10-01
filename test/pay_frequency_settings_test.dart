import 'package:flutter_test/flutter_test.dart';
import 'package:gabay/services/safe_to_spend.dart';
import 'package:gabay/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('migrates existing calendar payday settings to twice-monthly', () async {
    SharedPreferences.setMockInitialValues({
      'settings_salary_payday_days': ['14', '30'],
    });

    await SettingsService().load();

    expect(SettingsService().payFrequency, PayFrequency.twiceMonthly);
    expect(SettingsService().payday1, 14);
    expect(SettingsService().payday2, 30);
  });

  test('persists frequency-specific payday fields', () async {
    SharedPreferences.setMockInitialValues({});
    await SettingsService().load();

    await SettingsService().setPaySchedule(
      frequency: PayFrequency.every15Days,
      payday1: 15,
      payday2: 30,
      intervalDays: 15,
      anchorPayday: DateTime(2026, 10, 15),
    );
    await SettingsService().load();

    expect(SettingsService().payFrequency, PayFrequency.every15Days);
    expect(SettingsService().intervalDays, 15);
    expect(SettingsService().anchorPayday, DateTime(2026, 10, 15));
  });

  test('sorts twice-monthly dates and rejects duplicate paydays', () async {
    SharedPreferences.setMockInitialValues({});
    await SettingsService().load();

    await SettingsService().setPaySchedule(
      frequency: PayFrequency.twiceMonthly,
      payday1: 30,
      payday2: 14,
    );
    expect(SettingsService().payday1, 14);
    expect(SettingsService().payday2, 30);

    await expectLater(
      SettingsService().setPaySchedule(
        frequency: PayFrequency.twiceMonthly,
        payday1: 14,
        payday2: 14,
      ),
      throwsArgumentError,
    );
  });
}
