import 'package:home_widget/home_widget.dart';
import 'package:flutter/foundation.dart';

class WidgetService {
  static const String iOSAppGroupId = 'group.com.johnlemueldayaday.gabay';

  // Must match the `kind` strings in GABAI.swift exactly.
  static const List<String> _widgetKinds = [
    'SafeToSpendWidget',
    'WeeklyBudgetWidget',
  ];

  static Future<bool> updateSafeToSpendWidget({
    required double safeToSpend,
    required double weekSpent,
    required double weekBudget,
    double spentToday = 0.0,
    double dailyBudget = 0.0,
    int daysLeft = 0,
  }) async {
    try {
      final groupConfigured = await HomeWidget.setAppGroupId(iOSAppGroupId);
      if (groupConfigured != true) {
        throw StateError('iOS did not configure the GABAI widget App Group.');
      }

      final safeToSpendSaved = await HomeWidget.saveWidgetData<double>(
        'safe_to_spend',
        safeToSpend,
      );
      final weekSpentSaved = await HomeWidget.saveWidgetData<double>(
        'week_spent',
        weekSpent,
      );
      final weekBudgetSaved = await HomeWidget.saveWidgetData<double>(
        'week_budget',
        weekBudget,
      );
      final spentTodaySaved = await HomeWidget.saveWidgetData<double>(
        'spent_today',
        spentToday,
      );
      final dailyBudgetSaved = await HomeWidget.saveWidgetData<double>(
        'daily_budget',
        dailyBudget,
      );
      final daysLeftSaved = await HomeWidget.saveWidgetData<int>(
        'days_left',
        daysLeft,
      );
      if (safeToSpendSaved != true ||
          weekSpentSaved != true ||
          weekBudgetSaved != true ||
          spentTodaySaved != true ||
          dailyBudgetSaved != true ||
          daysLeftSaved != true) {
        throw StateError('GABAI could not save the widget data.');
      }

      for (final kind in _widgetKinds) {
        final updated = await HomeWidget.updateWidget(iOSName: kind);
        if (updated != true) {
          throw StateError('iOS did not refresh the $kind widget.');
        }
      }
      return true;
    } catch (error, stackTrace) {
      debugPrint('Error updating GABAI widgets: $error');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }
}
