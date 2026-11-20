import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gabay/models/finance_models.dart';
import 'package:gabay/pages/wallet.dart';
import 'package:gabay/services/finance_storage.dart';
import 'package:gabay/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('account balance visibility defaults to visible and persists', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await SettingsService().load();
    await FinanceStorage.saveAccounts([
      Account(id: 'cash', name: 'Cash', type: 'Cash', balance: 2200),
      Account(id: 'bdo', name: 'BDO', type: 'Bank', balance: 9600),
    ]);
    await FinanceStorage.saveTransactions([
      FinanceTransaction(
        id: 'bdo-cash-transfer',
        amount: 300,
        accountId: 'bdo',
        accountName: 'BDO',
        type: 'TRANSFER',
        category: 'Transfer',
        description: 'Transmitted to Cash',
        destinationAccountId: 'cash',
        destinationAccountName: 'Cash',
      ),
      FinanceTransaction(
        id: 'legacy-transfer-out',
        amount: 300,
        accountId: 'bdo',
        accountName: 'BDO',
        type: 'EXPENSE',
        category: 'Transfer',
        description: 'Transfer to Cash',
      ),
      FinanceTransaction(
        id: 'legacy-transfer-in',
        amount: 300,
        accountId: 'cash',
        accountName: 'Cash',
        type: 'INCOME',
        category: 'Transfer',
        description: 'Transfer from BDO',
      ),
    ]);

    await tester.pumpWidget(const MaterialApp(home: WalletPage()));
    await tester.pumpAndSettle();

    expect(find.text('₱2,200.00'), findsOneWidget);
    expect(find.text('₱9,600.00'), findsOneWidget);
    expect(find.text('Transmitted to Cash'), findsNWidgets(2));
    expect(find.text('Transmitted to BDO'), findsNothing);
    expect(find.text('from BDO'), findsNWidgets(2));
    expect(find.text('₱300.00'), findsNWidgets(2));
    expect(find.byIcon(Icons.swap_horiz_rounded), findsNothing);
    expect(
      find.byWidgetPredicate((widget) {
        if (widget is! Image) return false;
        final image = widget.image;
        return image is AssetImage &&
            image.assetName == 'assets/images/transfer_logged.png';
      }),
      findsNWidgets(2),
    );

    final transferRow = find.byKey(
      const ValueKey('wallet_transaction_undo_bdo-cash-transfer'),
    );
    final transferAmount = find.descendant(
      of: transferRow,
      matching: find.text('₱300.00'),
    );
    final destinationIcon = find.descendant(
      of: transferRow,
      matching: find.byKey(
        const ValueKey('transfer_destination_icon_bdo-cash-transfer'),
      ),
    );
    expect(
      tester.widget<Text>(transferAmount).style?.color,
      const Color(0xFF3B82F6),
    );
    expect(
      tester.getTopLeft(destinationIcon).dy,
      greaterThan(tester.getTopLeft(transferAmount).dy),
    );

    expect(find.byTooltip('Show accounts'), findsNothing);
    expect(find.byTooltip('Hide Cash balance'), findsOneWidget);

    await tester.tap(find.byTooltip('Hide Cash balance'));
    await tester.pumpAndSettle();
    expect(find.text('*****'), findsOneWidget);
    expect(find.text('₱2,200.00'), findsNothing);
    expect(find.text('₱9,600.00'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pumpWidget(const MaterialApp(home: WalletPage()));
    await tester.pumpAndSettle();
    expect(find.text('*****'), findsOneWidget);

    await tester.tap(find.byTooltip('Show Cash balance'));
    await tester.pumpAndSettle();
    expect(find.text('₱2,200.00'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pumpWidget(const MaterialApp(home: WalletPage()));
    await tester.pumpAndSettle();
    expect(find.text('₱2,200.00'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
