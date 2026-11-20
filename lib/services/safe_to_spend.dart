import 'dart:math' as math;

import 'package:intl/intl.dart';

String formatPeso(double amount) =>
    '₱${NumberFormat('#,##0.00').format(amount)}';

enum PayFrequency {
  monthly,
  twiceMonthly,
  weekly,
  everyTwoWeeks,
  every15Days,
  every30Days,
  custom,
}

int _localDayNumber(DateTime date) {
  final year = date.year;
  final month = date.month;
  final day = date.day;
  final adjustedYear = year - (month <= 2 ? 1 : 0);
  final era = adjustedYear ~/ 400;
  final yearOfEra = adjustedYear - era * 400;
  final adjustedMonth = month + (month > 2 ? -3 : 9);
  final dayOfYear = (153 * adjustedMonth + 2) ~/ 5 + day - 1;
  final dayOfEra =
      yearOfEra * 365 + yearOfEra ~/ 4 - yearOfEra ~/ 100 + dayOfYear;
  return era * 146097 + dayOfEra;
}

int calculateDaysLeft({required DateTime today, required DateTime payday}) {
  final localToday = today.toLocal();
  final localPayday = payday.toLocal();
  final difference = _localDayNumber(localPayday) - _localDayNumber(localToday);
  return difference >= 0 ? difference + 1 : 0;
}

double? calculateSuggestedDailyBudget({
  required double balance,
  required DateTime today,
  required DateTime payday,
}) {
  if (!balance.isFinite || balance <= 0) return null;
  final daysUntilPayday =
      _localDayNumber(payday.toLocal()) - _localDayNumber(today.toLocal());
  if (daysUntilPayday < 0) return null;
  return balance / math.max(1, daysUntilPayday);
}

DateTime nextPayday({
  required DateTime today,
  required PayFrequency frequency,
  int payday1 = 15,
  int? payday2 = 30,
  int? intervalDays,
  DateTime? anchor,
}) {
  final localToday = today.toLocal();
  final todayDate = DateTime(localToday.year, localToday.month, localToday.day);
  if (frequency == PayFrequency.monthly ||
      frequency == PayFrequency.twiceMonthly) {
    final paydays = frequency == PayFrequency.monthly
        ? [payday1]
      : [payday1, ?payday2];
    DateTime? earliest;
    for (var monthOffset = 0; monthOffset <= 1; monthOffset++) {
      final month = DateTime(todayDate.year, todayDate.month + monthOffset, 1);
      final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
      for (final payday in paydays) {
        if (payday < 1 || payday > 31) continue;
        final candidate = DateTime(
          month.year,
          month.month,
          math.min(payday, daysInMonth),
        );
        if (!candidate.isBefore(todayDate) &&
            (earliest == null || candidate.isBefore(earliest))) {
          earliest = candidate;
        }
      }
    }
    return earliest ?? todayDate;
  }

  final days =
      intervalDays ??
      switch (frequency) {
        PayFrequency.weekly => 7,
        PayFrequency.everyTwoWeeks => 14,
        PayFrequency.every15Days => 15,
        PayFrequency.every30Days => 30,
        PayFrequency.custom => 1,
        PayFrequency.monthly || PayFrequency.twiceMonthly => 1,
      };
  final safeInterval = days.clamp(1, 90);
  final localAnchor = anchor?.toLocal();
  if (localAnchor == null) return todayDate;
  final anchorDate = DateTime(
    localAnchor.year,
    localAnchor.month,
    localAnchor.day,
  );
  if (!anchorDate.isBefore(todayDate)) return anchorDate;

  final elapsedDays = _localDayNumber(todayDate) - _localDayNumber(anchorDate);
  final intervalCount = (elapsedDays + safeInterval - 1) ~/ safeInterval;
  return DateTime(
    anchorDate.year,
    anchorDate.month,
    anchorDate.day + intervalCount * safeInterval,
  );
}

