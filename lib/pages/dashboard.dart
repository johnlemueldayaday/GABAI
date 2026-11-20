import 'dart:async';
import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gabay/models/bill_models.dart';
import 'package:gabay/models/grocery_models.dart';
import 'package:gabay/models/finance_models.dart';
import 'package:gabay/config/app_theme.dart';
import 'package:gabay/navigation/app_routes.dart';
import 'package:gabay/pages/gab_chat.dart';
import 'package:gabay/pages/bills.dart';
import 'package:gabay/services/bill_storage.dart';
import 'package:gabay/services/finance_storage.dart';
import 'package:gabay/services/settings_service.dart';
import 'package:gabay/services/safe_to_spend.dart';
import 'package:gabay/services/bill_expense_classifier.dart';
import 'package:gabay/services/widget_service.dart';
import 'package:gabay/widgets/account_icon.dart';
import 'package:gabay/widgets/app_drawer.dart';
import 'package:gabay/widgets/gab_picker_sheet.dart';
import 'package:gabay/widgets/home/home_helpers.dart';
import 'package:gabay/pages/wallet.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with WidgetsBindingObserver {
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
  late final PageController _safeToSpendPageController;

  Future<void> _openBillDetails(Bill bill) async {
    await Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => BillsPage(initialSelectedBillId: bill.id),
      ),
    );
    await _loadData();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SettingsService().dailySpendingAllocationNotifier.addListener(
      _handleDailyAllocationChanged,
    );
    _loadData();
    _safeToSpendPageController = PageController(
      initialPage: _showWeeklySpending ? 1 : 0,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SettingsService().dailySpendingAllocationNotifier.removeListener(
      _handleDailyAllocationChanged,
    );
    _safeToSpendPageController.dispose();
    super.dispose();
  }

  void _handleDailyAllocationChanged() {
    if (!mounted) return;
    setState(
      () => _dailyAllocation =
          SettingsService().dailySpendingAllocationNotifier.value,
    );
    unawaited(_updateWidgetData());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_loadData());
    }
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

    unawaited(_updateWidgetData());
  }

  Future<void> _updateWidgetData() async {
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
    final totalCycleDays = getCycleLength(
      frequency: _payFrequency,
      intervalDays: _intervalDays,
      payday1: _payday1,
      payday2: _payday2,
    );
    final cycleStart = resolvedPayday.subtract(
      Duration(days: totalCycleDays - 1),
    );
    final effectiveCycleStart = cycleStart.isAfter(today) ? today : cycleStart;
    final cycleSpentBeforeToday = _calculateSpentBetween(
      effectiveCycleStart,
      today,
    );
    final todaySpent = _calculateSpentBetween(today, tomorrow);
    final daysLeft = calculateDaysLeft(today: today, payday: resolvedPayday);
    final spendingPlan = SafeToSpend.calculate(
      balance: _netWorth,
      dailyBudget: _dailyAllocation,
      daysLeft: daysLeft,
      spentToday: todaySpent,
      totalCycleDays: totalCycleDays,
      cycleSpentBeforeToday: cycleSpentBeforeToday,
    );
    final weekStart = today.subtract(const Duration(days: 6));
    final weekSpent = _calculateSpentBetween(weekStart, tomorrow);
    final weekBudget = _dailyAllocation * 7;

    final updated = await WidgetService.updateSafeToSpendWidget(
      safeToSpend: spendingPlan.safeToSpend,
      weekSpent: weekSpent,
      weekBudget: weekBudget,
    );
    if (!updated) {
      debugPrint('GABAI widget data was not updated. Check App Group signing.');
    }
  }

  void _showAddTransactionSheet({String initialType = 'EXPENSE'}) {
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String selectedType = initialType;
    String? selectedAccountId = _accounts.isNotEmpty
        ? _accounts.first.id
        : null;
    String selectedCategory = initialType == 'INCOME'
        ? incomeCategories.first
        : expenseCategories.first;

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
                        key: const ValueKey('transaction_expense_tab'),
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
                        key: const ValueKey('transaction_income_tab'),
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
                _GabPickerTile(
                  label: 'Account',
                  value: selectedAccountId != null
                      ? _accounts
                            .firstWhere(
                              (a) => a.id == selectedAccountId,
                              orElse: () => _accounts.first,
                            )
                            .name
                      : null,
                  leading: selectedAccountId != null
                      ? AccountIconImage(
                          name: _accounts
                              .firstWhere(
                                (a) => a.id == selectedAccountId,
                                orElse: () => _accounts.first,
                              )
                              .name,
                          icon: _accounts
                              .firstWhere(
                                (a) => a.id == selectedAccountId,
                                orElse: () => _accounts.first,
                              )
                              .icon,
                          size: 22,
                        )
                      : null,
                  onTap: () async {
                    final picked = await showGabPicker<String>(
                      context: context,
                      title: 'Select Account',
                      selectedValue: selectedAccountId,
                      items: _accounts
                          .map(
                            (a) => GabPickerItem<String>(
                              value: a.id,
                              label: a.name,
                              leading: AccountIconImage(
                                name: a.name,
                                icon: a.icon,
                                size: 24,
                              ),
                            ),
                          )
                          .toList(),
                    );
                    if (picked != null) {
                      setSheetState(() => selectedAccountId = picked.value);
                    }
                  },
                ),
                const SizedBox(height: 16),
                _GabPickerTile(
                  label: 'Category',
                  value: selectedCategory,
                  onTap: () async {
                    final picked = await showGabPicker<String>(
                      context: context,
                      title: 'Select Category',
                      selectedValue: selectedCategory,
                      showSearch: true,
                      searchHint: 'Search categories…',
                      items: currentCategories
                          .map((c) => GabPickerItem<String>(value: c, label: c))
                          .toList(),
                    );
                    if (picked != null) {
                      setSheetState(() => selectedCategory = picked.value);
                    }
                  },
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
        totalBalance: _netWorth,
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
    unawaited(_updateWidgetData());
  }

  double _calculateSpentBetween(DateTime start, DateTime end) {
    var total = 0.0;
    for (final transaction in _transactions) {
      if (!transaction.isExpense ||
          transaction.isTransfer ||
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

    final todayBudget = _dailyAllocation;
    final todayProgress = todayBudget <= 0
        ? 0.0
        : (todaySpent / todayBudget).clamp(0.0, 1.0).toDouble();

    final weekBudget = _dailyAllocation * 7;
    final weekProgress = weekBudget <= 0
        ? 0.0
        : (weekSpent / weekBudget).clamp(0.0, 1.0).toDouble();

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

            _GreetingSection(
              spentToday: spendingPlan.spentToday,
              dailyBudget: _dailyAllocation,
              onChatClosed: _loadData,
            ),

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
                        child: _BalanceActionButton(
                          key: const ValueKey('dashboard_income_action'),
                          onTap: () =>
                              _showAddTransactionSheet(initialType: 'INCOME'),
                          icon: Icons.add_rounded,
                          label: 'Income',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _BalanceActionButton(
                          key: const ValueKey('dashboard_expense_action'),
                          onTap: () =>
                              _showAddTransactionSheet(initialType: 'EXPENSE'),
                          icon: Icons.arrow_upward_rounded,
                          label: 'Expense',
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
                          SizedBox(
                            height: 44,
                            child: PageView(
                              controller: _safeToSpendPageController,
                              physics: const BouncingScrollPhysics(),
                              onPageChanged: (index) {
                                setState(() {
                                  _showWeeklySpending = index == 1;
                                });
                              },
                              children: [
                                _buildPeriodPage(
                                  isWeek: false,
                                  progress: todayProgress,
                                  safeToSpend: spendingPlan.safeToSpend,
                                ),
                                _buildPeriodPage(
                                  isWeek: true,
                                  progress: weekProgress,
                                  safeToSpend: spendingPlan.safeToSpend,
                                ),
                              ],
                            ),
                          ),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: Text(
                              key: ValueKey<double>(
                                spendingPlan.effectiveDailyBudget,
                              ),
                              '${formatPeso(spendingPlan.effectiveDailyBudget)}/day',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: spendingPlan.extra < 0
                                    ? const Color.fromARGB(255, 37, 37, 37)
                                    : kMuted,
                              ),
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
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            _SectionHeader(title: 'Upcoming Events'),
            _UpcomingEventsList(bills: _bills, onBillTapped: _openBillDetails),

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

  Widget _buildPeriodPage({
    required bool isWeek,
    required double progress,
    required double safeToSpend,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            final next = isWeek ? 0 : 1;
            _safeToSpendPageController.animateToPage(
              next,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
            );
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.chevron_left_rounded,
                size: 17,
                color: isWeek ? kMuted : kPrimary,
              ),
              Text(
                isWeek ? 'WEEK' : 'TODAY',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: kPrimary,
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 17,
                color: isWeek ? kPrimary : kMuted,
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 7,
            backgroundColor: kPrimary.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation<Color>(
              safeToSpend <= 0 ? Colors.red : kPrimary,
            ),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          '${NumberFormat('0.##').format(progress * 100)}% of 100%',
          style: GoogleFonts.plusJakartaSans(fontSize: 9, color: kMuted),
        ),
      ],
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
  final double totalBalance;
  final PayFrequency initialFrequency;
  final int initialPayday1;
  final int? initialPayday2;
  final int? initialIntervalDays;
  final DateTime? initialAnchorPayday;

  const _DailyAllocationDialog({
    required this.currency,
    required this.initialAmount,
    required this.totalBalance,
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

  double? get _suggestedDailyBudget {
    final payday = _resolvedPayday;
    if (payday == null) return null;
    return calculateSuggestedDailyBudget(
      balance: widget.totalBalance,
      today: _today,
      payday: payday,
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
    final suggestedBudget = _suggestedDailyBudget;
    final suggestedBudgetLabel = suggestedBudget == null
        ? 'Suggest'
        : 'Suggest ${widget.currency}${NumberFormat('#,##0.00').format(suggestedBudget)}';
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('daily_budget_input'),
                  controller: _dailyBudgetController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Daily budget',
                    prefixText: '${widget.currency} ',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                key: const ValueKey('suggested_daily_budget_button'),
                onPressed: suggestedBudget == null
                    ? null
                    : () {
                        final value = suggestedBudget.toStringAsFixed(2);
                        _dailyBudgetController.value = TextEditingValue(
                          text: value,
                          selection: TextSelection.collapsed(
                            offset: value.length,
                          ),
                        );
                      },
                icon: const Icon(Icons.lightbulb_outline_rounded, size: 16),
                label: Text(suggestedBudgetLabel),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  shape: const StadiumBorder(),
                ),
              ),
            ],
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
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text:
                            '${calculateDaysLeft(today: _today, payday: resolved) - 1}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const TextSpan(text: ' days until next payday'),
                    ],
                  ),
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
  void didUpdateWidget(_GlassTrendChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.transactions != widget.transactions ||
        oldWidget.recentLists != widget.recentLists) {
      _animCtrl.forward(from: 0);
    }
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
      if (!txn.isExpense || txn.isTransfer) continue;
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.payments_outlined, size: 15, color: kPrimary),
            const SizedBox(width: 5),
            Text(
              'WEEKLY SPENDING',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: kMuted,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: AnimatedBuilder(
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
                                          Color.lerp(
                                            kPrimary,
                                            Colors.black,
                                            0.15,
                                          )!,
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
                          color: hasData
                              ? null
                              : kMuted.withValues(alpha: 0.08),
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
          ),
        ),
      ],
    );
  }
}

