import 'package:flutter_test/flutter_test.dart';
import 'package:gabay/models/bill_models.dart';
import 'package:gabay/models/finance_models.dart';
import 'package:gabay/services/bai_assistant.dart';
import 'package:gabay/services/bill_storage.dart';
import 'package:gabay/services/finance_storage.dart';
import 'package:gabay/services/future_event_storage.dart';
import 'package:gabay/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _testDateText(DateTime date) {
  const months = [
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
  return '${months[date.month - 1]} ${date.day}';
}

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
        type: 'bill',
      ),
    ]);

    final reply = await BaiAssistant().getAsyncGreeting();

    expect(
      reply.text,
      '📅 Reminder: Car Loan Bill (P-1,000.00) is due today. Did you pay it?',
    );
  });

  test(
    'bill due flow records payment from selected wallet and status',
    () async {
      final today = DateTime.now();
      await FinanceStorage.saveAccounts([
        Account(id: 'cash', name: 'Cash', type: 'Cash', balance: 3000),
        Account(id: 'bdo', name: 'BDO', type: 'Bank', balance: 2000),
      ]);
      await FutureEventStorage.saveEvents([
        FutureEvent(
          id: 'rent-due',
          amount: 1200,
          category: 'Rent',
          description: 'Rent Bill',
          scheduledDate: DateTime(today.year, today.month, today.day),
          type: 'bill',
        ),
      ]);
      final assistant = BaiAssistant();

      await assistant.getAsyncGreeting();
      final walletPrompt = await assistant.handle('Yes');
      expect(
        walletPrompt.text,
        'Which wallet did you use to pay for it? Available wallets: Cash, BDO.',
      );

      final confirmation = await assistant.handle('Cash');
      expect(confirmation.text, contains('✅ Payment recorded!'));
      expect(
        confirmation.text,
        contains('Rent Bill  P-1,200.00 was paid from Cash.'),
      );
      expect(confirmation.text, contains('Cash balance: P 1,800.00'));

      final events = await FutureEventStorage.loadEvents();
      expect(events.single.status, 'paid');
      expect(events.single.wallet, 'Cash');
      expect(events.single.isCompleted, isTrue);
      final transaction = (await FinanceStorage.loadTransactions()).single;
      expect(transaction.category, 'Bills');
      expect(transaction.type, 'EXPENSE');
      expect(transaction.amount, 1200);
      expect((await FinanceStorage.loadAccounts()).first.balance, 1800);
    },
  );

  test('income due flow adds wallet income and marks event received', () async {
    final today = DateTime.now();
    await FinanceStorage.saveAccounts([
      Account(id: 'cash', name: 'Cash', type: 'Cash', balance: 1000),
      Account(id: 'bdo', name: 'BDO', type: 'Bank', balance: 2000),
    ]);
    await FutureEventStorage.saveEvents([
      FutureEvent(
        id: 'salary-due',
        amount: 8000,
        category: 'Salary',
        description: 'Salary',
        scheduledDate: DateTime(today.year, today.month, today.day),
        type: 'income',
      ),
    ]);
    final assistant = BaiAssistant();

    final reminder = await assistant.getAsyncGreeting();
    expect(
      reminder.text,
      '💰 Reminder: Salary (P 8,000.00) is expected today. Did you receive it?',
    );
    final walletPrompt = await assistant.handle('yes');
    expect(
      walletPrompt.text,
      'Which wallet did you deposit or transfer it to? Available wallets: Cash, BDO.',
    );

    final confirmation = await assistant.handle('BDO');
    expect(confirmation.text, contains('✅ Salary received!'));
    expect(
      confirmation.text,
      contains('P 8,000.00 was added to your BDO wallet.'),
    );
    expect(confirmation.text, contains('BDO balance: P 10,000.00'));

    final events = await FutureEventStorage.loadEvents();
    expect(events.single.status, 'received');
    expect(events.single.wallet, 'BDO');
    final transaction = (await FinanceStorage.loadTransactions()).single;
    expect(transaction.type, 'INCOME');
    expect(transaction.amount, 8000);
    expect((await FinanceStorage.loadAccounts()).last.balance, 10000);
  });

  test('due bill wallet prompt lists and accepts configured GCash', () async {
    final today = DateTime.now();
    await FinanceStorage.saveAccounts([
      Account(id: 'gcash', name: 'GCash', type: 'E-Wallet', balance: 700),
      Account(id: 'cash', name: 'Cash', type: 'Cash', balance: 1000),
    ]);
    await FutureEventStorage.saveEvents([
      FutureEvent(
        id: 'phone-bill',
        amount: 500,
        category: 'Phone',
        description: 'Phone Bill',
        scheduledDate: DateTime(today.year, today.month, today.day),
        type: 'bill',
      ),
    ]);
    final assistant = BaiAssistant();

    await assistant.getAsyncGreeting();
    final walletPrompt = await assistant.handle('Yes');
    expect(
      walletPrompt.text,
      'Which wallet did you use to pay for it? Available wallets: Cash, GCash.',
    );
    expect(walletPrompt.quickReplies, ['Cash', 'GCash']);

    final confirmation = await assistant.handle('GCash');
    expect(confirmation.text, contains('was paid from GCash.'));
    final event = (await FutureEventStorage.loadEvents()).single;
    expect(event.wallet, 'GCash');
    expect(
      (await FinanceStorage.loadAccounts())
          .firstWhere((account) => account.id == 'gcash')
          .balance,
      200,
    );
  });

  test('declining due reminder advances date and reschedule count', () async {
    final today = DateTime.now();
    final dueDate = DateTime(today.year, today.month, today.day);
    await FutureEventStorage.saveEvents([
      FutureEvent(
        id: 'internet-due',
        amount: 900,
        category: 'Internet',
        description: 'Internet Bill',
        scheduledDate: dueDate,
        type: 'bill',
      ),
    ]);
    final assistant = BaiAssistant();
    await assistant.getAsyncGreeting();

    final reply = await assistant.handle('No');

    expect(
      reply.text,
      'Okay, I moved your Internet Bill to ${_testDateText(dueDate.add(const Duration(days: 1)))}. I will remind you again tomorrow.',
    );
    final event = (await FutureEventStorage.loadEvents()).single;
    expect(event.status, 'pending');
    expect(event.rescheduleCount, 1);
    expect(event.scheduledDate, dueDate.add(const Duration(days: 1)));
  });

  test('third reschedule offers a new date and resets its counter', () async {
    final today = DateTime.now();
    final dueDate = DateTime(today.year, today.month, today.day);
    await FutureEventStorage.saveEvents([
      FutureEvent(
        id: 'insurance-due',
        amount: 700,
        category: 'Insurance',
        description: 'Insurance Bill',
        scheduledDate: dueDate,
        type: 'bill',
        rescheduleCount: 2,
      ),
    ]);
    final assistant = BaiAssistant();
    await assistant.getAsyncGreeting();

    final limitReply = await assistant.handle('No');
    expect(
      limitReply.text,
      'This has been moved 3 times. Would you like to set a new date?',
    );
    final datePrompt = await assistant.handle('Yes');
    expect(datePrompt.text, 'What new date would you like to set?');

    final newDate = dueDate.add(const Duration(days: 10));
    final confirmation = await assistant.handle(_testDateText(newDate));
    expect(confirmation.text, contains('I will remind you then.'));
    final event = (await FutureEventStorage.loadEvents()).single;
    expect(event.scheduledDate, newDate);
    expect(event.rescheduleCount, 0);
    expect(event.status, 'pending');
  });

  test(
    'due bill rejects unknown and insufficient wallets and checks amount changes',
    () async {
      final today = DateTime.now();
      await FinanceStorage.saveAccounts([
        Account(id: 'cash', name: 'Cash', type: 'Cash', balance: 100),
        Account(id: 'bdo', name: 'BDO', type: 'Bank', balance: 2000),
      ]);
      await FutureEventStorage.saveEvents([
        FutureEvent(
          id: 'tuition-due',
          amount: 500,
          category: 'Tuition',
          description: 'Tuition Bill',
          scheduledDate: DateTime(today.year, today.month, today.day),
          type: 'bill',
        ),
      ]);
      final assistant = BaiAssistant();
      await assistant.getAsyncGreeting();
      await assistant.handle('paid');

      final unknownWallet = await assistant.handle('GCash');
      expect(
        unknownWallet.text,
        "I couldn't find that wallet. Available wallets: Cash, BDO. Which one would you like to use?",
      );

      final insufficient = await assistant.handle('Cash');
      expect(
        insufficient.text,
        'Your Cash balance is P100.00, which is lower than this bill. Would you like to use another wallet?',
      );

      final amountQuestion = await assistant.handle('BDO 600');
      expect(
        amountQuestion.text,
        'Would you like to change the amount? The scheduled amount is P-500.00.',
      );
      final newAmountPrompt = await assistant.handle('Yes');
      expect(newAmountPrompt.text, 'What is the new amount?');
      final walletPrompt = await assistant.handle('600');
      expect(walletPrompt.text, contains('Which wallet'));
      final confirmation = await assistant.handle('BDO');
      expect(confirmation.text, contains('P-600.00 was paid from BDO.'));
    },
  );

  test(
    'oldest due event is prompted first and completed events are excluded',
    () async {
      final today = DateTime.now();
      await FutureEventStorage.saveEvents([
        FutureEvent(
          id: 'newer',
          amount: 200,
          category: 'Water',
          description: 'Water Bill',
          scheduledDate: DateTime(today.year, today.month, today.day - 1),
          type: 'bill',
        ),
        FutureEvent(
          id: 'older',
          amount: 100,
          category: 'Rent',
          description: 'Rent Bill',
          scheduledDate: DateTime(today.year, today.month, today.day - 2),
          type: 'bill',
        ),
        FutureEvent(
          id: 'already-paid',
          amount: 300,
          category: 'Internet',
          description: 'Internet Bill',
          scheduledDate: DateTime(today.year, today.month, today.day),
          type: 'bill',
          status: 'paid',
        ),
      ]);

      final reply = await BaiAssistant().getAsyncGreeting();
      expect(reply.text, contains('Rent Bill'));
      expect(reply.text, isNot(contains('Water Bill')));
      expect(reply.text, isNot(contains('Internet Bill')));
    },
  );

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
    'upcoming salary asks for missing amount then date and saves as income event',
    () async {
      await FinanceStorage.saveAccounts([
        Account(id: 'cash', name: 'Cash', type: 'Cash', balance: 1000),
        Account(id: 'bdo', name: 'BDO', type: 'Bank', balance: 2000),
      ]);
      final assistant = BaiAssistant();

      final today = DateTime.now();
      const months = [
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
      final amountPrompt = await assistant.handle(
        'I will have my salary on ${today.day}',
      );
      expect(amountPrompt.text, 'How much is your Salary?');

      final confirmation = await assistant.handle('8k');
      expect(
        confirmation.text,
        contains('💰 Incoming Transaction Added to Calendar!'),
      );
      expect(confirmation.text, contains('Salary            P 8,000.00'));
      expect(
        confirmation.text,
        contains('Date:             ${months[today.month - 1]} ${today.day}'),
      );
      expect(
        confirmation.text,
        contains('I will remind you on the day it arrives.'),
      );
      expect(confirmation.highlightColor, 'green');

      final events = await FutureEventStorage.loadEvents();
      expect(events, hasLength(1));
      expect(events.single.description, 'Salary');
      expect(events.single.amount, 8000);
      expect(
        events.single.scheduledDate,
        DateTime(today.year, today.month, today.day),
      );

      final bills = await BillStorage.loadBills();
      expect(bills, hasLength(1));
      expect(bills.single.isIncome, isTrue);
      expect(bills.single.type, 'Salary');

      final accounts = await FinanceStorage.loadAccounts();
      expect(accounts.map((account) => account.balance), [1000, 2000]);
      expect(await FinanceStorage.loadTransactions(), isEmpty);
    },
  );

  test(
    'upcoming income accepts weekday abbreviations and 13th month names',
    () async {
      final weekdayReply = await BaiAssistant().handle('Salary on Wed 5k');
      expect(
        weekdayReply.text,
        contains('💰 Incoming Transaction Added to Calendar!'),
      );
      expect(weekdayReply.text, contains('Salary'));
      expect(weekdayReply.text, contains('P 5,000.00'));

      final nextMonthReply = await BaiAssistant().handle(
        'I will get my 13th month pay on December 15 20k',
      );
      expect(
        nextMonthReply.text,
        contains('🎁 Incoming Transaction Added to Calendar!'),
      );
      expect(nextMonthReply.text, contains('13th Month Pay'));
      expect(nextMonthReply.text, contains('P 20,000.00'));
      expect(nextMonthReply.text, contains('Date:             December 15'));
    },
  );

  test('upcoming income accepts a weekday with the article the', () async {
    final reply = await BaiAssistant().handle(
      'My salary will arrive on the Saturday 5k',
    );

    expect(reply.text, contains('💰 Incoming Transaction Added to Calendar!'));
    expect(reply.text, contains('P 5,000.00'));
    expect(reply.text, contains('Date:'));
  });

  test(
    'future paid statement with amount and date asks for missing income name',
    () async {
      final assistant = BaiAssistant();
      final namePrompt = await assistant.handle(
        'I will be paid 12k on December 30',
      );
      expect(namePrompt.text, 'What kind of incoming money is this?');

      final confirmation = await assistant.handle('Bonus');
      expect(
        confirmation.text,
        contains('🎁 Incoming Transaction Added to Calendar!'),
      );
      expect(confirmation.text, contains('Bonus'));
      expect(confirmation.text, contains('P 12,000.00'));
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

  test('wallet prompts use configured accounts and accept GCash', () async {
    await FinanceStorage.saveAccounts([
      Account(id: 'bdo', name: 'BDO', type: 'Bank', balance: 2000),
      Account(id: 'gcash', name: 'GCash', type: 'E-Wallet', balance: 3000),
      Account(id: 'cash', name: 'Cash', type: 'Cash', balance: 1000),
    ]);
    final assistant = BaiAssistant();

    final sourcePrompt = await assistant.handle('Received 500');
    expect(sourcePrompt.text, 'What was this income from?');
    final walletPrompt = await assistant.handle('Salary');
    expect(
      walletPrompt.text,
      'Which wallet did you deposit it to? Available wallets: Cash, BDO, GCash.',
    );
    expect(walletPrompt.quickReplies, ['Cash', 'BDO', 'GCash']);

    final confirmation = await assistant.handle('GCash');
    expect(confirmation.text, contains('Wallet: GCash'));
    final transaction = (await FinanceStorage.loadTransactions()).single;
    expect(transaction.description, 'Salary');
    expect(transaction.accountId, 'gcash');
    expect(
      (await FinanceStorage.loadAccounts())
          .firstWhere((account) => account.id == 'gcash')
          .balance,
      3500,
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

  test('scheduled event lists show pending items sorted by due date', () async {
    final today = DateTime.now();
    final later = DateTime(today.year, today.month, today.day + 12);
    final sooner = DateTime(today.year, today.month, today.day + 4);
    await FutureEventStorage.saveEvents([
      FutureEvent(
        id: 'salary',
        amount: 8000,
        category: 'Salary',
        description: 'Salary',
        scheduledDate: later,
        type: 'income',
      ),
      FutureEvent(
        id: 'electricity',
        amount: 300,
        category: 'Electricity',
        description: 'Electricity Bill',
        scheduledDate: sooner,
        type: 'bill',
      ),
      FutureEvent(
        id: 'paid-rent',
        amount: 900,
        category: 'Rent',
        description: 'Rent Bill',
        scheduledDate: sooner,
        type: 'bill',
        status: 'paid',
      ),
    ]);
    final assistant = BaiAssistant();

    final bills = await assistant.handle('Show my upcoming bills');
    expect(bills.text, contains('📅 Upcoming Events'));
    expect(bills.text, contains('Electricity Bill   P-300.00'));
    expect(bills.text, isNot(contains('Salary')));
    expect(bills.text, isNot(contains('Rent Bill')));

    final income = await assistant.handle('Show my incoming money');
    expect(income.text, contains('Salary   P +8,000.00'));
    expect(income.text, isNot(contains('Electricity Bill')));
  });

  test(
    'scheduled deletion requires yes and removes its calendar mirror',
    () async {
      final today = DateTime.now();
      final event = FutureEvent(
        id: 'electricity',
        amount: 300,
        category: 'Electricity',
        description: 'Electricity Bill',
        scheduledDate: DateTime(today.year, today.month, today.day + 4),
        type: 'bill',
      );
      await FutureEventStorage.saveEvents([event]);
      await BillStorage.saveBills([
        Bill(
          id: 'future_electricity',
          type: 'Electricity Bill',
          amount: 300,
          dueDate: event.scheduledDate,
          isIncome: false,
        ),
      ]);
      final assistant = BaiAssistant();

      final confirmation = await assistant.handle('Cancel my electricity bill');
      expect(
        confirmation.text,
        'Are you sure you want to delete Electricity Bill?',
      );
      expect(await FutureEventStorage.loadEvents(), hasLength(1));

      final deleted = await assistant.handle('Yes');
      expect(deleted.text, 'Done! I deleted Electricity Bill.');
      expect(await FutureEventStorage.loadEvents(), isEmpty);
      expect(await BillStorage.loadBills(), isEmpty);
    },
  );

  test('scheduled move and amount updates persist to calendar bills', () async {
    final today = DateTime.now();
    final initialDate = DateTime(today.year, today.month, today.day + 4);
    final movedDate = DateTime(today.year, today.month, today.day + 12);
    final event = FutureEvent(
      id: 'electricity',
      amount: 300,
      category: 'Electricity',
      description: 'Electricity Bill',
      scheduledDate: initialDate,
      type: 'bill',
    );
    await FutureEventStorage.saveEvents([event]);
    await BillStorage.saveBills([
      Bill(
        id: 'future_electricity',
        type: 'Electricity Bill',
        amount: 300,
        dueDate: initialDate,
        isIncome: false,
      ),
    ]);
    final assistant = BaiAssistant();

    final moved = await assistant.handle(
      'Move my electricity bill to ${_testDateText(movedDate)}',
    );
    expect(
      moved.text,
      'Done! I moved your Electricity Bill to ${_testDateText(movedDate)}.',
    );
    final updated = await assistant.handle('Change my electricity bill to 450');
    expect(updated.text, 'Done! Your Electricity Bill is now P 450.00.');

    final savedEvent = (await FutureEventStorage.loadEvents()).single;
    expect(savedEvent.scheduledDate, movedDate);
    expect(savedEvent.amount, 450);
    final savedBill = (await BillStorage.loadBills()).single;
    expect(savedBill.dueDate, movedDate);
    expect(savedBill.amount, 450);
  });

  test(
    'ambiguous scheduled management asks the user to select an entry',
    () async {
      final today = DateTime.now();
      await FutureEventStorage.saveEvents([
        FutureEvent(
          id: 'salary-1',
          amount: 8000,
          category: 'Salary',
          description: 'Salary',
          scheduledDate: DateTime(today.year, today.month, today.day + 4),
          type: 'income',
        ),
        FutureEvent(
          id: 'salary-2',
          amount: 7500,
          category: 'Salary',
          description: 'Salary',
          scheduledDate: DateTime(today.year, today.month, today.day + 8),
          type: 'income',
        ),
      ]);
      final assistant = BaiAssistant();

      final selection = await assistant.handle('Change my salary to 9k');
      expect(selection.text, contains('Which one do you mean?'));
      expect(selection.text, contains('1.'));
      expect(selection.text, contains('2.'));

      final confirmation = await assistant.handle('2');
      expect(confirmation.text, 'Done! Your Salary is now P 9,000.00.');
      final events = await FutureEventStorage.loadEvents();
      expect(events.map((event) => event.amount), [8000, 9000]);
    },
  );

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
