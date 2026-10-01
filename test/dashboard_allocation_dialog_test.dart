import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gabay/pages/dashboard.dart';
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

    await tester.enterText(find.byType(TextField), '500');
    await tester.tap(find.byType(DropdownButtonFormField<PayFrequency>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Every 15 days').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('Next payday:'), findsWidgets);
    expect(find.byType(DropdownButtonFormField<int>), findsNothing);
    await tester.tap(find.byType(OutlinedButton).last);
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
}
