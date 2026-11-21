import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gabay/models/finance_models.dart';
import 'package:gabay/pages/dashboard.dart';
import 'package:gabay/services/finance_storage.dart';
import 'package:gabay/services/safe_to_spend.dart';
import 'package:gabay/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('choosing an interval frequency persists and updates the card', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await SettingsService().load();

    await tester.pumpWidget(const MaterialApp(home: DashboardPage()));
    await tester.pumpAndSettle();

    final spendCard = find.byKey(const ValueKey('safe_to_spend_card'));
    await tester.ensureVisible(spendCard);
    await tester.pumpAndSettle();
    await tester.tap(spendCard);
    await tester.pumpAndSettle();

    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final settings = SettingsService();
    final nextPaydayDate = nextPayday(
      today: todayDate,
      frequency: settings.payFrequency,
      payday1: settings.payday1,
      payday2: settings.payday2,
      intervalDays: settings.intervalDays,
      anchor: settings.anchorPayday,
    );
    final daysUntilPayday =
        calculateDaysLeft(today: todayDate, payday: nextPaydayDate) - 1;
    final countdownFinder = find.byWidgetPredicate(
      (widget) =>
          widget is RichText &&
          widget.text.toPlainText().endsWith(' days until next payday'),
    );
    expect(countdownFinder, findsOneWidget);
    final countdown = tester.widget<RichText>(countdownFinder);
    expect(
      countdown.text.toPlainText(),
      '$daysUntilPayday days until next payday',
    );
    final spans = _textSpans(countdown.text);
    final numberSpan = spans.singleWhere(
      (span) => span.text == '$daysUntilPayday',
    );
    final labelSpan = spans.singleWhere(
      (span) => span.text == ' days until next payday',
    );
    expect(numberSpan.style?.fontWeight, FontWeight.bold);
    expect(labelSpan.style?.fontWeight, isNot(FontWeight.bold));

    await tester.enterText(find.byType(TextField), '500');
    await tester.tap(find.byKey(const ValueKey('pay_frequency_picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Every 15 days').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('Next payday:'), findsWidgets);
    expect(find.byKey(const ValueKey('payday_picker')), findsNothing);
    await tester.tap(find.text('Next payday anchor'));
    await tester.pumpAndSettle();
    expect(find.byType(CalendarDatePicker), findsOneWidget);
    await tester.tap(find.text('Cancel').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(SettingsService().dailySpendingAllocation, 500);
    expect(SettingsService().payFrequency, PayFrequency.every15Days);
    expect(SettingsService().intervalDays, 15);
    expect(SettingsService().anchorPayday, isNotNull);
    expect(find.textContaining('Next payday:'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('suggested budget fills the field and allows manual override', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await SettingsService().load();
    final today = DateTime.now();
    await SettingsService().setPaySchedule(
      frequency: PayFrequency.everyTwoWeeks,
      payday1: 15,
      intervalDays: 14,
      anchorPayday: DateTime(today.year, today.month, today.day + 1),
    );
    await FinanceStorage.saveAccounts([
      Account(id: 'cash', name: 'Cash', type: 'Cash', balance: 1200),
    ]);

    await tester.pumpWidget(const MaterialApp(home: DashboardPage()));
    await tester.pumpAndSettle();

    final spendCard = find.byKey(const ValueKey('safe_to_spend_card'));
    await tester.ensureVisible(spendCard);
    await tester.tap(spendCard);
    await tester.pumpAndSettle();

    final budgetField = find.byKey(const ValueKey('daily_budget_input'));
    await tester.enterText(budgetField, '123');
    await tester.tap(
      find.byKey(const ValueKey('suggested_daily_budget_button')),
    );
    await tester.pump();
    expect(tester.widget<TextField>(budgetField).controller!.text, '1200.00');

    await tester.enterText(budgetField, '750');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(SettingsService().dailySpendingAllocation, 750);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'dashboard greeting shows a bubble for the current budget range',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await SettingsService().load();
      await SettingsService().setDailySpendingAllocation(100);
      await FinanceStorage.saveAccounts([
        Account(id: 'cash', name: 'Cash', type: 'Cash', balance: 1000),
      ]);
      await FinanceStorage.saveTransactions([
        FinanceTransaction(
          id: 'today-transfer-out',
          amount: 900,
          accountId: 'cash',
          accountName: 'Cash',
          type: 'EXPENSE',
          category: 'Transfer',
          description: 'Transfer to GCash',
          date: DateTime.now(),
        ),
        FinanceTransaction(
          id: 'today-transfer-in',
          amount: 900,
          accountId: 'gcash',
          accountName: 'GCash',
          type: 'INCOME',
          category: 'Transfer',
          description: 'Transfer from Cash',
          date: DateTime.now(),
        ),
        FinanceTransaction(
          id: 'today-expense',
          amount: 60,
          accountId: 'cash',
          accountName: 'Cash',
          type: 'EXPENSE',
          category: 'Food',
          description: 'Lunch',
          date: DateTime.now(),
        ),
      ]);

      await tester.pumpWidget(const MaterialApp(home: DashboardPage()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Text &&
              [
                'halfway through your safe-to-spend',
                'Half of your budget is gone',
                '₱40.00 left',
                'Chill muna sa spending',
                'Still safe, but',
                "you've used 60% already",
              ].any((fragment) => widget.data?.contains(fragment) ?? false),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}

Iterable<TextSpan> _textSpans(InlineSpan span) sync* {
  if (span is! TextSpan) return;
  yield span;
  for (final child in span.children ?? const <InlineSpan>[]) {
    yield* _textSpans(child);
  }
}
