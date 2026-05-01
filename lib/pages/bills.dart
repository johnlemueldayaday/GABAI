import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../config/app_theme.dart';
import '../widgets/app_drawer.dart';
import '../models/bill_models.dart';
import '../services/bill_storage.dart';

class BillsPage extends StatefulWidget {
  const BillsPage({super.key});

  @override
  State<BillsPage> createState() => _BillsPageState();
}

class _BillsPageState extends State<BillsPage> {
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  List<Bill> _allBills = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
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

  void _nextMonth() => setState(() => _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1));
  void _prevMonth() => setState(() => _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1));

  List<DateTime> _getDaysInMonth() {
    final first = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final last = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);
    final days = <DateTime>[];
    
    // Add empty slots for days before the first day of the month
    for (int i = 0; i < first.weekday % 7; i++) {
      days.add(first.subtract(Duration(days: (first.weekday % 7) - i)));
    }
    
    for (int i = 1; i <= last.day; i++) {
      days.add(DateTime(_selectedMonth.year, _selectedMonth.month, i));
    }
    
    return days;
  }

  bool _hasBillOn(DateTime day) {
    return _allBills.any((b) => 
      b.dueDate.year == day.year && 
      b.dueDate.month == day.month && 
      b.dueDate.day == day.day
    );
  }

  bool _isOverdue(DateTime day) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return day.isBefore(today) && _allBills.any((b) => 
      b.dueDate.year == day.year && 
      b.dueDate.month == day.month && 
      b.dueDate.day == day.day && 
      !b.isPaid
    );
  }

  void _showBillsForDay(DateTime day) {
    final bills = _allBills.where((b) => 
      b.dueDate.year == day.year && 
      b.dueDate.month == day.month && 
      b.dueDate.day == day.day
    ).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _DayBillsSheet(
        day: day,
        bills: bills,
        onAdd: (newBill) {
          setState(() {
            _allBills.add(newBill);
            _saveData();
          });
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
              _allBills[idx] = _allBills[idx].copyWith(isPaid: !_allBills[idx].isPaid);
              _saveData();
            }
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final days = _getDaysInMonth();
    final monthName = DateFormat('MMMM yyyy').format(_selectedMonth);

    return Scaffold(
      backgroundColor: kBackground,
      drawer: const AppDrawer(currentPage: 'Bills'),
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
          'Bills Tracker',
          style: GoogleFonts.plusJakartaSans(
            color: kTextCharcoal,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: Icon(Icons.chevron_left, color: kTextCharcoal),
                      onPressed: _prevMonth,
                    ),
                    Text(
                      monthName,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: kTextCharcoal,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.chevron_right, color: kTextCharcoal),
                      onPressed: _nextMonth,
                    ),
                  ],
                ),
              ),
              // Day Names
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: ['S', 'M', 'T', 'W', 'T', 'F', 'S'].map((d) => Expanded(
                    child: Center(
                      child: Text(
                        d,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: kMuted,
                        ),
                      ),
                    ),
                  )).toList(),
                ),
              ),
              const SizedBox(height: 10),
              // Calendar Grid
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: GridView.builder(
                    itemCount: days.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 7,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                    ),
                    itemBuilder: (context, index) {
                      final day = days[index];
                      final isSelectedMonth = day.month == _selectedMonth.month;
                      final isToday = day.day == DateTime.now().day && day.month == DateTime.now().month && day.year == DateTime.now().year;
                      final hasBills = _hasBillOn(day);
                      final overdue = _isOverdue(day);

                      return GestureDetector(
                        onTap: isSelectedMonth ? () => _showBillsForDay(day) : null,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            color: isToday ? kPrimary : (isSelectedMonth ? kCardBg : Colors.transparent),
                            borderRadius: BorderRadius.circular(12),
                            border: isToday ? null : Border.all(
                              color: overdue ? Colors.red.withValues(alpha: 0.5) : (hasBills ? kPrimary.withValues(alpha: 0.3) : Colors.transparent),
                              width: 1.5,
                            ),
                            boxShadow: isSelectedMonth ? [kShadowSoft] : null,
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Text(
                                day.day.toString(),
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: isToday ? Colors.white : (isSelectedMonth ? kTextCharcoal : kMuted.withValues(alpha: 0.3)),
                                ),
                              ),
                              if (hasBills)
                                Positioned(
                                  bottom: 6,
                                  child: Container(
                                    width: 4,
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color: overdue ? Colors.red : (isToday ? Colors.white : kPrimary),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Overdue Summary
              _buildSummary(),
            ],
          ),
    );
  }

  Widget _buildSummary() {
    final overdueCount = _allBills.where((b) => b.dueDate.isBefore(DateTime.now()) && !b.isPaid).length;
    final upcomingCount = _allBills.where((b) => b.dueDate.isAfter(DateTime.now()) && !b.isPaid).length;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, -4),
          )
        ],
      ),
      child: Row(
        children: [
          _SummaryItem(label: 'Overdue', count: overdueCount, color: Colors.red),
          const SizedBox(width: 16),
          _SummaryItem(label: 'Upcoming', count: upcomingCount, color: kPrimary),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _SummaryItem({required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label.toUpperCase(),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: color,
                letterSpacing: 0.5,
              ),
            ),
            Text(
              count.toString(),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ],
        ),
      ),
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
  final List<String> _frequencies = [
    'Everyday',
    'Weekly',
    'Monthly',
    'Quarterly',
    'Bi-monthly',
    'Annually'
  ];

  @override
  void dispose() {
    _amountCtrl.dispose();
    _typeCtrl.dispose();
    super.dispose();
  }

  Widget _buildBillItem(Bill b, Animation<double> animation) {
    return SlideTransition(
      position: animation.drive(Tween<Offset>(
        begin: const Offset(0, 1),
        end: Offset.zero,
      ).chain(CurveTween(curve: Curves.easeOutCubic))),
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
                onChanged: (_) => widget.onTogglePaid(b.id),
                activeColor: kPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(b.type, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: kTextCharcoal)),
                    Row(
                      children: [
                        Text('₱${b.amount.toStringAsFixed(2)}', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: kMuted, fontWeight: FontWeight.w600)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: kPrimary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                          child: Text(b.frequency, style: GoogleFonts.plusJakartaSans(fontSize: 9, fontWeight: FontWeight.w700, color: kPrimary)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                onPressed: () => widget.onDelete(b.id),
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
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
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
                    Text('Bills for', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: kMuted, fontWeight: FontWeight.w600)),
                    Text(dateStr, style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800, color: kTextCharcoal)),
                  ],
                ),
                const Spacer(),
                IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.close, color: kMuted)),
              ],
            ),
          ),
          Divider(color: kBorder, height: 1),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: animation.drive(Tween<Offset>(
                      begin: const Offset(0, 0.1),
                      end: Offset.zero,
                    ).chain(CurveTween(curve: Curves.easeOutCubic))),
                    child: child,
                  ),
                );
              },
              child: widget.bills.isEmpty
                  ? Center(
                      key: const ValueKey('empty'),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.receipt_long_outlined, size: 48, color: kMuted.withValues(alpha: 0.3)),
                          const SizedBox(height: 12),
                          Text('No bills for this day', style: GoogleFonts.plusJakartaSans(color: kMuted, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    )
                  : AnimatedList(
                      key: _listKey,
                      initialItemCount: widget.bills.length,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      itemBuilder: (context, i, animation) {
                        final b = widget.bills[i];
                        return _buildBillItem(b, animation);
                      },
                    ),
            ),
          ),


          const Divider(),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Add New Bill', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: kTextCharcoal)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _typeCtrl,
                        style: TextStyle(color: kTextCharcoal),
                        decoration: InputDecoration(
                          hintText: 'Bill Name',
                          hintStyle: TextStyle(color: kMuted.withValues(alpha: 0.5)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: kBorder)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: kPrimary)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 1,
                      child: TextField(
                        controller: _amountCtrl,
                        keyboardType: TextInputType.number,
                        style: TextStyle(color: kTextCharcoal),
                        decoration: InputDecoration(
                          hintText: 'Amount',
                          hintStyle: TextStyle(color: kMuted.withValues(alpha: 0.5)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: kBorder)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: kPrimary)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  // ignore: deprecated_member_use
                  value: _selectedFrequency,
                  dropdownColor: kCardBg,
                  style: TextStyle(color: kTextCharcoal, fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'Frequency',
                    labelStyle: TextStyle(color: kMuted),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: kBorder)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: kPrimary)),
                  ),
                  items: _frequencies.map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
                  onChanged: (v) => setState(() => _selectedFrequency = v!),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () async {
                      final amount = double.tryParse(_amountCtrl.text);
                      final type = _typeCtrl.text.trim();
                      if (amount != null && type.isNotEmpty) {
                        final confirmed = await showGeneralDialog<bool>(
                          context: context,
                          barrierDismissible: true,
                          barrierLabel: 'Confirm',
                          pageBuilder: (context, anim1, anim2) => const SizedBox(),
                          transitionBuilder: (context, anim1, anim2, child) {
                            return Transform.scale(
                              scale: anim1.value,
                              child: Opacity(
                                opacity: anim1.value,
                                child: AlertDialog(
                                  backgroundColor: kCardBg,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                  title: Text(
                                    'Confirm Bill',
                                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: kTextCharcoal),
                                  ),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Bills for',
                                        style: GoogleFonts.plusJakartaSans(fontSize: 12, color: kMuted),
                                      ),
                                      Text(
                                        DateFormat('MMMM d, yyyy').format(widget.day),
                                        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: kTextCharcoal),
                                      ),
                                      const SizedBox(height: 16),
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: kBackground,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: kBorder),
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(type, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: kTextCharcoal)),
                                                  Text('₱${amount.toStringAsFixed(2)} - $_selectedFrequency', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: kMuted)),
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
                                      onPressed: () => Navigator.pop(context, false),
                                      child: Text('Cancel', style: TextStyle(color: kMuted)),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, true),
                                      child: Text('Yes, Add', style: TextStyle(color: kPrimary, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );

                        if (confirmed == true) {
                          final newBill = Bill(
                            id: DateTime.now().millisecondsSinceEpoch.toString(),
                            type: type,
                            amount: amount,
                            dueDate: widget.day,
                            frequency: _selectedFrequency,
                          );
                          
                          widget.onAdd(newBill);
                          
                          // Animate the insertion
                          _listKey.currentState?.insertItem(widget.bills.length);
                          
                          _amountCtrl.clear();
                          _typeCtrl.clear();
                          setState(() {});
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: const Text('Add Bill'),
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
