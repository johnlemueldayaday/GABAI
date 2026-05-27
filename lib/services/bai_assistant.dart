import 'package:gabay/models/finance_models.dart';
import 'package:gabay/services/finance_storage.dart';
import 'package:gabay/services/settings_service.dart';
import 'package:gabay/services/ramsey_cooking_assistant.dart';
import 'package:gabay/services/bill_storage.dart';
import 'package:gabay/services/future_event_storage.dart';
import 'package:gabay/models/bill_models.dart';
import 'package:gabay/services/price_storage.dart';

/// Unified reply object for BAI
class BaiReply {
  final String text;
  final List<String>? extraTexts;
  final List<String> quickReplies;
  final String? navigateTo;
  final String? highlightColor; // 'red' for expenses, 'green' for income

  const BaiReply(
    this.text, {
    this.extraTexts,
    this.quickReplies = const [],
    this.navigateTo,
    this.highlightColor,
  });
}

/// BAI Step state machine for multi-turn cooking conversations
enum BaiStep {
  idle,
  cravingPrompt,
  dishPrompt,
  cartPrompt,
  awaitingExpenseAccount,
  awaitingIncomeAccount,
  awaitingDuePaymentAction,
  awaitingDuePaymentAccount,
}

/// BAI (Brother AI) - Unified smart assistant merging Ramsey + Tarsi
class BaiAssistant {
  final String _currency = SettingsService().currency;

  // Cooking state (from Ramsey)
  final RamseyCookingAssistant _cookingEngine = RamseyCookingAssistant();
  BaiStep _step = BaiStep.idle;

  // Track last spending for breakdown follow-up
  bool _awaitingBreakdown = false;

  // Track pending expense details when waiting for account
  double? _pendingExpenseAmount;
  String? _pendingExpenseDescription;
  String? _pendingExpenseCategory;

  // Track pending income details when waiting for account
  double? _pendingIncomeAmount;
  String? _pendingIncomeDescription;
  String? _pendingIncomeCategory;

  // Track pending due event when processing past-due events
  FutureEvent? _pendingDueEvent;

  String _accountLabel(Account account) {
    final normalizedName = account.name.trim().toLowerCase();
    final hasAssetIcon =
        account.icon.startsWith('assets/images/') ||
        {
          'gcash',
          'maya',
          'paymaya',
          'cash',
          'bdo',
          'landbank',
          'psbank',
        }.contains(normalizedName);

    return hasAssetIcon ? account.name : '${account.icon} ${account.name}';
  }

  /// Returns an inline icon token like `{{icon:assets/images/gcash.png}}`
  /// that the chat bubble widget can parse and render as an inline image.
  String _accountIconToken(Account account) {
    final normalizedName = account.name.trim().toLowerCase();
    const iconMap = {
      'gcash': 'assets/images/gcash.png',
      'maya': 'assets/images/paymaya.png',
      'paymaya': 'assets/images/paymaya.png',
      'cash': 'assets/images/cash.png',
      'bdo': 'assets/images/bdo.png',
      'landbank': 'assets/images/landbank.png',
      'psbank': 'assets/images/psbank.png',
    };
    String? assetPath;
    if (account.icon.startsWith('assets/images/')) {
      assetPath = account.icon;
    } else {
      assetPath = iconMap[normalizedName];
    }
    if (assetPath != null) {
      return '{{icon:$assetPath}}';
    }
    return '${account.icon} ${account.name}';
  }

  BaiReply get greeting {
    final meal = RamseyCookingAssistant.detectMeal(
      DateTime.now(),
    ).toLowerCase();
    return BaiReply(
      "What can I do for you?",

      quickReplies: [
        'What can I cook for $meal?',
        'What is my total balance?',
        'Do I have upcoming bills?',
      ],
    );
  }

  /// Known income categories — anything the user RECEIVES.
  static const _incomeCategories = {
    'salary',
    'freelance',
    'business',
    'allowance',
    'scholarship',
    'investment',
    'remittance',
    'bonus',
    'commission',
    'pension',
    'rental income',
    'dividends',
    'gift',
    'refund',
    'reimbursement',
    'debt collection', // friend paying you back
  };

  /// Known outgoing categories for scheduled events.
  static const _outgoingCategories = {
    'car loan',
    'auto loan',
    'vehicle loan',
    'loan',
    'debt',
    'insurance',
    'meralco bill',
    'electricity bill',
    'electricity',
    'water',
    'internet',
    'rent',
    'netflix',
    'spotify',
    'subscription',
    'credit card',
    'home credit',
  };

  /// Returns true if the pending due event is an EXPENSE (outgoing money).
  /// Returns false if it is INCOME (incoming money like Salary, Allowance, etc.)
  bool _pendingEventIsOutgoing() {
    final event = _pendingDueEvent;
    if (event == null) return false;
    // Check stored category first — most reliable
    final cat = event.category.toLowerCase().trim();
    if (_outgoingCategories.contains(cat)) return true;
    if (_incomeCategories.contains(cat)) return false;
    // Fallback: check description keywords
    return _isFutureOutgoingObligation(
      '${event.category} ${event.description}'.toLowerCase(),
    );
  }

  Future<BaiReply> getAsyncGreeting() async {
    final dueEvents = await FutureEventStorage.getDueEvents();
    if (dueEvents.isNotEmpty) {
      _pendingDueEvent = dueEvents.first;
      _step = BaiStep.awaitingDuePaymentAction;
      final amountStr = _formatNumberWithCommas(
        _pendingDueEvent!.amount.toStringAsFixed(2),
      );
      final isOutgoing = _pendingEventIsOutgoing();
      final question = isOutgoing
          ? "Did you pay your ${_pendingDueEvent!.description}?"
          : "Did you receive your ${_pendingDueEvent!.description}?";
      return BaiReply(
        "You have a scheduled event due today:\n${_pendingDueEvent!.description} $_currency$amountStr\n\n$question",
        quickReplies: const ["Yes", "No"],
      );
    }
    return greeting;
  }

  /// Main intent router — the brain of BAI
  Future<BaiReply> handle(String rawInput) async {
    final input = rawInput.trim();
    final n = input.toLowerCase(); // normalized

    // ─── 0. GREETING / HELP ───
    if (n == 'help' || n == 'commands' || n.contains('what can you do')) {
      return _helpReply();
    }
    if (n == 'start over' || n == 'reset') {
      _resetState();
      return greeting;
    }

    // ─── 1. STATE MACHINE (mid-conversation flows take priority) ───
    final undoResult = await _tryUndo(n);
    if (undoResult != null &&
        _step != BaiStep.awaitingDuePaymentAction &&
        _step != BaiStep.awaitingDuePaymentAccount) {
      _resetState();
      return undoResult;
    }

    if (_step != BaiStep.idle) {
      return await _handleStateMachine(n);
    }

    // ─── 2. FUTURE INCOMING EVENTS ───
    final futureEventResult = await _tryFutureEvent(n);
    if (futureEventResult != null) return futureEventResult;

    // ─── 3. FINANCE: transfers (highest specificity regex) ───
    final transferResult = await _tryTransfer(n);
    if (transferResult != null) return transferResult;

    // ─── 4. FINANCE: expense logging ───
    final expenseResult = await _tryLogExpense(n);
    if (expenseResult != null) return expenseResult;

    // ─── 5. FINANCE: income logging ───
    final incomeResult = await _tryLogIncome(n);
    if (incomeResult != null) return incomeResult;

    // ─── 6. FINANCE: total balance / balance checks ───
    final balanceResult = await _tryBalanceCheck(n);
    if (balanceResult != null) return balanceResult;

    // ─── 7. BILLS ───
    if (_isWeeklyBillAsk(n)) return await _weeklyBillsReply();
    if (_isBillAsk(n)) return await _billsSummaryReply();

    // ─── 7. GROCERY SPENDING HISTORY ───
    if (_awaitingBreakdown && _isBreakdownAsk(n)) {
      _awaitingBreakdown = false;
      final reply = _cookingEngine.handle(input);
      return _fromRamsey(reply);
    }
    if (_isSpendingAsk(n)) {
      _awaitingBreakdown = true;
      final reply = _cookingEngine.handle(input);
      return _fromRamsey(reply);
    }

    // ─── 8. GROCERY BUDGET ───
    if (_isBudgetAsk(n)) {
      final reply = _cookingEngine.handle(input);
      return _fromRamsey(reply);
    }

    // ─── 9. ANALYTICS ───
    if (_isAnalyticsAsk(n)) {
      final reply = _cookingEngine.handle(input);
      return _fromRamsey(reply);
    }

    // ─── 10. COOKING: direct recipe request ───
    if (_isCookingAsk(n)) {
      return _delegateToCooking(input);
    }

    // ─── 11. MEAL PLAN ───
    if (_isMealPlanAsk(n)) {
      final reply = _cookingEngine.handle(input);
      return _fromRamsey(reply);
    }

    // ─── 12. BILL NOTIFICATIONS ───
    if (n.contains('notify me')) {
      return const BaiReply(
        "Got it! I've set a reminder for you. I'll make sure to notify you 3 days before the due date so you never miss a payment! 🔔",
        quickReplies: [
          'What is my total balance?',
          'What can I cook for dinner?',
        ],
      );
    }

    // ─── 13. CRAVING KEYWORDS (e.g. "healthy", "soupy", "spicy") ───
    if (_isCravingKeyword(n)) {
      return _delegateToCooking(input);
    }

    // ─── FALLBACK ───
    return _fallbackReply();
  }

  // ═══════════════════════════════════════════════
  //  STATE MACHINE (multi-turn cooking flows)
  // ═══════════════════════════════════════════════

  Future<BaiReply> _handleStateMachine(String n) async {
    if (_step != BaiStep.awaitingDuePaymentAction &&
        _step != BaiStep.awaitingDuePaymentAccount) {
      final undoResult = await _tryUndo(n);
      if (undoResult != null) {
        _resetState();
        return undoResult;
      }
    }

    // Handle awaiting expense account state
    if (_step == BaiStep.awaitingExpenseAccount) {
      return await _handleExpenseAccountResponse(n);
    }

    // Handle awaiting income account state
    if (_step == BaiStep.awaitingIncomeAccount) {
      return await _handleIncomeAccountResponse(n);
    }

    if (_step == BaiStep.awaitingDuePaymentAction) {
      return await _handleDuePaymentActionResponse(n);
    }

    if (_step == BaiStep.awaitingDuePaymentAccount) {
      return await _handleDuePaymentAccountResponse(n);
    }

    // Allow finance commands to break out of cooking flow
    final transferResult = await _tryTransfer(n);
    if (transferResult != null) {
      _resetState();
      return transferResult;
    }
    final futureEventResult = await _tryFutureEvent(n);
    if (futureEventResult != null) {
      _resetState();
      return futureEventResult;
    }
    final multiResult = await _tryMultiTransaction(n);
    if (multiResult != null) {
      _resetState();
      return multiResult;
    }
    final expenseResult = await _tryLogExpense(n);
    if (expenseResult != null) {
      _resetState();
      return expenseResult;
    }
    final incomeResult = await _tryLogIncome(n);
    if (incomeResult != null) {
      _resetState();
      return incomeResult;
    }
    final correctionResult = await _tryCorrection(n);
    if (correctionResult != null) {
      _resetState();
      return correctionResult;
    }
    final balanceResult = await _tryBalanceCheck(n);
    if (balanceResult != null) {
      _resetState();
      return balanceResult;
    }

    // Otherwise delegate to Ramsey's state machine
    final reply = _cookingEngine.handle(n);
    _syncStep();
    return _fromRamsey(reply);
  }

  void _syncStep() {
    // Mirror Ramsey's internal step to BAI's step
    switch (_cookingEngine.stepForBai) {
      case RamseyStep.mealPrompt:
        _step = BaiStep.idle;
        break;
      case RamseyStep.cravingPrompt:
        _step = BaiStep.cravingPrompt;
        break;
      case RamseyStep.dishPrompt:
        _step = BaiStep.dishPrompt;
        break;
      case RamseyStep.cartPrompt:
        _step = BaiStep.cartPrompt;
        break;
    }
  }

