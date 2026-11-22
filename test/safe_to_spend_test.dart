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
    expect(result.availableToday, 500);
    expect(result.extra, 1000);
    expect(result.safeToSpend, 1000);
  });

  test('accounts for spending already deducted from balance', () {
    final result = SafeToSpend.calculate(
      balance: 7700,
      dailyBudget: 500,
      daysLeft: 14,
      spentToday: 300,
    );

    expect(result.reservedFuture, 6500);
    expect(result.availableToday, 200);
    expect(result.extra, 1200);
    expect(result.safeToSpend, 1200);
  });

  test('lets surplus absorb spending above today allocation', () {
    final result = SafeToSpend.calculate(
      balance: 7200,
      dailyBudget: 500,
      daysLeft: 14,
      spentToday: 800,
    );

    expect(result.availableToday, -300);
    expect(result.extra, 700);
    expect(result.safeToSpend, 700);
  });

  test('reports a shortfall when balance cannot cover future budget', () {
    final result = SafeToSpend.calculate(
      balance: 7000,
      dailyBudget: 500,
      daysLeft: 15,
      spentToday: 0,
    );

    expect(result.availableToday, 500);
    expect(result.extra, 0);
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
    expect(firstCase.effectiveDailyBudget, 500);
    expect(firstCase.isSevereShortfall, isFalse);
    expect(secondCase.safeToSpend, 200);
    expect(secondCase.effectiveDailyBudget, 500);
    expect(secondCase.isSevereShortfall, isFalse);
  });

  test('zero balance reduces effective budget to zero with warning state', () {
    final result = SafeToSpend.calculate(
      balance: 0,
      dailyBudget: 500,
      daysLeft: 14,
      spentToday: 0,
    );

    expect(result.safeToSpend, -6500);
    expect(result.effectiveDailyBudget, 0);
    expect(result.extra, -6500);
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
    expect(recovered.safeToSpend, 500);
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
    expect(result.availableToday, 500);
    expect(result.extra, 800);
    expect(result.safeToSpend, 800);

    final passedPayday = SafeToSpend.calculate(
      balance: 800,
      dailyBudget: 500,
      daysLeft: -3,
      spentToday: 0,
    );
    expect(passedPayday.daysLeft, 0);
    expect(passedPayday.availableToday, 500);
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

      expect(result.availableToday, 500);
      expect(result.extra, 800);
      expect(result.safeToSpend, 800);
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

    expect(negativeBalance.availableToday, 500);
    expect(negativeBalance.extra, -7100);
    expect(zeroBalance.availableToday, 500);
    expect(zeroBalance.extra, -7000);
    expect(zeroAllocation.availableToday, 0);
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

    expect(firstDay.safeToSpend, 1000);
    expect(afterSpending300.safeToSpend, 1200);
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
    expect(formatPeso(-350), '-₱350.00');
  });

  test(
    'overspending adjusts daily budget per day and keeps a negative safe to spend',
    () {
      // Weekly budget: 7,000, 1,000/day. Day 1: spent 1,100.
      final overspentCase = SafeToSpend.calculate(
        balance: 5900,
        dailyBudget: 1000,
        daysLeft: 7,
        spentToday: 1100,
        totalCycleDays: 7,
        cycleSpentBeforeToday: 0,
      );

      // The user is -100 below the future reserve.
      expect(overspentCase.safeToSpend, -100);
      // Adjusted daily budget: (7000 - 1100) / 6 = 5900 / 6 = 983.33/day
      expect(overspentCase.effectiveDailyBudget, closeTo(983.33, 0.01));
    },
  );

  test(
    'undoing recent overspent expense refreshes safe to spend and restored daily budget',
    () {
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
    },
  );

  test('deducts upcoming unpaid expense bills from safeToSpend without affecting balance', () {
    // User scenario: balance = 5376, dailyBudget = 200, daysLeft = 9 (futureDays = 8, reservedFuture = 1600)
    // Water bill = 2000 unpaid
    final withBill = SafeToSpend.calculate(
      balance: 5376,
      dailyBudget: 200,
      daysLeft: 9,
      spentToday: 0,
      upcomingBills: 2000,
    );

    expect(withBill.reservedFuture, 1600);
    expect(withBill.upcomingBills, 2000);
    // 5376 - 1600 - 2000 = 1776
    expect(withBill.safeToSpend, 1776);
    expect(withBill.extra, 1776);
  });
}
