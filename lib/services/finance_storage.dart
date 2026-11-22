import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/finance_models.dart';
import 'notification_service.dart';

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
  /// This is the core method that Gab's `add_transaction` tool will call.
  /// Throws an exception if the transaction would result in a negative balance for Cash, E-Wallet, or Bank accounts.
  static Future<void> addTransaction(
    FinanceTransaction txn, {
    bool notify = true,
  }) async {
    if (txn.isTransfer) {
      throw ArgumentError.value(
        txn.type,
        'txn.type',
        'Transfers must be recorded with transferMoney.',
      );
    }

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

    // 4. Trigger system local notification
    if (notify && !kIsWeb) {
      try {
        final totalBalance = accounts.fold(0.0, (sum, a) => sum + a.balance);
        await NotificationService().notifyTransaction(
          type: txn.type,
          amount: txn.amount,
          accountName: account.name,
          newBalance: txn.type == 'INCOME' ? totalBalance : newBalance,
          description:
              txn.description.isNotEmpty ? txn.description : txn.category,
          accountId: account.id,
          transactionId: txn.id,
        );
      } catch (_) {
        // Notification dispatch should not prevent successful transaction storage
      }
    }
  }

  /// Transfer money between two accounts and log one transfer transaction.
  /// This is the core method that Gab's `transfer_money` tool will call.
  /// Throws an exception if the source account has insufficient funds.
  static Future<void> transferMoney({
    required Account fromAccount,
    required Account toAccount,
    required double amount,
    double fee = 0,
    bool requireSourceBalance = false,
  }) async {
    if (!amount.isFinite || amount <= 0) {
      throw ArgumentError.value(amount, 'amount', 'Must be a positive number.');
    }
    if (!fee.isFinite || fee < 0) {
      throw ArgumentError.value(fee, 'fee', 'Must be a non-negative number.');
    }
    if (fromAccount.id == toAccount.id) {
      throw ArgumentError('Source and destination accounts must be different.');
    }

    final accounts = await loadAccounts();
    final fromIdx = accounts.indexWhere(
      (account) => account.id == fromAccount.id,
    );
    final toIdx = accounts.indexWhere((account) => account.id == toAccount.id);
    if (fromIdx == -1 || toIdx == -1) {
      throw Exception('Transfer account not found.');
    }

    final source = accounts[fromIdx];
    final destination = accounts[toIdx];
    final totalDebit = amount + fee;
    if (!totalDebit.isFinite) {
      throw ArgumentError.value(totalDebit, 'amount and fee');
    }
    if ((requireSourceBalance || _isNonNegativeAccount(source.type)) &&
        source.balance < totalDebit) {
      final message = fee == 0 && !requireSourceBalance
          ? 'Insufficient funds in ${source.name}. Balance: '
                '${source.balance.toStringAsFixed(2)}'
          : 'Insufficient funds in ${source.name}. Transfer and fee total '
                '${totalDebit.toStringAsFixed(2)}, but balance is '
                '${source.balance.toStringAsFixed(2)}.';
      throw Exception(message);
    }

    final now = DateTime.now();
    final transferTxn = FinanceTransaction(
      id: '${now.microsecondsSinceEpoch}_transfer',
      amount: amount,
      accountId: source.id,
      accountName: source.name,
      type: 'TRANSFER',
      category: 'Transfer',
      description: 'Transmitted to ${destination.name}',
      date: now,
      previousBalance: source.balance,
      destinationAccountId: destination.id,
      destinationAccountName: destination.name,
    );

    final transactions = await loadTransactions();
    transactions.add(transferTxn);
    if (fee > 0) {
      transactions.add(
        FinanceTransaction(
          id: '${now.microsecondsSinceEpoch}_transfer_fee',
          amount: fee,
          accountId: source.id,
          accountName: source.name,
          type: 'EXPENSE',
          category: 'Other',
          description: 'Transaction Fee',
          date: now,
          previousBalance: source.balance - amount,
        ),
      );
    }
    await saveTransactions(transactions);

    accounts[fromIdx] = source.copyWith(balance: source.balance - totalDebit);
    accounts[toIdx] = destination.copyWith(
      balance: destination.balance + amount,
    );
    await saveAccounts(accounts);
  }

  /// Get transactions filtered by account ID.
  static Future<List<FinanceTransaction>> getTransactionsForAccount(
    String accountId,
  ) async {
    final all = await loadTransactions();
    return all
        .where(
          (transaction) =>
              transaction.accountId == accountId ||
              transaction.destinationAccountId == accountId,
        )
        .toList();
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
    return deleteTransaction(transactions.last.id);
  }

  /// Delete a specific transaction and revert its account balance.
  static Future<FinanceTransaction?> deleteTransaction(
    String transactionId,
  ) async {
    final transactions = await loadTransactions();
    final txnIndex = transactions.indexWhere((t) => t.id == transactionId);
    if (txnIndex == -1) return null;

    final txn = transactions[txnIndex];
    final legacyCounterpart = _findLegacyTransferCounterpart(txn, transactions);
    final removedIds = {txn.id};
    if (legacyCounterpart != null) removedIds.add(legacyCounterpart.id);
    transactions.removeWhere(
      (transaction) => removedIds.contains(transaction.id),
    );
    await saveTransactions(transactions);

    final accounts = await loadAccounts();
    if (txn.destinationAccountId != null) {
      _reverseTransfer(
        accounts,
        txn.accountId,
        txn.destinationAccountId!,
        txn.amount,
      );
    } else if (legacyCounterpart != null) {
      final outgoing = txn.type == 'EXPENSE' ? txn : legacyCounterpart;
      final incoming = txn.type == 'INCOME' ? txn : legacyCounterpart;
      _reverseTransfer(
        accounts,
        outgoing.accountId,
        incoming.accountId,
        txn.amount,
      );
    } else {
      final accountIndex = accounts.indexWhere((a) => a.id == txn.accountId);
      if (accountIndex != -1) {
        final account = accounts[accountIndex];
        final newBalance = txn.type == 'INCOME'
            ? account.balance - txn.amount
            : account.balance + txn.amount;
        accounts[accountIndex] = account.copyWith(balance: newBalance);
      }
    }
    await saveAccounts(accounts);

    return txn;
  }

  static FinanceTransaction? _findLegacyTransferCounterpart(
    FinanceTransaction txn,
    List<FinanceTransaction> transactions,
  ) {
    if (!txn.isTransfer || txn.destinationAccountId != null) return null;

    final counterpartId = txn.id.endsWith('_out')
        ? '${txn.id.substring(0, txn.id.length - 4)}_in'
        : txn.id.endsWith('_in')
        ? '${txn.id.substring(0, txn.id.length - 3)}_out'
        : null;
    if (counterpartId == null) return null;

    for (final candidate in transactions) {
      if (candidate.id == counterpartId &&
          candidate.isTransfer &&
          candidate.amount == txn.amount) {
        return candidate;
      }
    }
    return null;
  }

  static void _reverseTransfer(
    List<Account> accounts,
    String sourceAccountId,
    String destinationAccountId,
    double amount,
  ) {
    final sourceIndex = accounts.indexWhere(
      (account) => account.id == sourceAccountId,
    );
    final destinationIndex = accounts.indexWhere(
      (account) => account.id == destinationAccountId,
    );
    if (sourceIndex != -1) {
      final source = accounts[sourceIndex];
      accounts[sourceIndex] = source.copyWith(balance: source.balance + amount);
    }
    if (destinationIndex != -1) {
      final destination = accounts[destinationIndex];
      accounts[destinationIndex] = destination.copyWith(
        balance: destination.balance - amount,
      );
    }
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
