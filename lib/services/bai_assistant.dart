import 'package:gabay/models/finance_models.dart';
import 'package:gabay/services/finance_storage.dart';
import 'package:gabay/services/settings_service.dart';
import 'package:gabay/services/ramsey_cooking_assistant.dart';
import 'package:gabay/services/bill_storage.dart';

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

  BaiReply get greeting {
    final meal = RamseyCookingAssistant.detectMeal(
      DateTime.now(),
    ).toLowerCase();
    return BaiReply(
      "Kumusta! I'm BAI, your Brother AI. 🤖🇵🇭",
      extraTexts: const [
        "I'm your all-in-one smart assistant — I can help with cooking, grocery tracking, bills, and your personal finances.\n\n"
            "Try asking me:\n"
            "'What can I cook for dinner?'\n"
            "'How much did I spend this week?'\n"
            "'Spent 150 on coffee from Cash'\n"
            "'Transfer 500 from Bank to GCash'\n"
            "'What is my total balance?'",
      ],
      quickReplies: [
        'What can I cook for $meal?',
        'What is my total balance?',
        'Do I have upcoming bills?',
      ],
    );
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
    if (_step != BaiStep.idle) {
      return await _handleStateMachine(n);
    }

    // ─── 2. FINANCE: transfers (highest specificity regex) ───
    final transferResult = await _tryTransfer(n);
    if (transferResult != null) return transferResult;

    // ─── 3. FINANCE: expense logging ───
    final expenseResult = await _tryLogExpense(n);
    if (expenseResult != null) return expenseResult;

    // ─── 4. FINANCE: income logging ───
    final incomeResult = await _tryLogIncome(n);
    if (incomeResult != null) return incomeResult;

    // ─── 5. FINANCE: total balance / balance checks ───
    final balanceResult = await _tryBalanceCheck(n);
    if (balanceResult != null) return balanceResult;

    // ─── 6. BILLS ───
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
    // Handle awaiting expense account state
    if (_step == BaiStep.awaitingExpenseAccount) {
      return await _handleExpenseAccountResponse(n);
    }

    // Handle awaiting income account state
    if (_step == BaiStep.awaitingIncomeAccount) {
      return await _handleIncomeAccountResponse(n);
    }

    // Allow finance commands to break out of cooking flow
    final transferResult = await _tryTransfer(n);
    if (transferResult != null) {
      _resetState();
      return transferResult;
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
    final undoResult = await _tryUndo(n);
    if (undoResult != null) {
      _resetState();
      return undoResult;
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
    _pendingIncomeAmount = null;
    _pendingIncomeDescription = null;
    _pendingIncomeCategory = null;
  }

  Future<BaiReply> _handleExpenseAccountResponse(String n) async {
    final accounts = await FinanceStorage.loadAccounts();
    if (accounts.isEmpty) return _noAccountsReply();

    // Find the account from user input
    Account? acc = _findAccount(n, accounts);
    if (acc == null) {
      final accountNames = accounts.map((a) => a.name).join(', ');
      return BaiReply(
        "I couldn't find that account. Available accounts: $accountNames\n\nWhich account did you spend from?",
      );
    }

    // Log the expense with the provided account
    final amount = _pendingExpenseAmount!;
    final desc = _pendingExpenseDescription!;
    final category = _pendingExpenseCategory!;

    try {
      final txn = FinanceTransaction(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        amount: amount,
        accountId: acc.id,
        accountName: acc.name,
        type: 'EXPENSE',
        category: category,
        description: desc,
      );
      await FinanceStorage.addTransaction(txn);

      _resetState();
      return BaiReply(
        "💸 Expense logged!\n\n- $_currency${amount.toStringAsFixed(2)} on $desc from ${acc.icon} ${acc.name} ($category)\n• New Balance: $_currency${(acc.balance - amount).toStringAsFixed(2)}",
        quickReplies: const [
          "What is my total balance?",
          "Check account balances",
        ],
        highlightColor: 'red',
      );
    } catch (e) {
      _resetState();
      return BaiReply(
        "⚠️ ${e.toString()}",
        quickReplies: const ["What is my total balance?"],
      );
    }
  }

  Future<BaiReply> _handleIncomeAccountResponse(String n) async {
    final accounts = await FinanceStorage.loadAccounts();
    if (accounts.isEmpty) return _noAccountsReply();

    // Find the account from user input
    Account? acc = _findAccount(n, accounts);
    if (acc == null) {
      final accountNames = accounts.map((a) => a.name).join(', ');
      return BaiReply(
        "I couldn't find that account. Available accounts: $accountNames\n\nWhich account did you receive it in?",
      );
    }

    // Log the income with the provided account
    final amount = _pendingIncomeAmount!;
    final desc = _pendingIncomeDescription!;
    final category = _pendingIncomeCategory!;

    try {
      final txn = FinanceTransaction(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        amount: amount,
        accountId: acc.id,
        accountName: acc.name,
        type: 'INCOME',
        category: category,
        description: desc,
      );
      await FinanceStorage.addTransaction(txn);

      _resetState();
      return BaiReply(
        "💵 Income logged!\n\n+ $_currency${amount.toStringAsFixed(2)} to ${acc.icon} ${acc.name} ($category)\n• New Balance: $_currency${(acc.balance + amount).toStringAsFixed(2)}",
        quickReplies: const [
          "What is my total balance?",
          "Check account balances",
        ],
        highlightColor: 'green',
      );
    } catch (e) {
      _resetState();
      return BaiReply(
        "⚠️ ${e.toString()}",
        quickReplies: const ["What is my total balance?"],
      );
    }
  }

  // ═══════════════════════════════════════════════
  //  FINANCE HANDLERS (from Tarsi)
  // ═══════════════════════════════════════════════

  Future<BaiReply?> _tryTransfer(String n) async {
    final reg = RegExp(
      r'(?:transfer|move|send|transferred|moved|sent)\s+(\d+(?:\.\d+)?)\s*(?:pesos|php|₱)?\s*from\s+(.+?)\s+to\s+(.+)',
    );
    final m = reg.firstMatch(n);
    if (m == null) return null;

    final amount = double.tryParse(m.group(1) ?? '');
    final fromName = m.group(2)?.trim() ?? '';
    final toName = m.group(3)?.trim() ?? '';
    if (amount == null || amount <= 0) return null;

    final accounts = await FinanceStorage.loadAccounts();
    if (accounts.isEmpty) return _noAccountsReply();

    final from = _findAccount(fromName, accounts);
    final to = _findAccount(toName, accounts);
    if (from == null) {
      return BaiReply(
        "⚠️ Can't find account '$fromName'. Available: ${accounts.map((e) => e.name).join(', ')}",
      );
    }
    if (to == null) {
      return BaiReply(
        "⚠️ Can't find account '$toName'. Available: ${accounts.map((e) => e.name).join(', ')}",
      );
    }
    if (from.id == to.id) {
      return const BaiReply("⚠️ Source and destination must be different.");
    }
    if (from.balance < amount) {
      return BaiReply(
        "⚠️ Insufficient funds in ${from.icon} ${from.name}. Balance: $_currency${from.balance.toStringAsFixed(2)}",
      );
    }

    try {
      await FinanceStorage.transferMoney(
        fromAccount: from,
        toAccount: to,
        amount: amount,
      );
      return BaiReply(
        "✅ Transfer Successful!\n\n• Moved $_currency${amount.toStringAsFixed(2)} from ${from.icon} ${from.name} to ${to.icon} ${to.name}.",
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

    // 2. Extract amount
    final amountReg = RegExp(r'(\d+(?:\.\d+)?)');
    final amountMatch = amountReg.firstMatch(n);
    if (amountMatch == null) return null;

    final amountStr = amountMatch.group(1);
    if (amountStr == null) return null;
    final amount = double.tryParse(amountStr);
    if (amount == null || amount <= 0) return null;

    final accounts = await FinanceStorage.loadAccounts();
    if (accounts.isEmpty) return _noAccountsReply();

    // 3. Try to detect account from text
    Account? acc = _detectAccountFromText(n, accounts);
    bool accountProvided = (acc != null);

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

    String descStr = _cleanDescription(n, amountStr, matchedAccSuffix);

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
      cleanedDesc = cleanedDesc[0].toUpperCase() + cleanedDesc.substring(1);
    }

    // If no account was detected, ask the user!
    if (!accountProvided) {
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
    final txn = FinanceTransaction(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      amount: amount,
      accountId: acc.id,
      accountName: acc.name,
      type: 'EXPENSE',
      category: category,
      description: cleanedDesc,
    );

    try {
      await FinanceStorage.addTransaction(txn);
      return BaiReply(
        "💸 Expense logged!\n\n- $_currency${amount.toStringAsFixed(2)} on $cleanedDesc from ${acc.icon} ${acc.name} ($category)\n• New Balance: $_currency${(acc.balance - amount).toStringAsFixed(2)}",
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

  Future<BaiReply?> _tryLogIncome(String n) async {
    // 1. Differentiate intent
    if (!_isIncomeIntent(n)) return null;

    // 2. Extract amount
    final amountReg = RegExp(r'(\d+(?:\.\d+)?)');
    final amountMatch = amountReg.firstMatch(n);
    if (amountMatch == null) return null;

    final amountStr = amountMatch.group(1);
    if (amountStr == null) return null;
    final amount = double.tryParse(amountStr);
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

    String descStr = _cleanDescription(n, amountStr, matchedAccSuffix);

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
      } else {
        cleanedDesc = 'General Income';
      }
    } else {
      cleanedDesc = cleanedDesc[0].toUpperCase() + cleanedDesc.substring(1);
    }

    // If no account was detected, ask the user!
    if (acc == null) {
      _pendingIncomeAmount = amount;
      _pendingIncomeDescription = cleanedDesc;
      _pendingIncomeCategory = _categorizeIncome(cleanedDesc);
      _step = BaiStep.awaitingIncomeAccount;

      final accountNames = accounts.map((a) => a.name).join(', ');
      return BaiReply(
        "Where did you receive it?\n\nAvailable accounts: $accountNames",
      );
    }

    final category = _categorizeIncome(cleanedDesc);
    final txn = FinanceTransaction(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      amount: amount,
      accountId: acc.id,
      accountName: acc.name,
      type: 'INCOME',
      category: category,
      description: cleanedDesc,
    );

    try {
      await FinanceStorage.addTransaction(txn);
      return BaiReply(
        "💵 Income logged!\n\n+ $_currency${amount.toStringAsFixed(2)} to ${acc.icon} ${acc.name} ($category)\n• New Balance: $_currency${(acc.balance + amount).toStringAsFixed(2)}",
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
                "• ${a.icon} ${a.name}: $_currency${a.balance.toStringAsFixed(2)}",
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
          "• ${a.icon} ${a.name} balance: $_currency${a.balance.toStringAsFixed(2)}",
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
      'revert',
      'delete last',
      'remove last',
      'cancel last',
      'undo previous',
      'revert previous',
      'undo last transaction',
      'revert previous transaction',
    ];

    if (!undoKeywords.any((k) => l.contains(k))) {
      return null;
    }

    final deletedTxn = await FinanceStorage.deleteLastTransaction();
    if (deletedTxn == null) {
      return BaiReply(
        "⚠️ No transactions to undo.",
        quickReplies: const ["What is my total balance?"],
      );
    }

    final type = deletedTxn.type == 'INCOME' ? 'income' : 'expense';
    final action = deletedTxn.type == 'INCOME' ? 'received' : 'spent';
    return BaiReply(
      "✅ Undone!\n\n• Removed $type: $_currency${deletedTxn.amount.toStringAsFixed(2)} $action on ${deletedTxn.description}\n• Account: ${deletedTxn.accountName}\n• Balance has been reverted.",
      quickReplies: const [
        "What is my total balance?",
        "Check account balances",
      ],
    );
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

  String _cleanDescription(
    String text,
    String amountStr,
    String? accMatchText,
  ) {
    String desc = text;
    // Remove the amount
    desc = desc.replaceFirst(amountStr, '');
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
        l.contains('sent his') ||
        l.contains('added') && l.contains('to my') ||
        l.contains('got') && !l.contains('spent') && !l.contains('paid')) {
      return true;
    }

    return false;
  }

  bool _isExpenseIntent(String text) {
    // If it's classified as income, it's not expense
    if (_isIncomeIntent(text)) return false;

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
    "• 'What can I cook for dinner?'\n"
    "• 'Recipe for adobo'\n"
    "• 'Suggest a weekly meal plan'\n\n"
    "🛒 Grocery Tracking\n"
    "• 'How much did I spend this week?'\n"
    "• 'Show my budget'\n"
    "• 'Show analytics'\n\n"
    "📋 Bills\n"
    "• 'Do I have upcoming bills?'\n"
    "• 'How much are my bills this week?'\n\n"
    "💰 Finance & Wallet\n"
    "• 'What is my total balance?'\n"
    "• 'Spent 150 on coffee from Cash'\n"
    "• 'Received 25000 salary to Bank Account'\n"
    "• 'Transfer 500 from Bank to GCash'",
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