  BaiReply _delegateToCooking(String input) {
    final reply = _cookingEngine.handle(input);
    _syncStep();
    return _fromRamsey(reply);
  }

  void _resetState() {
    _step = BaiStep.idle;
    _awaitingBreakdown = false;
    _pendingExpenseAmount = null;
    _pendingExpenseDescription = null;
    _pendingExpenseCategory = null;
    _pendingExpenseCategory = null;
    _pendingIncomeAmount = null;
    _pendingIncomeDescription = null;
    _pendingIncomeCategory = null;
    _pendingDueEvent = null;
  }

  Future<BaiReply> _handleExpenseAccountResponse(String n) async {
    // Allow user to cancel the pending transaction
    if (n == 'cancel' ||
        n == 'cancel transaction' ||
        n == 'nevermind' ||
        n == 'never mind') {
      _resetState();
      return const BaiReply(
        "Transaction cancelled. What else can I help you with?",
      );
    }

    final accounts = await FinanceStorage.loadAccounts();
    if (accounts.isEmpty) return _noAccountsReply();

    // Find the account from user input — try exact first, then fuzzy
    Account? acc =
        _findAccount(n, accounts) ?? _detectAccountFromText(n, accounts);
    if (acc == null) {
      final accountNames = accounts.map((a) => a.name).join(', ');
      return BaiReply(
        "I couldn't find that account. Available accounts: $accountNames\n\nWhich account did you spend from?",
        quickReplies: accounts.map((a) => a.name).toList(),
      );
    }

    // Log the expense with the provided account
    final amount = _pendingExpenseAmount!;
    final desc = _pendingExpenseDescription!;
    final category = _pendingExpenseCategory!;
    final cleanTitle = _cleanTransactionTitle(desc, amount: amount);

    // Pre-flight: check if account has sufficient balance
    if (acc.balance < amount) {
      final accounts = await FinanceStorage.loadAccounts();
      final otherAccounts = accounts
          .where((a) => a.id != acc.id && a.balance >= amount)
          .toList();
      final allOthers = accounts.where((a) => a.id != acc.id).toList();
      final listToShow = otherAccounts.isNotEmpty ? otherAccounts : allOthers;
      final alternativeNames = listToShow.map((a) => a.name).join(', ');
      // DO NOT reset state — keep transaction pending
      return BaiReply(
        "⚠️ Insufficient funds. ${_accountLabel(acc)} only has $_currency${_formatNumberWithCommas(acc.balance.toStringAsFixed(2))} but the transaction requires -$_currency${_formatNumberWithCommas(amount.toStringAsFixed(2))}.\n\nWhich alternative account would you like to use?\nAvailable: $alternativeNames",
        quickReplies: listToShow.map((a) => a.name).toList(),
      );
    }

    try {
      final txn = FinanceTransaction(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        amount: amount,
        accountId: acc.id,
        accountName: acc.name,
        type: 'EXPENSE',
        category: category,
        description: cleanTitle,
      );
      await FinanceStorage.addTransaction(txn);

      final prevBalanceStr = _formatNumberWithCommas(
        acc.balance.toStringAsFixed(2),
      );
      final amountStr = _formatNumberWithCommas(amount.toStringAsFixed(2));
      final newBalanceStr = _formatNumberWithCommas(
        (acc.balance - amount).toStringAsFixed(2),
      );

      _resetState();
      return BaiReply(
        "💸 Expense logged!\n\n$cleanTitle                                      -$_currency$amountStr\n${_accountLabel(acc)} (prev bal: $_currency$prevBalanceStr)\n\nNew Balance: $_currency$newBalanceStr",
        quickReplies: const [
          "What is my total balance?",
          "Check account balances",
        ],
        highlightColor: 'red',
      );
    } catch (e) {
      final errMsg = e.toString();
      // Check for insufficient funds — retain state and ask for alternative account
      final isInsufficientFunds =
          errMsg.toLowerCase().contains('insufficient') ||
          errMsg.toLowerCase().contains('negative balance');
      if (isInsufficientFunds) {
        final accounts = await FinanceStorage.loadAccounts();
        final otherAccounts = accounts
            .where((a) => a.id != acc.id && a.balance >= _pendingExpenseAmount!)
            .toList();
        final alternativeNames = otherAccounts.isNotEmpty
            ? otherAccounts.map((a) => a.name).join(', ')
            : accounts
                  .where((a) => a.id != acc.id)
                  .map((a) => a.name)
                  .join(', ');
        // DO NOT reset state — keep transaction pending
        return BaiReply(
          "⚠️ Insufficient funds. ${_accountLabel(acc)} doesn't have enough balance for -$_currency${_formatNumberWithCommas(_pendingExpenseAmount!.toStringAsFixed(2))}.\n\nWhich alternative account would you like to use?\nAvailable: $alternativeNames",
          quickReplies: otherAccounts.map((a) => a.name).toList(),
        );
      }
      // For other errors, also retain state so user can retry
      return BaiReply(
        "⚠️ $errMsg\n\nThe transaction is still open. You can try a different account or type 'cancel'.",
        quickReplies: const ["Cancel"],
      );
    }
  }

  Future<BaiReply> _handleIncomeAccountResponse(String n) async {
    // Allow user to cancel the pending transaction
    if (n == 'cancel' ||
        n == 'cancel transaction' ||
        n == 'nevermind' ||
        n == 'never mind') {
      _resetState();
      return const BaiReply(
        "Transaction cancelled. What else can I help you with?",
      );
    }

    final accounts = await FinanceStorage.loadAccounts();
    if (accounts.isEmpty) return _noAccountsReply();

    // Find the account from user input — try exact first, then fuzzy
    Account? acc =
        _findAccount(n, accounts) ?? _detectAccountFromText(n, accounts);
    if (acc == null) {
      final accountNames = accounts.map((a) => a.name).join(', ');
      return BaiReply(
        "I couldn't find that account. Available accounts: $accountNames\n\nWhich account did you receive it in?",
        quickReplies: accounts.map((a) => a.name).toList(),
      );
    }

    // Log the income with the provided account
    final amount = _pendingIncomeAmount!;
    final desc = _pendingIncomeDescription!;
    final category = _pendingIncomeCategory!;
    final cleanTitle = _cleanTransactionTitle(desc, amount: amount);

    try {
      final txn = FinanceTransaction(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        amount: amount,
        accountId: acc.id,
        accountName: acc.name,
        type: 'INCOME',
        category: category,
        description: cleanTitle,
      );
      await FinanceStorage.addTransaction(txn);

      final prevBalanceStr = _formatNumberWithCommas(
        acc.balance.toStringAsFixed(2),
      );
      final amountStr = _formatNumberWithCommas(amount.toStringAsFixed(2));
      final newBalanceStr = _formatNumberWithCommas(
        (acc.balance + amount).toStringAsFixed(2),
      );

      _resetState();
      return BaiReply(
        "💵 Income logged!\n\n$cleanTitle                                      +$_currency$amountStr\n${_accountLabel(acc)} (prev bal: $_currency$prevBalanceStr)\n\nNew Balance: $_currency$newBalanceStr",
        quickReplies: const [
          "What is my total balance?",
          "Check account balances",
        ],
        highlightColor: 'green',
      );
    } catch (e) {
      final errMsg = e.toString();
      // Check for insufficient funds — retain state and ask for alternative account
      final isInsufficientFunds =
          errMsg.toLowerCase().contains('insufficient') ||
          errMsg.toLowerCase().contains('negative balance');
      if (isInsufficientFunds) {
        final accounts = await FinanceStorage.loadAccounts();
        final otherAccounts = accounts.where((a) => a.id != acc.id).toList();
        final alternativeNames = otherAccounts.map((a) => a.name).join(', ');
        // DO NOT reset state — keep transaction pending
        return BaiReply(
          "⚠️ Something went wrong with ${_accountLabel(acc)}.\n\nThe transaction is still open. Try another account: $alternativeNames",
          quickReplies: otherAccounts.map((a) => a.name).toList(),
        );
      }
      return BaiReply(
        "⚠️ $errMsg\n\nThe transaction is still open. You can try a different account or type 'cancel'.",
        quickReplies: const ["Cancel"],
      );
    }
  }

  Future<BaiReply> _handleDuePaymentActionResponse(String n) async {
    final isOutgoing = _pendingEventIsOutgoing();
    final confirmWords = isOutgoing
        ? ['yes', 'y', 'yeah', 'yep', 'paid', 'done', 'sure']
        : [
            'yes',
            'y',
            'yeah',
            'yep',
            'received',
            'got it',
            'yup',
            'sure',
            'done',
          ];
    final confirmed = confirmWords.any((w) => n == w || n.contains(w));

    if (confirmed) {
      _step = BaiStep.awaitingDuePaymentAccount;
      final accounts = await FinanceStorage.loadAccounts();
      final accountTokens = accounts
          .map((a) => _accountIconToken(a))
          .join(', ');
      final prompt = isOutgoing
          ? "Awesome! What wallet are you using?\nAvailable: $accountTokens"
          : "Nice! What wallet did you receive it in?\nAvailable: $accountTokens";
      return BaiReply(
        prompt,
        quickReplies: accounts.map((a) => a.name).toList(),
      );
    }

    final noWords = [
      'no',
      'n',
      'nope',
      'not yet',
      "haven't",
      'havent',
      'not paid',
      'not received',
      'nah',
      'cancel',
      'reschedule',
    ];
    final denied = noWords.any((w) => n == w || n.contains(w));

    if (denied) {
      final event = _pendingDueEvent!;
      final newDate = DateTime.now().add(const Duration(days: 1));
      await FutureEventStorage.updateEvent(
        event.copyWith(scheduledDate: newDate),
      );

      final dateStr = _formatDate(newDate);
      final amountStr = _formatNumberWithCommas(
        event.amount.toStringAsFixed(2),
      );
      _resetState();
      return BaiReply(
        isOutgoing
            ? "⏭️ Rescheduled!\n\n${event.description}\n$_currency$amountStr\nPayment moved to: $dateStr"
            : "⏭️ Rescheduled!\n\n${event.description}\n$_currency$amountStr\nExpected receipt moved to: $dateStr",
        quickReplies: const [
          "What is my total balance?",
          "Show upcoming events",
        ],
        highlightColor: isOutgoing ? 'red' : 'green',
      );
    }

    final question = isOutgoing
        ? "Sorry, I didn't get that. Did you pay your ${_pendingDueEvent!.description}?"
        : "Sorry, I didn't get that. Did you receive your ${_pendingDueEvent!.description}?";
    return BaiReply(question, quickReplies: const ["Yes", "No"]);
  }

