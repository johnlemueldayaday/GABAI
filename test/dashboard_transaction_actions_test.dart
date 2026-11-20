import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gabay/config/app_theme.dart';
import 'package:gabay/models/finance_models.dart';
import 'package:gabay/pages/dashboard.dart';
import 'package:gabay/services/finance_storage.dart';
import 'package:gabay/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SettingsService().load();
    await FinanceStorage.saveAccounts([
      Account(id: 'cash', name: 'Cash', type: 'Cash', balance: 1000),
    ]);
  });

  testWidgets('dashboard Income action opens the modal on the Income tab', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: DashboardPage()));
    await tester.pumpAndSettle();

    final incomeAction = find.byKey(const ValueKey('dashboard_income_action'));
    await tester.ensureVisible(incomeAction);
    await tester.tap(incomeAction);
    await tester.pumpAndSettle();

    expect(find.text('Log Transaction'), findsOneWidget);
    final incomeText = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const ValueKey('transaction_income_tab')),
        matching: find.text('Income'),
      ),
    );
    expect(incomeText.style?.color, kPrimary);

    await tester.tap(find.byKey(const ValueKey('transaction_expense_tab')));
    await tester.pump();
    final expenseText = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const ValueKey('transaction_expense_tab')),
        matching: find.text('Expense'),
      ),
    );
    expect(expenseText.style?.color, Colors.red);
  });

  testWidgets('dashboard Expense action opens the modal on the Expense tab', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: DashboardPage()));
    await tester.pumpAndSettle();

    final expenseAction = find.byKey(
      const ValueKey('dashboard_expense_action'),
    );
    await tester.ensureVisible(expenseAction);
    await tester.tap(expenseAction);
    await tester.pumpAndSettle();

    expect(find.text('Log Transaction'), findsOneWidget);
    final expenseText = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const ValueKey('transaction_expense_tab')),
        matching: find.text('Expense'),
      ),
    );
    expect(expenseText.style?.color, Colors.red);
  });

  testWidgets('dashboard shows debt income with a concise title', (
    tester,
  ) async {
    await FinanceStorage.saveTransactions([
      FinanceTransaction(
        id: 'debt-income',
        amount: 100,
        accountId: 'cash',
        accountName: 'Cash',
        type: 'INCOME',
        category: 'Reimbursement',
        description: 'Debt Lance',
      ),
    ]);

    await tester.pumpWidget(const MaterialApp(home: DashboardPage()));
    await tester.pumpAndSettle();

    final recentIncome = find.byKey(const ValueKey('recent_income_section'));
    await tester.scrollUntilVisible(
      recentIncome,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.descendant(of: recentIncome, matching: find.text('Lance Debt')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: recentIncome,
        matching: find.text('Debt Lance Reimbursement'),
      ),
      findsNothing,
    );
  });
}
