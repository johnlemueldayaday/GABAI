import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../config/app_theme.dart';
import '../widgets/app_drawer.dart';
import '../models/bill_models.dart';
import '../models/finance_models.dart';
import '../services/bill_storage.dart';
import '../services/finance_storage.dart';

class BillsPage extends StatefulWidget {
  const BillsPage({super.key});

  @override
  State<BillsPage> createState() => _BillsPageState();
}

class _BillsPageState extends State<BillsPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  List<Bill> _allBills = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadData();
  }

  Future<void> _loadData() async {
    final bills = await BillStorage.loadBills();
    setState(() {
      _allBills = bills;
      _isLoading = false;
    });
  }

  Future<void> _saveData() async {
    await BillStorage.saveBills(_allBills);
  }

  List<Bill> _getEventsForDay(DateTime day) {
    return _allBills.where((b) => isSameDay(b.dueDate, day)).toList();
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
        onDelete: (id) {
          setState(() {
            _allBills.removeWhere((b) => b.id == id);
            _saveData();
          });
        },
        onTogglePaid: (id) {
          setState(() {
            final idx = _allBills.indexWhere((b) => b.id == id);
            if (idx != -1) {
              _allBills[idx] = _allBills[idx].copyWith(
                isPaid: !_allBills[idx].isPaid,
              );
              _saveData();
            }
          });
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
        return Container(
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
                          '₱${b.amount.toStringAsFixed(2)}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: kMuted,
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
            ],
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

  const _DayBillsSheet({
    required this.day,
    required this.bills,
    required this.onAdd,
    required this.onDelete,
    required this.onTogglePaid,
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
                          '₱${b.amount.toStringAsFixed(2)}',
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
          ),
        ),
      ),
    );
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