class _UpcomingEventsList extends StatelessWidget {
  final List<Bill> bills;
  final Future<void> Function(Bill) onBillTapped;
  const _UpcomingEventsList({required this.bills, required this.onBillTapped});

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

          return GestureDetector(
            onTap: () => onBillTapped(bill),
            child: Container(
              width: MediaQuery.of(context).size.width * 0.75,
              margin: EdgeInsets.only(
                right: index == items.length - 1 ? 0 : 12,
              ),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: kCardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: kBorder.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Image.asset(
                    'assets/images/events_logged.png',
                    width: 44,
                    height: 44,
                    fit: BoxFit.contain,
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
                  Row(
                    children: [
                      Text(
                        formatPeso(bill.amount),
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w800,
                          color: kTextCharcoal,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.orange,
                        size: 18,
                      ),
                    ],
                  ),
                ],
              ),
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
    if (!isIncome &&
        (description.startsWith('Bill Paid:') ||
            description.startsWith('Paid:'))) {
      return cleanBillName(description);
    }
    if (description.isEmpty) return category;
    if (!isIncome || category.isEmpty || category == 'Others') {
      return description;
    }
    if (category.toLowerCase() == 'reimbursement' &&
        RegExp(
          r'\b(?:debt|loan|utang)\b',
          caseSensitive: false,
        ).hasMatch(description)) {
      final withoutCategory = description
          .replaceAll(RegExp(r'\breimbursement\b', caseSensitive: false), '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      final leadingDebtTerm = RegExp(
        r'^(debt|loan|utang)\s+(.+)$',
        caseSensitive: false,
      ).firstMatch(withoutCategory);
      if (leadingDebtTerm != null) {
        return '${leadingDebtTerm.group(2)} ${leadingDebtTerm.group(1)}';
      }
      return withoutCategory;
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
                Image.asset(
                  isIncome
                      ? 'assets/images/income_logged.png'
                      : 'assets/images/expense_logged.png',
                  width: 44,
                  height: 44,
                  fit: BoxFit.contain,
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
  final double dailyBudget;
  final Future<void> Function() onChatClosed;

  const _GreetingSection({
    required this.spentToday,
    required this.dailyBudget,
    required this.onChatClosed,
  });

  @override
  State<_GreetingSection> createState() => _GreetingSectionState();
}

class _GreetingSectionState extends State<_GreetingSection> {
  static const _lastBudgetMessageKey = 'dashboard_last_budget_bubble_message';
  static const _greenMessages = [
    "You're doing great today! Still got {remaining} left to play with 😎",
    "Easy lang, you're way under budget. Keep it up! 💪",
    "Wallet's feeling good so far. Nice job! ✨",
    'Safe pa tayo, {remaining} left. Enjoy your day! 😊',
    'Look at you being responsible today 👏',
    'Plenty of room left in your budget. No stress! 🌿',
  ];
  static const _yellowMessages = [
    "You're halfway through your safe-to-spend. Pace yourself, okay? 🙂",
    'Half of your budget is gone already. Still fine, just keep an eye on it 👀',
    '{remaining} left. Think twice before the next purchase, okay?',
    "Chill muna sa spending, you're already past the middle 😅",
    "Still safe, but don't get too excited with spending yet!",
    "Just a heads up, you've used {percent}% already. You got this though! 💛",
  ];
  static const _orangeMessages = [
    "Uh oh, you're getting close to your limit! Only {remaining} left 😬",
    'Careful na, your budget is running low. Spend wisely okay? 🧐',
    "You've used {percent}% already! Maybe skip the non-essentials today?",
    'Almost there to the limit. Think before you tap! 🙏',
    "Your budget's getting thin, don't go crazy now okay? 😅",
    'Just {remaining} left. Choose what really matters!',
  ];
  static const _redMessages = [
    "You're almost tight on budget! Don't spend too much okay? 🥺",
    'Your safe-to-spend is almost gone, only {remaining} left! Be careful 🚨',
    'Konti na lang ang natitira, {remaining} na lang! Hold the spending okay? ✋',
    'Almost out of budget! Maybe save the extras for tomorrow? 🙏',
    "Warning! You've used {percent}% already. Please go easy 😭",
    'Super tight na, only {remaining} left. Essentials only today, okay? 💸',
  ];
  static const _finishedMessages = [
    "You've used up your safe-to-spend for today. Time to stop spending! 🛑",
    "Budget's all gone! Only the must-haves from here, okay? 🙏",
    "Zero left na! Let's pause the spending for now 😮‍💨",
    "You hit your limit today. Tomorrow's a fresh start! 🌅",
    'No more safe-to-spend left. Please hold off on buying okay? ✋',
    "Budget finished! Let's be extra careful for the rest of the day 💛",
  ];
  static const _overBudgetMessages = [
    "Oops, you went over your budget by {over_amount}. It's okay, let's be careful tomorrow 😅",
    "You're over the limit na! Let's try to balance it out soon okay? 🥲",
    "Over budget by {over_amount}. No judgment, but let's slow down a bit 🙏",
    "Your budget got exceeded. Maybe we can adjust tomorrow's spending?",
    "Hala, over na tayo sa budget! Let's cut back for the next few days 😬",
    "You went past your limit. Don't worry, we can fix this together 💪",
  ];

  List<String> _messages = ['Hi, welcome!'];
  int _currentIndex = 0;
  Timer? _timer;
  bool _isLoading = true;
  final Random _random = Random();
  late final VideoPlayerController _greetingAvatarController;
  late final Future<void> _greetingAvatarReady;

  @override
  void didUpdateWidget(covariant _GreetingSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.spentToday != widget.spentToday ||
        oldWidget.dailyBudget != widget.dailyBudget) {
      _loadGreeting();
    }
  }

  @override
  void initState() {
    super.initState();
    _greetingAvatarController = VideoPlayerController.asset(
      'assets/images/greetings_avatar_dashboard.mp4',
    );
    _greetingAvatarReady = _initializeGreetingAvatar();
    _loadGreeting();
  }

  Future<void> _initializeGreetingAvatar() async {
    await _greetingAvatarController.initialize();
    await _greetingAvatarController.setLooping(true);
    await _greetingAvatarController.play();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _greetingAvatarController.dispose();
    super.dispose();
  }

  Future<void> _loadGreeting() async {
    _timer?.cancel();
    final bills = await BillStorage.loadBills();
    if (!mounted) return;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    List<String> activeMessages = [];
    final budgetMessage = await _selectBudgetMessage();
    if (!mounted) return;

    if (budgetMessage != null) {
      activeMessages.add(budgetMessage);
    } else {
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
    }

    // Default if empty
    if (activeMessages.isEmpty) {
      activeMessages.add('Hi, welcome!');
    }

    setState(() {
      _messages = activeMessages;
      _currentIndex = 0;
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

  Future<String?> _selectBudgetMessage() async {
    final budget = widget.dailyBudget;
    final spent = widget.spentToday;
    if (!budget.isFinite || budget <= 0 || !spent.isFinite || spent < 0) {
      return null;
    }

    final percentUsed = spent / budget * 100;
    final remaining = budget - spent;
    final List<String> variants;
    if (percentUsed > 100) {
      variants = _overBudgetMessages;
    } else if (percentUsed == 100) {
      variants = _finishedMessages;
    } else if (percentUsed >= 90) {
      variants = _redMessages;
    } else if (percentUsed >= 75) {
      variants = _orangeMessages;
    } else if (percentUsed >= 50) {
      variants = _yellowMessages;
    } else {
      variants = _greenMessages;
    }

    final percentText = percentUsed.round().toString();
    final preferences = await SharedPreferences.getInstance();
    final lastTemplate = preferences.getString(_lastBudgetMessageKey);
    final candidates = variants
        .where((message) => message != lastTemplate)
        .toList();
    final selectedTemplate = candidates[_random.nextInt(candidates.length)];
    await preferences.setString(_lastBudgetMessageKey, selectedTemplate);
    return selectedTemplate
        .replaceAll('{remaining}', formatPeso(remaining))
        .replaceAll('{percent}', percentText)
        .replaceAll('{over_amount}', formatPeso(spent - budget));
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async {
        await Navigator.push(
          context,
          PageRouteBuilder<void>(
            settings: const RouteSettings(name: kGabChatRouteName),
            pageBuilder: (_, _, _) => const GabChatPage(),
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
        await widget.onChatClosed();
      },
      child: Semantics(
        button: true,
        label: 'Open GAB chat',
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Transform.translate(
                offset: Offset.zero,
                child: Container(
                  width: 130,
                  height: 130,
                  alignment: Alignment.center,
                  child: FutureBuilder<void>(
                    future: _greetingAvatarReady,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Icon(
                          Icons.account_circle_outlined,
                          size: 96,
                          color: kMuted,
                        );
                      }
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const SizedBox.shrink();
                      }
                      final size = _greetingAvatarController.value.size;
                      return FittedBox(
                        fit: BoxFit.contain,
                        child: SizedBox(
                          width: size.width,
                          height: size.height,
                          child: VideoPlayer(_greetingAvatarController),
                        ),
                      );
                    },
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
                        horizontal: 20,
                        vertical: 14,
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

class _BalanceActionButton extends StatefulWidget {
  final VoidCallback onTap;
  final IconData icon;
  final String label;

  const _BalanceActionButton({
    super.key,
    required this.onTap,
    required this.icon,
    required this.label,
  });

  @override
  State<_BalanceActionButton> createState() => _BalanceActionButtonState();
}

class _BalanceActionButtonState extends State<_BalanceActionButton> {
  bool _isDown = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) {
        setState(() => _isDown = true);
        unawaited(HapticFeedback.mediumImpact());
      },
      onTapUp: (_) => setState(() => _isDown = false),
      onTapCancel: () => setState(() => _isDown = false),
      onTap: () {
        setState(() => _isDown = false);
        unawaited(HapticFeedback.heavyImpact());
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _isDown ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOutCubic,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white.withValues(alpha: _isDown ? 0.20 : 0.28),
                Colors.white.withValues(alpha: _isDown ? 0.13 : 0.18),
                Colors.white.withValues(alpha: _isDown ? 0.06 : 0.09),
              ],
              stops: const [0.0, 0.45, 1.0],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: _isDown ? 0.16 : 0.22),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
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

    // 1. Draw soft 3D shadow (more pronounced)
    canvas.drawShadow(
      path.shift(const Offset(0, 3)),
      Colors.black.withValues(alpha: 0.15),
      8,
      false,
    );

    // 2. Draw 3D gradient fill
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Colors.white,
        Color.lerp(Colors.white, color, 0.6)!,
        Color.lerp(color, Colors.black, 0.05)!,
      ],
      stops: const [0.0, 0.7, 1.0],
    );

    final fillPaint = Paint()
      ..shader = gradient.createShader(Offset.zero & size)
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, fillPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Tappable field that opens a [GabPickerSheet] bottom sheet.
/// Used in place of [DropdownButtonFormField] inside the transaction sheet.
class _GabPickerTile extends StatelessWidget {
  final String label;
  final String? value;
  final Widget? leading;
  final VoidCallback onTap;

  const _GabPickerTile({
    required this.label,
    required this.onTap,
    this.value,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kBorder),
        ),
        child: Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 10)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: kMuted,
                    ),
                  ),
                  if (value != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      value!,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: kTextCharcoal,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.keyboard_arrow_down_rounded, color: kMuted, size: 22),
          ],
        ),
      ),
    );
  }
}
