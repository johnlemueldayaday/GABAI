import 'package:flutter_test/flutter_test.dart';
import 'package:gabay/services/safe_to_spend.dart';

void main() {
  test('every 15 days stays on its date anchor', () {
    const frequency = PayFrequency.every15Days;
    final anchor = DateTime(2026, 10, 15);
    final dates = <DateTime, DateTime>{
      DateTime(2026, 10, 1): DateTime(2026, 10, 15),
      DateTime(2026, 10, 16): DateTime(2026, 10, 30),
      DateTime(2026, 10, 31): DateTime(2026, 11, 14),
    };

    for (final entry in dates.entries) {
      final payday = nextPayday(
        today: entry.key,
        frequency: frequency,
        anchor: anchor,
      );
      expect(payday, entry.value);
      expect(calculateDaysLeft(today: entry.key, payday: payday), 15);
    }
  });

  test('every 30 days resolves one anchored 30-day cycle', () {
    final payday = nextPayday(
      today: DateTime(2026, 10, 16),
      frequency: PayFrequency.every30Days,
      anchor: DateTime(2026, 10, 15),
    );
    expect(payday, DateTime(2026, 11, 14));
    expect(
      calculateDaysLeft(today: DateTime(2026, 10, 16), payday: payday),
      30,
    );
  });

  test('weekly resolves seven days after anchor', () {
    final payday = nextPayday(
      today: DateTime(2026, 10, 16),
      frequency: PayFrequency.weekly,
      anchor: DateTime(2026, 10, 15),
    );
    expect(payday, DateTime(2026, 10, 22));
    expect(calculateDaysLeft(today: DateTime(2026, 10, 16), payday: payday), 7);
  });

  test('custom interval resolves from the original anchor', () {
    expect(
      nextPayday(
        today: DateTime(2026, 10, 27),
        frequency: PayFrequency.custom,
        intervalDays: 10,
        anchor: DateTime(2026, 10, 15),
      ),
      DateTime(2026, 11, 4),
    );
  });

  test('today on payday counts as one day', () {
    final today = DateTime(2026, 10, 15);
    final payday = nextPayday(
      today: today,
      frequency: PayFrequency.every15Days,
      anchor: today,
    );
    expect(payday, today);
    expect(calculateDaysLeft(today: today, payday: payday), 1);
  });

  test('handles year rollover and leap-year month-end clamping', () {
    expect(
      nextPayday(
        today: DateTime(2026, 12, 20),
        frequency: PayFrequency.every15Days,
        anchor: DateTime(2026, 12, 15),
      ),
      DateTime(2026, 12, 30),
    );
    expect(
      nextPayday(
        today: DateTime(2026, 12, 31),
        frequency: PayFrequency.every15Days,
        anchor: DateTime(2026, 12, 15),
      ),
      DateTime(2027, 1, 14),
    );
    expect(
      nextPayday(
        today: DateTime(2024, 2, 28),
        frequency: PayFrequency.monthly,
        payday1: 31,
      ),
      DateTime(2024, 2, 29),
    );
    expect(
      nextPayday(
        today: DateTime(2024, 2, 29),
        frequency: PayFrequency.monthly,
        payday1: 31,
      ),
      DateTime(2024, 2, 29),
    );
    expect(
      nextPayday(
        today: DateTime(2023, 2, 28),
        frequency: PayFrequency.monthly,
        payday1: 31,
      ),
      DateTime(2023, 2, 28),
    );
  });

  test('existing calendar schedules resolve dates on or after today', () {
    expect(
      nextPayday(
        today: DateTime(2026, 10, 16),
        frequency: PayFrequency.monthly,
        payday1: 15,
      ),
      DateTime(2026, 11, 15),
    );
    expect(
      nextPayday(
        today: DateTime(2026, 10, 31),
        frequency: PayFrequency.twiceMonthly,
        payday1: 14,
        payday2: 30,
      ),
      DateTime(2026, 11, 14),
    );
  });
}
