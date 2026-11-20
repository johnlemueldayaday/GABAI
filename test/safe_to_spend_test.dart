import 'package:flutter_test/flutter_test.dart';
import 'package:gabay/services/safe_to_spend.dart';

void main() {
  test('suggested budget divides balance by days until payday', () {
    expect(
      calculateSuggestedDailyBudget(
        balance: 10000,
        today: DateTime(2026, 11, 18),
        payday: DateTime(2026, 11, 30),
      ),
      closeTo(10000 / 12, 0.001),
    );
    expect(
      calculateSuggestedDailyBudget(
        balance: 10000,
        today: DateTime(2026, 11, 30),
        payday: DateTime(2026, 11, 30),
      ),
      10000,
    );
  });

  test('uses surplus balance for today', () {
    final result = SafeToSpend.calculate(
      balance: 8000,
      dailyBudget: 500,
      daysLeft: 15,
      spentToday: 0,
    );

    expect(result.reservedFuture, 7000);
    expect(result.availableToday, 1000);
    expect(result.extra, 500);
    expect(result.safeToSpend, 500);
  });

  test('accounts for spending already deducted from balance', () {
    final result = SafeToSpend.calculate(
      balance: 7700,
      dailyBudget: 500,
      daysLeft: 14,
      spentToday: 300,
    );

    expect(result.reservedFuture, 6500);
    expect(result.availableToday, 1200);
    expect(result.extra, 700);
    expect(result.safeToSpend, 700);
  });

  test('lets surplus absorb spending above today allocation', () {
    final result = SafeToSpend.calculate(
      balance: 7200,
      dailyBudget: 500,
      daysLeft: 14,
      spentToday: 800,
    );

    expect(result.availableToday, 700);
    expect(result.extra, 200);
    expect(result.safeToSpend, 200);
  });

  test('reports a shortfall when balance cannot cover future budget', () {
    final result = SafeToSpend.calculate(
      balance: 7000,
      dailyBudget: 500,
      daysLeft: 15,
      spentToday: 0,
    );

    expect(result.availableToday, 0);
    expect(result.extra, -500);
    expect(result.safeToSpend, 0);
  });

  test('reduces effective daily budget based on current shortfall', () {
    final firstCase = SafeToSpend.calculate(
      balance: 6500,
      dailyBudget: 500,
      daysLeft: 14,
      spentToday: 0,
    );
    final secondCase = SafeToSpend.calculate(
      balance: 6200,
      dailyBudget: 500,
      daysLeft: 13,
      spentToday: 0,
    );

    expect(firstCase.safeToSpend, 0);
    expect(firstCase.effectiveDailyBudget, closeTo(464.29, 0.01));
    expect(firstCase.isSevereShortfall, isFalse);
    expect(secondCase.safeToSpend, 0);
    expect(secondCase.effectiveDailyBudget, closeTo(476.92, 0.01));
    expect(secondCase.isSevereShortfall, isFalse);
  });

  test('zero balance reduces effective budget to zero with warning state', () {
    final result = SafeToSpend.calculate(
      balance: 0,
      dailyBudget: 500,
      daysLeft: 14,
      spentToday: 0,
    );

    expect(result.safeToSpend, 0);
    expect(result.effectiveDailyBudget, 0);
    expect(result.extra, -7000);
    expect(result.isSevereShortfall, isTrue);
  });

  test('effective budget returns to full guide when balance recovers', () {
    final recovered = SafeToSpend.calculate(
      balance: 7000,
      dailyBudget: 500,
      daysLeft: 14,
      spentToday: 0,
    );

    expect(recovered.effectiveDailyBudget, 500);
    expect(recovered.safeToSpend, 0);
    expect(recovered.isSevereShortfall, isFalse);
  });

  test('payday today reserves no future days', () {
    final result = SafeToSpend.calculate(
      balance: 800,
      dailyBudget: 500,
      daysLeft: 0,
      spentToday: 0,
    );

    expect(result.daysLeft, 0);
    expect(result.availableToday, 800);
    expect(result.extra, 800);
    expect(result.safeToSpend, 800);

    final passedPayday = SafeToSpend.calculate(
      balance: 800,
      dailyBudget: 500,
      daysLeft: -3,
      spentToday: 0,
    );
    expect(passedPayday.daysLeft, 0);
    expect(passedPayday.availableToday, 800);
    expect(passedPayday.safeToSpend, 800);
  });

  test(
    'one day left assigns the balance to today and nothing to future days',
    () {
      final result = SafeToSpend.calculate(
        balance: 800,
        dailyBudget: 500,
        daysLeft: 1,
        spentToday: 0,
      );

      expect(result.availableToday, 800);
      expect(result.extra, 300);
      expect(result.safeToSpend, 300);
    },
  );

  test('handles negative balance and zero allocation', () {
    final negativeBalance = SafeToSpend.calculate(
      balance: -100,
      dailyBudget: 500,
      daysLeft: 15,
      spentToday: 0,
    );
    final zeroAllocation = SafeToSpend.calculate(
      balance: 800,
      dailyBudget: 0,
      daysLeft: 15,
      spentToday: 0,
    );
    final zeroBalance = SafeToSpend.calculate(
      balance: 0,
      dailyBudget: 500,
      daysLeft: 15,
      spentToday: 0,
    );

    expect(negativeBalance.availableToday, -7100);
    expect(negativeBalance.extra, -7600);
    expect(zeroBalance.availableToday, -7000);
    expect(zeroBalance.extra, -7500);
    expect(zeroAllocation.availableToday, 800);
    expect(zeroAllocation.extra, 800);
    expect(zeroAllocation.safeToSpend, 800);
  });

  test('counts local calendar days until payday and excludes payday', () {
    expect(
      calculateDaysLeft(
        today: DateTime(2026, 10, 1),
        payday: DateTime(2026, 10, 15),
      ),
      15,
    );
    expect(
      calculateDaysLeft(
        today: DateTime(2026, 10, 14),
        payday: DateTime(2026, 10, 15),
      ),
      2,
    );
    expect(
      calculateDaysLeft(
        today: DateTime(2026, 10, 15),
        payday: DateTime(2026, 10, 15),
      ),
      1,
    );
  });

  test('finds next payday from editable monthly dates', () {
    expect(
      calculateNextPayday(today: DateTime(2026, 10, 1), paydayDays: [15, 30]),
      DateTime(2026, 10, 15),
    );
    expect(
      calculateNextPayday(today: DateTime(2026, 10, 15), paydayDays: [15, 30]),
      DateTime(2026, 10, 30),
    );
    expect(
      calculateNextPayday(today: DateTime(2026, 10, 21), paydayDays: [5, 20]),
      DateTime(2026, 11, 5),
    );
    expect(
      calculateNextPayday(today: DateTime(2026, 2, 28), paydayDays: [15, 30]),
      DateTime(2026, 3, 15),
    );
  });

  test('unspent budget remains in balance and raises next-day safe amount', () {
    final firstDay = SafeToSpend.calculate(
      balance: 8000,
      dailyBudget: 500,
      daysLeft: 15,
      spentToday: 0,
    );
    final afterSpending300 = SafeToSpend.calculate(
      balance: 7700,
      dailyBudget: 500,
      daysLeft: 14,
      spentToday: 0,
    );

    expect(firstDay.safeToSpend, 500);
    expect(afterSpending300.safeToSpend, 700);
  });

  test('finds next configured payday and clamps dates to month end', () {
    expect(
      calculateNextPayday(today: DateTime(2026, 10, 1), paydayDays: [15, 30]),
      DateTime(2026, 10, 15),
    );
    expect(
      calculateNextPayday(today: DateTime(2026, 10, 15), paydayDays: [15, 30]),
      DateTime(2026, 10, 30),
    );
    expect(
      calculateNextPayday(today: DateTime(2026, 2, 28), paydayDays: [15, 30]),
      DateTime(2026, 3, 15),
    );
  });

  test('formats pesos with separators and two decimals', () {
    expect(formatPeso(8000), '₱8,000.00');
  });

  test('overspending adjusts daily budget per day and sets safe to spend to 0', () {
    // Weekly budget: 7,000, 1,000/day. Day 1: spent 1,100.
    final overspentCase = SafeToSpend.calculate(
      balance: 5900,
      dailyBudget: 1000,
      daysLeft: 7,
      spentToday: 1100,
      totalCycleDays: 7,
      cycleSpentBeforeToday: 0,
    );

    // 0 safe to spend for today because 1100 >= 1000
    expect(overspentCase.safeToSpend, 0);
    // Adjusted daily budget: (7000 - 1100) / 6 = 5900 / 6 = 983.33/day
    expect(overspentCase.effectiveDailyBudget, closeTo(983.33, 0.01));
  });

  test('undoing recent overspent expense refreshes safe to spend and restored daily budget', () {
    // Undoing the 1,100 expense restores spentToday to 0
    final undoneCase = SafeToSpend.calculate(
      balance: 7000,
      dailyBudget: 1000,
      daysLeft: 7,
      spentToday: 0,
      totalCycleDays: 7,
      cycleSpentBeforeToday: 0,
    );

    expect(undoneCase.safeToSpend, 1000);
    expect(undoneCase.effectiveDailyBudget, 1000);
  });
}
