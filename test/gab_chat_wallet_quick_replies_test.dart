import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:gabay/models/finance_models.dart';
import 'package:gabay/pages/gab_chat.dart';
import 'package:gabay/services/finance_storage.dart';
import 'package:gabay/services/gab_assistant.dart';
import 'package:gabay/services/future_event_storage.dart';
import 'package:gabay/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const notificationChannel = MethodChannel(
    'dexterous.com/flutter/local_notifications',
  );
  const timezoneChannel = MethodChannel('flutter_timezone');
  final notificationCalls = <MethodCall>[];

  setUp(() {
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    notificationCalls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      ..setMockMethodCallHandler(notificationChannel, (call) async {
        notificationCalls.add(call);
        return true;
      })
      ..setMockMethodCallHandler(
        timezoneChannel,
        (call) async => 'Asia/Manila',
      );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      ..setMockMethodCallHandler(notificationChannel, null)
      ..setMockMethodCallHandler(timezoneChannel, null);
  });

  testWidgets(
    'wallet quick-reply card shows formatted balance and selects wallet',
    (tester) async {
      String? selectedWallet;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WalletQuickRepliesWidget(
              wallets: [
                Account(
                  id: 'bdo',
                  name: 'BDO',
                  type: 'Bank',
                  balance: 4940,
                  icon: 'assets/images/bdo.png',
                ),
              ],
              onTap: (wallet) => selectedWallet = wallet,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('BDO'), findsOneWidget);
      expect(find.text('₱4,940.00'), findsOneWidget);

      await tester.tap(find.text('BDO'));
      expect(selectedWallet, 'BDO');
    },
  );

  testWidgets('starter chips fill and focus the message input', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await SettingsService().load();
    GabAssistant().resetConversation();

    await tester.pumpWidget(const MaterialApp(home: GabChatPage()));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Clear Chat'));
    await tester.pumpAndSettle();

    expect(find.text('Expense'), findsOneWidget);
    expect(find.text('Income'), findsOneWidget);
    expect(find.text('Upcoming Bill'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Expense')).dy,
      lessThan(tester.getTopLeft(find.text('Income')).dy),
    );
    expect(
      tester.getTopLeft(find.text('Income')).dy,
      lessThan(tester.getTopLeft(find.text('Upcoming Bill')).dy),
    );
    for (final asset in [
      'assets/images/expense_logged.png',
      'assets/images/income_logged.png',
      'assets/images/events_logged.png',
    ]) {
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Image &&
              widget.image is AssetImage &&
              (widget.image as AssetImage).assetName == asset,
        ),
        findsOneWidget,
      );
    }

    final inputFinder = find.byType(TextField);
    final expenseChip = find.ancestor(
      of: find.text('Expense'),
      matching: find.byType(InkWell),
    );
    expect(tester.getSize(expenseChip).height, greaterThanOrEqualTo(44));

    await tester.tap(find.text('Expense'));
    await tester.pump();
    var input = tester.widget<TextField>(inputFinder);
    expect(input.controller!.text, 'I spent ');
    expect(input.controller!.selection.extentOffset, 'I spent '.length);
    expect(input.focusNode!.hasFocus, isTrue);
    expect(find.text('GAB is thinking'), findsNothing);

    await tester.enterText(inputFinder, 'existing text');
    await tester.ensureVisible(find.text('Income'));
    await tester.tap(find.text('Income'));
    await tester.pump();
    input = tester.widget<TextField>(inputFinder);
    expect(input.controller!.text, 'I received ');
    expect(input.controller!.selection.extentOffset, 'I received '.length);

    await tester.ensureVisible(find.text('Upcoming Bill'));
    await tester.tap(find.text('Upcoming Bill'));
    await tester.pump();
    input = tester.widget<TextField>(inputFinder);
    expect(input.controller!.text, 'I have an upcoming ');
    expect(
      input.controller!.selection.extentOffset,
      'I have an upcoming '.length,
    );
    expect(find.text('GAB is thinking'), findsNothing);
  });

  testWidgets('wallet selection completes expense and emits OS notification', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await SettingsService().load();
    await FinanceStorage.saveAccounts([
      Account(id: 'cash', name: 'Cash', type: 'Cash', balance: 1000),
    ]);
    GabAssistant().resetConversation();

    await tester.pumpWidget(const MaterialApp(home: GabChatPage()));
    await tester.pumpAndSettle();

    Future<void> sendMessage(String message) async {
      await tester.enterText(find.byType(TextField), message);
      await tester.tap(find.byTooltip('Send'));
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
    }

    await sendMessage('I spent 300');
    expect(_findAssistantText('What did you spend it on?'), findsOneWidget);
    await sendMessage('Coffee');

    expect(
      _findAssistantText('Which wallet did you spend it from?'),
      findsOneWidget,
    );
    final walletReplies = find.byType(WalletQuickRepliesWidget);
    expect(walletReplies, findsOneWidget);
    await tester.tap(
      find.descendant(of: walletReplies, matching: find.text('Cash')),
    );
    await tester.pumpAndSettle();

    expect(find.byType(MaterialBanner), findsNothing);
    final notificationCall = notificationCalls.singleWhere(
      (call) => call.method == 'show',
    );
    final notificationArguments =
        notificationCall.arguments as Map<dynamic, dynamic>;
    expect(notificationArguments['title'], 'Spent ₱300.00 from Cash');
    expect(notificationArguments['body'], 'Your wallet balance is now ₱700.00');
    expect(
      notificationCalls.where(
        (call) => call.method == 'requestExactAlarmsPermission',
      ),
      isEmpty,
    );
  });

  testWidgets(
    'income confirmation shows right-aligned balance and help replies',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await SettingsService().load();
      await FinanceStorage.saveAccounts([
        Account(id: 'cash', name: 'Cash', type: 'Cash', balance: 1000),
      ]);
      GabAssistant().resetConversation();

      await tester.pumpWidget(const MaterialApp(home: GabChatPage()));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Clear Chat'));
      await tester.pumpAndSettle();

      Future<void> sendMessage(String message) async {
        await tester.enterText(find.byType(TextField), message);
        await tester.tap(find.byTooltip('Send'));
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpAndSettle();
      }

      await sendMessage('Lance paid his debt 200');
      final walletReplies = find.byType(WalletQuickRepliesWidget);
      expect(walletReplies, findsOneWidget);
      await tester.tap(
        find.descendant(of: walletReplies, matching: find.text('Cash')),
      );
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      expect(
        _findAssistantText(
          '💵 Income logged!\nLance Debt  +₱200.00\n'
          'New Cash balance: ₱1,200.00',
        ),
        findsOneWidget,
      );
      expect(find.text('What is my total balance?'), findsOneWidget);
      expect(find.text('Help'), findsOneWidget);
      for (final reply in ['What is my total balance?', 'Help']) {
        final quickReply = find.ancestor(
          of: find.text(reply),
          matching: find.byType(InkWell),
        );
        expect(
          tester.getCenter(quickReply.first).dx,
          greaterThan(tester.getSize(find.byType(Scaffold)).width / 2),
        );
      }
    },
  );

  testWidgets('upcoming Shopee bill asks for amount and wallet in chat', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await SettingsService().load();
    await FinanceStorage.saveAccounts([
      Account(id: 'cash', name: 'Cash', type: 'Cash', balance: 1000),
    ]);
    GabAssistant().resetConversation();

    await tester.pumpWidget(const MaterialApp(home: GabChatPage()));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Clear Chat'));
    await tester.pumpAndSettle();

    Future<void> sendMessage(String message) async {
      await tester.enterText(find.byType(TextField), message);
      await tester.tap(find.byTooltip('Send'));
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
    }

    await sendMessage('i have an upcoming shopee');
    expect(_findAssistantText('How much is the shopee bill?'), findsOneWidget);

    await sendMessage('250');
    expect(
      _findAssistantText('Which wallet are you going to use?'),
      findsOneWidget,
    );
    final walletReplies = find.byType(WalletQuickRepliesWidget);
    expect(walletReplies, findsOneWidget);
    await tester.tap(
      find.descendant(of: walletReplies, matching: find.text('Cash')),
    );
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is RichText &&
            widget.text.toPlainText().contains('Bill Added to Calendar!') &&
            widget.text.toPlainText().contains('shopee\nAmount: -₱ 250.00\n') &&
            widget.text.toPlainText().contains('Wallet: Cash'),
      ),
      findsOneWidget,
    );
    final events = await FutureEventStorage.loadEvents();
    expect(events.single.description, 'shopee');
    expect(events.single.wallet, 'Cash');
  });
}

Finder _findAssistantText(String text) => find.byWidgetPredicate(
  (widget) => widget is RichText && widget.text.toPlainText().trim() == text,
);
