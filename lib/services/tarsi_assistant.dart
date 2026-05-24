import 'package:gabay/models/finance_models.dart';
import 'package:gabay/services/finance_storage.dart';
import 'package:gabay/services/settings_service.dart';

class TarsiReply {
  final String text;
  final List<String>? extraTexts;
  final List<String> quickReplies;
  final bool success;

  const TarsiReply(this.text, {this.extraTexts, this.quickReplies = const [], this.success = true});
}

class TarsiAssistant {
  final String _currency = SettingsService().currency;

  String _accountLabel(Account account) {
    final normalizedName = account.name.trim().toLowerCase();
    final hasAssetIcon = account.icon.startsWith('assets/images/') ||
        {
          'gcash',
          'maya',
          'paymaya',
          'cash',
          'bdo',
          'landbank',
          'psbank',
        }.contains(normalizedName);

    return hasAssetIcon
        ? account.name
        : '${account.icon} ${account.name}';
  }

  TarsiReply get greeting {
    return const TarsiReply(
      "Hello! I am Tarsi, your private, local financial assistant. 🦉",
      extraTexts: [
        "I can help you track expenses, income, and transfers completely offline.\n\nTry saying:\n• 'Spent 150 on coffee from Cash'\n• 'Received 25000 salary to Bank Account'\n• 'Transfer 500 from Bank Account to GCash'\n• 'What is my total balance?'"
      ],
      quickReplies: [
        "What is my total balance?",
        "Check account balances",
        "Spent 150 on coffee from Cash"
      ],
    );
  }

  /// Maps a parsed item description to one of the predefined categories
  String _categorizeExpense(String desc) {
    final lower = desc.toLowerCase().trim();
    if (lower.contains('coffee') ||
        lower.contains('food') ||
        lower.contains('drinks') ||
        lower.contains('dinner') ||
        lower.contains('lunch') ||
        lower.contains('breakfast') ||
        lower.contains('snack') ||
        lower.contains('restaurant') ||
        lower.contains('milk') ||
        lower.contains('grocery') ||
        lower.contains('groceries') ||
        lower.contains('burger') ||
        lower.contains('starbucks')) {
      return 'Food & Drinks';
    }
    if (lower.contains('gas') ||
        lower.contains('transport') ||
        lower.contains('taxi') ||
        lower.contains('grab') ||
        lower.contains('fare') ||
        lower.contains('bus') ||
        lower.contains('jeep') ||
        lower.contains('jeepney') ||
        lower.contains('train') ||
        lower.contains('ride') ||
        lower.contains('toll')) {
      return 'Transportation';
    }
    if (lower.contains('rent') ||
        lower.contains('electricity') ||
        lower.contains('water') ||
        lower.contains('internet') ||
        lower.contains('wifi') ||
        lower.contains('load') ||
        lower.contains('bill') ||
        lower.contains('bills') ||
        lower.contains('utility') ||
        lower.contains('utilities') ||
        lower.contains('power')) {
      return 'Bills & Utilities';
    }
    if (lower.contains('movie') ||
        lower.contains('netflix') ||
        lower.contains('game') ||
        lower.contains('gaming') ||
        lower.contains('cinema') ||
        lower.contains('concert') ||
        lower.contains('fun') ||
        lower.contains('steam') ||
        lower.contains('spotify') ||
        lower.contains('arcade')) {
      return 'Entertainment';
    }
    if (lower.contains('shirt') ||
        lower.contains('clothes') ||
        lower.contains('shoes') ||
        lower.contains('shopping') ||
        lower.contains('mall') ||
        lower.contains('lazada') ||
        lower.contains('shopee')) {
      return 'Shopping';
    }
    return 'Others';
  }

  String _categorizeIncome(String desc) {
    final lower = desc.toLowerCase().trim();
    if (lower.contains('salary') || lower.contains('sweldo') || lower.contains('paycheck') || lower.contains('salary')) {
      return 'Salary';
    }
    if (lower.contains('freelance') || lower.contains('sideline') || lower.contains('gig') || lower.contains('project')) {
      return 'Freelance';
    }
    if (lower.contains('invest') || lower.contains('investment') || lower.contains('stocks') || lower.contains('crypto') || lower.contains('dividend')) {
      return 'Investment';
    }
    return 'Others';
  }

