import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/finance_models.dart';

/// Persists and manages financial accounts and transactions locally.
/// Follows the same SharedPreferences pattern as BillStorage and GroceryStorage.
class FinanceStorage {
  static const _accountsKey = 'finance_accounts';
  static const _transactionsKey = 'finance_transactions';

  // ──────────────────────────────────────────────
  //  ACCOUNTS
  // ──────────────────────────────────────────────

  /// Save all accounts to local storage.
  static Future<void> saveAccounts(List<Account> accounts) async {
    final prefs = await SharedPreferences.getInstance();
    final data = accounts.map((a) => a.toJson()).toList();
    await prefs.setString(_accountsKey, jsonEncode(data));
  }

  /// Load all accounts from local storage.
  static Future<List<Account>> loadAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_accountsKey);
    if (str == null) return [];
    try {
      final List<dynamic> data = jsonDecode(str);
      return data.map((a) => Account.fromJson(a)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Add a new account and persist.
  static Future<List<Account>> addAccount(Account account) async {
    final accounts = await loadAccounts();
    accounts.add(account);
    await saveAccounts(accounts);
    return accounts;
  }

  /// Update an existing account by ID and persist.
  static Future<List<Account>> updateAccount(Account updated) async {
    final accounts = await loadAccounts();
    final index = accounts.indexWhere((a) => a.id == updated.id);
    if (index != -1) {
      accounts[index] = updated;
      await saveAccounts(accounts);
    }
    return accounts;
  }

  /// Delete an account by ID and persist.
  static Future<List<Account>> deleteAccount(String accountId) async {
    final accounts = await loadAccounts();
    accounts.removeWhere((a) => a.id == accountId);
    await saveAccounts(accounts);
    return accounts;
  }

  /// Find an account by its name (case-insensitive).
  static Future<Account?> findAccountByName(String name) async {
    final accounts = await loadAccounts();
    final lower = name.toLowerCase().trim();
    try {
      return accounts.firstWhere((a) => a.name.toLowerCase().trim() == lower);
    } catch (_) {
      return null;
    }
  }

  /// Calculate total net worth across all accounts.
  static Future<double> getNetWorth() async {
    final accounts = await loadAccounts();
    double total = 0;
    for (final a in accounts) {
      total += a.balance;
    }
    return total;
  }

  // ──────────────────────────────────────────────
  //  TRANSACTIONS
  // ──────────────────────────────────────────────

  /// Save all transactions to local storage.
  static Future<void> saveTransactions(List<FinanceTransaction> txns) async {
    final prefs = await SharedPreferences.getInstance();
    final data = txns.map((t) => t.toJson()).toList();
    await prefs.setString(_transactionsKey, jsonEncode(data));
  }

  /// Load all transactions from local storage.
  static Future<List<FinanceTransaction>> loadTransactions() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_transactionsKey);
    if (str == null) return [];
    try {
      final List<dynamic> data = jsonDecode(str);
      return data.map((t) => FinanceTransaction.fromJson(t)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Add a transaction, update the linked account balance, and persist both.
  /// This is the core method that Tarsi's `add_transaction` tool will call.
  /// Throws an exception if the transaction would result in a negative balance for Cash, E-Wallet, or Bank accounts.
  static Future<void> addTransaction(FinanceTransaction txn) async {
    // 1. Load the account to check balance constraints
    final accounts = await loadAccounts();
    final index = accounts.indexWhere((a) => a.id == txn.accountId);
    if (index == -1) {
      throw Exception('Account not found');
    }

    final account = accounts[index];
    double newBalance;
    if (txn.type == 'INCOME') {
      newBalance = account.balance + txn.amount;
    } else {
      newBalance = account.balance - txn.amount;
    }

    // Check for negative balance on Cash, E-Wallet, and Bank accounts
    if (_isNonNegativeAccount(account.type) && newBalance < 0) {
      throw Exception(
        'Insufficient funds. Transaction would result in a negative balance for ${account.name} (${account.type}).',
      );
    }

    // 2. Save the transaction
    final transactions = await loadTransactions();
    transactions.add(txn.copyWith(previousBalance: account.balance));
    await saveTransactions(transactions);

    // 3. Update the account balance
    accounts[index] = account.copyWith(balance: newBalance);
    await saveAccounts(accounts);
  }

  /// Transfer money between two accounts and log it as two transactions.
  /// This is the core method that Tarsi's `transfer_money` tool will call.
  /// Throws an exception if the source account has insufficient funds.
  static Future<void> transferMoney({
    required Account fromAccount,
    required Account toAccount,
    required double amount,
  }) async {
    // Check if source account has sufficient funds
    if (_isNonNegativeAccount(fromAccount.type) &&
        fromAccount.balance < amount) {
      throw Exception(
        'Insufficient funds in ${fromAccount.name}. Balance: ${fromAccount.balance.toStringAsFixed(2)}',
      );
    }

    final now = DateTime.now();
    final txnId = now.millisecondsSinceEpoch.toString();

    // Create outgoing transaction
    final outTxn = FinanceTransaction(
      id: '${txnId}_out',
      amount: amount,
      accountId: fromAccount.id,
      accountName: fromAccount.name,
      type: 'EXPENSE',
      category: 'Transfer',
      description: 'Transfer to ${toAccount.name}',
      date: now,
    );

    // Create incoming transaction
    final inTxn = FinanceTransaction(
      id: '${txnId}_in',
      amount: amount,
      accountId: toAccount.id,
      accountName: toAccount.name,
      type: 'INCOME',
      category: 'Transfer',
      description: 'Transfer from ${fromAccount.name}',
      date: now,
    );

    // Save both transactions
    final transactions = await loadTransactions();
    transactions.addAll([outTxn, inTxn]);
    await saveTransactions(transactions);

    // Update both account balances
    final accounts = await loadAccounts();
    final fromIdx = accounts.indexWhere((a) => a.id == fromAccount.id);
    final toIdx = accounts.indexWhere((a) => a.id == toAccount.id);
    if (fromIdx != -1) {
      accounts[fromIdx] = accounts[fromIdx].copyWith(
        balance: accounts[fromIdx].balance - amount,
      );
    }
    if (toIdx != -1) {
      accounts[toIdx] = accounts[toIdx].copyWith(
        balance: accounts[toIdx].balance + amount,
      );
    }
    await saveAccounts(accounts);
  }

  /// Get transactions filtered by account ID.
  static Future<List<FinanceTransaction>> getTransactionsForAccount(
    String accountId,
  ) async {
    final all = await loadTransactions();
    return all.where((t) => t.accountId == accountId).toList();
  }

  /// Get transactions filtered by date range.
  static Future<List<FinanceTransaction>> getTransactionsByDateRange(
    DateTime start,
    DateTime end,
  ) async {
    final all = await loadTransactions();
    return all
        .where((t) => t.date.isAfter(start) && t.date.isBefore(end))
        .toList();
  }

  /// Get today's transactions.
  static Future<List<FinanceTransaction>> getTodayTransactions() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    return getTransactionsByDateRange(
      startOfDay.subtract(const Duration(seconds: 1)),
      endOfDay,
    );
  }

  // ──────────────────────────────────────────────
  //  CLEAR ALL
  // ──────────────────────────────────────────────

  /// Directly set the stored net worth value.
  static Future<void> setNetWorth(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('finance_net_worth', value);
  }

  /// Wipe all financial data (accounts + transactions).
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accountsKey);
    await prefs.remove(_transactionsKey);
  }

  /// Delete the last transaction and revert the account balance.
  /// Returns the deleted transaction, or null if no transactions exist.
  static Future<FinanceTransaction?> deleteLastTransaction() async {
    final transactions = await loadTransactions();
    if (transactions.isEmpty) return null;

    // Get the last transaction
    final lastTxn = transactions.last;

    // Remove it from the list
    transactions.removeLast();
    await saveTransactions(transactions);

    // Revert the account balance
    final accounts = await loadAccounts();
    final index = accounts.indexWhere((a) => a.id == lastTxn.accountId);
    if (index != -1) {
      final account = accounts[index];
      double newBalance;
      if (lastTxn.type == 'INCOME') {
        newBalance = account.balance - lastTxn.amount;
      } else {
        newBalance = account.balance + lastTxn.amount;
      }
      accounts[index] = account.copyWith(balance: newBalance);
      await saveAccounts(accounts);
    }

    return lastTxn;
  }

  /// Delete a specific transaction and revert its account balance.
  static Future<FinanceTransaction?> deleteTransaction(
    String transactionId,
  ) async {
    final transactions = await loadTransactions();
    final txnIndex = transactions.indexWhere((t) => t.id == transactionId);
    if (txnIndex == -1) return null;

    final txn = transactions.removeAt(txnIndex);
    await saveTransactions(transactions);

    final accounts = await loadAccounts();
    final accountIndex = accounts.indexWhere((a) => a.id == txn.accountId);
    if (accountIndex != -1) {
      final account = accounts[accountIndex];
      final newBalance = txn.isIncome
          ? account.balance - txn.amount
          : account.balance + txn.amount;
      accounts[accountIndex] = account.copyWith(balance: newBalance);
      await saveAccounts(accounts);
    }

    return txn;
  }

  /// Check if an account type should not allow negative balances.
  /// Cash, E-Wallet, and Bank accounts cannot go negative.
  static bool _isNonNegativeAccount(String accountType) {
    final normalizedType = accountType.toLowerCase().trim();
    return normalizedType == 'cash' ||
        normalizedType == 'e-wallet' ||
        normalizedType == 'ewallet' ||
        normalizedType == 'bank';
  }
}
