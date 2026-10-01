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
  }) {
    final validBalance = balance.isFinite ? balance : 0.0;
    final validBudget = dailyBudget.isFinite ? math.max(0.0, dailyBudget) : 0.0;
    final validSpentToday = spentToday.isFinite
        ? math.max(0.0, spentToday)
        : 0.0;
    final remainingDays = math.max(0, daysLeft);
    final reservedFuture = validBudget * math.max(0, remainingDays - 1);
    final availableToday = validBalance - reservedFuture;
    final extra = validBalance - validBudget * remainingDays;
    final hasShortfall = extra < 0;
    final effectiveDailyBudget = hasShortfall
        ? (remainingDays > 0
              ? math.max(0.0, validBalance / remainingDays)
              : 0.0)
        : validBudget;
    final isSevereShortfall =
        hasShortfall &&
        validBudget > 0 &&
        effectiveDailyBudget < validBudget * 0.4;

    return SafeToSpend(
      balance: validBalance,
      dailyBudget: validBudget,
      daysLeft: remainingDays,
      spentToday: validSpentToday,
      reservedFuture: reservedFuture,
      availableToday: availableToday,
      extra: extra,
      safeToSpend: math.max(extra, 0.0),
      effectiveDailyBudget: effectiveDailyBudget,
      isSevereShortfall: isSevereShortfall,
    );
  }
}