  /// Parses and handles user input locally, interacting with FinanceStorage
  Future<TarsiReply> handle(String rawInput) async {
    final normalized = rawInput.toLowerCase().trim();
    final accounts = await FinanceStorage.loadAccounts();

    if (accounts.isEmpty) {
      return const TarsiReply(
        "You don't have any accounts set up yet. Please visit the Wallet dashboard to create an account first!",
        quickReplies: ["Show my total balance"],
      );
    }

    // 1. HELP / GREETING REQUESTS
    if (normalized == 'help' || normalized.contains('what can you do') || normalized.contains('commands')) {
      return TarsiReply(
        "Here are some examples of what you can ask me:\n\n"
        "📈 Logging Transactions:\n"
        "• *'Spent 200 on milk tea from GCash'*\n"
        "• *'Received 15000 salary to Bank Account'*\n\n"
        "💸 Transferring Money:\n"
        "• *'Transfer 1000 from Bank Account to GCash'*\n\n"
        "📊 Checking Balances:\n"
        "• *'What is my total balance?'*\n"
        "• *'Check Cash balance'*",
        quickReplies: const ["What is my total balance?", "Check account balances"],
      );
    }

    // 2. NET WORTH / BALANCE CHECKS
    if (normalized == 'total balance' ||
        normalized.contains('totalbalance') ||
        normalized.contains('how much money do i have') ||
        normalized.contains('total balance') ||
        normalized.contains('financial status') ||
        normalized == 'check balances' ||
        normalized == 'check account balances') {
      final netWorth = await FinanceStorage.getNetWorth();
      final lines = <String>[];
      for (final a in accounts) {
        lines.add("• ${_accountLabel(a)}: $_currency${a.balance.toStringAsFixed(2)}");
      }
      return TarsiReply(
        "🦉 Your Financial Summary:\n\n"
        "💰 Total Balance: $_currency${netWorth.toStringAsFixed(2)}\n\n"
        "${lines.join('\n')}",
        quickReplies: const ["Check GCash balance", "Check Cash balance"],
      );
    }

    // 3. INDIVIDUAL ACCOUNT BALANCE CHECKS
    for (final a in accounts) {
      final nameLower = a.name.toLowerCase().trim();
      if (normalized == '$nameLower balance' ||
          normalized == 'balance of $nameLower' ||
          normalized == 'check $nameLower' ||
          normalized == 'check $nameLower balance' ||
          normalized.contains('how much') && normalized.contains(nameLower)) {
        return TarsiReply(
          "🦉 Your current balance for ${_accountLabel(a)} is $_currency${a.balance.toStringAsFixed(2)}.",
          quickReplies: const ["What is my total balance?"],
        );
      }
    }

    // 4. TRANSFERS DETECTER
    // Regex: Match "transfer/move 500 from Acc1 to Acc2"
    final transferReg = RegExp(
        r'(?:transfer|move|send|transferred|moved|sent)\s+(\d+(?:\.\d+)?)\s*(?:pesos|php|₱)?\s*from\s+(.+?)\s+to\s+(.+)');
    final transferMatch = transferReg.firstMatch(normalized);
    if (transferMatch != null) {
      final amount = double.tryParse(transferMatch.group(1) ?? '');
      final fromName = transferMatch.group(2)?.trim() ?? '';
      final toName = transferMatch.group(3)?.trim() ?? '';

      if (amount != null && amount > 0) {
        final fromAcc = _findAccountBestMatch(fromName, accounts);
        final toAcc = _findAccountBestMatch(toName, accounts);

        if (fromAcc == null) {
          return TarsiReply(
            "⚠️ I couldn't find the source account '$fromName'. Available accounts: ${accounts.map((e) => e.name).join(', ')}",
          );
        }
        if (toAcc == null) {
          return TarsiReply(
            "⚠️ I couldn't find the destination account '$toName'. Available accounts: ${accounts.map((e) => e.name).join(', ')}",
          );
        }
        if (fromAcc.id == toAcc.id) {
          return const TarsiReply("⚠️ Source and destination accounts must be different.");
        }
        if (fromAcc.balance < amount) {
          return TarsiReply(
            "⚠️ Insufficient funds in ${_accountLabel(fromAcc)}.\n"
            "Balance: $_currency${fromAcc.balance.toStringAsFixed(2)}, requested: $_currency${amount.toStringAsFixed(2)}",
          );
        }

        // Execute transfer
        await FinanceStorage.transferMoney(fromAccount: fromAcc, toAccount: toAcc, amount: amount);
        return TarsiReply(
          "✅ Transfer Successful!\n\n"
          "Moved $_currency${amount.toStringAsFixed(2)} from ${_accountLabel(fromAcc)} to ${_accountLabel(toAcc)}.",
          quickReplies: const ["What is my total balance?", "Check account balances"],
        );
      }
    }

    // 5. EXPENSE DETECTER
    // Regex matches: "spent 150 on coffee from Cash" / "paid 1000 for wifi using Bank Account"
    final expenseReg = RegExp(
        r'(?:spent|paid|cost|buy|bought|gastos|expense|bumili)\s+(\d+(?:\.\d+)?)\s*(?:pesos|php|₱)?\s*(?:on|for)\s+(.+?)\s+(?:from|using|in|through|with)\s+(.+)');
    var expenseMatch = expenseReg.firstMatch(normalized);

    // Alternative match order: "spent 150 from Cash on coffee"
    if (expenseMatch == null) {
      final altExpenseReg = RegExp(
          r'(?:spent|paid|cost|buy|bought|gastos|expense|bumili)\s+(\d+(?:\.\d+)?)\s*(?:pesos|php|₱)?\s*(?:from|using|in|through|with)\s+(.+?)\s+(?:on|for)\s+(.+)');
      expenseMatch = altExpenseReg.firstMatch(normalized);
      if (expenseMatch != null) {
        // Swap group 2 and 3 so group 2 is description and group 3 is account
        final amountStr = expenseMatch.group(1);
        final accStr = expenseMatch.group(2);
        final descStr = expenseMatch.group(3);
        
        final amount = double.tryParse(amountStr ?? '');
        if (amount != null && amount > 0 && accStr != null && descStr != null) {
          return await _logExpense(amount, descStr, accStr, accounts);
        }
      }
    } else {
      final amount = double.tryParse(expenseMatch.group(1) ?? '');
      final desc = expenseMatch.group(2) ?? 'Expense';
      final accName = expenseMatch.group(3) ?? '';
      if (amount != null && amount > 0) {
        return await _logExpense(amount, desc, accName, accounts);
      }
    }

    // 6. INCOME DETECTER
    // Regex matches: "received 5000 as freelance in GCash" / "salary 25000 to Bank Account"
    final incomeReg = RegExp(
        r'(?:received|earned|deposit|deposits|sweldo|income|add income)\s+(\d+(?:\.\d+)?)\s*(?:pesos|php|₱)?\s*(?:as|for|of)?\s*(.+?)\s+(?:to|in|into|through|with)\s+(.+)');
    var incomeMatch = incomeReg.firstMatch(normalized);

    if (incomeMatch == null) {
      // Alternative: "salary 25000 to Cash"
      final altIncomeReg = RegExp(
          r'(.+?)\s+(\d+(?:\.\d+)?)\s*(?:pesos|php|₱)?\s*(?:to|in|into|through|with)\s+(.+)');
      incomeMatch = altIncomeReg.firstMatch(normalized);
      if (incomeMatch != null) {
        final desc = incomeMatch.group(1)?.trim();
        final amountStr = incomeMatch.group(2);
        final accStr = incomeMatch.group(3)?.trim();
        
        final amount = double.tryParse(amountStr ?? '');
        if (amount != null && amount > 0 && desc != null && accStr != null && _isIncomeDesc(desc)) {
          return await _logIncome(amount, desc, accStr, accounts);
        }
      }
    } else {
      final amount = double.tryParse(incomeMatch.group(1) ?? '');
      final desc = incomeMatch.group(2) ?? 'Income';
      final accName = incomeMatch.group(3) ?? '';
      if (amount != null && amount > 0) {
        return await _logIncome(amount, desc, accName, accounts);
      }
    }

    // Default fallback
    return const TarsiReply(
      "🦉 I didn't quite catch that. You can log transactions like:\n"
      "• *'Spent 150 on coffee from Cash'*\n"
      "• *'salary 25000 to Bank Account'*\n"
      "• *'transfer 500 from Cash to GCash'*",
      quickReplies: ["What is my total balance?", "Check account balances"],
    );
  }

