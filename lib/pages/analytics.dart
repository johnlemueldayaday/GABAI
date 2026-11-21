import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:gabay/models/bill_models.dart';
import 'package:gabay/models/grocery_models.dart';
import 'package:gabay/models/finance_models.dart';
import 'package:gabay/pages/price_comparison.dart';
import 'package:gabay/config/app_theme.dart';
import 'package:gabay/services/bill_storage.dart';
import 'package:gabay/services/finance_storage.dart';
import 'package:gabay/widgets/app_drawer.dart';
import 'package:gabay/widgets/home/home_helpers.dart';
import 'package:gabay/services/settings_service.dart';
import 'package:gabay/services/bill_expense_classifier.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

// ─── Enums ────────────────────────────────────────────────────────────────────
enum _Period { today, week, month, year }

enum _Section { totalSpent, groceryCategory, billsBreakdown, history }

String _formatAnalyticsAmount(double amount) =>
    NumberFormat('#,##0.00').format(amount);

extension _PeriodX on _Period {
  String get shortLabel {
    switch (this) {
      case _Period.today:
        return 'Today';
      case _Period.week:
        return 'Week';
      case _Period.month:
        return 'Month';
      case _Period.year:
        return 'Year';
    }
  }

  DateTimeRange get range {
    final now = DateTime.now();
    switch (this) {
      case _Period.today:
        final s = DateTime(now.year, now.month, now.day);
        return DateTimeRange(start: s, end: s.add(const Duration(days: 1)));
      case _Period.week:
        // Use ISO weekday: Mon=1 … Sun=7, we want Mon as start
        final s = DateTime(now.year, now.month, now.day - (now.weekday - 1));
        return DateTimeRange(start: s, end: s.add(const Duration(days: 7)));
      case _Period.month:
        final s = DateTime(now.year, now.month);
        return DateTimeRange(start: s, end: DateTime(now.year, now.month + 1));
      case _Period.year:
        return DateTimeRange(
          start: DateTime(now.year),
          end: DateTime(now.year + 1),
        );
    }
  }
}

extension _SectionX on _Section {
  String get title {
    switch (this) {
      case _Section.totalSpent:
        return 'Total Spent Breakdown';
      case _Section.groceryCategory:
        return 'Grocery Category Breakdown';
      case _Section.billsBreakdown:
        return 'Bills Breakdown';
      case _Section.history:
        return 'History Breakdown';
    }
  }
}

// ─── Color Palette ────────────────────────────────────────────────────────────
const _kPalette = [
  Color(0xFF3B82F6),
  Color(0xFF10B981),
  Color(0xFFF59E0B),
  Color(0xFFEF4444),
  Color(0xFF8B5CF6),
  Color(0xFFEC4899),
  Color(0xFF06B6D4),
  Color(0xFF84CC16),
  Color(0xFF14B8A6),
  Color(0xFFF97316),
  Color(0xFF6366F1),
  Color(0xFFDB2777),
];

// ─── Bill icon mapping ────────────────────────────────────────────────────────
IconData _billIcon(String type) {
  switch (type.toLowerCase()) {
    case 'water':
      return Icons.water_drop_outlined;
    case 'internet':
      return Icons.wifi_rounded;
    case 'electricity':
      return Icons.bolt_rounded;
    case 'car loan':
      return Icons.directions_car_outlined;
    case 'home credit':
      return Icons.credit_card_outlined;
    case 'skyro':
      return Icons.credit_card_outlined;
    case 'netflix':
      return Icons.play_circle_outline_rounded;
    case 'phone':
      return Icons.phone_android_rounded;
    case 'gas':
      return Icons.local_gas_station_outlined;
    case 'insurance':
      return Icons.security_outlined;
    case 'rent':
      return Icons.home_outlined;
    case 'subscription':
      return Icons.subscriptions_outlined;
    case 'tuition':
      return Icons.school_outlined;
    case 'medical':
      return Icons.local_hospital_outlined;
    case 'transportation':
      return Icons.directions_bus_outlined;
    case 'dining':
      return Icons.restaurant_outlined;
    case 'shopping':
      return Icons.shopping_bag_outlined;
    case 'utilities':
      return Icons.electrical_services_outlined;
    default:
      return Icons.receipt_long_outlined;
  }
}

