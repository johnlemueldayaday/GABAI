import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gabay/pages/cart.dart';
import 'package:gabay/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('GroceryApp renders splash screen', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'settings_onboarding_complete': true,
    });
    await SettingsService().load();

    await tester.pumpWidget(const GroceryApp());
    expect(find.text('GABAI'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('SAFE TO SPEND'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
