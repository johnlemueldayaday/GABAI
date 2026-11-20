import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gabay/models/finance_models.dart';
import 'package:gabay/models/grocery_models.dart';
import 'package:gabay/pages/analytics.dart';
import 'package:gabay/services/finance_storage.dart';
import 'package:gabay/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SettingsService().load();
    AppState.recentLists = [];
  });

  testWidgets('transfer legs are excluded from Analytics income and spending', (
    tester,
  ) async {
    final now = DateTime.now();
    await FinanceStorage.saveTransactions([
      FinanceTransaction(
        id: 'transfer-out',
        amount: 2200,
        accountId: 'cash',
        accountName: 'Cash',
        type: 'EXPENSE',
        category: 'Transfer',
        description: 'Transfer to GCash',
        date: now,
      ),
      FinanceTransaction(
        id: 'transfer-in',
        amount: 2200,
        accountId: 'gcash',
        accountName: 'GCash',
        type: 'INCOME',
        category: 'Transfer',
        description: 'Transfer from Cash',
        date: now,
      ),
      FinanceTransaction(
        id: 'single-transfer',
        amount: 750,
        accountId: 'bank',
        accountName: 'Bank',
        type: 'TRANSFER',
        category: 'Transfer',
        description: 'Transmitted to Cash',
        destinationAccountId: 'cash',
        destinationAccountName: 'Cash',
        date: now,
      ),
      FinanceTransaction(
        id: 'salary',
        amount: 6000,
        accountId: 'bank',
        accountName: 'Bank',
        type: 'INCOME',
        category: 'Salary',
        date: now,
      ),
      FinanceTransaction(
        id: 'lunch',
        amount: 300,
        accountId: 'cash',
        accountName: 'Cash',
        type: 'EXPENSE',
        category: 'Food',
        description: 'Lunch',
        date: now,
      ),
      FinanceTransaction(
        id: 'transaction-fee',
        amount: 15,
        accountId: 'cash',
        accountName: 'Cash',
        type: 'EXPENSE',
        category: 'Other',
        description: 'Transaction Fee',
        date: now,
      ),
    ]);

    await tester.pumpWidget(const MaterialApp(home: AnalyticsPage()));
    await tester.pumpAndSettle();

    expect(find.text('₱6,000.00'), findsOneWidget);
    expect(find.text('₱315.00'), findsWidgets);
    expect(find.text('₱300.00'), findsWidgets);
    expect(find.text('Transfer'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