@Deprecated('Use nextPayday with an explicit PayFrequency.')
DateTime calculateNextPayday({
  required DateTime today,
  required List<int> paydayDays,
}) {
  final normalized = paydayDays.toSet().toList()..sort();
  final result = nextPayday(
    today: today,
    frequency: normalized.length > 1
        ? PayFrequency.twiceMonthly
        : PayFrequency.monthly,
    payday1: normalized.isEmpty ? 15 : normalized.first,
    payday2: normalized.length > 1 ? normalized[1] : null,
  );
  final localToday = today.toLocal();
  final todayDate = DateTime(localToday.year, localToday.month, localToday.day);
  if (result.isAfter(todayDate)) return result;
  return nextPayday(
    today: todayDate.add(const Duration(days: 1)),
    frequency: normalized.length > 1
        ? PayFrequency.twiceMonthly
        : PayFrequency.monthly,
    payday1: normalized.isEmpty ? 15 : normalized.first,
    payday2: normalized.length > 1 ? normalized[1] : null,
  );
}

int getCycleLength({
  required PayFrequency frequency,
  int? intervalDays,
  int payday1 = 15,
  int? payday2,
}) {
  return switch (frequency) {
    PayFrequency.weekly => 7,
    PayFrequency.everyTwoWeeks => 14,
    PayFrequency.every15Days => 15,
    PayFrequency.every30Days => 30,
    PayFrequency.custom =>
      (intervalDays != null && intervalDays > 0) ? intervalDays : 10,
    PayFrequency.monthly => 30,
    PayFrequency.twiceMonthly => 15,
  };
}

class SafeToSpend {
  final double balance;
  final double dailyBudget;
  final int daysLeft;
  final double spentToday;
  final double reservedFuture;
  final double availableToday;
  final double extra;
  final double safeToSpend;
  final double effectiveDailyBudget;
  final bool isSevereShortfall;

  const SafeToSpend({
    required this.balance,
    required this.dailyBudget,
    required this.daysLeft,
    required this.spentToday,
    required this.reservedFuture,
    required this.availableToday,
    required this.extra,
    required this.safeToSpend,
    required this.effectiveDailyBudget,
    required this.isSevereShortfall,
  });

  factory SafeToSpend.calculate({
    required double balance,
    required double dailyBudget,
    required int daysLeft,
    required double spentToday,
    int? totalCycleDays,           // kept for API compatibility, unused
    double cycleSpentBeforeToday = 0.0, // kept for API compatibility, unused
  }) {
    final validBalance = balance.isFinite ? balance : 0.0;
    final validBudget = dailyBudget.isFinite ? math.max(0.0, dailyBudget) : 0.0;
    final validSpentToday =
        spentToday.isFinite ? math.max(0.0, spentToday) : 0.0;

    final remainingDays = math.max(0, daysLeft);

    // Days after today (payday period minus today)
    final futureDays = math.max(0, remainingDays - 1);

    // Money that must be kept for future days
    final reservedFuture = validBudget * futureDays;

    // Surplus above what's needed for future days.
    // NOTE: validBalance is already the current balance AFTER today's spending
    // (FinanceStorage updates the account balance on every transaction), so we
    // do NOT subtract spentToday again here — that would double-count it.
    //
    // Logic (user example):
    //   balance=6940, dailyBudget=400, daysLeft=13
    //   futureDays=12, reservedFuture=4800
    //   extra = 6940 - 4800 = 2140  → safe to spend
    //
    //   If 500 spent today → balance becomes 6440
    //   extra = 6440 - 4800 = 1640  → safe to spend
    //
    //   If 2240 spent today → balance becomes 4700
    //   extra = 4700 - 4800 = -100  → safe to spend = 0
    //   effectiveDailyBudget = 4700 / 12 = 391.67
    final extra = validBalance - reservedFuture;
    final safeToSpend = math.max(0.0, extra);

    // When we've dipped into the future reserve (extra < 0), recalculate the
    // daily budget across remaining future days so the user knows their new cap.
    final effectiveDailyBudget = (extra < 0 && futureDays > 0)
        ? math.max(0.0, validBalance / futureDays)
        : validBudget;

    final isSevereShortfall = extra < 0 &&
        validBudget > 0 &&
        effectiveDailyBudget < validBudget * 0.4;

    // availableToday: today's daily cap minus what's already been spent today.
    // Used for the daily progress bar (can be negative if overspent today's cap).
    final availableToday = validBudget - validSpentToday;

    return SafeToSpend(
      balance: validBalance,
      dailyBudget: validBudget,
      daysLeft: remainingDays,
      spentToday: validSpentToday,
      reservedFuture: reservedFuture,
      availableToday: availableToday,
      extra: extra,
      safeToSpend: safeToSpend,
      effectiveDailyBudget: effectiveDailyBudget,
      isSevereShortfall: isSevereShortfall,
    );
  }
}