// ─── Spent Item model ─────────────────────────────────────────────────────────
class _SpentItem {
  final String label;
  final double amount;
  final IconData icon;
  _SpentItem({required this.label, required this.amount, required this.icon});
}

// ─── Analytics Page ───────────────────────────────────────────────────────────
class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});
  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  List<Bill>? _bills;
  List<FinanceTransaction> _transactions = [];
  final String _currency = SettingsService().currency;

  _Period _period = _Period.month;

  // Reorderable section list (draggable order)
  final List<_Section> _sectionOrder = [
    _Section.totalSpent,
    _Section.groceryCategory,
    _Section.billsBreakdown,
    _Section.history,
  ];

  // Collapsible state per section
  late final Map<_Section, bool> _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = {for (final s in _Section.values) s: true};
    _loadData();
  }

  Future<void> _loadData() async {
    final bills = await BillStorage.loadBills();
    final txns = await FinanceStorage.loadTransactions();
    if (!mounted) return;
    setState(() {
      _bills = bills;
      _transactions = txns;
    });
  }

  // ── Period helpers ────────────────────────────────────────────────────────
  bool _inRange(DateTime date) {
    final r = _period.range;
    // inclusive start, exclusive end
    return !date.isBefore(r.start) && date.isBefore(r.end);
  }

  List<FinanceTransaction> get _filteredTxns =>
      _transactions.where((t) => _inRange(t.date)).toList();

  List<GroceryList> get _filteredLists =>
      AppState.recentLists.where((l) => _inRange(l.date)).toList();

  List<Bill> get _filteredBills =>
      (_bills ?? []).where((b) => b.isPaid && _inRange(b.dueDate)).toList();

  // ── Stat totals (transactions only – no double counting) ──────────────────
  double get _totalIncome => _filteredTxns
      .where((t) => t.isIncome && !t.isTransfer)
      .fold(0.0, (s, t) => s + t.amount);

  double get _totalSpent {
    // To ensure exact match with the "Total Spent Breakdown",
    // we sum the merged items directly.
    return _buildMergedItems().fold(0.0, (s, item) => s + item.amount);
  }

  // ── Merged breakdown items ────────────────────────────────────────────────
  List<_SpentItem> _buildMergedItems() {
    final Map<String, double> cats = {};

    // 1. Add non-grocery expense transactions
    for (final t in _filteredTxns.where(
      (tx) => tx.isExpense && !tx.isTransfer && tx.category != 'Groceries',
    )) {
      final paidBillLabel = isPaidBillTransaction(t.category, t.description)
          ? (billLabelForExpense('${t.category} ${t.description}') ??
                cleanBillName(t.description))
          : null;
      final type =
          paidBillLabel ??
          (t.category.trim().isEmpty ? 'Other' : t.category.trim());
      cats[type] = (cats[type] ?? 0) + t.amount;
    }

    // 2. Add detailed grocery items from finished lists
    for (final list in _filteredLists) {
      for (final item in list.items) {
        final cat = item.category.trim().isEmpty
            ? 'General'
            : item.category.trim();
        cats[cat] =
            (cats[cat] ?? 0) + getItemTotal(item.price, item.qty, item.unit);
      }
    }

    final items = <_SpentItem>[];
    for (final e in cats.entries) {
      items.add(
        _SpentItem(label: e.key, amount: e.value, icon: _billIcon(e.key)),
      );
    }
    items.sort((a, b) => b.amount.compareTo(a.amount));
    return items;
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final filteredLists = _filteredLists;
    final filteredBills = _filteredBills;
    final mergedItems = _buildMergedItems();

    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: Icon(Icons.menu_rounded, color: kTextCharcoal, size: 28),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: Text(
          'Analytics',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      drawer: const AppDrawer(currentPage: 'Analytics'),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        children: [
          // ── Period Toggle ────────────────────────────────────────────────
          _PeriodToggle(
            selected: _period,
            onChanged: (p) => setState(() => _period = p),
          ),
          const SizedBox(height: 14),

          // ── Stat Cards ───────────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: 'INCOME',
                  value: '$_currency${_formatAnalyticsAmount(_totalIncome)}',
                  iconAsset: 'assets/images/income_logged.png',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatCard(
                  label: 'SPENT',
                  value: '$_currency${_formatAnalyticsAmount(_totalSpent)}',
                  iconAsset: 'assets/images/expense_logged.png',
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Reorderable Sections ─────────────────────────────────────────
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            padding: EdgeInsets.zero,
            proxyDecorator: (child, index, animation) => Material(
              elevation: 10,
              color: Colors.transparent,
              shadowColor: Colors.black26,
              borderRadius: BorderRadius.circular(20),
              child: child,
            ),
            onReorderItem: (oldIndex, newIndex) {
              setState(() {
                final item = _sectionOrder.removeAt(oldIndex);
                _sectionOrder.insert(newIndex, item);
              });
            },
            children: _sectionOrder.asMap().entries.map((entry) {
              final index = entry.key;
              final section = entry.value;
              return _buildSectionCard(
                key: ValueKey(section),
                section: section,
                index: index,
                filteredLists: filteredLists,
                filteredBills: filteredBills,
                mergedItems: mergedItems,
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required Key key,
    required _Section section,
    required int index,
    required List<GroceryList> filteredLists,
    required List<Bill> filteredBills,
    required List<_SpentItem> mergedItems,
  }) {
    final isExpanded = _expanded[section]!;

    Widget content;
    String subtitle;

    switch (section) {
      case _Section.totalSpent:
        final total = mergedItems.fold(0.0, (a, b) => a + b.amount);
        subtitle = '$_currency${_formatAnalyticsAmount(total)}';
        content = _TotalSpentContent(items: mergedItems, currency: _currency);
        break;

      case _Section.groceryCategory:
        final Map<String, double> catSpent = {};
        for (final l in filteredLists) {
          for (final i in l.items) {
            catSpent[i.category] =
                (catSpent[i.category] ?? 0) +
                getItemTotal(i.price, i.qty, i.unit);
          }
        }
        final total = catSpent.values.fold(0.0, (a, b) => a + b);
        subtitle = '$_currency${_formatAnalyticsAmount(total)}';
        content = _CategoryDonutContent(catSpent: catSpent);
        break;

      case _Section.billsBreakdown:
        final Map<String, double> billTotals = {};
        for (final b in filteredBills) {
          if (b.isIncome) continue;
          final t = billLabelForExpense(b.type) ?? cleanBillName(b.type).trim();
          if (t.isEmpty) continue;
          billTotals[t] = (billTotals[t] ?? 0) + b.amount;
        }
        for (final transaction in _filteredTxns.where(
          (tx) =>
              tx.isExpense &&
              !tx.isTransfer &&
              !isPaidBillTransaction(tx.category, tx.description),
        )) {
          final label = billLabelForExpense(
            '${transaction.category} ${transaction.description}',
          );
          if (label != null) {
            billTotals[label] = (billTotals[label] ?? 0) + transaction.amount;
          }
        }
        final total = billTotals.values.fold(0.0, (a, b) => a + b);
        subtitle = '$_currency${_formatAnalyticsAmount(total)}';
        content = _BillsContent(billTotals: billTotals);
        break;

      case _Section.history:
        subtitle =
            '${filteredLists.length} trip${filteredLists.length == 1 ? "" : "s"}';
        content = _HistoryContent(recentLists: filteredLists);
        break;
    }

    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [kShadowSoft],
        border: Border.all(color: kBorder.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          // ── Section Header ──────────────────────────────────────────────
          InkWell(
            onTap: () => setState(() => _expanded[section] = !isExpanded),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  // Drag handle
                  ReorderableDragStartListener(
                    index: index,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: Icon(
                        Icons.drag_indicator_rounded,
                        color: kMuted.withValues(alpha: 0.5),
                        size: 20,
                      ),
                    ),
                  ),
                  // Title + subtitle
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          section.title,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: kTextCharcoal,
                          ),
                        ),
                        Text(
                          subtitle,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: kMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Collapse chevron
                  AnimatedRotation(
                    turns: isExpanded ? 0 : -0.5,
                    duration: const Duration(milliseconds: 220),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 22,
                      color: kMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // ── Section Content (animated) ────────────────────────────────
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 280),
            crossFadeState: isExpanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Column(
              children: [
                Divider(height: 1, color: kBorder.withValues(alpha: 0.5)),
                Padding(padding: const EdgeInsets.all(16), child: content),
              ],
            ),
            secondChild: const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

// ─── Period Toggle ────────────────────────────────────────────────────────────
class _PeriodToggle extends StatelessWidget {
  final _Period selected;
  final ValueChanged<_Period> onChanged;
  const _PeriodToggle({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final itemWidth = totalWidth / _Period.values.length;
        final selectedIndex = _Period.values.indexOf(selected);

        return Container(
          height: 38,
          decoration: BoxDecoration(
            color: kCardBg.withValues(alpha: 0.6), // Glassy background base
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Stack(
                children: [
                  // Sliding highlight pill
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    left: selectedIndex * itemWidth,
                    top: 2,
                    bottom: 2,
                    width: itemWidth,
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: kPrimary,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: kPrimary.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Buttons
                  Row(
                    children: _Period.values.map((p) {
                      final sel = p == selected;
                      return Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => onChanged(p),
                          child: Center(
                            child: AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 300),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: sel
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                color: sel ? Colors.white : kMuted,
                              ),
                              child: Text(p.shortLabel),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
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

// ─── Stat Card ────────────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String label, value;
  final String iconAsset;
  const _StatCard({
    required this.label,
    required this.value,
    required this.iconAsset,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [kShadowSoft],
      ),
      child: Row(
        children: [
          Image.asset(iconAsset, width: 32, height: 32, fit: BoxFit.contain),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    color: kMuted.withValues(alpha: 0.7),
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  value,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: kTextCharcoal,
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

// ─── Total Spent Content (merged grocery + bills) ─────────────────────────────
class _TotalSpentContent extends StatelessWidget {
  final List<_SpentItem> items;
  final String currency;
  const _TotalSpentContent({required this.items, required this.currency});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return _emptyState('No spending data this period');
    }

    final grandTotal = items.fold(0.0, (a, b) => a + b.amount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Grand total row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Total',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: kMuted,
              ),
            ),
            Text(
              '$currency${_formatAnalyticsAmount(grandTotal)}',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: kTextCharcoal,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...items.asMap().entries.map((entry) {
          final i = entry.key;
          final item = entry.value;
          final color = _kPalette[i % _kPalette.length];
          final percent = grandTotal > 0 ? item.amount / grandTotal : 0.0;
          final pctLabel = '${(percent * 100).round()}%';

          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(item.icon, size: 13, color: color),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        item.label,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: kTextCharcoal,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '$currency${_formatAnalyticsAmount(item.amount)}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: kTextCharcoal,
                      ),
                    ),
                    const SizedBox(width: 6),
                    SizedBox(
                      width: 36,
                      child: Text(
                        pctLabel,
                        textAlign: TextAlign.end,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Stack(
                  children: [
                    Container(
                      height: 7,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: kMutedBg.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: percent.clamp(0.0, 1.0),
                      child: Container(
                        height: 7,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [color, color.withValues(alpha: 0.6)],
                          ),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: color.withValues(alpha: 0.2),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

// ─── Category Donut Content ───────────────────────────────────────────────────
class _CategoryDonutContent extends StatelessWidget {
  final Map<String, double> catSpent;
  const _CategoryDonutContent({required this.catSpent});

  @override
  Widget build(BuildContext context) {
    final sorted = catSpent.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = catSpent.values.fold(0.0, (a, b) => a + b);

    if (sorted.isEmpty) return _emptyState('No grocery data this period');

    return Row(
      children: [
        SizedBox(
          width: 130,
          height: 130,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  sectionsSpace: 3,
                  centerSpaceRadius: 44,
                  sections: List.generate(
                    sorted.length.clamp(0, 5),
                    (i) => PieChartSectionData(
                      color: _kPalette[i % _kPalette.length],
                      value: sorted[i].value,
                      title: '',
                      radius: 14,
                    ),
                  ),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '₱${_formatAnalyticsAmount(total)}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: kTextCharcoal,
                    ),
                  ),
                  Text(
                    'Total',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: kMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(sorted.length.clamp(0, 5), (i) {
              final color = _kPalette[i % _kPalette.length];
              final pct = total > 0
                  ? (sorted[i].value / total * 100).round()
                  : 0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        sorted[i].key,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: kTextCharcoal,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '$pct%',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '₱${_formatAnalyticsAmount(sorted[i].value)}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: kTextCharcoal,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

// ─── Bills Content ────────────────────────────────────────────────────────────
class _BillsContent extends StatelessWidget {
  final Map<String, double> billTotals;
  const _BillsContent({required this.billTotals});

  @override
  Widget build(BuildContext context) {
    final sorted = billTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = billTotals.values.fold(0.0, (a, b) => a + b);

    if (sorted.isEmpty) return _emptyState('No outgoing bills this period');

    return Column(
      children: [
        // Donut + legend
        Row(
          children: [
            SizedBox(
              width: 120,
              height: 120,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PieChart(
                    PieChartData(
                      sectionsSpace: 3,
                      centerSpaceRadius: 38,
                      sections: List.generate(
                        sorted.length.clamp(0, 6),
                        (i) => PieChartSectionData(
                          color: _kPalette[i % _kPalette.length],
                          value: sorted[i].value,
                          title: '',
                          radius: 14,
                        ),
                      ),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '₱${_formatAnalyticsAmount(total)}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: kTextCharcoal,
                        ),
                      ),
                      Text(
                        'Total',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: kMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: List.generate(sorted.length.clamp(0, 5), (i) {
                  final color = _kPalette[i % _kPalette.length];
                  final pct = total > 0
                      ? (sorted[i].value / total * 100).round()
                      : 0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Icon(_billIcon(sorted[i].key), size: 12, color: color),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            sorted[i].key,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: kTextCharcoal,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '$pct%',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Divider(height: 1, color: kBorder.withValues(alpha: 0.4)),
        const SizedBox(height: 16),
        // Horizontal bars
        Column(
          children: sorted.asMap().entries.map((entry) {
            final i = entry.key;
            final e = entry.value;
            final color = _kPalette[i % _kPalette.length];
            final percent = total > 0 ? e.value / total : 0.0;
            final pctLabel = '${(percent * 100).round()}%';
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Icon(_billIcon(e.key), size: 12, color: color),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          e.key,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: kTextCharcoal,
                          ),
                        ),
                      ),
                      Text(
                        '₱${_formatAnalyticsAmount(e.value)}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: kTextCharcoal,
                        ),
                      ),
                      const SizedBox(width: 6),
                      SizedBox(
                        width: 34,
                        child: Text(
                          pctLabel,
                          textAlign: TextAlign.end,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: color,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Stack(
                    children: [
                      Container(
                        height: 6,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: kMutedBg.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: percent.clamp(0.0, 1.0),
                        child: Container(
                          height: 6,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [color, color.withValues(alpha: 0.65)],
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ─── History Content ──────────────────────────────────────────────────────────
class _HistoryContent extends StatefulWidget {
  final List<GroceryList> recentLists;
  const _HistoryContent({required this.recentLists});
  @override
  State<_HistoryContent> createState() => _HistoryContentState();
}

class _HistoryContentState extends State<_HistoryContent> {
  int _visibleCount = 3;

  @override
  Widget build(BuildContext context) {
    if (widget.recentLists.isEmpty) return _emptyState('No trips this period');

    final displayed = widget.recentLists.take(_visibleCount).toList();
    final hasMore = widget.recentLists.length > _visibleCount;

    return Column(
      children: [
        // Header row
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Expanded(
                flex: 5,
                child: Text(
                  'LIST',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: kMuted,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              Text(
                'TOTAL',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: kMuted,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: kBorder.withValues(alpha: 0.4)),
        ...displayed.map((l) {
          final total = l.items.fold(
            0.0,
            (s, i) => s + getItemTotal(i.price, i.qty, i.unit),
          );
          return GestureDetector(
            onTap: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => _HistoryBreakdownSheet(list: l),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: kPrimary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.shopping_bag_outlined,
                      color: kPrimary,
                      size: 14,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.name,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: kTextCharcoal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          l.store.trim().isNotEmpty ? l.store : 'General Store',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: kMuted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₱${_formatAnalyticsAmount(total)}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: kTextCharcoal,
                        ),
                      ),
                      Text(
                        'Completed',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: kPrimary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
        if (hasMore) ...[
          const SizedBox(height: 4),
          Center(
            child: TextButton(
              onPressed: () => setState(() => _visibleCount += 3),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 10,
                ),
                backgroundColor: kMutedBg.withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                'Show More',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: kPrimary,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ─── Empty State Helper ───────────────────────────────────────────────────────
Widget _emptyState(String msg) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 16),
  child: Center(
    child: Text(
      msg,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: kMuted,
      ),
    ),
  ),
);

// ─── History Breakdown Sheet ──────────────────────────────────────────────────
class _HistoryBreakdownSheet extends StatelessWidget {
  final GroceryList list;
  const _HistoryBreakdownSheet({required this.list});

  @override
  Widget build(BuildContext context) {
    final Map<String, double> catTotals = {};
    final Map<String, int> catCounts = {};
    final Map<String, List<GroceryItem>> catItems = {};
    double totalSpend = 0.0;

    for (final i in list.items) {
      final t = getItemTotal(i.price, i.qty, i.unit);
      catTotals[i.category] = (catTotals[i.category] ?? 0) + t;
      catCounts[i.category] = (catCounts[i.category] ?? 0) + 1;
      catItems.putIfAbsent(i.category, () => []).add(i);
      totalSpend += t;
    }

    final sorted = catTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: kBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 12, 0),
            child: Row(
              children: [
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close_rounded, color: kMuted),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              children: [
                SizedBox(
                  height: 240,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        PieChartData(
                          sectionsSpace: 4,
                          centerSpaceRadius: 80,
                          sections: List.generate(
                            sorted.length,
                            (i) => PieChartSectionData(
                              color: _kPalette[i % _kPalette.length],
                              value: sorted[i].value,
                              title: '',
                              radius: 28,
                            ),
                          ),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '₱${_formatAnalyticsAmount(totalSpend)}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: kTextCharcoal,
                            ),
                          ),
                          Text(
                            'Total',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: kMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PriceComparisonPage(),
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: kCardBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: kBorder.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'See how all your trips compare',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: kTextCharcoal,
                                ),
                              ),
                              Text(
                                'View spending recap by category, item, and store',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                  color: kMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded, color: kMuted),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'What you bought',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: kTextCharcoal,
                  ),
                ),
                const SizedBox(height: 16),
                ...List.generate(sorted.length, (i) {
                  final e = sorted[i];
                  final color = _kPalette[i % _kPalette.length];
                  final percent = totalSpend > 0 ? e.value / totalSpend : 0.0;
                  final items = catItems[e.key] ?? [];
                  return _CategoryBreakdownItem(
                    category: e.key,
                    spent: e.value,
                    itemsCount: catCounts[e.key] ?? 0,
                    proportion: percent,
                    color: color,
                    items: items,
                  );
                }),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryBreakdownItem extends StatefulWidget {
  final String category;
  final double spent;
  final int itemsCount;
  final double proportion;
  final Color color;
  final List<GroceryItem> items;
  const _CategoryBreakdownItem({
    required this.category,
    required this.spent,
    required this.itemsCount,
    required this.proportion,
    required this.color,
    required this.items,
  });
  @override
  State<_CategoryBreakdownItem> createState() => _CategoryBreakdownItemState();
}

class _CategoryBreakdownItemState extends State<_CategoryBreakdownItem> {
  bool _isExpanded = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _isExpanded = !_isExpanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.category,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: kTextCharcoal,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${widget.itemsCount} item${widget.itemsCount == 1 ? "" : "s"}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: kMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₱${_formatAnalyticsAmount(widget.spent)}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: kTextCharcoal,
                      ),
                    ),
                    Text(
                      '${(widget.proportion * 100).round()}%',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: widget.color,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                AnimatedRotation(
                  turns: _isExpanded ? 0.25 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: kMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Stack(
              children: [
                Container(
                  height: 7,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: kMutedBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: widget.proportion.clamp(0.0, 1.0),
                  child: Container(
                    height: 7,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          widget.color,
                          widget.color.withValues(alpha: 0.7),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
            if (_isExpanded) ...[
              const SizedBox(height: 16),
              Divider(color: kBorder),
              const SizedBox(height: 8),
              ...widget.items.map(
                (item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: kMutedBg.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${item.qty == item.qty.truncateToDouble() ? item.qty.toInt() : item.qty} ${item.unit}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: kTextCharcoal,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          item.name,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: kTextCharcoal,
                          ),
                        ),
                      ),
                      Text(
                        '₱${_formatAnalyticsAmount(getItemTotal(item.price, item.qty, item.unit))}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: kTextCharcoal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
