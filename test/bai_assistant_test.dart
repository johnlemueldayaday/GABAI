import 'package:flutter_test/flutter_test.dart';
import 'package:gabay/models/finance_models.dart';
import 'package:gabay/services/bai_assistant.dart';
import 'package:gabay/services/bill_storage.dart';
import 'package:gabay/services/finance_storage.dart';
import 'package:gabay/services/future_event_storage.dart';
import 'package:gabay/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SettingsService().load();
  });

  test('due car loan event is prompted as an outgoing payment', () async {
    final today = DateTime.now();
    await FutureEventStorage.saveEvents([
      FutureEvent(
        id: 'car-loan-due',
        amount: 1000,
        category: 'Car Loan',
        description: 'Car Loan',
        scheduledDate: DateTime(today.year, today.month, today.day),
      ),
    ]);

    final reply = await BaiAssistant().getAsyncGreeting();

    expect(reply.text, contains('Did you pay your Car Loan?'));
    expect(reply.text, isNot(contains('Did you receive your Car Loan?')));
  });

  test(
    'upcoming electricity bill saves event and calendar bill without wallet changes',
    () async {
      await FinanceStorage.saveAccounts([
        Account(id: 'cash', name: 'Cash', type: 'Cash', balance: 1000),
        Account(id: 'bdo', name: 'BDO', type: 'Bank', balance: 2000),
      ]);
      final today = DateTime.now();
      final date = DateTime(today.year, today.month, today.day + 2);
      const monthNames = [
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December',
      ];
      final dateText = '${monthNames[date.month - 1]} ${date.day}';
      final reply = await BaiAssistant().handle(
        'I have electricity bill 300 on ${monthNames[date.month - 1]} ${date.day}',
      );

      expect(reply.text, contains('💡 Bill Added to Calendar!'));
      expect(reply.text, contains('Electricity Bill        P-300.00'));
      expect(reply.text, contains('Date:              $dateText'));
      expect(reply.text, contains('I will remind you on the due date.'));
      expect(reply.highlightColor, 'red');

      final events = await FutureEventStorage.loadEvents();
      expect(events, hasLength(1));
      expect(events.single.amount, 300);
      expect(events.single.description, 'Electricity Bill');
      expect(
        events.single.scheduledDate,
        DateTime(date.year, date.month, date.day),
      );

      final bills = await BillStorage.loadBills();
      expect(bills, hasLength(1));
      expect(bills.single.type, 'Electricity Bill');
      expect(bills.single.isIncome, isFalse);
      expect(bills.single.dueDate, DateTime(date.year, date.month, date.day));

      final accounts = await FinanceStorage.loadAccounts();
      expect(accounts.map((account) => account.balance), [1000, 2000]);
      expect(await FinanceStorage.loadTransactions(), isEmpty);
    },
  );

  test('upcoming bill flow asks in name amount date order', () async {
    final assistant = BaiAssistant();
    final date = DateTime.now().add(const Duration(days: 3));
    const monthNames = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    final datePrompt = await assistant.handle('I have electricity bill 300');
    expect(datePrompt.text, 'When is the Electricity bill due?');

    final confirmation = await assistant.handle(
      '${monthNames[date.month - 1]} ${date.day}',
    );
    expect(confirmation.text, contains('💡 Bill Added to Calendar!'));
    expect(confirmation.text, contains('P-300.00'));
    expect(await FutureEventStorage.loadEvents(), hasLength(1));
  });

  test(
    'bill parser supports labeled entries and treats on-number as date',
    () async {
      final today = DateTime.now();
      const monthNames = [
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December',
      ];
      final labeledReply = await BaiAssistant().handle(
        'Bill: electricity, 300, ${monthNames[today.month - 1]} ${today.day}',
      );
      expect(labeledReply.text, contains('💡 Bill Added to Calendar!'));
      expect(labeledReply.text, contains('P-300.00'));

      final noAmountReply = await BaiAssistant().handle(
        'I have water bill on ${today.day}',
      );
      expect(noAmountReply.text, 'How much is the Water bill?');
    },
  );

  test(
    'upcoming bill asks for missing name or amount without saving',
    () async {
      final assistant = BaiAssistant();

      final namePrompt = await assistant.handle('I have a bill 300 due on 20');
      expect(namePrompt.text, 'What bill is this?');
      expect(await FutureEventStorage.loadEvents(), isEmpty);
      await assistant.handle('cancel');

      final amountPrompt = await assistant.handle('Electricity due tomorrow');
      expect(amountPrompt.text, 'How much is the Electricity bill?');
      expect(await FutureEventStorage.loadEvents(), isEmpty);
    },
  );

  test(
    'allocation updates support all periods and accepted phrasing',
    () async {
      final assistant = BaiAssistant();
      const confirmations = {
        'Update my daily allocation 500':
            '✅ Done! Your daily budget is now P 500.00.',
        'This week\'s budget will be 2000':
            '✅ Done! Your weekly budget is now P 2,000.00.',
        'Budget for this week is 3500':
            '✅ Done! Your weekly budget is now P 3,500.00.',
        'Update my budget this month to 3000':
            '✅ Done! Your monthly budget is now P 3,000.00.',
      };
      const dailyAmounts = {
        'Update my daily allocation 500': 500.0,
        'This week\'s budget will be 2000': 2000 / 7,
        'Budget for this week is 3500': 3500 / 7,
        'Update my budget this month to 3000': 3000 / 30,
      };

      for (final entry in confirmations.entries) {
        final reply = await assistant.handle(entry.key);
        expect(reply.text, entry.value, reason: entry.key);
        expect(
          SettingsService().dailySpendingAllocation,
          closeTo(dailyAmounts[entry.key]!, 0.001),
          reason: entry.key,
        );
      }
    },
  );

  test('allocation update asks for period and then amount', () async {
    final assistant = BaiAssistant();

    final periodPrompt = await assistant.handle('Update my budget');
    expect(
      periodPrompt.text,
      'Which budget would you like to update: daily, weekly, or monthly?',
    );

    final amountPrompt = await assistant.handle('Weekly');
    expect(amountPrompt.text, 'What amount would you like to set?');

    final confirmation = await assistant.handle('3500');
    expect(confirmation.text, '✅ Done! Your weekly budget is now P 3,500.00.');
    expect(SettingsService().dailySpendingAllocation, closeTo(3500 / 7, 0.001));
  });

  test(
    'budget inquiry reports the current app allocation without changing it',
    () async {
      await SettingsService().setDailySpendingAllocation(500);
      final assistant = BaiAssistant();

      final reply = await assistant.handle('What is my budget?');
      final weeklyReply = await assistant.handle(
        'How much is my weekly budget?',
      );

      expect(reply.text, 'Your daily budget is P 500.00.');
      expect(weeklyReply.text, 'Your weekly budget is P 3,500.00.');
      expect(SettingsService().dailySpendingAllocation, 500);
    },
  );

  test(
    'number alone and vague budget statements do not update allocation',
    () async {
      final assistant = BaiAssistant();
      final initialAllocation = SettingsService().dailySpendingAllocation;

      await assistant.handle('500');
      final vagueReply = await assistant.handle('My budget is too small');

      expect(SettingsService().dailySpendingAllocation, initialAllocation);
      expect(vagueReply.text, 'I hear you. Would you like to update it?');
    },
  );

  test('spending statements never update allocation', () async {
    expect(SettingsService().dailySpendingAllocation, 172.30);
    final reply = await BaiAssistant().handle('I spent 500 today');
    expect(SettingsService().dailySpendingAllocation, 172.30);
    expect(reply.text, isNot(contains('✅ Done! Your')));
  });

  test('spending from a budget is still routed to expense logging', () async {
    await FinanceStorage.saveAccounts([
      Account(id: 'cash', name: 'Cash', type: 'Cash', balance: 1000),
      Account(id: 'bdo', name: 'BDO', type: 'Bank', balance: 1000),
    ]);

    final reply = await BaiAssistant().handle('Spent 500 from my budget');

    expect(reply.text, 'What did you spend from your wallet?');
    expect(SettingsService().dailySpendingAllocation, 172.30);
    expect(await FinanceStorage.loadTransactions(), isEmpty);
  });

  test(
    'expense flow asks for missing item then wallet and saves once',
    () async {
      await FinanceStorage.saveAccounts([
        Account(id: 'cash', name: 'Cash', type: 'Cash', balance: 1000),
        Account(id: 'bdo', name: 'BDO', type: 'Bank', balance: 2000),
      ]);
      final assistant = BaiAssistant();

      final itemPrompt = await assistant.handle('I spent 300');
      expect(itemPrompt.text, 'What did you spend from your wallet?');

      final walletPrompt = await assistant.handle('Shoes');
      expect(
        walletPrompt.text,
        'Which wallet did you spend it from? Available wallets: Cash, BDO.',
      );

      final confirmation = await assistant.handle('BDO');
      expect(confirmation.text, contains('✅ Expense logged!\nShoes  P-300.00'));
      expect(confirmation.text, contains('Wallet: BDO'));
      expect(confirmation.text, contains('Remaining today: P -127.70'));
      expect(SettingsService().dailySpendingAllocation, 172.30);

      final accounts = await FinanceStorage.loadAccounts();
      expect(
        accounts.firstWhere((account) => account.name == 'BDO').balance,
        1700,
      );
      final transactions = await FinanceStorage.loadTransactions();
      expect(transactions, hasLength(1));
      expect(transactions.single.type, 'EXPENSE');
      expect(transactions.single.description, 'Shoes');
    },
  );

  test(
    'expense flow rejects invalid amounts and wallets without saving',
    () async {
      await FinanceStorage.saveAccounts([
        Account(id: 'cash', name: 'Cash', type: 'Cash', balance: 1000),
        Account(id: 'bdo', name: 'BDO', type: 'Bank', balance: 1000),
      ]);
      final assistant = BaiAssistant();

      final invalidAmount = await assistant.handle('Bought tea 0');
      expect(
        invalidAmount.text,
        'Please enter a valid amount, for example 250.00.',
      );

      final walletPrompt = await assistant.handle('250.00');
      expect(
        walletPrompt.text,
        contains('Which wallet did you spend it from?'),
      );

      final invalidWallet = await assistant.handle('GCash');
      expect(
        invalidWallet.text,
        "I couldn't find that wallet. Available wallets: Cash, BDO. Which one would you like to use?",
      );
      expect(await FinanceStorage.loadTransactions(), isEmpty);

      final confirmation = await assistant.handle('Cash');
      expect(confirmation.text, contains('Tea  P-250.00'));
      expect(await FinanceStorage.loadTransactions(), hasLength(1));
    },
  );

  test('expense commands do not change the daily allocation', () async {
    await FinanceStorage.saveAccounts([
      Account(id: 'cash', name: 'Cash', type: 'Cash', balance: 1000),
      Account(id: 'bdo', name: 'BDO', type: 'Bank', balance: 1000),
    ]);

    final reply = await BaiAssistant().handle('I spend 90 on wax using cash');

    expect(reply.text, contains('Wax  P-90.00'));
    expect(SettingsService().dailySpendingAllocation, 172.30);
  });

  test('future income signal interrupts an unfinished expense flow', () async {
    await FinanceStorage.saveAccounts([
      Account(id: 'cash', name: 'Cash', type: 'Cash', balance: 1000),
      Account(id: 'bdo', name: 'BDO', type: 'Bank', balance: 1000),
    ]);
    final assistant = BaiAssistant();

    await assistant.handle('I spent 300');
    final reply = await assistant.handle('I will have my salary on 10');

    expect(reply.text, contains('How much'));
    expect(await FinanceStorage.loadTransactions(), isEmpty);
  });

  test('cancelling an incomplete expense saves nothing', () async {
    await FinanceStorage.saveAccounts([
      Account(id: 'cash', name: 'Cash', type: 'Cash', balance: 1000),
      Account(id: 'bdo', name: 'BDO', type: 'Bank', balance: 1000),
    ]);
    final assistant = BaiAssistant();

    await assistant.handle('Bought coffee 120');
    final reply = await assistant.handle('never mind');

    expect(reply.text, 'Okay, I cancelled that. Nothing was saved.');
    expect(await FinanceStorage.loadTransactions(), isEmpty);
  });

  test(
    'income flow logs a complete source and wallet and updates its balance',
    () async {
      await FinanceStorage.saveAccounts([
        Account(id: 'cash', name: 'Cash', type: 'Cash', balance: 1000),
        Account(id: 'bdo', name: 'BDO', type: 'Bank', balance: 2000),
      ]);
      final assistant = BaiAssistant();

      final walletPrompt = await assistant.handle('I got my salary 8000');
      expect(
        walletPrompt.text,
        'Which wallet did you deposit it to? Available wallets: Cash, BDO.',
      );

      final confirmation = await assistant.handle('BDO');
      expect(
        confirmation.text,
        '✅ Income logged!\nSalary  P +8,000.00\nWallet: BDO',
      );

      final accounts = await FinanceStorage.loadAccounts();
      expect(
        accounts.firstWhere((account) => account.name == 'BDO').balance,
        10000,
      );
      final transactions = await FinanceStorage.loadTransactions();
      expect(transactions, hasLength(1));
      expect(transactions.single.type, 'INCOME');
      expect(transactions.single.description, 'Salary');
      expect(transactions.single.amount, 8000);
      final today = DateTime.now();
      expect(transactions.single.date.year, today.year);
      expect(transactions.single.date.month, today.month);
      expect(transactions.single.date.day, today.day);
    },
  );

  test('income flow asks for a missing amount first', () async {
    await FinanceStorage.saveAccounts([
      Account(id: 'cash', name: 'Cash', type: 'Cash', balance: 1000),
      Account(id: 'bdo', name: 'BDO', type: 'Bank', balance: 2000),
    ]);
    final assistant = BaiAssistant();

    final amountPrompt = await assistant.handle('I got my salary');
    expect(amountPrompt.text, 'How much did you receive?');

    final walletPrompt = await assistant.handle('8000');
    expect(
      walletPrompt.text,
      'Which wallet did you deposit it to? Available wallets: Cash, BDO.',
    );
    expect(await FinanceStorage.loadTransactions(), isEmpty);
  });

  test('income flow asks for the missing source before the wallet', () async {
    await FinanceStorage.saveAccounts([
      Account(id: 'cash', name: 'Cash', type: 'Cash', balance: 1000),
      Account(id: 'bdo', name: 'BDO', type: 'Bank', balance: 2000),
    ]);
    final assistant = BaiAssistant();

    final sourcePrompt = await assistant.handle('Received 500');
    expect(sourcePrompt.text, 'What was this income from?');
    expect(await FinanceStorage.loadTransactions(), isEmpty);

    final walletPrompt = await assistant.handle('Allowance');
    expect(
      walletPrompt.text,
      'Which wallet did you deposit it to? Available wallets: Cash, BDO.',
    );

    final confirmation = await assistant.handle('Cash');
    expect(
      confirmation.text,
      contains('✅ Income logged!\nAllowance  P +500.00'),
    );
    expect(confirmation.text, contains('Wallet: Cash'));

    final accounts = await FinanceStorage.loadAccounts();
    expect(
      accounts.firstWhere((account) => account.name == 'Cash').balance,
      1500,
    );
  });

  test(
    'income flow recognizes earned, just-got, and was-paid wording',
    () async {
      final assistant = BaiAssistant();

      for (final command in [
        'Earned 500',
        'I just got 500',
        'I was paid 500',
      ]) {
        final sourcePrompt = await assistant.handle(command);
        expect(
          sourcePrompt.text,
          'What was this income from?',
          reason: command,
        );
        await assistant.handle('cancel');
      }

      expect(await FinanceStorage.loadTransactions(), isEmpty);
    },
  );

  test(
    'income flow rejects invalid amounts and wallets without saving',
    () async {
      await FinanceStorage.saveAccounts([
        Account(id: 'cash', name: 'Cash', type: 'Cash', balance: 1000),
        Account(id: 'bdo', name: 'BDO', type: 'Bank', balance: 2000),
      ]);
      final assistant = BaiAssistant();

      final invalidAmount = await assistant.handle('Received 0');
      expect(
        invalidAmount.text,
        'Please enter a valid amount, for example 8,000.00.',
      );

      final sourcePrompt = await assistant.handle('8000');
      expect(sourcePrompt.text, 'What was this income from?');

      final walletPrompt = await assistant.handle('Salary');
      expect(
        walletPrompt.text,
        'Which wallet did you deposit it to? Available wallets: Cash, BDO.',
      );

      final invalidWallet = await assistant.handle('GCash');
      expect(
        invalidWallet.text,
        "I couldn't find that wallet. Available wallets: Cash, BDO. Which one would you like to use?",
      );
      expect(await FinanceStorage.loadTransactions(), isEmpty);

      final confirmation = await assistant.handle('Cash');
      expect(confirmation.text, contains('✅ Income logged!'));
      expect(await FinanceStorage.loadTransactions(), hasLength(1));
    },
  );

  test('cancelling an incomplete income saves nothing', () async {
    await FinanceStorage.saveAccounts([
      Account(id: 'cash', name: 'Cash', type: 'Cash', balance: 1000),
      Account(id: 'bdo', name: 'BDO', type: 'Bank', balance: 2000),
    ]);
    final assistant = BaiAssistant();

    await assistant.handle('Received 500');
    final reply = await assistant.handle('cancel');

    expect(reply.text, 'Okay, I cancelled that. Nothing was saved.');
    expect(await FinanceStorage.loadTransactions(), isEmpty);
  });

  test('new income command replaces the unfinished income flow', () async {
    await FinanceStorage.saveAccounts([
      Account(id: 'cash', name: 'Cash', type: 'Cash', balance: 1000),
      Account(id: 'bdo', name: 'BDO', type: 'Bank', balance: 2000),
    ]);
    final assistant = BaiAssistant();

    await assistant.handle('Received 500');
    final walletPrompt = await assistant.handle('I got my salary 8000');
    expect(
      walletPrompt.text,
      'Which wallet did you deposit it to? Available wallets: Cash, BDO.',
    );

    final confirmation = await assistant.handle('BDO');
    expect(confirmation.text, contains('Salary  P +8,000.00'));
    final transactions = await FinanceStorage.loadTransactions();
    expect(transactions, hasLength(1));
    expect(transactions.single.amount, 8000);
    expect(transactions.single.description, 'Salary');
  });

  test(
    'allocation updates do not notify app-wide settings listeners',
    () async {
      final settings = SettingsService();
      var settingsNotified = false;
      var allocationNotified = false;
      void onSettingsChanged() => settingsNotified = true;
      void onAllocationChanged() => allocationNotified = true;

      settings.addListener(onSettingsChanged);
      settings.dailySpendingAllocationNotifier.addListener(onAllocationChanged);
      await settings.setDailySpendingAllocation(500);
      settings.removeListener(onSettingsChanged);
      settings.dailySpendingAllocationNotifier.removeListener(
        onAllocationChanged,
      );

      expect(settingsNotified, isFalse);
      expect(allocationNotified, isTrue);
    },
  );
}