  bool _isIncomeDesc(String desc) {
    final d = desc.toLowerCase();
    return d.contains('salary') || d.contains('sweldo') || d.contains('bonus') || d.contains('gift') || d.contains('freelance') || d.contains('earned') || d.contains('dividends');
  }

  Future<TarsiReply> _logExpense(double amount, String desc, String accName, List<Account> accounts) async {
    final acc = _findAccountBestMatch(accName, accounts);
    if (acc == null) {
      return TarsiReply(
        "⚠️ I couldn't find the account '$accName' to log the expense. Available: ${accounts.map((e) => e.name).join(', ')}",
      );
    }

    final category = _categorizeExpense(desc);
    final txn = FinanceTransaction(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      amount: amount,
      accountId: acc.id,
      accountName: acc.name,
      type: 'EXPENSE',
      category: category,
      description: desc[0].toUpperCase() + desc.substring(1),
    );

    await FinanceStorage.addTransaction(txn);
    return TarsiReply(
      "💸 Expense Logged Successfully!\n\n"
      "Recorded an expense of $_currency${amount.toStringAsFixed(2)} from your ${_accountLabel(acc)} under $category.\n"
      "New Balance: $_currency${(acc.balance - amount).toStringAsFixed(2)}",
      quickReplies: const ["What is my total balance?", "Check account balances"],
    );
  }

