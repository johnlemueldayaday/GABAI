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

  const BaiReply(this.text, {this.extraTexts, this.quickReplies = const [], this.navigateTo});
}

/// BAI Step state machine for multi-turn cooking conversations
enum BaiStep { idle, cravingPrompt, dishPrompt, cartPrompt }

/// BAI (Brother AI) - Unified smart assistant merging Ramsey + Tarsi
class BaiAssistant {
  final String _currency = SettingsService().currency;

  // Cooking state (from Ramsey)
  final RamseyCookingAssistant _cookingEngine = RamseyCookingAssistant();
  BaiStep _step = BaiStep.idle;

  // Track last spending for breakdown follow-up
  bool _awaitingBreakdown = false;

  BaiReply get greeting {
    final meal = RamseyCookingAssistant.detectMeal(DateTime.now()).toLowerCase();
    return BaiReply(
      "Kumusta! I'm BAI, your Brother AI. 🤖🇵🇭",
      extraTexts: const [
        "I'm your all-in-one smart assistant — I can help with cooking, grocery tracking, bills, and your personal finances.\n\n"
        "Try asking me:\n"
        "• 'What can I cook for dinner?'\n"
        "• 'How much did I spend this week?'\n"
        "• 'Spent 150 on coffee from Cash'\n"
        "• 'Transfer 500 from Bank to GCash'\n"
        "• 'What is my net worth?'"
      ],
      quickReplies: [
        'What can I cook for $meal?',
        'What is my net worth?',
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

    // ─── 5. FINANCE: net worth / balance checks ───
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
        quickReplies: ['What is my net worth?', 'What can I cook for dinner?'],
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
    // Allow finance commands to break out of cooking flow
    final transferResult = await _tryTransfer(n);
    if (transferResult != null) { _resetState(); return transferResult; }
    final expenseResult = await _tryLogExpense(n);
    if (expenseResult != null) { _resetState(); return expenseResult; }
    final incomeResult = await _tryLogIncome(n);
    if (incomeResult != null) { _resetState(); return incomeResult; }
    final balanceResult = await _tryBalanceCheck(n);
    if (balanceResult != null) { _resetState(); return balanceResult; }

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
  }

  // ═══════════════════════════════════════════════
  //  FINANCE HANDLERS (from Tarsi)
  // ═══════════════════════════════════════════════

  Future<BaiReply?> _tryTransfer(String n) async {
    final reg = RegExp(
        r'(?:transfer|move|send|transferred|moved|sent)\s+(\d+(?:\.\d+)?)\s*(?:pesos|php|₱)?\s*from\s+(.+?)\s+to\s+(.+)');
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
    if (from == null) return BaiReply("⚠️ Can't find account '$fromName'. Available: ${accounts.map((e) => e.name).join(', ')}");
    if (to == null) return BaiReply("⚠️ Can't find account '$toName'. Available: ${accounts.map((e) => e.name).join(', ')}");
    if (from.id == to.id) return const BaiReply("⚠️ Source and destination must be different.");
    if (from.balance < amount) return BaiReply("⚠️ Insufficient funds in ${from.icon} ${from.name}. Balance: $_currency${from.balance.toStringAsFixed(2)}");

    await FinanceStorage.transferMoney(fromAccount: from, toAccount: to, amount: amount);
    return BaiReply(
      "✅ **Transfer Successful!**\n\nMoved **$_currency${amount.toStringAsFixed(2)}** from ${from.icon} **${from.name}** to ${to.icon} **${to.name}**.",
      quickReplies: const ["What is my net worth?", "Check account balances"],
    );
  }

  Future<BaiReply?> _tryLogExpense(String n) async {
    final expenseKeywords = ['spent', 'paid', 'cost', 'buy', 'bought', 'gastos', 'expense', 'bumili', 'add', 'log', 'logged', 'minus', 'deduct'];
    
    // Fast fail if no number
    final amountReg = RegExp(r'(\d+(?:\.\d+)?)');
    final amountMatch = amountReg.firstMatch(n);
    if (amountMatch == null) return null;

    final amountStr = amountMatch.group(1);
    final amount = double.tryParse(amountStr ?? '');
    if (amount == null || amount <= 0) return null;

    // Prevent overlap with income
    if (_isIncomeDesc(n) || n.contains('received') || n.contains('earned')) {
       return null;
    }

    bool hasKeyword = expenseKeywords.any((k) => n.contains(k));
    if (!hasKeyword) return null;

    String descStr = n;
    
    // Extract account FIRST before removing words
    String accName = 'Cash'; // Default
    final accReg = RegExp(r'(?:from|using|in|through|with)\s+(.+)$');
    final accMatch = accReg.firstMatch(descStr);
    if (accMatch != null) {
      accName = accMatch.group(1)?.trim() ?? 'Cash';
      descStr = descStr.replaceAll(accMatch.group(0)!, '');
    }

    // Now clean up description
    for (var k in expenseKeywords) {
      descStr = descStr.replaceAll(RegExp(r'\b' + k + r'\b'), '');
    }
    descStr = descStr.replaceFirst(amountStr!, '');
    descStr = descStr.replaceAll(RegExp(r'\b(?:i|on|for|pesos|php|₱|the|a|an)\b'), '');
    descStr = descStr.replaceAll(RegExp(r'\s+'), ' '); // fix multiple spaces
    descStr = descStr.trim();

    if (descStr.isEmpty) descStr = 'General Expense';

    final accounts = await FinanceStorage.loadAccounts();
    if (accounts.isEmpty) return _noAccountsReply();
    
    Account? acc = _findAccount(accName, accounts);
    acc ??= accounts.isNotEmpty ? accounts.first : null;
    if (acc == null) return BaiReply("⚠️ Can't find an account to log this expense.");

    final category = _categorizeExpense(descStr);
    final txn = FinanceTransaction(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      amount: amount,
      accountId: acc.id,
      accountName: acc.name,
      type: 'EXPENSE',
      category: category,
      description: descStr[0].toUpperCase() + descStr.substring(1),
    );
    await FinanceStorage.addTransaction(txn);
    return BaiReply(
      "💸 **Expense Logged!**\n\n**$_currency${amount.toStringAsFixed(2)}** from ${acc.icon} **${acc.name}** • $category\nNew Balance: $_currency${(acc.balance - amount).toStringAsFixed(2)}",
      quickReplies: const ["What is my net worth?", "Check account balances"],
    );
  }

  Future<BaiReply?> _tryLogIncome(String n) async {
    final incomeKeywords = ['received', 'earned', 'deposit', 'deposits', 'sweldo', 'income', 'salary', 'freelance', 'sahod', 'bonus'];
    
    final amountReg = RegExp(r'(\d+(?:\.\d+)?)');
    final amountMatch = amountReg.firstMatch(n);
    if (amountMatch == null) return null;

    final amountStr = amountMatch.group(1);
    final amount = double.tryParse(amountStr ?? '');
    if (amount == null || amount <= 0) return null;

    bool hasKeyword = incomeKeywords.any((k) => n.contains(k));
    if (!hasKeyword) {
      if (!n.contains('to ') && !n.contains('into ')) return null;
    }

    String descStr = n;

    // Extract account FIRST
    String accName = 'Bank Account'; // Default
    final accReg = RegExp(r'(?:to|in|into|through|with)\s+(.+)$');
    final accMatch = accReg.firstMatch(descStr);
    if (accMatch != null) {
      accName = accMatch.group(1)?.trim() ?? 'Bank Account';
      descStr = descStr.replaceAll(accMatch.group(0)!, '');
    }

    // Now clean up description
    for (var k in incomeKeywords) {
      descStr = descStr.replaceAll(RegExp(r'\b' + k + r'\b'), '');
    }
    descStr = descStr.replaceFirst(amountStr!, '');
    descStr = descStr.replaceAll(RegExp(r'\b(?:i|as|for|pesos|php|₱|add|the|a|an)\b'), '');
    descStr = descStr.replaceAll(RegExp(r'\s+'), ' ');
    descStr = descStr.trim();

    // If there's no description left, use the original income keyword if available
    if (descStr.isEmpty) {
      if (n.contains('salary') || n.contains('sweldo') || n.contains('sahod')) {
        descStr = 'Salary';
      } else if (n.contains('freelance')) {
        descStr = 'Freelance';
      } else {
        descStr = 'General Income';
      }
    }

    final accounts = await FinanceStorage.loadAccounts();
    if (accounts.isEmpty) return _noAccountsReply();
    
    Account? acc = _findAccount(accName, accounts);
    acc ??= accounts.isNotEmpty ? accounts.first : null;
    if (acc == null) return BaiReply("⚠️ Can't find an account to log this income.");

    final category = _categorizeIncome(descStr);
    final txn = FinanceTransaction(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      amount: amount,
      accountId: acc.id,
      accountName: acc.name,
      type: 'INCOME',
      category: category,
      description: descStr[0].toUpperCase() + descStr.substring(1),
    );
    await FinanceStorage.addTransaction(txn);
    return BaiReply(
      "💵 **Income Logged!**\n\n**$_currency${amount.toStringAsFixed(2)}** to ${acc.icon} **${acc.name}** • $category\nNew Balance: $_currency${(acc.balance + amount).toStringAsFixed(2)}",
      quickReplies: const ["What is my net worth?", "Check account balances"],
    );
  }

  Future<BaiReply?> _tryBalanceCheck(String n) async {
    // Net worth
    if (n == 'net worth' || n.contains('networth') || n.contains('what is my net worth') ||
        n.contains('how much money do i have') || n.contains('total balance') ||
        n.contains('financial status') || n == 'check balances' || n == 'check account balances') {
      final accounts = await FinanceStorage.loadAccounts();
      if (accounts.isEmpty) return _noAccountsReply();
      final netWorth = await FinanceStorage.getNetWorth();
      final lines = accounts.map((a) => "• ${a.icon} **${a.name}**: $_currency${a.balance.toStringAsFixed(2)}").toList();
      return BaiReply(
        "💰 **Your Net Worth**: **$_currency${netWorth.toStringAsFixed(2)}**\n\n${lines.join('\n')}",
        quickReplies: const ["Check Cash balance", "What can I cook?"],
      );
    }

    // Individual account
    final accounts = await FinanceStorage.loadAccounts();
    for (final a in accounts) {
      final name = a.name.toLowerCase().trim();
      if (n == '$name balance' || n == 'balance of $name' || n == 'check $name' ||
          n == 'check $name balance' || (n.contains('how much') && n.contains(name))) {
        return BaiReply(
          "${a.icon} **${a.name}** balance: **$_currency${a.balance.toStringAsFixed(2)}**",
          quickReplies: const ["What is my net worth?"],
        );
      }
    }
    return null;
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
      n.contains('total bills this week') || n.contains('bills this week');

  bool _isBillAsk(String n) =>
      n.contains('upcoming bills') || n.contains('do i have bills') ||
      n.contains('any bills') || n.contains('bayad') || n.contains('overdue');

  bool _isSpendingAsk(String n) =>
      n.contains('spend') || n.contains('spending') || n.contains('gastos') ||
      n.contains('purchase') || n.contains('how much did i');

  bool _isBreakdownAsk(String n) =>
      n == 'yes' || n == 'oo' || n.contains('breakdown') || n.contains('show');

  bool _isBudgetAsk(String n) =>
      n.contains('budget') || n.contains('limit') || n.contains('magkano nalang');

  bool _isAnalyticsAsk(String n) =>
      n.contains('analytics') || n.contains('insight') || n.contains('habit') ||
      n.contains('chart') || n.contains('summary');

  bool _isMealPlanAsk(String n) =>
      n.contains('meal plan') || n.contains('plan my meals') || n.contains('meal prep');

  bool _isCookingAsk(String n) =>
      n.contains('cook') || n.contains('recipe') || n.contains('dish') ||
      n.contains('ulam') || n.contains('luto') || n.contains('kain') ||
      n.contains('suggest') || n.contains('breakfast') || n.contains('lunch') ||
      n.contains('dinner') || n.contains('snack') || n.contains('merienda') ||
      n.contains('hapunan') || n.contains('almusal') || n.contains('tanghalian') ||
      n.contains('what can i') || n.contains('midnight');

  bool _isCravingKeyword(String n) =>
      n == 'healthy' || n == 'soupy' || n == 'spicy' || n == 'anything' ||
      n == 'sabaw' || n == 'maanghang' || n == 'kahit ano' ||
      n.contains('fridge') || n.contains('ref');

  bool _isIncomeDesc(String d) {
    final l = d.toLowerCase();
    return l.contains('salary') || l.contains('sweldo') || l.contains('bonus') ||
        l.contains('gift') || l.contains('freelance') || l.contains('earned') || l.contains('dividends');
  }

  // ═══════════════════════════════════════════════
  //  FINANCE CATEGORY CLASSIFIERS
  // ═══════════════════════════════════════════════

  String _categorizeExpense(String desc) {
    final l = desc.toLowerCase();
    if (_matchAny(l, ['coffee','food','drinks','dinner','lunch','breakfast','snack','restaurant','milk','grocery','groceries','burger','starbucks','milktea','milk tea'])) return 'Food & Drinks';
    if (_matchAny(l, ['gas','transport','taxi','grab','fare','bus','jeep','jeepney','train','ride','toll'])) return 'Transportation';
    if (_matchAny(l, ['rent','electricity','water','internet','wifi','load','bill','utility','utilities','power'])) return 'Bills & Utilities';
    if (_matchAny(l, ['movie','netflix','game','gaming','cinema','concert','steam','spotify','arcade'])) return 'Entertainment';
    if (_matchAny(l, ['shirt','clothes','shoes','shopping','mall','lazada','shopee'])) return 'Shopping';
    return 'Others';
  }

  String _categorizeIncome(String desc) {
    final l = desc.toLowerCase();
    if (_matchAny(l, ['salary','sweldo','paycheck'])) return 'Salary';
    if (_matchAny(l, ['freelance','sideline','gig','project'])) return 'Freelance';
    if (_matchAny(l, ['invest','investment','stocks','crypto','dividend'])) return 'Investment';
    return 'Others';
  }

  bool _matchAny(String input, List<String> keywords) => keywords.any(input.contains);

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

  // ═══════════════════════════════════════════════
  //  REPLY HELPERS
  // ═══════════════════════════════════════════════

  BaiReply _fromRamsey(RamseyReply r) => BaiReply(r.text, extraTexts: r.extraTexts, quickReplies: r.quickReplies, navigateTo: r.navigateTo);

  BaiReply _noAccountsReply() => const BaiReply(
    "You don't have any financial accounts set up yet. Visit the Wallet page to create one first!",
    quickReplies: ["What can I cook?"],
  );

  BaiReply _helpReply() => const BaiReply(
    "Here's everything I can help you with:\n\n"
    "🍳 **Cooking**\n"
    "• 'What can I cook for dinner?'\n"
    "• 'Recipe for adobo'\n"
    "• 'Suggest a weekly meal plan'\n\n"
    "🛒 **Grocery Tracking**\n"
    "• 'How much did I spend this week?'\n"
    "• 'Show my budget'\n"
    "• 'Show analytics'\n\n"
    "📋 **Bills**\n"
    "• 'Do I have upcoming bills?'\n"
    "• 'How much are my bills this week?'\n\n"
    "💰 **Finance & Wallet**\n"
    "• 'What is my net worth?'\n"
    "• 'Spent 150 on coffee from Cash'\n"
    "• 'Received 25000 salary to Bank Account'\n"
    "• 'Transfer 500 from Bank to GCash'",
    quickReplies: ["What can I cook?", "What is my net worth?", "Do I have upcoming bills?"],
  );

  BaiReply _fallbackReply() => const BaiReply(
    "I'm here to help! Just ask me anything about cooking, groceries, bills, or your wallet. Type 'help' to see all my commands. 😊",
    quickReplies: ["Help", "What can I cook?", "What is my net worth?"],
  );
}