  Future<BaiReply> _handleDuePaymentAccountResponse(String n) async {
    if (n == 'cancel' || n == 'nevermind') {
      _resetState();
      return const BaiReply("Got it, we can settle it later.");
    }

    final accounts = await FinanceStorage.loadAccounts();
    Account? acc =
        _findAccount(n, accounts) ?? _detectAccountFromText(n, accounts);
    if (acc == null) {
      return BaiReply(
        "I couldn't find that account. Which wallet are you using?",
        quickReplies: accounts.map((a) => a.name).toList(),
      );
    }

    final event = _pendingDueEvent!;
    final amount = event.amount;
    final isOutgoing = _pendingEventIsOutgoing();

    // Only check insufficient funds for outgoing/expense events
    if (isOutgoing && acc.balance < amount) {
      final reqStr = _formatNumberWithCommas(amount.toStringAsFixed(2));
      final hasStr = _formatNumberWithCommas(acc.balance.toStringAsFixed(2));
      return BaiReply(
        "⚠️ Insufficient funds in ${_accountLabel(acc)}\n(Has: $_currency$hasStr, Needs: $_currency$reqStr)\nChoose another wallet:",
        quickReplies: accounts
            .where((a) => a.balance >= amount)
            .map((a) => a.name)
            .toList(),
      );
    }

    try {
      final txn = FinanceTransaction(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        amount: amount,
        accountId: acc.id,
        accountName: acc.name,
        type: isOutgoing ? 'EXPENSE' : 'INCOME',
        category: event.category,
        description: event.description,
      );
      await FinanceStorage.addTransaction(txn);

      final updatedEvent = event.copyWith(isCompleted: true);
      await FutureEventStorage.updateEvent(updatedEvent);

      // also clear from bills if it's there
      final bills = await BillStorage.loadBills();
      bills.removeWhere((b) => b.id == 'future_${event.id}');
      await BillStorage.saveBills(bills);

      final amountStr = _formatNumberWithCommas(amount.toStringAsFixed(2));
      final newBalance = isOutgoing
          ? acc.balance - amount
          : acc.balance + amount;
      final newBalanceStr = _formatNumberWithCommas(
        newBalance.toStringAsFixed(2),
      );
      final icon = _accountIconToken(acc);

      _resetState();
      if (isOutgoing) {
        return BaiReply(
          "💸 Paid Bill!\n\n${event.description}                                      -$_currency$amountStr $icon\nRemaining balance :                    $_currency$newBalanceStr $icon",
          quickReplies: const [
            "What is my total balance?",
            "Check account balances",
          ],
          highlightColor: 'red',
        );
      } else {
        return BaiReply(
          "💵 Received Income!\n\n${event.description}    +$_currency$amountStr $icon\nNew Balance :    $_currency$newBalanceStr $icon",
          quickReplies: const [
            "What is my total balance?",
            "Check account balances",
          ],
          highlightColor: 'green',
        );
      }
    } catch (e) {
      _resetState();
      return BaiReply("⚠️ ${e.toString()}");
    }
  }

  // ═══════════════════════════════════════════════
  //  FINANCE HANDLERS (from Tarsi)
  // ═══════════════════════════════════════════════

