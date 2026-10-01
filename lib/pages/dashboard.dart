import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:gabay/models/bill_models.dart';
import 'package:gabay/models/grocery_models.dart';
import 'package:gabay/models/finance_models.dart';
import 'package:gabay/config/app_theme.dart';
import 'package:gabay/navigation/app_routes.dart';
import 'package:gabay/pages/bai_chat.dart';
import 'package:gabay/services/bill_storage.dart';
import 'package:gabay/services/finance_storage.dart';
import 'package:gabay/services/settings_service.dart';
import 'package:gabay/services/safe_to_spend.dart';
import 'package:gabay/widgets/account_icon.dart';
import 'package:gabay/widgets/app_drawer.dart';
import 'package:gabay/widgets/home/home_helpers.dart';
import 'package:gabay/pages/wallet.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  List<Bill> _bills = [];
  List<FinanceTransaction> _transactions = [];
  List<Account> _accounts = [];
  double _netWorth = 0.0;
  double _dailyAllocation = 172.30;
  PayFrequency _payFrequency = PayFrequency.twiceMonthly;
  int _payday1 = 15;
  int? _payday2 = 30;
  int? _intervalDays;
  DateTime? _anchorPayday;
  bool _showWeeklySpending = false;
  String _currency = '₱';

  @override
  void initState() {
    super.initState();
    SettingsService().dailySpendingAllocationNotifier.addListener(
      _handleDailyAllocationChanged,
    );
    _loadData();
  }

  @override
  void dispose() {
    SettingsService().dailySpendingAllocationNotifier.removeListener(
      _handleDailyAllocationChanged,
    );
    super.dispose();
  }

  void _handleDailyAllocationChanged() {
    if (!mounted) return;
    setState(
      () => _dailyAllocation =
          SettingsService().dailySpendingAllocationNotifier.value,
    );
  }

  Future<void> _loadData() async {
    final bills = await BillStorage.loadBills();
    final txns = await FinanceStorage.loadTransactions();
    final accounts = await FinanceStorage.loadAccounts();
    final netWorth = await FinanceStorage.getNetWorth();

    if (!mounted) return;
    setState(() {
      _bills = bills;
      _transactions = txns;
      _accounts = accounts;
      _netWorth = netWorth;
      _currency = SettingsService().currency;
      _dailyAllocation = SettingsService().dailySpendingAllocation;
      _payFrequency = SettingsService().payFrequency;
      _payday1 = SettingsService().payday1;
      _payday2 = SettingsService().payday2;
      _intervalDays = SettingsService().intervalDays;
      _anchorPayday = SettingsService().anchorPayday;
    });
  }

  void _showAddTransactionSheet() {
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String selectedType = 'EXPENSE';
    String? selectedAccountId = _accounts.isNotEmpty
        ? _accounts.first.id
        : null;
    String selectedCategory = expenseCategories.first;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          final isExpense = selectedType == 'EXPENSE';
          final currentCategories = isExpense
              ? expenseCategories
              : incomeCategories;
          if (!currentCategories.contains(selectedCategory)) {
            selectedCategory = currentCategories.first;
          }

          return Container(
            decoration: BoxDecoration(
              color: kCardBg,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(32),
              ),
            ),
            padding: EdgeInsets.fromLTRB(
              24,
              24,
              24,
              24 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Log Transaction',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: kTextCharcoal,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close, color: kMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setSheetState(() {
                          selectedType = 'EXPENSE';
                          selectedCategory = expenseCategories.first;
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: isExpense
                                ? Colors.red.withValues(alpha: 0.1)
                                : kBackground,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isExpense ? Colors.red : kBorder,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Expense',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.bold,
                              color: isExpense ? Colors.red : kMuted,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setSheetState(() {
                          selectedType = 'INCOME';
                          selectedCategory = incomeCategories.first;
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: !isExpense
                                ? kPrimary.withValues(alpha: 0.1)
                                : kBackground,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: !isExpense ? kPrimary : kBorder,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Income',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.bold,
                              color: !isExpense ? kPrimary : kMuted,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: TextStyle(color: kTextCharcoal),
                  decoration: InputDecoration(
                    labelText: 'Amount',
                    labelStyle: TextStyle(color: kMuted),
                    prefixText: '$_currency ',
                    prefixStyle: TextStyle(
                      color: kTextCharcoal,
                      fontWeight: FontWeight.bold,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: kBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: kPrimary),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: selectedAccountId,
                  dropdownColor: kCardBg,
                  style: TextStyle(color: kTextCharcoal, fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'Account',
                    labelStyle: TextStyle(color: kMuted),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: kBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: kPrimary),
                    ),
                  ),
                  items: _accounts
                      .map(
                        (a) => DropdownMenuItem(
                          value: a.id,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AccountIconImage(
                                name: a.name,
                                icon: a.icon,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(a.name),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setSheetState(() => selectedAccountId = v),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: selectedCategory,
                  dropdownColor: kCardBg,
                  style: TextStyle(color: kTextCharcoal, fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'Category',
                    labelStyle: TextStyle(color: kMuted),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: kBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: kPrimary),
                    ),
                  ),
                  items: currentCategories
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setSheetState(() => selectedCategory = v!),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descCtrl,
                  style: TextStyle(color: kTextCharcoal),
                  decoration: InputDecoration(
                    labelText: 'Description',
                    labelStyle: TextStyle(color: kMuted),
                    hintText: 'What was this for?',
                    hintStyle: TextStyle(color: kMuted.withValues(alpha: 0.5)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: kBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: kPrimary),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () async {
                      final amount = double.tryParse(amountCtrl.text);
                      if (amount != null && selectedAccountId != null) {
                        final account = _accounts.firstWhere(
                          (a) => a.id == selectedAccountId,
                        );
                        final txn = FinanceTransaction(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          amount: amount,
                          accountId: selectedAccountId!,
                          accountName: account.name,
                          type: selectedType,
                          category: selectedCategory,
                          description: descCtrl.text.trim(),
                        );
                        await FinanceStorage.addTransaction(txn);
                        if (context.mounted) {
                          Navigator.pop(context);
                          _loadData();
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      'Add Transaction',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showTransferSheet() {
    final amountCtrl = TextEditingController();
    String? fromAccountId = _accounts.isNotEmpty ? _accounts.first.id : null;
    String? toAccountId = _accounts.length > 1 ? _accounts[1].id : null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          decoration: BoxDecoration(
            color: kCardBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          padding: EdgeInsets.fromLTRB(
            24,
            24,
            24,
            24 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Transfer Funds',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: kTextCharcoal,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: kMuted),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: TextStyle(color: kTextCharcoal),
                decoration: InputDecoration(
                  labelText: 'Amount',
                  labelStyle: TextStyle(color: kMuted),
                  prefixText: '$_currency ',
                  prefixStyle: TextStyle(
                    color: kTextCharcoal,
                    fontWeight: FontWeight.bold,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: kBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: kPrimary),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: fromAccountId,
                dropdownColor: kCardBg,
                style: TextStyle(color: kTextCharcoal, fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'From Account',
                  labelStyle: TextStyle(color: kMuted),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: kBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: kPrimary),
                  ),
                ),
                items: _accounts
                    .map(
                      (a) => DropdownMenuItem(
                        value: a.id,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AccountIconImage(
                              name: a.name,
                              icon: a.icon,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(a.name),
                          ],
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setSheetState(() {
                  fromAccountId = v;
                  if (fromAccountId == toAccountId) {
                    toAccountId = _accounts
                        .firstWhere((a) => a.id != fromAccountId)
                        .id;
                  }
                }),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: toAccountId,
                dropdownColor: kCardBg,
                style: TextStyle(color: kTextCharcoal, fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'To Account',
                  labelStyle: TextStyle(color: kMuted),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: kBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: kPrimary),
                  ),
                ),
                items: _accounts
                    .where((a) => a.id != fromAccountId)
                    .map(
                      (a) => DropdownMenuItem(
                        value: a.id,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AccountIconImage(
                              name: a.name,
                              icon: a.icon,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(a.name),
                          ],
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setSheetState(() => toAccountId = v),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () async {
                    final amount = double.tryParse(amountCtrl.text);
                    if (amount != null &&
                        fromAccountId != null &&
                        toAccountId != null) {
                      final from = _accounts.firstWhere(
                        (a) => a.id == fromAccountId,
                      );
                      final to = _accounts.firstWhere(
                        (a) => a.id == toAccountId,
                      );
                      await FinanceStorage.transferMoney(
                        fromAccount: from,
                        toAccount: to,
                        amount: amount,
                      );
                      if (context.mounted) {
                        Navigator.pop(context);
                        _loadData();
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'Transfer Funds',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  Future<void> _editSpendingSchedule() async {
    final result = await showDialog<_SpendingScheduleResult>(
      context: context,
      builder: (_) => _DailyAllocationDialog(
        currency: _currency,
        initialAmount: _dailyAllocation,
        initialFrequency: _payFrequency,
        initialPayday1: _payday1,
        initialPayday2: _payday2,
        initialIntervalDays: _intervalDays,
        initialAnchorPayday: _anchorPayday,
      ),
    );
    if (result == null || !mounted) return;
    await SettingsService().setDailySpendingAllocation(result.dailyBudget);
    await SettingsService().setPaySchedule(
      frequency: result.frequency,
      payday1: result.payday1,
      payday2: result.payday2,
      intervalDays: result.intervalDays,
      anchorPayday: result.anchorPayday,
    );
    if (!mounted) return;
    setState(() {
      _dailyAllocation = result.dailyBudget;
      _payFrequency = result.frequency;
      _payday1 = result.payday1;
      _payday2 = result.payday2;
      _intervalDays = result.intervalDays;
      _anchorPayday = result.anchorPayday;
    });
  }

  double _calculateSpentBetween(DateTime start, DateTime end) {
    var total = 0.0;
    for (final transaction in _transactions) {
      if (!transaction.isExpense ||
          transaction.category.trim().toLowerCase() == 'transfer' ||
          transaction.date.isBefore(start) ||
          !transaction.date.isBefore(end)) {
        continue;
      }
      total += transaction.amount;
    }

    for (final list in AppState.recentLists) {
      if (list.date.isBefore(start) || !list.date.isBefore(end)) continue;
      total += list.items.fold(
        0.0,
        (sum, item) => sum + getItemTotal(item.price, item.qty, item.unit),
      );
    }
    return total;
  }

  Future<void> _undoTransaction(FinanceTransaction transaction) async {
    final deleted = await FinanceStorage.deleteTransaction(transaction.id);
    if (!mounted) return;

    if (deleted == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transaction was already removed.')),
      );
      await _loadData();
      return;
    }

    await _loadData();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Undid ${transaction.description.isNotEmpty ? transaction.description : transaction.category}.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final recentLists = AppState.recentLists;
    final userName = SettingsService().userName;
    final displayName = userName.isNotEmpty ? userName : 'User';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final resolvedPayday = nextPayday(
      today: today,
      frequency: _payFrequency,
      payday1: _payday1,
      payday2: _payday2,
      intervalDays: _intervalDays,
      anchor: _anchorPayday,
    );
    final todaySpent = _calculateSpentBetween(today, tomorrow);
    final daysLeft = calculateDaysLeft(today: today, payday: resolvedPayday);
    final spendingPlan = SafeToSpend.calculate(
      balance: _netWorth,
      dailyBudget: _dailyAllocation,
      daysLeft: daysLeft,
      spentToday: todaySpent,
    );
    final weekStart = today.subtract(const Duration(days: 6));
    final weekSpent = _calculateSpentBetween(weekStart, tomorrow);
    final periodSpent = _showWeeklySpending ? weekSpent : todaySpent;
    final periodBudget = _dailyAllocation * (_showWeeklySpending ? 7 : 1);
    final spendProgress = periodBudget <= 0
        ? 0.0
        : (periodSpent / periodBudget).clamp(0.0, 1.0).toDouble();

    final sortedTxns = List<FinanceTransaction>.from(_transactions)
      ..sort((a, b) => b.date.compareTo(a.date));
    final showExpenseFirst =
        sortedTxns.isNotEmpty && sortedTxns.first.isExpense;

    Widget buildIncomeSection() {
      return Column(
        key: const ValueKey('recent_income_section'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          _SectionHeader(title: 'Recent Income'),
          _TransactionList(
            transactions: _transactions.where((t) => t.isIncome).toList(),
            accounts: _accounts,
            isIncome: true,
            onUndo: _undoTransaction,
          ),
        ],
      );
    }

    Widget buildExpenseSection() {
      return Column(
        key: const ValueKey('recent_expenses_section'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          _SectionHeader(title: 'Recent Expenses'),
          _TransactionList(
            transactions: _transactions.where((t) => t.isExpense).toList(),
            accounts: _accounts,
            isIncome: false,
            onUndo: _undoTransaction,
          ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        backgroundColor: kBackground,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(Icons.menu_rounded, color: kTextCharcoal, size: 28),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Text(
          DateFormat('EEEE, MMM d').format(DateTime.now()).toUpperCase(),
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: kMuted,
            letterSpacing: 1.5,
          ),
        ),
        centerTitle: false,
      ),
      drawer: const AppDrawer(currentPage: 'Dashboard'),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          children: [
            const SizedBox(height: 20),

            // Greeting
            Text(
              '${_getGreeting()},\n$displayName!',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                height: 1.2,
                color: kTextCharcoal,
              ),
            ),
            const SizedBox(height: 16),

            _GreetingSection(spentToday: spendingPlan.spentToday),

            // Total Balance Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [kPrimary, kPrimaryLight],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: kPrimary.withValues(alpha: 0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const WalletPage()),
                      );
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TOTAL BALANCE',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Colors.white.withValues(alpha: 0.8),
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          formatPeso(_netWorth),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: _showAddTransactionSheet,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.add_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Transaction',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          onTap: _showTransferSheet,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.swap_horiz_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Transfer',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Stats Row — VisionOS Glassmorphic Island
            Row(
              children: [
                // Animated 3D Bar Chart
                Expanded(
                  child: Container(
                    height: 205,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: kCardBg,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [kShadowSoft],
                    ),
                    child: _GlassTrendChart(
                      recentLists: recentLists,
                      transactions: _transactions,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Daily spend and salary-cycle allowance.
                Expanded(
                  child: GestureDetector(
                    key: const ValueKey('safe_to_spend_card'),
                    onTap: _editSpendingSchedule,
                    onHorizontalDragEnd: (details) {
                      if (details.primaryVelocity == null ||
                          details.primaryVelocity == 0) {
                        return;
                      }
                      setState(() {
                        _showWeeklySpending = details.primaryVelocity! < 0;
                      });
                    },
                    child: Container(
                      height: 205,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: kCardBg,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [kShadowSoft],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.shield_outlined,
                                size: 15,
                                color: kPrimary,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'SAFE TO SPEND',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: kMuted,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            child: Text(
                              formatPeso(spendingPlan.safeToSpend),
                              key: ValueKey<double>(spendingPlan.safeToSpend),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: kTextCharcoal,
                              ),
                            ),
                          ),
                          Row(
                            children: [
                              Icon(
                                Icons.chevron_left_rounded,
                                size: 17,
                                color: _showWeeklySpending ? kMuted : kPrimary,
                              ),
                              Text(
                                _showWeeklySpending ? 'WEEK' : 'TODAY',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: kPrimary,
                                ),
                              ),
                              Icon(
                                Icons.chevron_right_rounded,
                                size: 17,
                                color: _showWeeklySpending ? kPrimary : kMuted,
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(
                                  value: spendProgress,
                                  minHeight: 7,
                                  backgroundColor: kPrimary.withValues(
                                    alpha: 0.1,
                                  ),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    spendingPlan.safeToSpend <= 0
                                        ? Colors.red
                                        : kPrimary,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${NumberFormat('0.##').format(spendProgress * 100)}% of 100%',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 9,
                                  color: kMuted,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '${formatPeso(_dailyAllocation)}/day',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: kMuted,
                            ),
                          ),
                          Text(
                            'Next payday: ${DateFormat('MMM d').format(resolvedPayday)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 9,
                              color: kMuted,
                            ),
                          ),
                          if (spendingPlan.extra < 0)
                            Text(
                              'Over plan by ${formatPeso(spendingPlan.extra.abs())}; revised ${formatPeso(spendingPlan.effectiveDailyBudget)}/day',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 8,
                                fontWeight: FontWeight.w700,
                                color: Colors.red,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            _SectionHeader(title: 'Upcoming Events'),
            _UpcomingEventsList(bills: _bills),

            if (showExpenseFirst) ...[
              buildExpenseSection(),
              buildIncomeSection(),
            ] else ...[
              buildIncomeSection(),
              buildExpenseSection(),
            ],

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _SpendingScheduleResult {
  final double dailyBudget;
  final PayFrequency frequency;
  final int payday1;
  final int? payday2;
  final int? intervalDays;
  final DateTime? anchorPayday;

  const _SpendingScheduleResult({
    required this.dailyBudget,
    required this.frequency,
    required this.payday1,
    required this.payday2,
    required this.intervalDays,
    required this.anchorPayday,
  });
}

class _DailyAllocationDialog extends StatefulWidget {
  final String currency;
  final double initialAmount;
  final PayFrequency initialFrequency;
  final int initialPayday1;
  final int? initialPayday2;
  final int? initialIntervalDays;
  final DateTime? initialAnchorPayday;

  const _DailyAllocationDialog({
    required this.currency,
    required this.initialAmount,
    required this.initialFrequency,
    required this.initialPayday1,
    required this.initialPayday2,
    required this.initialIntervalDays,
    required this.initialAnchorPayday,
  });

  @override
  State<_DailyAllocationDialog> createState() => _DailyAllocationDialogState();
}

class _DailyAllocationDialogState extends State<_DailyAllocationDialog> {
  late final TextEditingController _dailyBudgetController;
  late final TextEditingController _customIntervalController;
  late PayFrequency _frequency;
  late int _payday1;
  late int _payday2;
  late DateTime _anchorPayday;

  @override
  void initState() {
    super.initState();
    _dailyBudgetController = TextEditingController(
      text: widget.initialAmount.toStringAsFixed(2),
    );
    _customIntervalController = TextEditingController(
      text: (widget.initialIntervalDays ?? 10).toString(),
    );
    _frequency = widget.initialFrequency;
    _payday1 = widget.initialPayday1;
    _payday2 = widget.initialPayday2 ?? (widget.initialPayday1 == 15 ? 30 : 15);
    final today = _today;
    _anchorPayday =
        widget.initialAnchorPayday ??
        nextPayday(
          today: today,
          frequency: widget.initialFrequency,
          payday1: widget.initialPayday1,
          payday2: widget.initialPayday2,
          intervalDays: widget.initialIntervalDays,
        );
  }

  @override
  void dispose() {
    _dailyBudgetController.dispose();
    _customIntervalController.dispose();
    super.dispose();
  }

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  double? _parseAmount(String value) {
    final parsed = double.tryParse(value.replaceAll(',', '').trim());
    if (parsed == null || parsed <= 0 || !parsed.isFinite) return null;
    return parsed;
  }

  int? get _customInterval {
    final parsed = int.tryParse(_customIntervalController.text.trim());
    return parsed != null && parsed >= 1 && parsed <= 90 ? parsed : null;
  }

  int? get _intervalForFrequency => switch (_frequency) {
    PayFrequency.weekly => 7,
    PayFrequency.everyTwoWeeks => 14,
    PayFrequency.every15Days => 15,
    PayFrequency.every30Days => 30,
    PayFrequency.custom => _customInterval,
    PayFrequency.monthly || PayFrequency.twiceMonthly => null,
  };

  bool get _isCalendarBased =>
      _frequency == PayFrequency.monthly ||
      _frequency == PayFrequency.twiceMonthly;

  DateTime? get _resolvedPayday {
    final interval = _intervalForFrequency;
    if (!_isCalendarBased && interval == null) return null;
    return nextPayday(
      today: _today,
      frequency: _frequency,
      payday1: _payday1,
      payday2: _payday2,
      intervalDays: interval,
      anchor: _anchorPayday,
    );
  }

  bool get _valid {
    if (_parseAmount(_dailyBudgetController.text) == null) return false;
    if (_frequency == PayFrequency.twiceMonthly && _payday1 == _payday2) {
      return false;
    }
    if (!_isCalendarBased && _intervalForFrequency == null) return false;
    if (!_isCalendarBased && _resolvedPayday!.isBefore(_today)) return false;
    return true;
  }

  void _save() {
    if (!_valid) return;
    final amount = _parseAmount(_dailyBudgetController.text)!;
    Navigator.pop(
      context,
      _SpendingScheduleResult(
        dailyBudget: amount,
        frequency: _frequency,
        payday1: _payday1,
        payday2: _payday2,
        intervalDays: _intervalForFrequency,
        anchorPayday: _anchorPayday,
      ),
    );
  }

  Future<void> _pickAnchorPayday() async {
    final resolved = _resolvedPayday ?? _today;
    final selected = await showDatePicker(
      context: context,
      initialDate: resolved.isBefore(_today) ? _today : resolved,
      firstDate: _today,
      lastDate: DateTime(_today.year + 20),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _anchorPayday = DateTime(selected.year, selected.month, selected.day);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Spending schedule'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<PayFrequency>(
            initialValue: _frequency,
            decoration: const InputDecoration(labelText: 'Pay frequency'),
            items: PayFrequency.values
                .map(
                  (frequency) => DropdownMenuItem(
                    value: frequency,
                    child: Text(_frequencyLabel(frequency)),
                  ),
                )
                .toList(),
            onChanged: (frequency) {
              if (frequency != null) setState(() => _frequency = frequency);
            },
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _dailyBudgetController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Daily budget',
              prefixText: '${widget.currency} ',
            ),
          ),
          const SizedBox(height: 12),
          if (_frequency == PayFrequency.monthly)
            _paydayDropdown(
              label: 'Payday',
              value: _payday1,
              onChanged: (day) => setState(() => _payday1 = day),
            ),
          if (_frequency == PayFrequency.twiceMonthly)
            Row(
              children: [
                Expanded(
                  child: _paydayDropdown(
                    label: 'Payday 1',
                    value: _payday1,
                    onChanged: (day) => _updatePaydays(first: day),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _paydayDropdown(
                    label: 'Payday 2',
                    value: _payday2,
                    onChanged: (day) => _updatePaydays(second: day),
                  ),
                ),
              ],
            ),
          if (_isCalendarBased)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Dates after month-end use the last day of that month.',
                style: TextStyle(fontSize: 11, color: kMuted),
              ),
            ),
          if (!_isCalendarBased) ...[
            if (_frequency == PayFrequency.custom)
              TextField(
                controller: _customIntervalController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Every N days',
                  helperText: 'Enter a value from 1 to 90',
                ),
                onChanged: (_) => setState(() {}),
              ),
            OutlinedButton.icon(
              onPressed: _pickAnchorPayday,
              icon: const Icon(Icons.calendar_today_outlined),
              label: Text(
                'Next payday: ${DateFormat('MMM d').format(_resolvedPayday ?? _anchorPayday)}',
              ),
            ),
          ],
          if (_frequency == PayFrequency.twiceMonthly && _payday1 == _payday2)
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Choose two different payday dates.'),
            ),
          if (_resolvedPayday case final resolved?)
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Next payday: ${DateFormat('MMM d').format(resolved)}',
                  style: TextStyle(fontSize: 12, color: kMuted),
                ),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _valid ? _save : null,
          child: const Text('Save'),
        ),
      ],
    );
  }

  String _ordinalSuffix(int day) {
    if (day % 100 >= 11 && day % 100 <= 13) return 'th';
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

  DropdownButtonFormField<int> _paydayDropdown({
    required String label,
    required int value,
    required ValueChanged<int> onChanged,
  }) => DropdownButtonFormField<int>(
    initialValue: value,
    decoration: InputDecoration(labelText: label),
    items: List.generate(31, (index) => index + 1)
        .map(
          (day) => DropdownMenuItem(
            value: day,
            child: Text('$day${_ordinalSuffix(day)}'),
          ),
        )
        .toList(),
    onChanged: (day) {
      if (day != null) onChanged(day);
    },
  );

  void _updatePaydays({int? first, int? second}) {
    final firstValue = first ?? _payday1;
    final secondValue = second ?? _payday2;
    setState(() {
      if (firstValue != secondValue) {
        _payday1 = firstValue < secondValue ? firstValue : secondValue;
        _payday2 = firstValue < secondValue ? secondValue : firstValue;
      } else {
        _payday1 = firstValue;
        _payday2 = secondValue;
      }
    });
  }

  String _frequencyLabel(PayFrequency frequency) => switch (frequency) {
    PayFrequency.monthly => 'Monthly',
    PayFrequency.twiceMonthly => 'Twice a month',
    PayFrequency.weekly => 'Weekly',
    PayFrequency.everyTwoWeeks => 'Every 2 weeks',
    PayFrequency.every15Days => 'Every 15 days',
    PayFrequency.every30Days => 'Every 30 days',
    PayFrequency.custom => 'Custom',
  };
}

class _GlassTrendChart extends StatefulWidget {
  final List<GroceryList> recentLists;
  final List<FinanceTransaction> transactions;
  const _GlassTrendChart({
    required this.recentLists,
    required this.transactions,
  });

  @override
  State<_GlassTrendChart> createState() => _GlassTrendChartState();
}

class _GlassTrendChartState extends State<_GlassTrendChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _barAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _barAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutBack);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final sunday = now.subtract(Duration(days: now.weekday % 7));
    final startOfWeek = DateTime(sunday.year, sunday.month, sunday.day);
    final weeklyData = List.generate(7, (index) => 0.0);

    for (final list in widget.recentLists) {
      final difference = list.date.difference(startOfWeek).inDays;
      if (difference >= 0 && difference < 7) {
        weeklyData[difference] += list.items.fold(
          0.0,
          (s, i) => s + getItemTotal(i.price, i.qty, i.unit),
        );
      }
    }

    for (final txn in widget.transactions) {
      if (!txn.isExpense) continue;
      final difference = txn.date.difference(startOfWeek).inDays;
      if (difference >= 0 && difference < 7) {
        weeklyData[difference] += txn.amount;
      }
    }

    final chartMax =
        weeklyData.fold(0.0, (double max, val) => val > max ? val : max) * 1.3;
    final dayLabels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
    final todayIndex = now.weekday % 7;

    if (chartMax == 0) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bar_chart_rounded,
            color: kMuted.withValues(alpha: 0.3),
            size: 28,
          ),
          const SizedBox(height: 4),
          Text(
            'No data this week',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              color: kMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }

    return AnimatedBuilder(
      animation: _barAnim,
      builder: (context, _) {
        return BarChart(
          BarChartData(
            maxY: chartMax > 0 ? chartMax : 100,
            titlesData: FlTitlesData(
              show: true,
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              leftTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 24,
                  getTitlesWidget: (value, meta) {
                    final i = value.toInt();
                    if (i < 0 || i >= 7) return const SizedBox.shrink();
                    final isToday = i == todayIndex;
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: isToday
                            ? BoxDecoration(
                                color: kPrimarySoft,
                                shape: BoxShape.circle,
                              )
                            : null,
                        child: Text(
                          dayLabels[i],
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 9,
                            fontWeight: isToday
                                ? FontWeight.w800
                                : FontWeight.w600,
                            color: isToday
                                ? kPrimary
                                : kMuted.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            borderData: FlBorderData(show: false),
            gridData: const FlGridData(show: false),
            barTouchData: BarTouchData(enabled: false),
            barGroups: List.generate(7, (i) {
              final isToday = i == todayIndex;
              final hasData = weeklyData[i] > 0;
              return BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY:
                        (hasData ? weeklyData[i] : chartMax * 0.04) *
                        _barAnim.value,
                    gradient: hasData
                        ? LinearGradient(
                            colors: isToday
                                ? [
                                    kPrimaryLight,
                                    Color.lerp(
                                      kPrimaryLight,
                                      Colors.white,
                                      0.45,
                                    )!,
                                    kPrimary,
                                    Color.lerp(kPrimary, Colors.black, 0.15)!,
                                  ]
                                : [
                                    kPrimary.withValues(alpha: 0.35),
                                    kPrimary.withValues(alpha: 0.15),
                                    kPrimary.withValues(alpha: 0.25),
                                  ],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            stops: isToday
                                ? const [0.0, 0.25, 0.75, 1.0]
                                : const [0.0, 0.5, 1.0],
                          )
                        : null,
                    color: hasData ? null : kMuted.withValues(alpha: 0.08),
                    width: 10,
                    borderRadius: BorderRadius.circular(5),
                    backDrawRodData: BackgroundBarChartRodData(
                      show: true,
                      toY: chartMax,
                      color: kMuted.withValues(alpha: 0.05),
                    ),
                  ),
                ],
              );
            }),
          ),
          duration: Duration.zero,
        );
      },
    );
  }
}

class _UpcomingEventsList extends StatelessWidget {
  final List<Bill> bills;
  const _UpcomingEventsList({required this.bills});

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final upcomingBills =
        bills
            .where(
              (b) =>
                  !b.isPaid &&
                  b.dueDate.isAfter(today.subtract(const Duration(days: 1))),
            )
            .toList()
          ..sort((a, b) => a.dueDate.compareTo(b.dueDate));

    final items = upcomingBills;

    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Text('No upcoming events', style: TextStyle(color: kMuted)),
        ),
      );
    }

    return SizedBox(
      height: 90,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: items.length,
        itemBuilder: (context, index) {
          final bill = items[index];
          final days = bill.dueDate.difference(today).inDays;
          final dayStr = days == 0
              ? 'Today'
              : days == 1
              ? 'Tomorrow'
              : 'In $days days';

          return Container(
            width: MediaQuery.of(context).size.width * 0.75,
            margin: EdgeInsets.only(right: index == items.length - 1 ? 0 : 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kCardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kBorder.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.event_note_rounded,
                    color: Colors.orange,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        bill.type,
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                          color: kTextCharcoal,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        dayStr,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: kMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  formatPeso(bill.amount),
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    color: kTextCharcoal,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TransactionList extends StatelessWidget {
  final List<FinanceTransaction> transactions;
  final List<Account> accounts;
  final bool isIncome;
  final Future<void> Function(FinanceTransaction) onUndo;
  const _TransactionList({
    required this.transactions,
    required this.accounts,
    required this.isIncome,
    required this.onUndo,
  });

  String _money(double value) => formatPeso(value);

  String _displayTitle(FinanceTransaction transaction) {
    final description = transaction.description.trim();
    final category = transaction.category.trim();
    if (description.isEmpty) return category;
    if (!isIncome || category.isEmpty || category == 'Others') {
      return description;
    }
    if (description.toLowerCase().contains(category.toLowerCase())) {
      return description;
    }
    return '$description $category';
  }

  Future<bool> _confirmUndo(
    BuildContext context,
    FinanceTransaction transaction,
  ) async {
    final title = _displayTitle(transaction);
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Undo transaction?'),
            content: Text('This will remove "$title" and restore the balance.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Undo'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Widget _swipeUndoBackground() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.withValues(alpha: 0.22)),
      ),
      alignment: Alignment.centerRight,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.undo_rounded, color: Colors.red, size: 20),
          const SizedBox(height: 2),
          Text(
            'Undo',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.red,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final recent = transactions.toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final items = recent.take(3).toList();

    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Text(
            'No recent ${isIncome ? 'income' : 'expenses'}',
            style: TextStyle(color: kMuted),
          ),
        ),
      );
    }

    return Column(
      children: items.map((t) {
        final account = accounts.firstWhere(
          (a) => a.id == t.accountId,
          orElse: () => Account(
            id: t.accountId,
            name: t.accountName,
            type: '',
            icon: '💰',
          ),
        );

        return Dismissible(
          key: ValueKey('transaction_undo_${t.id}'),
          direction: DismissDirection.endToStart,
          background: _swipeUndoBackground(),
          confirmDismiss: (_) async {
            final confirmed = await _confirmUndo(context, t);
            if (confirmed) {
              await onUndo(t);
            }
            return false;
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kCardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kBorder.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (isIncome ? kPrimary : Colors.red).withValues(
                      alpha: 0.1,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isIncome
                        ? Icons.south_west_rounded
                        : Icons.north_east_rounded,
                    color: isIncome ? kPrimary : Colors.red,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _displayTitle(t),
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                          color: kTextCharcoal,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        DateFormat('MMM d, yyyy').format(t.date),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: kMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${isIncome ? '+' : '-'}${_money(t.amount)}',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800,
                        color: isIncome ? kPrimary : Colors.red,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (t.previousBalance != null) ...[
                          Text(
                            _money(t.previousBalance!),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: kMuted,
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        AccountIconImage(
                          name: account.name,
                          icon: account.icon,
                          size: 16,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.plusJakartaSans(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: kMuted,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _GreetingSection extends StatefulWidget {
  final double spentToday;

  const _GreetingSection({required this.spentToday});

  @override
  State<_GreetingSection> createState() => _GreetingSectionState();
}

class _GreetingSectionState extends State<_GreetingSection> {
  List<String> _messages = ['Hi, welcome!'];
  int _currentIndex = 0;
  Timer? _timer;
  bool _isLoading = true;

  @override
  void didUpdateWidget(covariant _GreetingSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.spentToday != widget.spentToday) {
      _loadGreeting();
    }
  }

  @override
  void initState() {
    super.initState();
    _loadGreeting();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadGreeting() async {
    _timer?.cancel();
    final bills = await BillStorage.loadBills();
    if (!mounted) return;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    List<String> activeMessages = [];

    // 1. Check Bills
    final sevenDaysLater = today.add(const Duration(days: 7));
    final upcomingBills = bills.where((bill) {
      final billDay = DateTime(
        bill.dueDate.year,
        bill.dueDate.month,
        bill.dueDate.day,
      );
      return billDay.isAfter(today) &&
          billDay.isBefore(sevenDaysLater.add(const Duration(days: 1))) &&
          !bill.isPaid;
    }).toList();

    if (upcomingBills.isNotEmpty) {
      upcomingBills.sort((a, b) => a.dueDate.compareTo(b.dueDate));
      final firstBill = upcomingBills.first;
      final dateStr = DateFormat(
        'EEEE',
      ).format(firstBill.dueDate).toLowerCase();
      activeMessages.add(
        'hey, you have upcoming ${firstBill.type.toLowerCase()} bill this $dateStr, worth ${formatPeso(firstBill.amount)}.',
      );
    }

    if (widget.spentToday > 0) {
      activeMessages.add(
        'your total spent for today is ${formatPeso(widget.spentToday)}.',
      );
    }

    // Default if empty
    if (activeMessages.isEmpty) {
      activeMessages.add('Hi, welcome!');
    }

    setState(() {
      _messages = activeMessages;
      _isLoading = false;
    });

    if (_messages.length > 1) {
      _timer = Timer.periodic(const Duration(milliseconds: 4500), (timer) {
        if (mounted) {
          setState(() {
            _currentIndex = (_currentIndex + 1) % _messages.length;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        Navigator.push(
          context,
          PageRouteBuilder<void>(
            settings: const RouteSettings(name: kBaiChatRouteName),
            pageBuilder: (_, _, _) => const BaiChatPage(),
            transitionDuration: const Duration(milliseconds: 280),
            reverseTransitionDuration: const Duration(milliseconds: 220),
            transitionsBuilder: (_, animation, _, child) {
              final transition = CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
                reverseCurve: Curves.easeInCubic,
              );
              return FadeTransition(
                opacity: transition,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.035, 0),
                    end: Offset.zero,
                  ).animate(transition),
                  child: child,
                ),
              );
            },
          ),
        );
      },
      child: Semantics(
        button: true,
        label: 'Open BAI chat',
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 3D Avatar Image
              Transform.translate(
                offset: Offset.zero,
                child: Container(
                  width: 130,
                  height: 130,
                  decoration: const BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage('assets/images/greeting_avatar.png'),
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              // Chat Bubble with Tail
              Flexible(
                child: IntrinsicWidth(
                  child: CustomPaint(
                    painter: _BubblePainter(kCardBg),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      margin: const EdgeInsets.only(left: 10, top: 0, right: 0),
                      child: _isLoading
                          ? SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  kPrimary,
                                ),
                              ),
                            )
                          : AnimatedSwitcher(
                              duration: const Duration(milliseconds: 500),
                              transitionBuilder: (child, animation) {
                                return FadeTransition(
                                  opacity: animation,
                                  child: SlideTransition(
                                    position: Tween<Offset>(
                                      begin: const Offset(0, 0.2),
                                      end: Offset.zero,
                                    ).animate(animation),
                                    child: child,
                                  ),
                                );
                              },
                              child: Text(
                                _messages[_currentIndex],
                                key: ValueKey<int>(_currentIndex),
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w400,
                                  color: kTextCharcoal,
                                ),
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BubblePainter extends CustomPainter {
  final Color color;
  _BubblePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    const r = 24.0; // corner radius
    const tw = 10.0; // tail width

    // Start path after the tail area on the top-left
    path.moveTo(tw + r, 0);
    path.lineTo(size.width - r, 0);
    path.quadraticBezierTo(size.width, 0, size.width, r);
    path.lineTo(size.width, size.height - r);
    path.quadraticBezierTo(
      size.width,
      size.height,
      size.width - r,
      size.height,
    );
    path.lineTo(tw + r, size.height);
    path.quadraticBezierTo(tw, size.height, tw, size.height - r);

    // Left side with the tail pointing left
    path.lineTo(tw, 45); // move down to where the tail starts
    path.lineTo(0, 35); // the tip of the tail (pointing to the person)
    path.lineTo(tw, 25); // back to the bubble wall
    path.lineTo(tw, r);
    path.quadraticBezierTo(tw, 0, tw + r, 0);
    path.close();

    // Draw a soft shadow first
    canvas.drawShadow(
      path.shift(const Offset(0, 4)),
      Colors.black.withValues(alpha: 0.05),
      12,
      true,
    );

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
