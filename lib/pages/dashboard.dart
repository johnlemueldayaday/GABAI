import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:gabay/models/bill_models.dart';
import 'package:gabay/models/grocery_models.dart';
import 'package:gabay/models/finance_models.dart';
import 'package:gabay/config/app_theme.dart';
import 'package:gabay/services/bill_storage.dart';
import 'package:gabay/services/finance_storage.dart';
import 'package:gabay/services/settings_service.dart';
import 'package:gabay/widgets/account_icon.dart';
import 'package:gabay/widgets/app_drawer.dart';
import 'package:gabay/widgets/home/home_helpers.dart';
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
  String _currency = '₱';
  String _timeFilter = 'Day';

  @override
  void initState() {
    super.initState();
    _loadData();
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

  double _calculateSpent() {
    final now = DateTime.now();
    double total = 0;

    // Calculate from finance transactions
    final expenses = _transactions.where((t) => t.isExpense);
    for (var t in expenses) {
      if (_timeFilter == 'Day' &&
          t.date.day == now.day &&
          t.date.month == now.month &&
          t.date.year == now.year) {
        total += t.amount;
      } else if (_timeFilter == 'Week' && now.difference(t.date).inDays <= 7) {
        total += t.amount;
      } else if (_timeFilter == 'Month' &&
          t.date.month == now.month &&
          t.date.year == now.year) {
        total += t.amount;
      }
    }

    // Calculate from grocery lists
    for (var list in AppState.recentLists) {
      if (_timeFilter == 'Day' &&
          list.date.day == now.day &&
          list.date.month == now.month &&
          list.date.year == now.year) {
        total += list.items.fold(
          0.0,
          (s, i) => s + getItemTotal(i.price, i.qty, i.unit),
        );
      } else if (_timeFilter == 'Week' &&
          now.difference(list.date).inDays <= 7) {
        total += list.items.fold(
          0.0,
          (s, i) => s + getItemTotal(i.price, i.qty, i.unit),
        );
      } else if (_timeFilter == 'Month' &&
          list.date.month == now.month &&
          list.date.year == now.year) {
        total += list.items.fold(
          0.0,
          (s, i) => s + getItemTotal(i.price, i.qty, i.unit),
        );
      }
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final recentLists = AppState.recentLists;
    final userName = SettingsService().userName;
    final displayName = userName.isNotEmpty ? userName : 'User';

    final sortedTxns = List<FinanceTransaction>.from(_transactions)
      ..sort((a, b) => b.date.compareTo(a.date));
    final showExpenseFirst = sortedTxns.isNotEmpty && sortedTxns.first.isExpense;

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
          ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(toolbarHeight: 0, backgroundColor: kBackground),
      drawer: const AppDrawer(currentPage: 'Dashboard'),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          children: [
            // Top Bar: Menu + Date
            Row(
              children: [
                Builder(
                  builder: (context) => IconButton(
                    icon: Icon(
                      Icons.menu_rounded,
                      color: kTextCharcoal,
                      size: 28,
                    ),
                    onPressed: () => Scaffold.of(context).openDrawer(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  DateFormat(
                    'EEEE, MMM d',
                  ).format(DateTime.now()).toUpperCase(),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: kMuted,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
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

            const _GreetingSection(),
            const SizedBox(height: 24),

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
                    '$_currency${_netWorth.toStringAsFixed(2)}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
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

            // Stats Row
            Row(
              children: [
                // Compact Bar Chart
                Expanded(
                  flex: 2,
                  child: Container(
                    height: 120,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: kCardBg,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [kShadowSoft],
                    ),
                    child: _MiniTrendChart(recentLists: recentLists),
                  ),
                ),
                const SizedBox(width: 16),
                // Spent Card
                Expanded(
                  flex: 3,
                  child: Container(
                    height: 120,
                    padding: const EdgeInsets.all(16),
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
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Spent $_timeFilter',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: kMuted,
                              ),
                            ),
                            PopupMenuButton<String>(
                              icon: Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: kMuted,
                                size: 20,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onSelected: (val) =>
                                  setState(() => _timeFilter = val),
                              itemBuilder: (context) => ['Day', 'Week', 'Month']
                                  .map(
                                    (f) => PopupMenuItem(
                                      value: f,
                                      child: Text(
                                        f,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ],
                        ),
                        Text(
                          '${SettingsService().currency}${_calculateSpent().toStringAsFixed(0)}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: kTextCharcoal,
                          ),
                        ),
                      ],
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

class _MiniTrendChart extends StatelessWidget {
  final List<GroceryList> recentLists;
  const _MiniTrendChart({required this.recentLists});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final sunday = now.subtract(Duration(days: now.weekday % 7));
    final startOfWeek = DateTime(sunday.year, sunday.month, sunday.day);

    final weeklyData = List.generate(7, (index) => 0.0);

    for (final list in recentLists) {
      final difference = list.date.difference(startOfWeek).inDays;
      if (difference >= 0 && difference < 7) {
        weeklyData[difference] += list.items.fold(
          0.0,
          (s, i) => s + getItemTotal(i.price, i.qty, i.unit),
        );
      }
    }

    final chartMax =
        weeklyData.fold(0.0, (max, val) => val > max ? val : max) * 1.2;
    if (chartMax == 0) {
      return const Center(child: Icon(Icons.bar_chart, color: Colors.grey));
    }

    return BarChart(
      BarChartData(
        maxY: chartMax > 0 ? chartMax : 100,
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: false),
        barTouchData: BarTouchData(enabled: false),
        barGroups: List.generate(7, (i) {
          final isToday = i == now.weekday % 7;
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: weeklyData[i],
                color: isToday ? kPrimary : kPrimary.withValues(alpha: 0.3),
                width: 8,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          );
        }),
      ),
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
                  '${SettingsService().currency}${bill.amount.toStringAsFixed(0)}',
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
  const _TransactionList({
    required this.transactions,
    required this.accounts,
    required this.isIncome,
  });

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

        return Container(
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
                      t.description.isNotEmpty ? t.description : t.category,
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
                    '${isIncome ? '+' : '-'}${SettingsService().currency}${t.amount.toStringAsFixed(0)}',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w800,
                      color: isIncome ? kPrimary : Colors.red,
                    ),
                  ),
                  const SizedBox(height: 6),
                  AccountIconImage(
                    name: account.name,
                    icon: account.icon,
                    size: 16,
                  ),
                ],
              ),
            ],
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
  const _GreetingSection();

  @override
  State<_GreetingSection> createState() => _GreetingSectionState();
}

class _GreetingSectionState extends State<_GreetingSection> {
  List<String> _messages = ['Hi, welcome!'];
  int _currentIndex = 0;
  Timer? _timer;
  bool _isLoading = true;

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
    final bills = await BillStorage.loadBills();
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
        'hey, you have upcoming ${firstBill.type.toLowerCase()} bill this $dateStr, worth ₱${firstBill.amount.toStringAsFixed(2)}.',
      );
    }

    // 2. Check Today's Spending
    double spentToday = 0.0;
    for (var list in AppState.recentLists) {
      final listDay = DateTime(list.date.year, list.date.month, list.date.day);
      if (listDay.isAtSameMomentAs(today)) {
        spentToday += list.items.fold(
          0.0,
          (s, i) => s + getItemTotal(i.price, i.qty, i.unit),
        );
      }
    }

    if (spentToday > 0) {
      activeMessages.add(
        'your total spent for today is ₱${spentToday.toStringAsFixed(2)}.',
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
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