  Future<BaiReply?> _tryTransfer(String n) async {
    // Check if the message contains explicit transfer keywords
    final explicitRegex = RegExp(
      r'\b(transfer|move|send|transferred|moved|sent)\b',
      caseSensitive: false,
    );
    final bool isExplicit = explicitRegex.hasMatch(n);

    // 1. Check if "to" is present in the string as a separator
    final toIndex = n.toLowerCase().indexOf(' to ');
    if (toIndex == -1) return null;

    // 2. Locate the amount anywhere in the string.
    // Supports numbers with optional decimals and optional suffix like 'k' or 'm'.
    // e.g. "500", "500.50", "500k", "500 cash"
    final amountRegex = RegExp(
      r'(\d+(?:\.\d+)?)\s*([km]?\b|[km]?(?=\D|$))',
      caseSensitive: false,
    );
    final amountMatch = amountRegex.firstMatch(n);
    if (amountMatch == null) return null;

    final amountStr = amountMatch.group(1)!;
    final suffixStr = amountMatch.group(2) ?? '';
    double? amount = double.tryParse(amountStr);
    if (amount == null || amount <= 0) return null;

    if (suffixStr.toLowerCase() == 'k') {
      amount *= 1000;
    } else if (suffixStr.toLowerCase() == 'm') {
      amount *= 1000000;
    }

    // 3. Remove the parsed amount chunk from the string to get clean parts
    final amountFullMatch = amountMatch.group(0)!;
    final cleanedText = n.replaceFirst(amountFullMatch, ' ');

    // 4. Split by the word "to"
    final splitParts = cleanedText.split(
      RegExp(r'\s+to\s+', caseSensitive: false),
    );
    if (splitParts.length < 2) return null;

    // The left part contains the source account name and optional noise
    // The right part contains the destination account name and optional noise
    String leftSide = splitParts[0].trim();
    String rightSide = splitParts.sublist(1).join(' to ').trim();

    // Remove noise words from leftSide and rightSide
    final noiseWords = RegExp(
      r'\b(transfer|move|send|transferred|moved|sent|from|pesos|php|₱)\b',
      caseSensitive: false,
    );
    leftSide = leftSide
        .replaceAll(noiseWords, ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    rightSide = rightSide
        .replaceAll(noiseWords, ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    final accounts = await FinanceStorage.loadAccounts();
    if (accounts.isEmpty) return _noAccountsReply();

    // 5. Detect accounts
    final from =
        _findAccount(leftSide, accounts) ??
        _detectAccountFromText(leftSide, accounts);
    final to =
        _findAccount(rightSide, accounts) ??
        _detectAccountFromText(rightSide, accounts);

    // If it's not an explicit request and we can't find one of the accounts,
    // we fall through to let other intent handlers process it.
    if (from == null) {
      if (!isExplicit) return null;
      return BaiReply(
        "⚠️ Can't find source account '$leftSide'. Available: ${accounts.map((e) => e.name).join(', ')}",
      );
    }
    if (to == null) {
      if (!isExplicit) return null;
      return BaiReply(
        "⚠️ Can't find destination account '$rightSide'. Available: ${accounts.map((e) => e.name).join(', ')}",
      );
    }
    if (from.id == to.id) {
      if (!isExplicit) return null;
      return const BaiReply("⚠️ Source and destination must be different.");
    }
    if (from.balance < amount) {
      return BaiReply(
        "⚠️ Insufficient funds in ${_accountLabel(from)}. Balance: $_currency${from.balance.toStringAsFixed(2)}",
      );
    }

    try {
      final prevFromBal = from.balance;
      final prevToBal = to.balance;

      await FinanceStorage.transferMoney(
        fromAccount: from,
        toAccount: to,
        amount: amount,
      );

      final amountStrFmt = _formatNumberWithCommas(amount.toStringAsFixed(2));
      final prevFromStr = _formatNumberWithCommas(
        prevFromBal.toStringAsFixed(2),
      );
      final prevToStr = _formatNumberWithCommas(prevToBal.toStringAsFixed(2));
      final newFromStr = _formatNumberWithCommas(
        (prevFromBal - amount).toStringAsFixed(2),
      );
      final newToStr = _formatNumberWithCommas(
        (prevToBal + amount).toStringAsFixed(2),
      );

      final fromIcon = _accountIconToken(from);
      final toIcon = _accountIconToken(to);

      return BaiReply(
        "🏛️ Transfer Logged!\n\nMoney Transfer                     +$_currency$amountStrFmt $toIcon\n\n$toIcon prev: $_currency$prevToStr → $_currency$newToStr\n$fromIcon prev: $_currency$prevFromStr → $_currency$newFromStr",
        quickReplies: const [
          "What is my total balance?",
          "Check account balances",
        ],
      );
    } catch (e) {
      return BaiReply(
        "⚠️ ${e.toString()}",
        quickReplies: const ["What is my total balance?"],
      );
    }
  }

  Future<BaiReply?> _tryLogExpense(String n) async {
    // 1. Differentiate intent
    if (!_isExpenseIntent(n)) return null;

    // 2. Extract amount using slang-aware extractor (handles k/m suffixes)
    final accounts = await FinanceStorage.loadAccounts();
    if (accounts.isEmpty) return _noAccountsReply();

    // 3. Try to detect account from text
    Account? acc = _detectAccountFromText(n, accounts);
    bool accountProvided = (acc != null);
    final fragmentItem = _extractExpenseItemFragment(n, acc);

    double? amount = _extractAmountWithSlang(n);
    if (amount == null || amount <= 0) {
      if (fragmentItem.isEmpty || !accountProvided) return null;

      final rememberedPrice = PriceStorage.getLastPriceAny(fragmentItem);
      if (rememberedPrice == null || rememberedPrice <= 0) {
        final category = _categorizeExpense(fragmentItem);
        return BaiReply(
          "How much was ${_titleCase(fragmentItem)}?\n\n"
          "${_accountLabel(acc)}\n"
          "Category: $category",
          quickReplies: const ["Cancel"],
        );
      }
      amount = rememberedPrice;
    }

    // Capture the raw amount string matched from text for description cleaning
    final amountStr =
        RegExp(
          r'(\d+(?:,\d{3})*(?:\.\d+)?)\s*[km]?\b',
        ).firstMatch(n)?.group(0) ??
        amount.toStringAsFixed(2);

    // Clean description using _cleanDescription
    String matchedAccSuffix = '';
    if (acc != null) {
      final nameIdx = n.toLowerCase().indexOf(acc.name.toLowerCase());
      if (nameIdx != -1) {
        final precedingText = n.substring(0, nameIdx).toLowerCase();
        final viaIdx = precedingText.lastIndexOf(
          RegExp(r'\b(?:from|using|in|through|with|via)\b'),
        );
        if (viaIdx != -1) {
          matchedAccSuffix = n.substring(viaIdx);
        } else {
          matchedAccSuffix = n.substring(nameIdx);
        }
      }
    }

    String descStr = fragmentItem.isNotEmpty
        ? fragmentItem
        : _cleanDescription(n, amountStr, matchedAccSuffix);

    // Clean up expense keywords from description to keep it clean
    final List<String> stripKeywords = [
      'spent',
      'paid',
      'cost',
      'buy',
      'bought',
      'gastos',
      'expense',
      'bumili',
      'add',
      'log',
      'logged',
      'minus',
      'deduct',
      'spending',
      'give',
      'gave',
      'pay',
      'sent',
      'lost',
      'given',
    ];
    String cleanedDesc = descStr;
    for (var k in stripKeywords) {
      cleanedDesc = cleanedDesc.replaceAll(
        RegExp(r'\b' + k + r'\b', caseSensitive: false),
        '',
      );
    }
    if (acc != null) {
      cleanedDesc = cleanedDesc.replaceAll(
        RegExp(RegExp.escape(acc.name), caseSensitive: false),
        '',
      );
    }
    cleanedDesc = cleanedDesc.replaceAll(
      RegExp(
        r'\b(?:gcash|maya|paymaya|cash|bdo|landbank|psbank|bank|wallet|account)\b',
        caseSensitive: false,
      ),
      '',
    );
    // Clean double spaces and dangling prepositions
    cleanedDesc = cleanedDesc.replaceAll(RegExp(r'\s+'), ' ').trim();
    cleanedDesc = cleanedDesc.replaceFirst(
      RegExp(
        r'^(?:for|to|from|via|in|on|with|using|my|me)\s+',
        caseSensitive: false,
      ),
      '',
    );
    cleanedDesc = cleanedDesc.replaceFirst(
      RegExp(
        r'\s+(?:for|to|from|via|in|on|with|using|my|me)$',
        caseSensitive: false,
      ),
      '',
    );
    if (cleanedDesc.isEmpty || cleanedDesc.toLowerCase() == 'i') {
      cleanedDesc = 'General Expense';
    } else {
      // Strip dangling k/m suffix tokens left from shorthand amounts
      cleanedDesc = cleanedDesc.replaceAll(
        RegExp(r'\b[km]\b', caseSensitive: false),
        '',
      );
      cleanedDesc = cleanedDesc.replaceAll(RegExp(r'\s+'), ' ').trim();
      cleanedDesc = cleanedDesc[0].toUpperCase() + cleanedDesc.substring(1);
    }

    // If no account was detected, ask the user!
    if (acc == null) {
      _pendingExpenseAmount = amount;
      _pendingExpenseDescription = cleanedDesc;
      _pendingExpenseCategory = _categorizeExpense(cleanedDesc);
      _step = BaiStep.awaitingExpenseAccount;

      final accountNames = accounts.map((a) => a.name).join(', ');
      return BaiReply(
        "Where did you spend it from?\n\nAvailable accounts: $accountNames",
      );
    }

    final category = _categorizeExpense(cleanedDesc);

    // Clean the transaction title
    final cleanTitle = _cleanTransactionTitle(cleanedDesc, amount: amount);

    final txn = FinanceTransaction(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      amount: amount,
      accountId: acc.id,
      accountName: acc.name,
      type: 'EXPENSE',
      category: category,
      description: cleanTitle,
    );

    try {
      await FinanceStorage.addTransaction(txn);
      final prevBalanceStr = _formatNumberWithCommas(
        acc.balance.toStringAsFixed(2),
      );
      final amountStr = _formatNumberWithCommas(amount.toStringAsFixed(2));
      final newBalanceStr = _formatNumberWithCommas(
        (acc.balance - amount).toStringAsFixed(2),
      );

      return BaiReply(
        "💸 Expense logged!\n\n$cleanTitle                                      -$_currency$amountStr\n${_accountLabel(acc)} (prev bal: $_currency$prevBalanceStr)\n\nNew Balance: $_currency$newBalanceStr",
        quickReplies: const [
          "What is my total balance?",
          "Check account balances",
        ],
        highlightColor: 'red',
      );
    } catch (e) {
      return BaiReply(
        "⚠️ ${e.toString()}",
        quickReplies: const ["What is my total balance?"],
      );
    }
  }

  Future<BaiReply?> _tryMultiTransaction(String n) async {
    // Check if input contains "and" which might indicate multiple transactions
    final l = n.toLowerCase();

    // Look for patterns like "received X and spent Y" or "got X and paid Y"
    final multiPattern = RegExp(
      r'(?:received|got|earned|income)\s+(\d+(?:\.\d+)?)\s*(?:k)?\s*(?:pesos|php|₱)?\s*(?:and|&)\s*(?:spent|paid|expense|bought)\s+(\d+(?:\.\d+)?)\s*(?:k)?',
      caseSensitive: false,
    );

    final match = multiPattern.firstMatch(l);
    if (match == null) return null;

    // Extract amounts with slang support
    final incomeAmountStr = match.group(1)!;
    final expenseAmountStr = match.group(2)!;

    double? incomeAmount = _parseAmountWithSlang(incomeAmountStr, l);
    double? expenseAmount = _parseAmountWithSlang(expenseAmountStr, l);

    if (incomeAmount == null || expenseAmount == null) return null;

    final accounts = await FinanceStorage.loadAccounts();
    if (accounts.isEmpty) return _noAccountsReply();

    // Use first account for both transactions (could enhance to ask for accounts)
    final account = accounts.first;

    final results = <String>[];

    // Extract expense category from input
    String expenseCategory = 'Others';
    if (l.contains('internet') || l.contains('wifi')) {
      expenseCategory = 'Utilities';
    } else if (l.contains('electric') || l.contains('power')) {
      expenseCategory = 'Utilities';
    } else if (l.contains('water')) {
      expenseCategory = 'Utilities';
    } else if (l.contains('rent')) {
      expenseCategory = 'Housing';
    } else if (l.contains('food') || l.contains('grocery')) {
      expenseCategory = 'Food & Drinks';
    }

    // Log income
    try {
      final incomeCleanTitle = _cleanTransactionTitle(
        'Salary',
        amount: incomeAmount,
      );
      final incomeTxn = FinanceTransaction(
        id: '${DateTime.now().millisecondsSinceEpoch}_income',
        amount: incomeAmount,
        accountId: account.id,
        accountName: account.name,
        type: 'INCOME',
        category: 'Salary',
        description: incomeCleanTitle,
      );
      await FinanceStorage.addTransaction(incomeTxn);
      results.add("Salary +$_currency${incomeAmount.toStringAsFixed(2)}");
    } catch (e) {
      results.add("Failed to log income: $e");
    }

    // Log expense
    try {
      final expenseCleanTitle = _cleanTransactionTitle(
        expenseCategory,
        amount: expenseAmount,
      );
      final expenseTxn = FinanceTransaction(
        id: '${DateTime.now().millisecondsSinceEpoch}_expense',
        amount: expenseAmount,
        accountId: account.id,
        accountName: account.name,
        type: 'EXPENSE',
        category: expenseCategory,
        description: expenseCleanTitle,
      );
      await FinanceStorage.addTransaction(expenseTxn);
      results.add(
        "$expenseCategory -$_currency${expenseAmount.toStringAsFixed(2)}",
      );
    } catch (e) {
      results.add("Failed to log expense: $e");
    }

    return BaiReply(
      results.join('\n\n'),
      quickReplies: const [
        "What is my total balance?",
        "Check account balances",
      ],
    );
  }

  double? _parseAmountWithSlang(String amountStr, String fullText) {
    // Check if the amount has "k" suffix in the full text
    final idx = fullText.toLowerCase().indexOf(amountStr.toLowerCase());
    if (idx != -1) {
      final afterAmount = fullText
          .substring(idx + amountStr.length)
          .toLowerCase()
          .trim();
      if (afterAmount.startsWith('k')) {
        final value = double.tryParse(amountStr);
        if (value != null) return value * 1000;
      }
    }
    return double.tryParse(amountStr);
  }

  Future<BaiReply?> _tryLogIncome(String n) async {
    // 1. Differentiate intent
    if (!_isIncomeIntent(n)) return null;

    // 2. Extract amount with slang support (k for thousands)
    final amount = _extractAmountWithSlang(n);
    if (amount == null || amount <= 0) return null;

    final accounts = await FinanceStorage.loadAccounts();
    if (accounts.isEmpty) return _noAccountsReply();

    // 3. Try to detect account from text
    Account? acc = _detectAccountFromText(n, accounts);

    // Clean description using _cleanDescription
    String matchedAccSuffix = '';
    if (acc != null) {
      final nameIdx = n.toLowerCase().indexOf(acc.name.toLowerCase());
      if (nameIdx != -1) {
        final precedingText = n.substring(0, nameIdx).toLowerCase();
        final viaIdx = precedingText.lastIndexOf(
          RegExp(r'\b(?:to|in|into|through|with|via)\b'),
        );
        if (viaIdx != -1) {
          matchedAccSuffix = n.substring(viaIdx);
        } else {
          matchedAccSuffix = n.substring(nameIdx);
        }
      }
    }

    String descStr = _cleanDescription(n, amount.toString(), matchedAccSuffix);

    // Clean up income keywords from description to keep it clean
    final List<String> stripKeywords = [
      'received',
      'recieved',
      'got paid',
      'get paid',
      'allowance',
      'salary',
      'sweldo',
      'sahod',
      'payroll',
      'bonus',
      'refund',
      'tax refund',
      'sold',
      'sale',
      'preloved',
      'inflow',
      'interest',
      'deposit',
      'deposits',
      'freelance',
      'sideline',
      'gig',
      'gave me',
      'handed me',
      'donated to me',
      'sent me',
      'paid me',
      'paid his',
      'paid her',
      'paid their',
      'paid back',
      'pay back',
      'na-receive',
      'pumasok',
      'dumating',
      'pax me',
      'debt',
      'utang',
      'got',
      'i',
    ];
    String cleanedDesc = descStr;
    for (var k in stripKeywords) {
      cleanedDesc = cleanedDesc.replaceAll(
        RegExp(r'\b' + k + r'\b', caseSensitive: false),
        '',
      );
    }
    // Clean double spaces and dangling prepositions
    cleanedDesc = cleanedDesc.replaceAll(RegExp(r'\s+'), ' ').trim();
    cleanedDesc = cleanedDesc.replaceFirst(
      RegExp(
        r'^(?:for|to|from|via|in|on|with|using|my|me)\s+',
        caseSensitive: false,
      ),
      '',
    );
    cleanedDesc = cleanedDesc.replaceFirst(
      RegExp(
        r'\s+(?:for|to|from|via|in|on|with|using|my|me)$',
        caseSensitive: false,
      ),
      '',
    );

    if (cleanedDesc.isEmpty) {
      if (n.contains('salary') || n.contains('sweldo') || n.contains('sahod')) {
        cleanedDesc = 'Salary';
      } else if (n.contains('freelance') || n.contains('gig')) {
        cleanedDesc = 'Freelance Income';
      } else if (n.contains('allowance')) {
        cleanedDesc = 'Allowance';
      } else if (n.contains('debt') ||
          n.contains('utang') ||
          n.contains('paid back') ||
          n.contains('pay back')) {
        cleanedDesc = 'Debt Payment';
      } else {
        cleanedDesc = 'General Income';
      }
    } else {
      cleanedDesc = cleanedDesc[0].toUpperCase() + cleanedDesc.substring(1);
    }

    final pendingCategory = _categorizeIncome('$n $cleanedDesc');
    final pendingEntity = _extractEntity(n);

    // If no account was detected, ask the user!
    if (acc == null) {
      _pendingIncomeAmount = amount;
      _pendingIncomeDescription =
          pendingCategory == 'Gift' && pendingEntity.isNotEmpty
          ? '$pendingEntity $pendingCategory'
          : cleanedDesc;
      _pendingIncomeCategory = pendingCategory;
      _step = BaiStep.awaitingIncomeAccount;

      final accountNames = accounts.map((a) => a.name).join(', ');
      return BaiReply(
        "Where did you receive it?\n\nAvailable accounts: $accountNames",
      );
    }

    final category = pendingCategory;
    final entity = pendingEntity;

    // Format description with entity if detected
    String formattedDesc = cleanedDesc;
    if (entity.isNotEmpty) {
      if (_isReimbursement(n)) {
        formattedDesc = '$entity ($category)';
      } else if (_isAllowance(n)) {
        formattedDesc = '$entity ($category)';
      } else if (_isPassiveIncome(n)) {
        formattedDesc = '$entity $category';
      } else if (category == 'Gift') {
        formattedDesc = '$entity $category';
      } else {
        formattedDesc = entity.isNotEmpty
            ? '$entity ($cleanedDesc)'
            : cleanedDesc;
      }
    }

    // Clean the transaction title
    final cleanTitle = _cleanTransactionTitle(formattedDesc, amount: amount);

    final txn = FinanceTransaction(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      amount: amount,
      accountId: acc.id,
      accountName: acc.name,
      type: 'INCOME',
      category: category,
      description: cleanTitle,
    );

    try {
      await FinanceStorage.addTransaction(txn);
      final prevBalanceStr = _formatNumberWithCommas(
        acc.balance.toStringAsFixed(2),
      );
      final amountStr = _formatNumberWithCommas(amount.toStringAsFixed(2));
      final newBalanceStr = _formatNumberWithCommas(
        (acc.balance + amount).toStringAsFixed(2),
      );

      return BaiReply(
        "💵 Income logged!\n\n$cleanTitle                                      +$_currency$amountStr\n${_accountLabel(acc)} (prev bal: $_currency$prevBalanceStr)\n\nNew Balance: $_currency$newBalanceStr",
        quickReplies: const [
          "What is my total balance?",
          "Check account balances",
        ],
        highlightColor: 'green',
      );
    } catch (e) {
      return BaiReply(
        "⚠️ ${e.toString()}",
        quickReplies: const ["What is my total balance?"],
      );
    }
  }

  Future<BaiReply?> _tryBalanceCheck(String n) async {
    // Total balance
    if (n == 'total balance' ||
        n.contains('totalbalance') ||
        n.contains('what is my total balance') ||
        n.contains('how much money do i have') ||
        n.contains('total balance') ||
        n.contains('financial status') ||
        n == 'check balances' ||
        n == 'check account balances') {
      final accounts = await FinanceStorage.loadAccounts();
      if (accounts.isEmpty) return _noAccountsReply();
      final netWorth = await FinanceStorage.getNetWorth();
      final lines = accounts
          .map(
            (a) =>
                "${_accountLabel(a)}: $_currency${a.balance.toStringAsFixed(2)}",
          )
          .toList();
      return BaiReply(
        "💰 Your Total Balance: $_currency${netWorth.toStringAsFixed(2)}\n\n${lines.join('\n')}",
        quickReplies: const ["Check Cash balance", "What can I cook?"],
      );
    }

    // Individual account
    final accounts = await FinanceStorage.loadAccounts();
    for (final a in accounts) {
      final name = a.name.toLowerCase().trim();
      if (n == '$name balance' ||
          n == 'balance of $name' ||
          n == 'check $name' ||
          n == 'check $name balance' ||
          (n.contains('how much') && n.contains(name))) {
        return BaiReply(
          "${_accountLabel(a)} balance: $_currency${a.balance.toStringAsFixed(2)}",
          quickReplies: const ["What is my total balance?"],
        );
      }
    }
    return null;
  }

  Future<BaiReply?> _tryUndo(String n) async {
    final l = n.toLowerCase();
    final undoKeywords = [
      'undo',
      'no',
      'cancel',
      'mali',
      'wrong',
      'erase that',
      'revert',
      'delete last',
      'delete last entry',
      'remove last',
      'cancel last',
      'nvm',
      'nevermind',
      'delete',
      'undo previous',
      'revert previous',
      'undo last transaction',
      'revert previous transaction',
    ];

    final exactUndoKeywords = ['undo', 'no', 'cancel', 'mali', 'wrong'];
    final phraseUndoKeywords = undoKeywords.where(
      (k) => !exactUndoKeywords.contains(k),
    );

    if (!exactUndoKeywords.contains(l) &&
        !phraseUndoKeywords.any((k) => l.contains(k))) {
      return null;
    }

    final deletedTxn = await FinanceStorage.deleteLastTransaction();
    if (deletedTxn == null) {
      return BaiReply(
        "⚠️ No transactions to undo.",
        quickReplies: const ["What is my total balance?"],
      );
    }

    final accounts = await FinanceStorage.loadAccounts();
    Account? restoredAccount;
    for (final account in accounts) {
      if (account.id == deletedTxn.accountId) {
        restoredAccount = account;
        break;
      }
    }

    final restoredLabel = restoredAccount != null
        ? _accountLabel(restoredAccount)
        : deletedTxn.accountName;
    final balanceLine = restoredAccount != null
        ? "\n\nNew Balance: $_currency${_formatNumberWithCommas(restoredAccount.balance.toStringAsFixed(2))}"
        : '';
    return BaiReply(
      "\u{1F504} Transaction Undo!\n\n"
      "${deletedTxn.description} removed.\n"
      "$restoredLabel balance restored.$balanceLine",
      quickReplies: const [
        "What is my total balance?",
        "Check account balances",
      ],
    );
  }

  Future<BaiReply?> _tryCorrection(String n) async {
    final l = n.toLowerCase();

    // Check for correction keywords
    final correctionKeywords = [
      'change that',
      'actually',
      'correct that',
      'wait',
      'no wait',
      'not really',
      'mistake',
      'wrong',
    ];

    if (!correctionKeywords.any((k) => l.contains(k))) {
      return null;
    }

    // Try to extract the new amount
    final newAmount = _extractAmountWithSlang(n);
    if (newAmount == null) {
      return BaiReply(
        "⚠️ I couldn't find the new amount. Please specify the correct amount.",
        quickReplies: const ["What is my total balance?"],
      );
    }

    // Get the last transaction
    final transactions = await FinanceStorage.loadTransactions();
    if (transactions.isEmpty) {
      return BaiReply(
        "⚠️ No transactions to correct.",
        quickReplies: const ["What is my total balance?"],
      );
    }

    final lastTxn = transactions.last;

    // Calculate the difference
    final oldAmount = lastTxn.amount;
    final difference = newAmount - oldAmount;

    // Delete the old transaction
    await FinanceStorage.deleteLastTransaction();

    // Create a new transaction with the corrected amount
    final accounts = await FinanceStorage.loadAccounts();
    final account = accounts.firstWhere(
      (a) => a.id == lastTxn.accountId,
      orElse: () => accounts.first,
    );

    final correctedTxn = FinanceTransaction(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      amount: newAmount,
      accountId: account.id,
      accountName: account.name,
      type: lastTxn.type,
      category: lastTxn.category,
      description: lastTxn.description,
    );

    try {
      await FinanceStorage.addTransaction(correctedTxn);

      final type = lastTxn.type == 'INCOME' ? 'income' : 'expense';
      final diffText = difference > 0
          ? '+$_currency${difference.toStringAsFixed(2)}'
          : '-$_currency${difference.abs().toStringAsFixed(2)}';

      return BaiReply(
        "✅ Corrected!\n\nUpdated $type from $_currency${oldAmount.toStringAsFixed(2)} to $_currency${newAmount.toStringAsFixed(2)}\nAdjustment: $diffText\nAccount: ${account.name}",
        quickReplies: const [
          "What is my total balance?",
          "Check account balances",
        ],
      );
    } catch (e) {
      return BaiReply(
        "⚠️ Failed to correct transaction: $e",
        quickReplies: const ["What is my total balance?"],
      );
    }
  }

  // ═══════════════════════════════════════════════
  //  BILLS HANDLERS
  // ═══════════════════════════════════════════════

  Future<BaiReply> _weeklyBillsReply() async {
    final bills = await BillStorage.loadBills();
    _cookingEngine.updateBills(bills);
    final reply = _cookingEngine.handle('total bills this week');
    return _fromRamsey(reply);
  }

  Future<BaiReply> _billsSummaryReply() async {
    final bills = await BillStorage.loadBills();
    _cookingEngine.updateBills(bills);
    final reply = _cookingEngine.handle('upcoming bills');
    return _fromRamsey(reply);
  }

  // ═══════════════════════════════════════════════
  //  INTENT DETECTION HELPERS
  // ═══════════════════════════════════════════════

  bool _isWeeklyBillAsk(String n) =>
      (n.contains('how much') && n.contains('bill')) ||
      n.contains('total bills this week') ||
      n.contains('bills this week');

  bool _isBillAsk(String n) =>
      n.contains('upcoming bills') ||
      n.contains('do i have bills') ||
      n.contains('any bills') ||
      n.contains('bayad') ||
      n.contains('overdue');

  bool _isSpendingAsk(String n) =>
      n.contains('spend') ||
      n.contains('spending') ||
      n.contains('gastos') ||
      n.contains('purchase') ||
      n.contains('how much did i');

  bool _isBreakdownAsk(String n) =>
      n == 'yes' || n == 'oo' || n.contains('breakdown') || n.contains('show');

  bool _isBudgetAsk(String n) =>
      n.contains('budget') ||
      n.contains('limit') ||
      n.contains('magkano nalang');

  bool _isAnalyticsAsk(String n) =>
      n.contains('analytics') ||
      n.contains('insight') ||
      n.contains('habit') ||
      n.contains('chart') ||
      n.contains('summary');

  bool _isMealPlanAsk(String n) =>
      n.contains('meal plan') ||
      n.contains('plan my meals') ||
      n.contains('meal prep');

  bool _isCookingAsk(String n) =>
      n.contains('cook') ||
      n.contains('recipe') ||
      n.contains('dish') ||
      n.contains('ulam') ||
      n.contains('luto') ||
      n.contains('kain') ||
      n.contains('suggest') ||
      n.contains('breakfast') ||
      n.contains('lunch') ||
      n.contains('dinner') ||
      n.contains('snack') ||
      n.contains('merienda') ||
      n.contains('hapunan') ||
      n.contains('almusal') ||
      n.contains('tanghalian') ||
      n.contains('what can i') ||
      n.contains('midnight');

  bool _isCravingKeyword(String n) =>
      n == 'healthy' ||
      n == 'soupy' ||
      n == 'spicy' ||
      n == 'anything' ||
      n == 'sabaw' ||
      n == 'maanghang' ||
      n == 'kahit ano' ||
      n.contains('fridge') ||
      n.contains('ref');

  // ═══════════════════════════════════════════════
  //  FINANCE CATEGORY CLASSIFIERS
  // ═══════════════════════════════════════════════

  String _categorizeExpense(String desc) {
    final l = desc.toLowerCase();
    if (_matchAny(l, [
      'coffee',
      'food',
      'drinks',
      'dinner',
      'lunch',
      'breakfast',
      'snack',
      'restaurant',
      'milk',
      'grocery',
      'groceries',
      'burger',
      'starbucks',
      'milktea',
      'milk tea',
    ])) {
      return 'Food & Drinks';
    }
    if (_matchAny(l, [
      'gas',
      'transport',
      'taxi',
      'grab',
      'fare',
      'bus',
      'jeep',
      'jeepney',
      'train',
      'ride',
      'toll',
    ])) {
      return 'Transportation';
    }
    if (_matchAny(l, [
      'rent',
      'electricity',
      'water',
      'internet',
      'wifi',
      'load',
      'bill',
      'utility',
      'utilities',
      'power',
    ])) {
      return 'Bills & Utilities';
    }
    if (_matchAny(l, [
      'movie',
      'netflix',
      'game',
      'gaming',
      'cinema',
      'concert',
      'steam',
      'spotify',
      'arcade',
    ])) {
      return 'Entertainment';
    }
    if (_matchAny(l, [
      'shirt',
      'clothes',
      'shoes',
      'shopping',
      'mall',
      'lazada',
      'shopee',
    ])) {
      return 'Shopping';
    }
    return 'Others';
  }

  String _categorizeIncome(String desc) {
    final l = desc.toLowerCase();
    if (_matchAny(l, ['gave me', 'gift', 'regalo'])) {
      return 'Gift';
    }
    if (_matchAny(l, ['salary', 'sweldo', 'paycheck'])) {
      return 'Salary';
    }
    if (_matchAny(l, ['freelance', 'sideline', 'gig', 'project'])) {
      return 'Freelance';
    }
    if (_matchAny(l, [
      'invest',
      'investment',
      'stocks',
      'crypto',
      'dividend',
    ])) {
      return 'Investment';
    }
    if (_matchAny(l, ['allowance', 'baon', 'padala'])) {
      return 'Allowance';
    }
    if (_matchAny(l, [
      'reimburse',
      'refund',
      'paid back',
      'pay back',
      'debt',
      'utang',
    ])) {
      return 'Reimbursement';
    }
    if (_matchAny(l, ['interest', 'dividend', 'payout'])) {
      return 'Passive Income';
    }
    return 'Others';
  }

  bool _matchAny(String input, List<String> keywords) =>
      keywords.any(input.contains);

  // ═══════════════════════════════════════════════
  //  ACCOUNT MATCHING
  // ═══════════════════════════════════════════════

  Account? _findAccount(String name, List<Account> accounts) {
    final l = name.toLowerCase().trim();
    if (l.isEmpty) return null;
    for (final a in accounts) {
      if (a.name.toLowerCase().trim() == l) return a;
    }
    for (final a in accounts) {
      final al = a.name.toLowerCase();
      if (al.contains(l) || l.contains(al)) return a;
    }
    return null;
  }

  Account? _detectAccountFromText(String text, List<Account> accounts) {
    final l = text.toLowerCase();
    // Try to match exact account names first (e.g. "Bank", "GCash", "Cash")
    for (final a in accounts) {
      final name = a.name.toLowerCase().trim();
      if (l.contains(name)) return a;
    }
    // Try to match common patterns
    if (l.contains('gcash')) {
      for (final a in accounts) {
        if (a.name.toLowerCase().contains('gcash')) return a;
      }
    }
    if (l.contains('maya')) {
      for (final a in accounts) {
        if (a.name.toLowerCase().contains('maya')) return a;
      }
    }
    if (l.contains('cash')) {
      for (final a in accounts) {
        if (a.name.toLowerCase().contains('cash')) return a;
      }
    }
    if (l.contains('psbank') || l.contains('ps bank')) {
      for (final a in accounts) {
        if (a.name.toLowerCase().contains('psbank')) return a;
      }
    }
    if (l.contains('bank') || l.contains('bdo') || l.contains('landbank')) {
      for (final a in accounts) {
        final name = a.name.toLowerCase();
        if (name.contains('bank') ||
            name.contains('bdo') ||
            name.contains('landbank')) {
          return a;
        }
      }
    }
    return null;
  }

  // ═══════════════════════════════════════════════
  //  SLANG & AMOUNT EXTRACTION
  // ═══════════════════════════════════════════════

  double? _extractAmountWithSlang(String text) {
    final l = text.toLowerCase();

    // Handle "m" for millions (e.g., "1m", "1.5m", "10m")
    final mMatch = RegExp(r'(\d+(?:,\d{3})*(?:\.\d+)?)\s*m\b').firstMatch(l);
    if (mMatch != null) {
      final value = double.tryParse(mMatch.group(1)!.replaceAll(',', ''));
      if (value != null) return value * 1000000;
    }

    // Handle "k" for thousands (e.g., "2k", "5k", "10k")
    final kMatch = RegExp(r'(\d+(?:,\d{3})*(?:\.\d+)?)\s*k\b').firstMatch(l);
    if (kMatch != null) {
      final value = double.tryParse(kMatch.group(1)!.replaceAll(',', ''));
      if (value != null) return value * 1000;
    }

    // Handle regular amounts
    final amountMatch = RegExp(r'(\d+(?:,\d{3})*(?:\.\d+)?)').firstMatch(l);
    if (amountMatch != null) {
      return double.tryParse(amountMatch.group(1)!.replaceAll(',', ''));
    }

    return null;
  }

  String _extractEntity(String text) {
    final l = text.toLowerCase();

    // Common Filipino entities/relationships
    final entities = [
      'papi',
      'daddy',
      'dad',
      'father',
      'tatay',
      'ama',
      'mom',
      'mommy',
      'mother',
      'momma',
      'nanay',
      'ina',
      'brother',
      'bro',
      'kuya',
      'bunso',
      'sister',
      'sis',
      'ate',
      'friend',
      'bestfriend',
      'bestie',
      'boss',
      'manager',
      'supervisor',
    ];

    for (final entity in entities) {
      if (l.contains(entity)) {
        return entity[0].toUpperCase() + entity.substring(1);
      }
    }

    // Try to extract proper names (capitalized words)
    final nameMatch = RegExp(r'\b[A-Z][a-z]+\b').firstMatch(text);
    if (nameMatch != null) {
      return nameMatch.group(0)!;
    }

    return '';
  }

  bool _isReimbursement(String text) {
    final l = text.toLowerCase();
    return l.contains('paid back') ||
        l.contains('reimburse') ||
        l.contains('reimbursement') ||
        l.contains('refund') ||
        l.contains('share') ||
        l.contains('split');
  }

  bool _isAllowance(String text) {
    final l = text.toLowerCase();
    return l.contains('baon') ||
        l.contains('allowance') ||
        l.contains('padala') ||
        l.contains('sent') && (l.contains('money') || l.contains('cash'));
  }

  bool _isPassiveIncome(String text) {
    final l = text.toLowerCase();
    return l.contains('dividend') ||
        l.contains('interest') ||
        l.contains('payout') ||
        l.contains('auto') ||
        l.contains('automatic') ||
        l.contains('credit');
  }

  String _cleanDescription(
    String text,
    String amountStr,
    String? accMatchText,
  ) {
    String desc = text;
    // Remove the amount
    desc = desc.replaceFirst(amountStr, '');
    desc = desc.replaceFirst(
      RegExp(
        r'\b' +
            RegExp.escape(amountStr.replaceFirst(RegExp(r'\.0$'), '')) +
            r'\b',
      ),
      '',
    );
    // Remove the account match suffix if provided
    if (accMatchText != null && accMatchText.isNotEmpty) {
      desc = desc.replaceFirst(accMatchText, '');
    }
    // Remove clean currency words/symbols
    desc = desc.replaceAll(
      RegExp(r'\b(?:pesos|php|₱|bucks|dollar|dollars)\b', caseSensitive: false),
      '',
    );
    // Remove leading/trailing punctuation and double spaces
    desc = desc.replaceAll(RegExp(r'\s+'), ' ').trim();
    // Remove trailing/leading "for", "to", "from", "via", "in" if they are left dangling
    desc = desc.replaceFirst(
      RegExp(r'^(?:for|to|from|via|in|on|with|using)\s+', caseSensitive: false),
      '',
    );
    desc = desc.replaceFirst(
      RegExp(r'\s+(?:for|to|from|via|in|on|with|using)$', caseSensitive: false),
      '',
    );

    // Capitalize first letter
    if (desc.isEmpty) return 'Transaction';
    return desc[0].toUpperCase() + desc.substring(1);
  }

  String _extractExpenseItemFragment(String text, Account? account) {
    var item = text.toLowerCase();

    item = item.replaceAll(
      RegExp(r'\b\d+(?:,\d{3})*(?:\.\d+)?\s*[km]?\b', caseSensitive: false),
      ' ',
    );
    item = item.replaceAll(
      RegExp(r'\b(?:pesos|peso|php|bucks|dollars?)\b', caseSensitive: false),
      ' ',
    );

    if (account != null) {
      item = item.replaceAll(
        RegExp(RegExp.escape(account.name), caseSensitive: false),
        ' ',
      );
    }

    final accountWords = [
      'gcash',
      'maya',
      'paymaya',
      'cash',
      'bank',
      'bdo',
      'landbank',
      'psbank',
      'wallet',
      'card',
      'account',
    ];
    for (final word in accountWords) {
      item = item.replaceAll(
        RegExp(r'\b' + word + r'\b', caseSensitive: false),
        ' ',
      );
    }

    item = item.replaceAll(
      RegExp(
        r'\b(?:spent|paid|cost|buy|bought|gastos|expense|bumili|add|log|logged|minus|deduct|spending|from|using|in|through|with|via|on|for|my|me|i)\b',
        caseSensitive: false,
      ),
      ' ',
    );
    item = item.replaceAll(RegExp(r'[^\w\s]'), ' ');
    item = item.replaceAll(RegExp(r'\s+'), ' ').trim();
    return item;
  }

  bool _looksLikeExpenseFragment(String text) {
    final l = text.toLowerCase().trim();
    if (l.isEmpty || _isIncomeIntent(l)) return false;

    final amount = _extractAmountWithSlang(l);
    final itemAfterAmount = _extractExpenseItemFragment(l, null);
    if (amount != null && itemAfterAmount.isNotEmpty) return true;

    final mentionsAccount = RegExp(
      r'\b(?:gcash|maya|paymaya|cash|bank|bdo|landbank|psbank|wallet|card)\b',
      caseSensitive: false,
    ).hasMatch(l);
    return mentionsAccount && itemAfterAmount.isNotEmpty;
  }

  String _titleCase(String text) {
    final words = text.trim().split(RegExp(r'\s+'));
    return words
        .where((word) => word.isNotEmpty)
        .map((word) => word[0].toUpperCase() + word.substring(1).toLowerCase())
        .join(' ');
  }

  bool _isIncomeIntent(String text) {
    final l = text.toLowerCase();
    // Strongly classified income indicators
    final List<String> strongIncomeKeywords = [
      'received',
      'recieved',
      'got paid',
      'get paid',
      'allowance',
      'salary',
      'sweldo',
      'sahod',
      'payroll',
      'bonus',
      'refund',
      'tax refund',
      'sold',
      'sale',
      'preloved',
      'inflow',
      'interest',
      'deposit',
      'deposits',
      'freelance',
      'sideline',
      'gig',
    ];

    if (strongIncomeKeywords.any((k) => l.contains(k))) return true;

    // Phrase structures for incoming money:
    // e.g. "Dad gave me 500", "Kuya sent 200", "Mark paid me back"
    if (l.contains('gave me') ||
        l.contains('handed me') ||
        l.contains('donated to me') ||
        l.contains('sent me') ||
        l.contains('paid me') ||
        l.contains('paid his') ||
        l.contains('paid her') ||
        l.contains('paid their') ||
        l.contains('sent his') ||
        l.contains('sent her') ||
        l.contains('debt') ||
        l.contains('utang') ||
        l.contains('bayad') && l.contains('utang') ||
        l.contains('pay back') ||
        l.contains('paid back') ||
        l.contains('na-receive') ||
        l.contains('pumasok') ||
        l.contains('dumating') ||
        l.contains('pax me') ||
        l.contains('added') && l.contains('to my') ||
        l.contains('got') && !l.contains('spent') && !l.contains('paid')) {
      return true;
    }

    return false;
  }

  bool _isExpenseIntent(String text) {
    // If it's classified as income, it's not expense
    if (_isIncomeIntent(text)) return false;
    if (_looksLikeExpenseFragment(text)) return true;

    final l = text.toLowerCase();
    final List<String> expenseKeywords = [
      'spent',
      'paid',
      'cost',
      'buy',
      'bought',
      'gastos',
      'expense',
      'bumili',
      'add',
      'log',
      'logged',
      'minus',
      'deduct',
      'spending',
      'donated',
      'gave',
      'give',
      'pay',
      'sent',
      'lost',
      'given',
    ];

    return expenseKeywords.any((k) => l.contains(k));
  }

  // ═══════════════════════════════════════════════
  //  FUTURE EVENT DETECTION & PARSING
  // ═══════════════════════════════════════════════

  bool _isFutureTense(String text) {
    final l = _normalizeFutureText(text);

    // GUARD: if the text contains past-tense markers, it is NOT a future event
    final pastMarkers = [
      'yesterday',
      'earlier',
      'just now',
      'already',
      'last night',
      'last week',
      'this morning',
      'this afternoon',
      'ago',
      'kanina',
      'kahapon',
    ];
    if (pastMarkers.any((k) => l.contains(k))) return false;

    final futureKeywords = [
      'is going to',
      'going to pay',
      'going to send',
      'going to transfer',
      'need to pay',
      'needs to pay',
      'have a loan',
      'has a loan',
      'due on',
      'due this',
      'bill drops',
      'will pay',
      'will transfer',
      'will send',
      'drops on',
      'expect on',
      'expecting',
      'scheduled for',
      'this coming',
      'next month',
      'next week',
      'upcoming',
      'future',
      'tomorrow',
      'tom ', // slang for tomorrow (space prevents matching 'tomato' etc.)
      ' tom', // end-of-phrase variant
      "i'm paying",
      "i will pay",
      "i'll pay",
      "i'm going to pay",
      'paying next',
      'paying this',
      'paying on',
    ];
    if (futureKeywords.any((k) => l.contains(k))) return true;

    final hasFutureDateMarker = _hasFutureDateReference(l);
    final hasIncomingAction = RegExp(
      r'\b(?:pay(?:\s+me)?(?:\s+back)?|send|transfer|clear|drop|receive|expect|incoming|salary|allowance|remittance|freelance)\b',
    ).hasMatch(l);
    final hasOutgoingObligation = _isFutureOutgoingObligation(l);

    return hasFutureDateMarker && (hasIncomingAction || hasOutgoingObligation);
  }

  String _normalizeFutureText(String text) {
    var normalized = text.toLowerCase().trim();
    final replacements = <String, String>{
      'tomorow': 'tomorrow',
      'tommorow': 'tomorrow',
      'tmrw': 'tomorrow',
      'tmr': 'tomorrow',
      'electrcity': 'electricity',
      'electricty': 'electricity',
      'eletricity': 'electricity',
      'elctricity': 'electricity',
      'bil ': 'bill ',
      'bll ': 'bill ',
      'homecredit': 'home credit',
      'net flix': 'netflix',
      'netfilx': 'netflix',
      'netfix': 'netflix',
    };

    for (final entry in replacements.entries) {
      normalized = normalized.replaceAll(entry.key, entry.value);
    }
    return normalized.replaceAll(RegExp(r'\s+'), ' ');
  }

  bool _hasFutureDateReference(String text) {
    final l = _normalizeFutureText(text);
    return l.contains('tomorrow') ||
        RegExp(r'\btom\b').hasMatch(l) ||
        l.contains('next week') ||
        l.contains('next month') ||
        RegExp(
          r'\b(?:on|this|next|by|due)\s+(?:the\s+)?\d{1,2}(?:st|nd|rd|th)?\b',
        ).hasMatch(l) ||
        RegExp(
          r'\bnext\s+month\s+(?:on\s+)?(?:the\s+)?\d{1,2}(?:st|nd|rd|th)?\b',
        ).hasMatch(l) ||
        RegExp(
          r'\b(?:monday|tuesday|wednesday|thursday|friday|saturday|sunday)\b',
        ).hasMatch(l);
  }

  DateTime? _parseDateFromText(String text) {
    var l = _normalizeFutureText(text);
    final now = DateTime.now();

    // Normalize 'tom' slang → 'tomorrow' (as a whole word, not part of other words)
    l = l.replaceAllMapped(RegExp(r'\btom\b'), (_) => 'tomorrow');

    // Parse "tomorrow"
    if (l.contains('tomorrow')) {
      return now.add(const Duration(days: 1));
    }

    // Parse "next week"
    if (l.contains('next week')) {
      return now.add(const Duration(days: 7));
    }

    // Parse "next month 12th", "next month on the 12th", etc.
    final nextMonthDayMatch = RegExp(
      r'\bnext\s+month\s+(?:on\s+)?(?:the\s+)?(\d{1,2})(?:st|nd|rd|th)?\b',
    ).firstMatch(l);
    if (nextMonthDayMatch != null) {
      final day = int.tryParse(nextMonthDayMatch.group(1)!);
      if (day != null && day >= 1 && day <= 31) {
        return DateTime(now.year, now.month + 1, day);
      }
    }

    // Parse "this 30th", "on the 15th", "on 30th", etc.
    final dayMatch = RegExp(
      r'(?:this|on|by|due)\s+(?:the\s+)?(\d{1,2})(?:st|nd|rd|th)?\b',
    ).firstMatch(l);
    if (dayMatch != null) {
      final day = int.tryParse(dayMatch.group(1)!);
      if (day != null && day >= 1 && day <= 31) {
        DateTime date = DateTime(now.year, now.month, day);
        if (date.isBefore(now)) {
          date = DateTime(now.year, now.month + 1, day);
        }
        return date;
      }
    }

    // Parse "Friday", "Sunday", etc.
    final days = [
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
      'sunday',
    ];
    for (int i = 0; i < days.length; i++) {
      if (l.contains(days[i])) {
        int targetDay = i + 1;
        int currentDay = now.weekday;
        int daysUntil = (targetDay - currentDay + 7) % 7;
        if (daysUntil == 0) daysUntil = 7;
        return now.add(Duration(days: daysUntil));
      }
    }

    // Parse "5th of the month"
    final nthMatch = RegExp(
      r'(\d{1,2})(?:st|nd|rd|th)?\s+(?:of\s+)?(?:the\s+)?month',
    ).firstMatch(l);
    if (nthMatch != null) {
      final day = int.tryParse(nthMatch.group(1)!);
      if (day != null && day >= 1 && day <= 31) {
        DateTime date = DateTime(now.year, now.month, day);
        if (date.isBefore(now)) {
          date = DateTime(now.year, now.month + 1, day);
        }
        return date;
      }
    }

    // Parse "next month"
    if (l.contains('next month')) {
      return DateTime(now.year, now.month + 1, 1);
    }

    // If future keywords detected but no specific date, default to tomorrow
    if (l.contains('tomorrow') ||
        l.contains("i'm paying") ||
        l.contains('i will pay') ||
        l.contains("i'll pay")) {
      return now.add(const Duration(days: 1));
    }

    // Also normalize standalone 'tom' (caught by futureKeywords but needs a date)
    if (RegExp(r'\btom\b').hasMatch(l)) {
      return now.add(const Duration(days: 1));
    }

    return null;
  }

  String _parseFrequency(String text) {
    final l = text.toLowerCase();
    if (l.contains('one time') ||
        l.contains('one-time') ||
        l.contains('once')) {
      return 'Once';
    }
    if (l.contains('every') ||
        l.contains('monthly') ||
        l.contains('each month')) {
      return 'Monthly';
    }
    if (l.contains('weekly') || l.contains('every week')) {
      return 'Weekly';
    }
    return 'Once';
  }

  String _defaultFutureFrequency(String text) {
    final explicit = _parseFrequency(text);
    if (explicit != 'Once' ||
        RegExp(r'\b(?:once|one-time|one time)\b').hasMatch(text)) {
      return explicit;
    }

    return explicit;
  }

  bool _isFutureOutgoingObligation(String text) {
    final l = _normalizeFutureText(text);
    final hasDueLanguage =
        _hasFutureDateReference(l) ||
        RegExp(r'\b(?:due|deadline|drops|coming up|by)\b').hasMatch(l);
    final hasObligation = RegExp(
      r'\b(?:need(?:s)?\s+to\s+pay|have\s+(?:a\s+)?(?:loan|bill|debt)|has\s+(?:a\s+)?(?:loan|bill|debt)|loan|bill|debt|insurance|rent|meralco|electricity|electric|power|water|internet|wifi|subscription|netflix|spotify|credit card|home credit|payment)\b',
    ).hasMatch(l);
    final payOut =
        RegExp(r'\b(?:pay|paying|paid)\b').hasMatch(l) &&
        !RegExp(r'\bpay(?:s|ing|ed)?\s+me\s+back\b').hasMatch(l);

    return (hasObligation || payOut) && hasDueLanguage;
  }

  double? _extractFutureAmount(String text) {
    var scrubbed = _normalizeFutureText(text);

    final datePatterns = [
      RegExp(r'\b(?:this|on|by|due)\s+(?:the\s+)?\d{1,2}(?:st|nd|rd|th)?\b'),
      RegExp(
        r'\bnext\s+month\s+(?:on\s+)?(?:the\s+)?\d{1,2}(?:st|nd|rd|th)?\b',
      ),
      RegExp(r'\b\d{1,2}(?:st|nd|rd|th)?\s+(?:of\s+)?(?:the\s+)?month\b'),
      RegExp(
        r'\b(?:next|this)\s+(?:monday|tuesday|wednesday|thursday|friday|saturday|sunday|week|month)\b',
      ),
      RegExp(
        r'\b(?:monday|tuesday|wednesday|thursday|friday|saturday|sunday)\b',
      ),
    ];

    for (final pattern in datePatterns) {
      scrubbed = scrubbed.replaceAll(pattern, ' ');
    }

    final currencyMatch = RegExp(
      r'(?:₱|php|peso|pesos)\s*(\d+(?:,\d{3})*(?:\.\d+)?)(\s*[km])?\b|(\d+(?:,\d{3})*(?:\.\d+)?)(\s*[km])?\s*(?:₱|php|peso|pesos)\b',
      caseSensitive: false,
    ).firstMatch(scrubbed);
    if (currencyMatch != null) {
      final raw = currencyMatch.group(1) ?? currencyMatch.group(3);
      final suffix = (currencyMatch.group(2) ?? currencyMatch.group(4))
          ?.trim()
          .toLowerCase();
      final parsed = double.tryParse(raw!.replaceAll(',', ''));
      if (parsed != null) {
        if (suffix == 'k') return parsed * 1000;
        if (suffix == 'm') return parsed * 1000000;
        return parsed;
      }
    }

    final actionAmountMatch = RegExp(
      r'\b(?:pay(?:\s+me)?(?:\s+back)?|send|transfer|clear|receive|expect|expecting|salary|allowance|remittance|freelance|incoming|income|payout)\D{0,30}?(\d+(?:,\d{3})*(?:\.\d+)?)(\s*[km])?\b',
      caseSensitive: false,
    ).firstMatch(scrubbed);
    if (actionAmountMatch != null) {
      final parsed = double.tryParse(
        actionAmountMatch.group(1)!.replaceAll(',', ''),
      );
      if (parsed != null) {
        final suffix = actionAmountMatch.group(2)?.trim().toLowerCase();
        if (suffix == 'k') return parsed * 1000;
        if (suffix == 'm') return parsed * 1000000;
        return parsed;
      }
    }

    final amountMatch = RegExp(
      r'\b(\d+(?:,\d{3})*(?:\.\d+)?)(\s*[km])?\b',
      caseSensitive: false,
    ).firstMatch(scrubbed);
    if (amountMatch == null) return null;

    final parsed = double.tryParse(amountMatch.group(1)!.replaceAll(',', ''));
    if (parsed == null) return null;

    final suffix = amountMatch.group(2)?.trim().toLowerCase();
    if (suffix == 'k') return parsed * 1000;
    if (suffix == 'm') return parsed * 1000000;
    return parsed;
  }

  String _categorizeFutureEvent(String text) {
    final l = text.toLowerCase();

    // Map to allowed categories
    if (_matchAny(l, ['salary', 'sweldo', 'paycheck', 'payday'])) {
      return 'Salary';
    }
    if (_matchAny(l, [
      'freelance',
      'sideline',
      'gig',
      'project',
      'client',
      'milestone',
    ])) {
      return 'Freelance';
    }
    if (_matchAny(l, [
      'business',
      'customer',
      'order',
      'invoice',
      'delivery',
    ])) {
      return 'Business';
    }
    if (_matchAny(l, ['allowance', 'baon', 'padala'])) {
      return 'Allowance';
    }
    if (_matchAny(l, ['scholarship', 'grant'])) {
      return 'Scholarship';
    }
    if (_matchAny(l, [
      'invest',
      'investment',
      'stocks',
      'crypto',
      'debt',
      'pay back',
      'reimburse',
    ])) {
      return 'Investment';
    }
    if (_matchAny(l, ['remittance', 'send money', 'transfer'])) {
      return 'Remittance';
    }

    return 'Salary'; // Default
  }

  String _categorizeFutureOutgoingEvent(String text) {
    final l = _normalizeFutureText(text);

    if (_matchAny(l, ['car loan', 'auto loan', 'vehicle loan'])) {
      return 'Car Loan';
    }
    if (_matchAny(l, ['debt'])) {
      return 'Debt';
    }
    if (_matchAny(l, ['loan'])) {
      return 'Loan';
    }
    if (_matchAny(l, ['insurance'])) {
      return 'Insurance';
    }
    if (_matchAny(l, ['meralco'])) {
      return 'Meralco Bill';
    }
    if (_matchAny(l, ['electric', 'electricity', 'power'])) {
      return 'Electricity Bill';
    }
    if (_matchAny(l, ['water'])) {
      return 'Water';
    }
    if (_matchAny(l, ['internet', 'wifi'])) {
      return 'Internet';
    }
    if (_matchAny(l, ['rent'])) {
      return 'Rent';
    }
    if (_matchAny(l, ['netflix'])) {
      return 'Netflix';
    }
    if (_matchAny(l, ['spotify'])) {
      return 'Spotify';
    }
    if (_matchAny(l, ['subscription'])) {
      return 'Subscription';
    }
    if (_matchAny(l, ['credit card'])) {
      return 'Credit Card';
    }
    if (_matchAny(l, ['home credit'])) {
      return 'Home Credit';
    }

    return _cleanFutureOutgoingTitle(text);
  }

  String _cleanFutureOutgoingTitle(String text) {
    var title = _normalizeFutureText(text);
    final amount = _extractFutureAmount(text);
    title = _removeMappedAmountFromTitle(title, amount);

    // Strip contractions first (i'm, i'll, i've, he's, she's, they're)
    title = title.replaceAll(
      RegExp(r"\bi'[a-z]+\b", caseSensitive: false),
      ' ',
    );
    title = title.replaceAll(
      RegExp(r"\bhe'[a-z]+\b", caseSensitive: false),
      ' ',
    );
    title = title.replaceAll(
      RegExp(r"\bshe'[a-z]+\b", caseSensitive: false),
      ' ',
    );
    title = title.replaceAll(
      RegExp(r"\bwe'[a-z]+\b", caseSensitive: false),
      ' ',
    );
    title = title.replaceAll(
      RegExp(r"\bthey'[a-z]+\b", caseSensitive: false),
      ' ',
    );

    title = title.replaceAll(
      RegExp(r'\b(?:this|on|by|due)\s+(?:the\s+)?\d{1,2}(?:st|nd|rd|th)?\b'),
      ' ',
    );
    title = title.replaceAll(
      RegExp(
        r'\b(?:i|my|have|has|a|an|the|need|needs|to|pay|paying|worth|around|about|bill|payment|due|drops|coming|up|for|on|by|tomorrow|next|week|month|going|will|gonna|am|is|are)\b',
        caseSensitive: false,
      ),
      ' ',
    );
    title = title.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (title.isEmpty) return 'Bill';

    return title
        .split(' ')
        .where((word) => word.isNotEmpty)
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  Future<BaiReply?> _tryFutureEvent(String n) async {
    final normalized = _normalizeFutureText(n);
    if (!_isFutureTense(normalized)) return null;

    // Extract the money amount after date markers have been removed, so
    // ordinals like "30th" never become the amount.
    final amount = _extractFutureAmount(normalized);
    if (amount == null || amount <= 0) return null;

    // Parse date
    final scheduledDate = _parseDateFromText(normalized);
    if (scheduledDate == null) {
      return BaiReply(
        "⚠️ I couldn't determine the date. Please specify when this event will occur (e.g., 'this 30th', 'on Friday', 'on the 15th').",
        quickReplies: const ["What is my total balance?"],
      );
    }

    final isOutgoing = _isFutureOutgoingObligation(normalized);

    // Parse frequency
    final frequency = _defaultFutureFrequency(normalized);

    // Parse category
    final category = isOutgoing
        ? _categorizeFutureOutgoingEvent(normalized)
        : _categorizeFutureEvent(normalized);

    // Extract entity
    final entity = _extractEntity(normalized);

    // Create description
    String description = category;
    if (entity.isNotEmpty) {
      description = '$entity ($category)';
    }

    // Clean the transaction title
    final cleanTitle = _cleanTransactionTitle(description, amount: amount);

    // Create future event
    final event = FutureEvent(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      amount: amount,
      category: category,
      description: cleanTitle,
      scheduledDate: scheduledDate,
      frequency: frequency,
      entity: entity.isNotEmpty ? entity : null,
    );

    try {
      await FutureEventStorage.addEvent(event);

      final bills = await BillStorage.loadBills();
      bills.add(
        Bill(
          id: 'future_${event.id}',
          type: category,
          amount: amount,
          dueDate: scheduledDate,
          isIncome: !isOutgoing,
          frequency: frequency,
        ),
      );
      await BillStorage.saveBills(bills);

      // Load accounts to show current balance of detected account
      final accounts = await FinanceStorage.loadAccounts();
      final detectedAcc = _detectAccountFromText(normalized, accounts);
      final amountStr = _formatNumberWithCommas(amount.toStringAsFixed(2));
      final dateStr = _formatDate(scheduledDate);

      if (isOutgoing) {
        // Outgoing: show current balance, and projected balance after execution
        final accLine = detectedAcc != null
            ? '${_accountLabel(detectedAcc)} (Current Balance: $_currency${_formatNumberWithCommas(detectedAcc.balance.toStringAsFixed(2))})'
            : 'Account not specified';
        final projectedBalance = detectedAcc != null
            ? _formatNumberWithCommas(
                (detectedAcc.balance - amount).toStringAsFixed(2),
              )
            : 'N/A';
        final frequencyNote = frequency == 'Once'
            ? ''
            : '\nFrequency: $frequency';

        return BaiReply(
          '📅 Bill Scheduled!\n\n$cleanTitle                                      -$_currency$amountStr\n$accLine\nScheduled for: $dateStr$frequencyNote\n\nNew Balance after execution: $_currency$projectedBalance',
          quickReplies: const [
            "Show upcoming events",
            "What is my total balance?",
          ],
          highlightColor: 'red',
        );
      } else {
        // Incoming: show current balance, and projected balance after execution
        final accLine = detectedAcc != null
            ? '${_accountLabel(detectedAcc)} (Current Balance: $_currency${_formatNumberWithCommas(detectedAcc.balance.toStringAsFixed(2))})'
            : 'Account not specified';
        final projectedBalance = detectedAcc != null
            ? _formatNumberWithCommas(
                (detectedAcc.balance + amount).toStringAsFixed(2),
              )
            : 'N/A';
        final frequencyNote = frequency == 'Once'
            ? ''
            : '\nFrequency: $frequency';

        return BaiReply(
          '📅 Income Scheduled!\n\n$cleanTitle                                   +$_currency$amountStr\n$accLine\nScheduled for: $dateStr$frequencyNote\n\nNew Balance after execution: $_currency$projectedBalance',
          quickReplies: const [
            "What is my total balance?",
            "Show upcoming events",
          ],
          highlightColor: 'green',
        );
      }
    } catch (e) {
      return BaiReply(
        "⚠️ Failed to schedule future event: $e",
        quickReplies: const ["What is my total balance?"],
      );
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final targetDate = DateTime(date.year, date.month, date.day);

    final daysDiff = targetDate.difference(today).inDays;

    if (daysDiff == 0) return 'today';
    if (daysDiff == 1) return 'tomorrow';
    if (daysDiff < 7) return 'this ${_getDayName(date.weekday)}';
    if (daysDiff < 14) return 'next ${_getDayName(date.weekday)}';

    return '${date.day}${_getOrdinalSuffix(date.day)} of ${_getMonthName(date.month)}';
  }

  String _getDayName(int weekday) {
    const days = [
      '',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return days[weekday];
  }

  String _getMonthName(int month) {
    const months = [
      '',
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
    return months[month];
  }

  String _getOrdinalSuffix(int day) {
    if (day >= 11 && day <= 13) return 'th';
    switch (day % 10) {
      case 1:
        return 'st';
      case 2:
        return 'nd';
      case 3:
        return 'rd';
      default:
        return 'th';
    }
  }

  // ═══════════════════════════════════════════════
  //  TRANSACTION TITLE CLEANING
  // ═══════════════════════════════════════════════

  String _cleanTransactionTitle(String rawText, {double? amount}) {
    String title = rawText.trim();

    // clean_ui_title rule: once a number is mapped to Amount, it must be
    // deleted from the title. Keep only the entity, category, or source noun.
    //
    // Few-shot mappings:
    // "my wife gave me 300" -> amount 300 -> "Wife"
    // "i paid 2000 from rent" -> amount 2000 -> "Rent"
    // "John paid me back 500" -> amount 500 -> "John"
    // "got my 15k sa sweldo" -> amount 15000 -> "Salary"
    title = _removeMappedAmountFromTitle(title, amount);

    // Remove pronouns
    final pronouns = [
      'i',
      'my',
      'me',
      'mine',
      'he',
      'him',
      'his',
      'she',
      'her',
      'hers',
      'they',
      'them',
      'their',
      'we',
      'us',
      'our',
    ];
    for (final pronoun in pronouns) {
      title = title.replaceAll(
        RegExp(r'\b' + pronoun + r'\b', caseSensitive: false),
        '',
      );
    }

    // Remove transaction action verbs
    final actionVerbs = [
      'paid',
      'pay',
      'sent',
      'send',
      'received',
      'receive',
      'got',
      'get',
      'transferred',
      'transfer',
      'spent',
      'spend',
      'bought',
      'buy',
      'purchased',
      'purchase',
      'gave',
      'give',
      'handed',
      'hand',
      'donated',
      'donate',
    ];
    for (final verb in actionVerbs) {
      title = title.replaceAll(
        RegExp(r'\b' + verb + r'\b', caseSensitive: false),
        '',
      );
    }

    // Remove structural prepositions (English and Filipino)
    final prepositions = [
      'from',
      'for',
      'to',
      'with',
      'by',
      'at',
      'on',
      'in',
      'of',
      'sa',
      'galing',
      'para',
      'kay',
      'mula',
      'upang',
    ];
    for (final prep in prepositions) {
      title = title.replaceAll(
        RegExp(r'\b' + prep + r'\b', caseSensitive: false),
        '',
      );
    }

    // Remove time/date words
    final timeWords = [
      'yesterday',
      'today',
      'tomorrow',
      'ago',
      'now',
      'earlier',
      'later',
      'last',
      'next',
      'recently',
    ];
    for (final timeWord in timeWords) {
      title = title.replaceAll(
        RegExp(r'\b' + timeWord + r'\b', caseSensitive: false),
        '',
      );
    }

    // Remove currency symbols and amounts
    title = title.replaceAll(RegExp(r'[₱$€£¥]'), '');
    title = title.replaceAll(
      RegExp(r'\b\d+(?:,\d+)*(?:\.\d+)?\s*[km]?\b', caseSensitive: false),
      '',
    );

    // Clean up extra spaces and punctuation
    title = title.replaceAll(RegExp(r'\s+'), ' ').trim();
    title = title.replaceAll(RegExp(r'^[^\w]+|[^\w]+$'), '');

    // Capitalize first letter of each word
    final words = title.split(' ');
    final capitalizedWords = words.map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).toList();
    title = capitalizedWords.join(' ');

    // Truncate to max 25 characters
    if (title.length > 25) {
      title = title.substring(0, 25).trim();
      // Don't cut in the middle of a word
      final lastSpace = title.lastIndexOf(' ');
      if (lastSpace > 10) {
        title = title.substring(0, lastSpace);
      }
    }

    // Fallback if title is empty after cleaning
    if (title.isEmpty) {
      title = 'Transaction';
    }

    return title;
  }

  String _removeMappedAmountFromTitle(String rawText, double? amount) {
    var title = rawText;
    if (amount == null || amount <= 0) return title;

    final wholeAmount = amount == amount.roundToDouble();
    final normalized = wholeAmount
        ? amount.toInt().toString()
        : amount.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
    final candidates = <String>{
      normalized,
      amount.toStringAsFixed(2),
      amount.toStringAsFixed(1),
      _formatNumberWithCommas(normalized),
    };

    if (amount >= 1000 && amount % 1000 == 0) {
      candidates.add('${(amount / 1000).toStringAsFixed(0)}k');
    } else if (amount >= 1000) {
      candidates.add(
        '${(amount / 1000).toStringAsFixed(1).replaceFirst(RegExp(r'\.0$'), '')}k',
      );
    }

    for (final candidate in candidates.where((c) => c.isNotEmpty)) {
      title = title.replaceAll(
        RegExp(
          r'(?<!\w)(?:â‚±|php|peso|pesos)?\s*' +
              RegExp.escape(candidate) +
              r'\s*(?:â‚±|php|peso|pesos)?(?!\w)',
          caseSensitive: false,
        ),
        ' ',
      );
    }

    return title;
  }

  String _formatNumberWithCommas(String value) {
    final parts = value.split('.');
    final whole = parts.first;
    final buffer = StringBuffer();

    for (int i = 0; i < whole.length; i++) {
      final remaining = whole.length - i;
      buffer.write(whole[i]);
      if (remaining > 1 && remaining % 3 == 1) {
        buffer.write(',');
      }
    }

    if (parts.length > 1) {
      buffer.write('.');
      buffer.write(parts.last);
    }

    return buffer.toString();
  }

  // ═══════════════════════════════════════════════
  //  REPLY HELPERS
  // ═══════════════════════════════════════════════

  BaiReply _fromRamsey(RamseyReply r) => BaiReply(
    r.text,
    extraTexts: r.extraTexts,
    quickReplies: r.quickReplies,
    navigateTo: r.navigateTo,
  );

  BaiReply _noAccountsReply() => const BaiReply(
    "You don't have any financial accounts set up yet. Visit the Wallet page to create one first!",
    quickReplies: ["What can I cook?"],
  );

  BaiReply _helpReply() => const BaiReply(
    "Here's everything I can help you with:\n\n"
    "🍳 Cooking\n"
    "'What can I cook for dinner?'\n"
    "'Recipe for adobo'\n"
    "'Suggest a weekly meal plan'\n\n"
    "🛒 Grocery Tracking\n"
    "'How much did I spend this week?'\n"
    "'Show my budget'\n"
    "'Show analytics'\n\n"
    "📋 Bills\n"
    "'Do I have upcoming bills?'\n"
    "'How much are my bills this week?'\n\n"
    "💰 Finance & Wallet\n"
    "'What is my total balance?'\n"
    "'Spent 150 on coffee from Cash'\n"
    "'Received 25000 salary to Bank Account'\n"
    "'Transfer 500 from Bank to GCash'\n\n"
    "📅 Future Events\n"
    "'Lance is going to pay me back 500 this 30th'\n"
    "'Expect my 25k salary to clear on the 15th'\n"
    "'Client will transfer 15k freelance milestone on Friday'",
    quickReplies: [
      "What can I cook?",
      "What is my total balance?",
      "Do I have upcoming bills?",
    ],
  );

  BaiReply _fallbackReply() => const BaiReply(
    "I'm here to help! Just ask me anything about cooking, groceries, bills, or your wallet. Type 'help' to see all my commands. 😊",
    quickReplies: ["Help", "What can I cook?", "What is my total balance?"],
  );
}