  Future<TarsiReply> _logIncome(double amount, String desc, String accName, List<Account> accounts) async {
    final acc = _findAccountBestMatch(accName, accounts);
    if (acc == null) {
      return TarsiReply(
        "⚠️ I couldn't find the account '$accName' to deposit the income. Available: ${accounts.map((e) => e.name).join(', ')}",
      );
    }

    final category = _categorizeIncome(desc);
    final txn = FinanceTransaction(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      amount: amount,
      accountId: acc.id,
      accountName: acc.name,
      type: 'INCOME',
      category: category,
      description: desc[0].toUpperCase() + desc.substring(1),
    );

    await FinanceStorage.addTransaction(txn);
    return TarsiReply(
      "💵 Income Logged Successfully!\n\n"
      "Recorded an income of $_currency${amount.toStringAsFixed(2)} to your ${_accountLabel(acc)} under $category.\n"
      "New Balance: $_currency${(acc.balance + amount).toStringAsFixed(2)}",
      quickReplies: const ["What is my total balance?", "Check account balances"],
    );
  }

  /// Tries to find the account that best matches the search input (case-insensitive & sub-matching)
  Account? _findAccountBestMatch(String inputName, List<Account> accounts) {
    final nameLower = inputName.toLowerCase().trim();
    if (nameLower.isEmpty) return null;

    // Exact match first
    for (final a in accounts) {
      if (a.name.toLowerCase().trim() == nameLower) return a;
    }
    // Sub-segment match
    for (final a in accounts) {
      final lowerA = a.name.toLowerCase();
      if (lowerA.contains(nameLower) || nameLower.contains(lowerA)) {
        return a;
      }
    }
    return null;
  }
}
