import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gabay/models/finance_models.dart';
import 'package:gabay/pages/wallet.dart';
import 'package:gabay/services/finance_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await FinanceStorage.saveAccounts([
      Account(id: 'cash', name: 'Cash', type: 'Cash', balance: 2200),
      Account(id: 'bdo', name: 'BDO', type: 'Bank', balance: 9600),
      Account(id: 'gcash', name: 'GCash', type: 'E-Wallet', balance: 20),
    ]);
  });

  test('transfer is one non-income and non-expense transaction', () async {
    final accounts = await FinanceStorage.loadAccounts();

    await FinanceStorage.transferMoney(
      fromAccount: accounts.firstWhere((account) => account.id == 'bdo'),
      toAccount: accounts.firstWhere((account) => account.id == 'cash'),
      amount: 300,
    );

    final transactions = await FinanceStorage.loadTransactions();
    expect(transactions, hasLength(1));
    final transfer = transactions.single;
    expect(transfer.type, 'TRANSFER');
    expect(transfer.isTransfer, isTrue);
    expect(transfer.isIncome, isFalse);
    expect(transfer.isExpense, isFalse);
    expect(transfer.accountId, 'bdo');
    expect(transfer.destinationAccountId, 'cash');
    expect(transfer.destinationAccountName, 'Cash');
    expect(transfer.description, 'Transmitted to Cash');

    final updatedAccounts = await FinanceStorage.loadAccounts();
    expect(
      updatedAccounts.firstWhere((account) => account.id == 'bdo').balance,
      9300,
    );
    expect(
      updatedAccounts.firstWhere((account) => account.id == 'cash').balance,
      2500,
    );
    expect(await FinanceStorage.getNetWorth(), 11820);
  });

  test(
    'transfer fee is logged as an expense and deducted from the source',
    () async {
      final accounts = await FinanceStorage.loadAccounts();

      await FinanceStorage.transferMoney(
        fromAccount: accounts.firstWhere((account) => account.id == 'bdo'),
        toAccount: accounts.firstWhere((account) => account.id == 'cash'),
        amount: 300,
        fee: 15,
      );

      final transactions = await FinanceStorage.loadTransactions();
      expect(transactions, hasLength(2));
      final fee = transactions.last;
      expect(fee.type, 'EXPENSE');
      expect(fee.isExpense, isTrue);
      expect(fee.category, 'Other');
      expect(fee.description, 'Transaction Fee');
      expect(fee.amount, 15);
      expect(fee.accountId, 'bdo');

      final updatedAccounts = await FinanceStorage.loadAccounts();
      expect(
        updatedAccounts.firstWhere((account) => account.id == 'bdo').balance,
        9285,
      );
      expect(
        updatedAccounts.firstWhere((account) => account.id == 'cash').balance,
        2500,
      );
      expect(await FinanceStorage.getNetWorth(), 11805);
    },
  );

  test('zero-fee transfer does not create an expense', () async {
    final accounts = await FinanceStorage.loadAccounts();

    await FinanceStorage.transferMoney(
      fromAccount: accounts.firstWhere((account) => account.id == 'bdo'),
      toAccount: accounts.firstWhere((account) => account.id == 'cash'),
      amount: 300,
      fee: 0,
    );

    expect(await FinanceStorage.loadTransactions(), hasLength(1));
  });

  test('undoing a transfer restores both account balances', () async {
    final accounts = await FinanceStorage.loadAccounts();
    await FinanceStorage.transferMoney(
      fromAccount: accounts.firstWhere((account) => account.id == 'bdo'),
      toAccount: accounts.firstWhere((account) => account.id == 'cash'),
      amount: 300,
    );
    final transfer = (await FinanceStorage.loadTransactions()).single;

    final deleted = await FinanceStorage.deleteTransaction(transfer.id);

    expect(deleted?.isTransfer, isTrue);
    expect(await FinanceStorage.loadTransactions(), isEmpty);
    final restoredAccounts = await FinanceStorage.loadAccounts();
    expect(
      restoredAccounts.firstWhere((account) => account.id == 'bdo').balance,
      9600,
    );
    expect(
      restoredAccounts.firstWhere((account) => account.id == 'cash').balance,
      2200,
    );
  });

  test('undoing a legacy paired transfer removes both entries', () async {
    await FinanceStorage.saveAccounts([
      Account(id: 'cash', name: 'Cash', type: 'Cash', balance: 2500),
      Account(id: 'bdo', name: 'BDO', type: 'Bank', balance: 9300),
      Account(id: 'gcash', name: 'GCash', type: 'E-Wallet', balance: 20),
    ]);
    await FinanceStorage.saveTransactions([
      FinanceTransaction(
        id: 'legacy_out',
        amount: 300,
        accountId: 'bdo',
        accountName: 'BDO',
        type: 'EXPENSE',
        category: 'Transfer',
        description: 'Transfer to Cash',
      ),
      FinanceTransaction(
        id: 'legacy_in',
        amount: 300,
        accountId: 'cash',
        accountName: 'Cash',
        type: 'INCOME',
        category: 'Transfer',
        description: 'Transfer from BDO',
      ),
    ]);

    await FinanceStorage.deleteTransaction('legacy_out');

    expect(await FinanceStorage.loadTransactions(), isEmpty);
    final restoredAccounts = await FinanceStorage.loadAccounts();
    expect(
      restoredAccounts.firstWhere((account) => account.id == 'bdo').balance,
      9600,
    );
    expect(
      restoredAccounts.firstWhere((account) => account.id == 'cash').balance,
      2200,
    );
  });

  test('insufficient funds checks the selected source account', () async {
    final accounts = await FinanceStorage.loadAccounts();

    await expectLater(
      FinanceStorage.transferMoney(
        fromAccount: accounts.firstWhere((account) => account.id == 'gcash'),
        toAccount: accounts.firstWhere((account) => account.id == 'cash'),
        amount: 300,
      ),
      throwsA(
        isA<Exception>().having(
          (error) => error.toString(),
          'message',
          contains('Insufficient funds in GCash'),
        ),
      ),
    );
    expect(await FinanceStorage.loadTransactions(), isEmpty);
  });

  test('insufficient funds checks transfer amount plus fee', () async {
    final accounts = await FinanceStorage.loadAccounts();

    await expectLater(
      FinanceStorage.transferMoney(
        fromAccount: accounts.firstWhere((account) => account.id == 'gcash'),
        toAccount: accounts.firstWhere((account) => account.id == 'cash'),
        amount: 15,
        fee: 10,
      ),
      throwsA(
        isA<Exception>().having(
          (error) => error.toString(),
          'message',
          allOf(
            contains('Insufficient funds in GCash'),
            contains('Transfer and fee total 25.00'),
          ),
        ),
      ),
    );
    expect(await FinanceStorage.loadTransactions(), isEmpty);
    final source = (await FinanceStorage.loadAccounts()).singleWhere(
      (account) => account.id == 'gcash',
    );
    expect(source.balance, 20);
  });

  testWidgets('Account transfer form logs the editable fee', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: WalletPage()));
    await tester.pumpAndSettle();

    final transferButton = find.byTooltip('Transfer');
    final addWalletButton = find.byTooltip('Add wallet');
    expect(tester.getSize(transferButton).width, greaterThanOrEqualTo(44));
    expect(tester.getSize(transferButton).height, greaterThanOrEqualTo(44));
    expect(
      tester.getCenter(transferButton).dx,
      lessThan(tester.getCenter(addWalletButton).dx),
    );
    await tester.tap(transferButton);
    await tester.pumpAndSettle();

    final amountField = find.byKey(const ValueKey('wallet_transfer_amount'));
    final feeField = find.byKey(const ValueKey('wallet_transfer_fee'));
    expect(tester.widget<TextField>(feeField).controller!.text, '10.00');
    await tester.enterText(amountField, '300');
    await tester.enterText(feeField, '15');
    await tester.tap(find.text('Transfer Funds').last);
    await tester.pumpAndSettle();

    final transactions = await FinanceStorage.loadTransactions();
    expect(transactions, hasLength(2));
    expect(transactions.last.description, 'Transaction Fee');
    expect(transactions.last.amount, 15);
    final accounts = await FinanceStorage.loadAccounts();
    expect(
      accounts.firstWhere((account) => account.id == 'cash').balance,
      1885,
    );
    expect(accounts.firstWhere((account) => account.id == 'bdo').balance, 9900);
  });

  testWidgets('Account transfer form reports insufficient amount plus fee', (
    tester,
  ) async {
    await FinanceStorage.saveAccounts([
      Account(id: 'cash', name: 'Cash', type: 'Cash', balance: 100),
      Account(id: 'bdo', name: 'BDO', type: 'Bank', balance: 1000),
    ]);
    await tester.pumpWidget(const MaterialApp(home: WalletPage()));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Transfer'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('wallet_transfer_amount')),
      '95',
    );
    await tester.tap(find.text('Transfer Funds').last);
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Transfer and fee total 105.00'),
      findsOneWidget,
    );
    expect(await FinanceStorage.loadTransactions(), isEmpty);
    expect(
      (await FinanceStorage.loadAccounts())
          .firstWhere((account) => account.id == 'cash')
          .balance,
      100,
    );
  });
}
