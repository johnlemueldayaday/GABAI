import 'package:home_widget/home_widget.dart';
import 'package:flutter/foundation.dart';

class WidgetService {
  static const String iOSAppGroupId = 'group.com.johnlemueldayaday.gabay';

  // Must match the `kind` strings in GABAY.swift exactly.
  static const List<String> _widgetKinds = [
    'SafeToSpendWidget',
    'WeeklyBudgetWidget',
  ];

  static Future<bool> updateSafeToSpendWidget({
    required double safeToSpend,
    required double weekSpent,
    required double weekBudget,
  }) async {
    try {
      final groupConfigured = await HomeWidget.setAppGroupId(iOSAppGroupId);
      if (groupConfigured != true) {
        throw StateError('iOS did not configure the GABAY widget App Group.');
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
      if (safeToSpendSaved != true ||
          weekSpentSaved != true ||
          weekBudgetSaved != true) {
        throw StateError('GABAY could not save the widget data.');
      }

      for (final kind in _widgetKinds) {
        final updated = await HomeWidget.updateWidget(iOSName: kind);
        if (updated != true) {
          throw StateError('iOS did not refresh the $kind widget.');
        }
      }
      return true;
    } catch (error, stackTrace) {
      debugPrint('Error updating GABAY widgets: $error');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }
}
