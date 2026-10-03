import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:gabay/widgets/account_icon.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../config/app_theme.dart';
import '../widgets/app_drawer.dart';
import '../models/bill_models.dart';
import '../models/finance_models.dart';
import '../services/bill_storage.dart';
import '../services/finance_storage.dart';
import '../services/notification_service.dart';
import '../services/safe_to_spend.dart';

class BillsPage extends StatefulWidget {
  final String? initialSelectedBillId;
  const BillsPage({super.key, this.initialSelectedBillId});

  @override
  State<BillsPage> createState() => _BillsPageState();
}

class _BillsPageState extends State<BillsPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  List<Bill> _allBills = [];
  bool _isLoading = true;

  String _formatSignedBillAmount(Bill bill) {
    final sign = bill.isIncome ? '+' : '-';
    return '$sign₱${bill.amount.toStringAsFixed(2)}';
  }

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadData();
  }

  Future<void> _loadData() async {
    final bills = await BillStorage.loadBills();
    if (!mounted) return;
    setState(() {
      _allBills = bills;
      _isLoading = false;
    });

    if (widget.initialSelectedBillId != null) {
      final bill = bills.firstWhere(
        (b) => b.id == widget.initialSelectedBillId,
        orElse: () => Bill(
          id: '',
          type: '',
          amount: 0,
          dueDate: DateTime.now(),
        ),
      );
      if (bill.id.isNotEmpty) {
        setState(() {
          _focusedDay = bill.dueDate;
          _selectedDay = bill.dueDate;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _showBillActionSheet(bill);
          }
        });
      }
    }
  }

  Future<void> _saveData() async {
    await BillStorage.saveBills(_allBills);
  }

  List<Bill> _getEventsForDay(DateTime day) {
    return _allBills.where((b) => isSameDay(b.dueDate, day)).toList();
  }

  Future<void> _markBillAsPaid(Bill bill, [Account? chosenAccount]) async {
    final accounts = await FinanceStorage.loadAccounts();
    Account? targetAccount = chosenAccount;

    if (targetAccount == null && accounts.isNotEmpty) {
      if (accounts.length > 1 && mounted) {
        targetAccount = await showModalBottomSheet<Account>(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (ctx) => _SelectAccountSheet(
            accounts: accounts,
            amount: bill.amount,
            isIncome: bill.isIncome,
          ),
        );
        if (targetAccount == null) return;
      } else {
        targetAccount = accounts.first;
      }
    }

    if (targetAccount != null) {
      final txn = FinanceTransaction(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        amount: bill.amount,
        accountId: targetAccount.id,
        accountName: targetAccount.name,
        type: bill.isIncome ? 'INCOME' : 'EXPENSE',
        category: bill.type,
        description: bill.isIncome ? 'Received: ${bill.type}' : 'Bill Paid: ${bill.type}',
        date: DateTime.now(),
      );
      try {
        await FinanceStorage.addTransaction(txn);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not deduct balance: $e')),
        );
        return;
      }
    }

    final idx = _allBills.indexWhere((b) => b.id == bill.id);
    if (idx != -1) {
      setState(() {
        _allBills[idx] = _allBills[idx].copyWith(isPaid: true);
      });
      await _saveData();
    }
    await NotificationService().cancelBillNotification(bill.id);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          targetAccount != null
              ? bill.isIncome
                  ? '${bill.type} received! ${formatPeso(bill.amount)} added to ${targetAccount.name}.'
                  : 'Bill paid! ${formatPeso(bill.amount)} deducted from ${targetAccount.name}.'
              : bill.isIncome
                  ? '${bill.type} marked as received.'
                  : 'Bill marked as paid.',
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _confirmCancelBill(Bill bill) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogCtx) => CupertinoAlertDialog(
        title: Text('Cancel ${bill.type}?'),
        content: const Text(
          'This will cancel this bill and remove it from upcoming events and calendar.',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Keep Bill'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Cancel Bill'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _allBills.removeWhere((b) => b.id == bill.id);
      });
      await _saveData();
      await NotificationService().cancelBillNotification(bill.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${bill.type} canceled.'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  void _showEditBillSheet(Bill bill) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _EditBillSheet(
        bill: bill,
        onSave: (updatedBill) async {
          final idx = _allBills.indexWhere((b) => b.id == bill.id);
          if (idx != -1) {
            setState(() {
              _allBills[idx] = updatedBill;
            });
            await _saveData();
            await NotificationService().scheduleBillNotification(updatedBill);
          }
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${updatedBill.type} updated.'),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            );
          }
        },
      ),
    );
  }

  void _showBillActionSheet(Bill bill) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _BillDetailActionSheet(
        bill: bill,
        onPaid: (account) async {
          Navigator.pop(sheetContext);
          await _markBillAsPaid(bill, account);
        },
        onEdit: () {
          Navigator.pop(sheetContext);
          _showEditBillSheet(bill);
        },
        onCancel: () async {
          Navigator.pop(sheetContext);
          await _confirmCancelBill(bill);
        },
      ),
    );
  }

  void _showAddEventSheet() {
    if (_selectedDay == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _DayBillsSheet(
        day: _selectedDay!,
        bills: _getEventsForDay(_selectedDay!),
        onAdd: (newBill) async {
          setState(() {
            _allBills.add(newBill);
            _saveData();
          });
          await NotificationService().scheduleBillNotification(newBill);

          // Only add to FinanceStorage automatically if date is today or in the past
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          final billDate = DateTime(newBill.dueDate.year, newBill.dueDate.month, newBill.dueDate.day);
          
          if (!billDate.isAfter(today)) {
            final accounts = await FinanceStorage.loadAccounts();
            if (accounts.isNotEmpty) {
              final account = accounts.first;
              final txn = FinanceTransaction(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                amount: newBill.amount,
                accountId: account.id,
                accountName: account.name,
                type: newBill.isIncome ? 'INCOME' : 'EXPENSE',
                category: newBill.type,
                description: 'Calendar Event: ${newBill.type}',
                date: newBill.dueDate,
              );
              await FinanceStorage.addTransaction(txn);
            }
          }
        },
        onDelete: (id) async {
          setState(() {
            _allBills.removeWhere((b) => b.id == id);
            _saveData();
          });
          await NotificationService().cancelBillNotification(id);
        },
        onTogglePaid: (id) async {
          final idx = _allBills.indexWhere((b) => b.id == id);
          if (idx != -1) {
            final bill = _allBills[idx];
            if (!bill.isPaid) {
              await _markBillAsPaid(bill, null);
            } else {
              setState(() {
                _allBills[idx] = bill.copyWith(isPaid: false);
                _saveData();
              });
              await NotificationService().scheduleBillNotification(_allBills[idx]);
            }
          }
        },
        onTapBill: (bill) {
          Navigator.pop(context);
          _showBillActionSheet(bill);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      drawer: const AppDrawer(
        currentPage: 'Bills',
      ), // We keep 'Bills' as identifier for drawer
      appBar: AppBar(
        backgroundColor: kBackground,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(Icons.menu_rounded, color: kTextCharcoal),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Text(
          'Calendar',
          style: GoogleFonts.plusJakartaSans(
            color: kTextCharcoal,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.add, color: kPrimary),
            onPressed: () {
              setState(() {
                _selectedDay ??= DateTime.now();
                _focusedDay = _selectedDay!;
              });
              _showAddEventSheet();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: TableCalendar<Bill>(
                    firstDay: DateTime.utc(2020, 10, 16),
                    lastDay: DateTime.utc(2030, 3, 14),
                    focusedDay: _focusedDay,
                    selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                    onDaySelected: (selectedDay, focusedDay) {
                      setState(() {
                        _selectedDay = selectedDay;
                        _focusedDay = focusedDay;
                      });
                      _showAddEventSheet();
                    },
                    onPageChanged: (focusedDay) {
                      _focusedDay = focusedDay;
                    },
                    eventLoader: _getEventsForDay,
                    calendarStyle: CalendarStyle(
                      markerDecoration: BoxDecoration(
                        color: kPrimary,
                        shape: BoxShape.circle,
                      ),
                      selectedDecoration: BoxDecoration(
                        color: kPrimary,
                        shape: BoxShape.circle,
                      ),
                      todayDecoration: BoxDecoration(
                        color: kPrimary.withValues(alpha: 0.3),
                        shape: BoxShape.circle,
                      ),
                    ),
                    headerStyle: HeaderStyle(
                      formatButtonVisible: false,
                      titleCentered: true,
                      titleTextStyle: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: kTextCharcoal,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: kCardBg,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(32),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 15,
                          offset: const Offset(0, -4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Upcoming Events',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: kTextCharcoal,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Expanded(child: _buildUpcomingEvents()),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildUpcomingEvents() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final upcoming = _allBills
        .where((b) => !b.dueDate.isBefore(today) && !b.isPaid)
        .toList();
    upcoming.sort((a, b) => a.dueDate.compareTo(b.dueDate));

    if (upcoming.isEmpty) {
      return Center(
        child: Text(
          'No upcoming scheduled entries.',
          style: GoogleFonts.plusJakartaSans(color: kMuted),
        ),
      );
    }

    return ListView.builder(
      itemCount: upcoming.length,
      itemBuilder: (context, i) {
        final b = upcoming[i];
        final isIncome = b.isIncome;
        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _showBillActionSheet(b),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: kBackground,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isIncome
                          ? kPrimary.withValues(alpha: 0.1)
                          : Colors.red.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isIncome
                          ? Icons.south_west_rounded
                          : Icons.arrow_outward_rounded,
                      color: isIncome ? kPrimary : Colors.red,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          b.type,
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w700,
                            color: kTextCharcoal,
                          ),
                        ),
                        Row(
                          children: [
                            Text(
                              _formatSignedBillAmount(b),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                color: isIncome ? kPrimary : Colors.red,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: kPrimary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                DateFormat('MMM d, yyyy').format(b.dueDate),
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: kPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: kMuted,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DayBillsSheet extends StatefulWidget {
  final DateTime day;
  final List<Bill> bills;
  final Function(Bill) onAdd;
  final Function(String) onDelete;
  final Function(String) onTogglePaid;
  final void Function(Bill)? onTapBill;

  const _DayBillsSheet({
    required this.day,
    required this.bills,
    required this.onAdd,
    required this.onDelete,
    required this.onTogglePaid,
    this.onTapBill,
  });

  @override
  State<_DayBillsSheet> createState() => _DayBillsSheetState();
}

class _DayBillsSheetState extends State<_DayBillsSheet> {
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  final _amountCtrl = TextEditingController();
  final _typeCtrl = TextEditingController();
  String _selectedFrequency = 'Monthly';
  String? _selectedBillType;
  bool _showCustomInput = false;
  bool _isIncomeType = false;

  String _formatSignedBillAmount(Bill bill) {
    final sign = bill.isIncome ? '+' : '-';
    return '$sign₱${bill.amount.toStringAsFixed(2)}';
  }

  final List<String> _frequencies = [
    'Once',
    'Everyday',
    'Weekly',
    'Monthly',
    'Quarterly',
    'Bi-monthly',
    'Annually',
  ];

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _typeCtrl.dispose();
    super.dispose();
  }

  Widget _buildBillItem(Bill b, Animation<double> animation) {
    return SlideTransition(
      position: animation.drive(
        Tween<Offset>(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
      ),
      child: FadeTransition(
        opacity: animation,
        child: GestureDetector(
          onTap: widget.onTapBill != null ? () => widget.onTapBill!(b) : null,
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kBackground,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
            children: [
              Checkbox(
                value: b.isPaid,
                onChanged: (val) {
                  final idx = widget.bills.indexWhere(
                    (bill) => bill.id == b.id,
                  );
                  if (idx != -1) {
                    setState(() {
                      widget.bills[idx] = widget.bills[idx].copyWith(
                        isPaid: val ?? false,
                      );
                    });
                    widget.onTogglePaid(b.id);
                  }
                },
                activeColor: kPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      b.type,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                        color: b.isPaid ? kMuted : kTextCharcoal,
                        decoration: b.isPaid
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          _formatSignedBillAmount(b),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: b.isIncome ? kPrimary : Colors.red,
                            fontWeight: FontWeight.w600,
                            decoration: b.isPaid
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: b.isPaid
                                ? kMuted.withValues(alpha: 0.1)
                                : kPrimary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            b.frequency,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: b.isPaid ? kMuted : kPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.delete_outline,
                  color: Colors.red,
                  size: 20,
                ),
                onPressed: () {
                  final idx = widget.bills.indexWhere(
                    (bill) => bill.id == b.id,
                  );
                  if (idx != -1) {
                    final removedBill = widget.bills.removeAt(idx);
                    _listKey.currentState?.removeItem(
                      idx,
                      (context, animation) =>
                          _buildBillItem(removedBill, animation),
                      duration: const Duration(milliseconds: 400),
                    );
                    widget.onDelete(b.id);
                    setState(() {});
                  }
                },
              ),
            ],
            ),   // Row
          ),     // Container
        ),       // GestureDetector
      ),         // FadeTransition
    );           // SlideTransition
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('MMMM d, yyyy').format(widget.day);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Entries for',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: kMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      dateStr,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: kTextCharcoal,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close, color: kMuted),
                ),
              ],
            ),
          ),
          Divider(color: kBorder, height: 1),
          Expanded(
            child: Stack(
              children: [
                AnimatedOpacity(
                  opacity: widget.bills.isEmpty ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.calendar_month_outlined,
                          size: 48,
                          color: kMuted.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No entries for this day',
                          style: GoogleFonts.plusJakartaSans(
                            color: kMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                AnimatedList(
                  key: _listKey,
                  initialItemCount: widget.bills.length,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  itemBuilder: (context, i, animation) {
                    final b = widget.bills[i];
                    return _buildBillItem(b, animation);
                  },
                ),
              ],
            ),
          ),

          const Divider(),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add New Entry',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    color: kTextCharcoal,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _isIncomeType = false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: !_isIncomeType
                                ? Colors.red.withValues(alpha: 0.1)
                                : kBackground,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: !_isIncomeType ? Colors.red : kBorder,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Outgoing',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.bold,
                              color: !_isIncomeType ? Colors.red : kMuted,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _isIncomeType = true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _isIncomeType
                                ? kPrimary.withValues(alpha: 0.1)
                                : kBackground,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _isIncomeType ? kPrimary : kBorder,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Incoming',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.bold,
                              color: _isIncomeType ? kPrimary : kMuted,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _selectedBillType,
                  dropdownColor: kCardBg,
                  elevation: 8,
                  borderRadius: BorderRadius.circular(16),
                  menuMaxHeight: 336,
                  icon: Icon(Icons.keyboard_arrow_down_rounded, color: kPrimary),
                  style: GoogleFonts.plusJakartaSans(color: kTextCharcoal, fontSize: 14, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    labelText: 'Type/Category',
                    labelStyle: TextStyle(color: kMuted),
                    hintText: 'Select or add type',
                    hintStyle: TextStyle(color: kMuted.withValues(alpha: 0.5)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: kBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: kPrimary),
                    ),
                  ),
                  items: [
                    ...(_isIncomeType
                            ? predefinedIncomeTypes
                            : predefinedExpenseTypes)
                        .map(
                          (type) =>
                              DropdownMenuItem(value: type, child: Text(type)),
                        ),
                    const DropdownMenuItem(
                      value: '_custom_',
                      child: Text('+ Add Custom Type'),
                    ),
                  ],
                  onChanged: (v) => setState(() {
                    if (v == '_custom_') {
                      _showCustomInput = true;
                      _selectedBillType = null;
                    } else {
                      _showCustomInput = false;
                      _selectedBillType = v;
                      _typeCtrl.clear();
                    }
                  }),
                ),
                if (_showCustomInput) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: _typeCtrl,
                    style: GoogleFonts.plusJakartaSans(color: kTextCharcoal, fontSize: 14, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: 'Enter custom type',
                      hintStyle: TextStyle(
                        color: kMuted.withValues(alpha: 0.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 16,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: kBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: kPrimary),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                TextField(
                  controller: _amountCtrl,
                  keyboardType: TextInputType.number,
                  style: GoogleFonts.plusJakartaSans(color: kTextCharcoal, fontSize: 14, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    labelText: 'Amount',
                    labelStyle: TextStyle(color: kMuted),
                    hintText: 'Amount',
                    hintStyle: TextStyle(color: kMuted.withValues(alpha: 0.5)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: kBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: kPrimary),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _selectedFrequency,
                  dropdownColor: kCardBg,
                  elevation: 8,
                  borderRadius: BorderRadius.circular(16),
                  menuMaxHeight: 336,
                  icon: Icon(Icons.keyboard_arrow_down_rounded, color: kPrimary),
                  style: GoogleFonts.plusJakartaSans(color: kTextCharcoal, fontSize: 14, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    labelText: 'Frequency',
                    labelStyle: TextStyle(color: kMuted),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: kBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: kPrimary),
                    ),
                  ),
                  items: _frequencies
                      .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedFrequency = v!),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () async {
                      String cleanAmount = _amountCtrl.text.replaceAll(',', '').replaceAll('₱', '').trim();
                      if (cleanAmount.toLowerCase().endsWith('k')) {
                        String numPart = cleanAmount.substring(0, cleanAmount.length - 1);
                        double? val = double.tryParse(numPart);
                        if (val != null) {
                          cleanAmount = (val * 1000).toString();
                        }
                      }
                      final amount = double.tryParse(cleanAmount);
                      final type = _showCustomInput
                          ? _typeCtrl.text.trim()
                          : _selectedBillType;

                      if (amount != null && type != null && type.isNotEmpty) {
                        final confirmed = await showGeneralDialog<bool>(
                          context: context,
                          barrierDismissible: true,
                          barrierLabel: 'Confirm',
                          pageBuilder: (context, anim1, anim2) =>
                              const SizedBox(),
                          transitionBuilder: (context, anim1, anim2, child) {
                            return Transform.scale(
                              scale: anim1.value,
                              child: Opacity(
                                opacity: anim1.value,
                                child: AlertDialog(
                                  backgroundColor: kCardBg,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  title: Text(
                                    'Confirm Entry',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.w800,
                                      color: kTextCharcoal,
                                    ),
                                  ),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Entry for',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 12,
                                          color: kMuted,
                                        ),
                                      ),
                                      Text(
                                        DateFormat(
                                          'MMMM d, yyyy',
                                        ).format(widget.day),
                                        style: GoogleFonts.plusJakartaSans(
                                          fontWeight: FontWeight.w700,
                                          color: kTextCharcoal,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: kBackground,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(color: kBorder),
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    type,
                                                    style:
                                                        GoogleFonts.plusJakartaSans(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: kTextCharcoal,
                                                        ),
                                                  ),
                                                  Text(
                                                    '₱${amount.toStringAsFixed(2)} - $_selectedFrequency',
                                                    style:
                                                        GoogleFonts.plusJakartaSans(
                                                          fontSize: 12,
                                                          color: kMuted,
                                                        ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: Text(
                                        'Cancel',
                                        style: TextStyle(color: kMuted),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: Text(
                                        'Yes, Add',
                                        style: TextStyle(
                                          color: kPrimary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );

                        if (confirmed == true) {
                          final newBill = Bill(
                            id: DateTime.now().millisecondsSinceEpoch
                                .toString(),
                            type: type,
                            amount: amount,
                            dueDate: widget.day,
                            isIncome: _isIncomeType,
                            frequency: _selectedFrequency,
                          );

                          widget.bills.add(newBill);
                          widget.onAdd(newBill);

                          _listKey.currentState?.insertItem(
                            widget.bills.length - 1,
                            duration: const Duration(milliseconds: 300),
                          );

                          _amountCtrl.clear();
                          if (_showCustomInput) _typeCtrl.clear();
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
                      'Add to Calendar',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectAccountSheet extends StatelessWidget {
  final List<Account> accounts;
  final double amount;
  final bool isIncome;

  const _SelectAccountSheet({
    required this.accounts,
    required this.amount,
    this.isIncome = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 5,
              decoration: BoxDecoration(
                color: kMuted.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            isIncome ? 'Select Wallet to Transfer To' : 'Select Account to Pay From',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: kTextCharcoal,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isIncome 
                ? 'Amount to add: ${formatPeso(amount)}'
                : 'Amount to deduct: ${formatPeso(amount)}',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: kMuted,
            ),
          ),
          const SizedBox(height: 16),
          ...accounts.map(
            (acc) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: kBackground,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: kBorder.withValues(alpha: 0.4)),
              ),
              child: ListTile(
                leading: AccountIconImage(
                  name: acc.name,
                  icon: acc.icon,
                  size: 28,
                ),
                title: Text(
                  acc.name,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    color: kTextCharcoal,
                  ),
                ),
                subtitle: Text(
                  'Balance: ${formatPeso(acc.balance)}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: kMuted,
                  ),
                ),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                onTap: () => Navigator.pop(context, acc),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BillDetailActionSheet extends StatelessWidget {
  final Bill bill;
  final Function(Account?) onPaid;
  final VoidCallback onEdit;
  final VoidCallback onCancel;

  const _BillDetailActionSheet({
    required this.bill,
    required this.onPaid,
    required this.onEdit,
    required this.onCancel,
  });

  IconData _iconForType(String type) {
    final lower = type.toLowerCase();
    if (lower.contains('car') || lower.contains('vehicle') || lower.contains('loan')) {
      return Icons.directions_car_rounded;
    }
    if (lower.contains('electric') || lower.contains('power')) {
      return Icons.bolt_rounded;
    }
    if (lower.contains('water')) {
      return Icons.water_drop_rounded;
    }
    if (lower.contains('internet') || lower.contains('wifi')) {
      return Icons.wifi_rounded;
    }
    if (lower.contains('phone')) {
      return Icons.phone_iphone_rounded;
    }
    if (lower.contains('rent') || lower.contains('house') || lower.contains('home')) {
      return Icons.home_rounded;
    }
    if (lower.contains('salary') || lower.contains('income')) {
      return Icons.attach_money_rounded;
    }
    return Icons.receipt_long_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final billDue = DateTime(bill.dueDate.year, bill.dueDate.month, bill.dueDate.day);
    final days = billDue.difference(today).inDays;

    final daysStr = days == 0
        ? 'Due Today'
        : days == 1
            ? 'Due Tomorrow'
            : days < 0
                ? 'Overdue by ${days.abs()} day${days.abs() > 1 ? 's' : ''}'
                : 'Due in $days days';

    return Container(
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 25,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // iOS grab bar
          Container(
            width: 40,
            height: 5,
            decoration: BoxDecoration(
              color: kMuted.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2.5),
            ),
          ),
          const SizedBox(height: 20),
          // Icon badge
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: (bill.isPaid
                      ? Colors.green
                      : bill.isIncome
                          ? kPrimary
                          : Colors.orange)
                  .withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _iconForType(bill.type),
              color: bill.isPaid
                  ? Colors.green
                  : bill.isIncome
                      ? kPrimary
                      : Colors.orange,
              size: 32,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            bill.type,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: kTextCharcoal,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (bill.isPaid ? Colors.green : Colors.orange)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  bill.isPaid ? 'PAID' : daysStr.toUpperCase(),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: bill.isPaid ? Colors.green : Colors.orange,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: kPrimary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  bill.frequency.toUpperCase(),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: kPrimary,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            formatPeso(bill.amount),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: kTextCharcoal,
            ),
          ),
          Text(
            DateFormat('EEEE, MMMM d, yyyy').format(bill.dueDate),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: kMuted,
            ),
          ),
          const SizedBox(height: 28),

          // Actions
          if (!bill.isPaid) ...[
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                onPressed: () => onPaid(null),
                icon: Icon(
                  bill.isIncome ? Icons.south_west_rounded : Icons.check_circle_rounded,
                  size: 18,
                ),
                label: Text(
                  bill.isIncome ? 'Received' : 'Bill Paid',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: bill.isIncome ? kPrimary : Colors.green.shade600,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],

          SizedBox(
            width: double.infinity,
            height: 42,
            child: OutlinedButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_rounded, size: 17),
              label: Text(
                'Edit Bill',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: kPrimary,
                side: BorderSide(color: kPrimary.withValues(alpha: 0.5)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          SizedBox(
            width: double.infinity,
            height: 38,
            child: TextButton.icon(
              onPressed: onCancel,
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 16),
              label: Text(
                bill.isIncome ? 'Remove' : 'Cancel Bill',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.red,
                ),
              ),
              style: TextButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditBillSheet extends StatefulWidget {
  final Bill bill;
  final Function(Bill) onSave;

  const _EditBillSheet({
    required this.bill,
    required this.onSave,
  });

  @override
  State<_EditBillSheet> createState() => _EditBillSheetState();
}

class _EditBillSheetState extends State<_EditBillSheet> {
  late final TextEditingController _typeCtrl;
  late final TextEditingController _amountCtrl;
  late DateTime _selectedDueDate;
  late String _selectedFrequency;
  late bool _isIncome;

  final List<String> _frequencies = [
    'Once',
    'Everyday',
    'Weekly',
    'Monthly',
    'Quarterly',
    'Bi-monthly',
    'Annually',
  ];

  @override
  void initState() {
    super.initState();
    _typeCtrl = TextEditingController(text: widget.bill.type);
    _amountCtrl = TextEditingController(text: widget.bill.amount.toStringAsFixed(2));
    _selectedDueDate = widget.bill.dueDate;
    _selectedFrequency = widget.bill.frequency;
    _isIncome = widget.bill.isIncome;
  }

  @override
  void dispose() {
    _typeCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: kMuted.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Edit Bill / Loan',
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
          Text(
            'Name / Type',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: kMuted,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _typeCtrl,
            decoration: InputDecoration(
              hintText: 'e.g. Car Loan, Electric Bill',
              filled: true,
              fillColor: kBackground,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: kBorder),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Amount',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: kMuted,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              prefixText: '₱ ',
              hintText: '0.00',
              filled: true,
              fillColor: kBackground,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: kBorder),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Due Date',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: kMuted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _selectedDueDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2035),
                        );
                        if (picked != null) {
                          setState(() {
                            _selectedDueDate = picked;
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        decoration: BoxDecoration(
                          color: kBackground,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: kBorder),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              DateFormat('MMM d, yyyy').format(_selectedDueDate),
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w600,
                                color: kTextCharcoal,
                              ),
                            ),
                            Icon(Icons.calendar_today_rounded, size: 16, color: kPrimary),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Frequency',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: kMuted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: kBackground,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: kBorder),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedFrequency,
                          isExpanded: true,
                          items: _frequencies
                              .map(
                                (f) => DropdownMenuItem(
                                  value: f,
                                  child: Text(
                                    f,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _selectedFrequency = val;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () {
                final amt = double.tryParse(_amountCtrl.text.replaceAll(',', '').trim());
                final type = _typeCtrl.text.trim();
                if (amt != null && amt > 0 && type.isNotEmpty) {
                  final updated = widget.bill.copyWith(
                    type: type,
                    amount: amt,
                    dueDate: _selectedDueDate,
                    frequency: _selectedFrequency,
                    isIncome: _isIncome,
                  );
                  widget.onSave(updated);
                  Navigator.pop(context);
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
                'Save Changes',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
