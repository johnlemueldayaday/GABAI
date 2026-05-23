import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:gabay/models/bill_models.dart';
import 'package:gabay/models/grocery_models.dart';
import 'package:gabay/pages/price_comparison.dart';
import 'package:gabay/config/app_theme.dart';
import 'package:gabay/services/bill_storage.dart';
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
  List<Bill>? _bills;

  @override
  void initState() {
    super.initState();
    _loadBills();
  }

  Future<void> _loadBills() async {
    final bills = await BillStorage.loadBills();
    if (!mounted) return;
    setState(() => _bills = bills);
  }

  @override
  Widget build(BuildContext context) {
    final recentLists = AppState.recentLists;
    final bills = _bills ?? [];

    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(Icons.menu_rounded, color: kTextCharcoal, size: 28),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Text(
          'Dashboard',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      drawer: const AppDrawer(currentPage: 'Dashboard'),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        children: [
          const _GreetingSection(),
          _buildSummaryGrid(recentLists),
          const SizedBox(height: 24),
          _SectionHeader(title: 'Spending Trend'),
          _TrendCard(recentLists: recentLists),
          const SizedBox(height: 24),
          _SectionHeader(title: 'Category Breakdown'),
          _CategoryDonutCard(recentLists: recentLists),
          const SizedBox(height: 24),
          _SectionHeader(title: 'Bills Breakdown'),
          _BillsPieCard(bills: bills),
          const SizedBox(height: 24),
          _SectionHeader(title: 'History Breakdown'),
          _HistoryList(recentLists: recentLists),
        ],
      ),
    );
  }

  Widget _buildSummaryGrid(List<GroceryList> lists) {
    double totalSpend = lists.fold(
      0.0,
      (s, l) =>
          s +
          l.items.fold(
            0.0,
            (si, i) => si + getItemTotal(i.price, i.qty, i.unit),
          ),
    );

    double weeklySpend = totalSpend;
    double monthlySpend = totalSpend;

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'WEEKLY',
            value: '₱${weeklySpend.toStringAsFixed(0)}',
            icon: Icons.view_week_rounded,
            color: const Color(0xFF10B981),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            label: 'MONTHLY',
            value: '₱${monthlySpend.toStringAsFixed(0)}',
            icon: Icons.calendar_today_rounded,
            color: const Color(0xFF6366F1),
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
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

class _NoDataOverlay extends StatelessWidget {
  const _NoDataOverlay();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: kCardBg.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: kBorder),
        ),
        child: Text(
          'No data available',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: kMuted,
          ),
        ),
      ),
    );
  }
}

Widget _bottomTitle(double value, TitleMeta meta) {
  const days = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
  final index = value.toInt();
  if (index < 0 || index >= 7) return const SizedBox();

  final isToday = index == DateTime.now().weekday % 7;

  return SideTitleWidget(
    meta: meta,
    space: 8,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          days[index],
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: isToday ? FontWeight.w900 : FontWeight.w700,
            color: isToday ? kPrimary : kMuted.withValues(alpha: 0.8),
          ),
        ),
        if (isToday)
          Container(
            margin: const EdgeInsets.only(top: 4),
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: kPrimary,
              shape: BoxShape.circle,
            ),
          ),
      ],
    ),
  );
}

Widget _leftTitle(double value, TitleMeta meta) {
  if (value == meta.max || value == meta.min) return const SizedBox();
  return SideTitleWidget(
    meta: meta,
    space: 8,
    child: Text(
      '₱${value.toInt()}',
      style: GoogleFonts.plusJakartaSans(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: kMuted.withValues(alpha: 0.6),
      ),
    ),
  );
}

class _TrendCard extends StatefulWidget {
  final List<GroceryList> recentLists;
  const _TrendCard({required this.recentLists});

  @override
  State<_TrendCard> createState() => _TrendCardState();
}

class _TrendCardState extends State<_TrendCard> {
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final sunday = now.subtract(Duration(days: now.weekday % 7));
    final startOfWeek = DateTime(sunday.year, sunday.month, sunday.day);

    final weeklyData = List.generate(7, (index) => 0.0);

    for (final list in widget.recentLists) {
      final difference = list.date.difference(startOfWeek).inDays;
      if (difference >= 0 && difference < 7) {
        final total = list.items.fold(
          0.0,
          (sum, item) => sum + getItemTotal(item.price, item.qty, item.unit),
        );
        weeklyData[difference] += total;
      }
    }

    final maxSpend = weeklyData.fold(0.0, (max, val) => val > max ? val : max);
    final chartMax = maxSpend > 0 ? maxSpend * 1.3 : 500.0;
    final hasData = weeklyData.any((v) => v > 0);

    return Container(
      height: 280,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.fromLTRB(12, 24, 24, 12),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          BarChart(
            BarChartData(
              maxY: chartMax,
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => kTextCharcoal,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    return BarTooltipItem(
                      '₱${rod.toY.toStringAsFixed(0)}',
                      GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    );
                  },
                ),
                touchCallback: (event, response) {
                  if (response == null || response.spot == null) {
                    setState(() => _touchedIndex = -1);
                    return;
                  }
                  setState(
                    () => _touchedIndex = response.spot!.touchedBarGroupIndex,
                  );
                },
              ),
              titlesData: FlTitlesData(
                show: true,
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: _bottomTitle,
                    reservedSize: 32,
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 50,
                    interval: chartMax / 4,
                    getTitlesWidget: _leftTitle,
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: chartMax / 4,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: kBorder.withValues(alpha: 0.3),
                  strokeWidth: 1,
                  dashArray: [5, 5],
                ),
              ),
              barGroups: List.generate(7, (i) {
                final isTouched = _touchedIndex == i;
                final isToday = i == now.weekday % 7;
                return BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: weeklyData[i],
                      gradient: LinearGradient(
                        colors: [
                          isToday ? kPrimary : kPrimary.withValues(alpha: 0.8),
                          isToday 
                              ? kPrimary.withValues(alpha: isTouched ? 0.9 : 0.7) 
                              : kPrimary.withValues(alpha: 0.6),
                        ],
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                      ),
                      width: 20,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(6),
                      ),
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
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOutCubic,
          ),
          if (!hasData) const _NoDataOverlay(),
        ],
      ),
    );
  }
}

class _CategoryDonutCard extends StatelessWidget {
  final List<GroceryList> recentLists;
  const _CategoryDonutCard({required this.recentLists});

  @override
  Widget build(BuildContext context) {
    Map<String, double> catSpent = {};
    for (var l in recentLists) {
      for (var i in l.items) {
        catSpent[i.category] =
            (catSpent[i.category] ?? 0) + getItemTotal(i.price, i.qty, i.unit);
      }
    }

    final sorted = catSpent.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final hasCategories = sorted.isNotEmpty;
    final colors = [
      kPrimary,
      const Color(0xFF6366F1),
      const Color(0xFFF59E0B),
      const Color(0xFFEC4899),
      const Color(0xFF06B6D4),
    ];

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [kShadowSoft],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            height: 140,
            child: hasCategories
                ? Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        PieChartData(
                          sectionsSpace: 4,
                          centerSpaceRadius: 46,
                          sections: List.generate(sorted.length.clamp(0, 5), (
                            index,
                          ) {
                            return PieChartSectionData(
                              color: colors[index % colors.length],
                              value: sorted[index].value,
                              title: '',
                              radius: 12,
                            );
                          }),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '₱${catSpent.values.fold(0.0, (a, b) => a + b).toStringAsFixed(0)}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: kTextCharcoal,
                            ),
                          ),
                          Text(
                            'Total',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: kMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
                : DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: kBorder, width: 12),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.donut_large_rounded,
                        size: 28,
                        color: kMuted.withValues(alpha: 0.35),
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: hasCategories
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: List.generate(sorted.length.clamp(0, 5), (index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: colors[index % colors.length],
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                sorted[index].key,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: kTextCharcoal,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '₱${sorted[index].value.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: kTextCharcoal,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  )
                : Text(
                    'No data available',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: kMuted,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _BillsPieCard extends StatelessWidget {
  final List<Bill> bills;
  const _BillsPieCard({required this.bills});

  @override
  Widget build(BuildContext context) {
    final billTotals = <String, double>{};
    for (final bill in bills) {
      final type = bill.type.trim().isEmpty ? 'Other' : bill.type.trim();
      billTotals[type] = (billTotals[type] ?? 0) + bill.amount;
    }

    final sorted = billTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final hasBills = sorted.isNotEmpty;
    final total = billTotals.values.fold(0.0, (a, b) => a + b);

    final colors = [
      const Color(0xFF14B8A6),
      const Color(0xFF6366F1),
      const Color(0xFFF59E0B),
      const Color(0xFFEC4899),
      const Color(0xFF06B6D4),
      const Color(0xFF84CC16),
    ];

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(color: kBorder.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Pie Chart Visualization
          if (hasBills)
            Row(
              children: [
                SizedBox(
                  width: 130,
                  height: 130,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        PieChartData(
                          sectionsSpace: 4,
                          centerSpaceRadius: 42,
                          sections: List.generate(sorted.length.clamp(0, 6), (index) {
                            return PieChartSectionData(
                              color: colors[index % colors.length],
                              value: sorted[index].value,
                              title: '',
                              radius: 12,
                            );
                          }),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '₱${total.toStringAsFixed(0)}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15,
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
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: List.generate(sorted.length.clamp(0, 5), (index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: colors[index % colors.length],
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                sorted[index].key,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: kTextCharcoal,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
                ),
              ],
            )
          else
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  'No bills added yet',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: kMuted,
                  ),
                ),
              ),
            ),

          if (hasBills) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Divider(height: 1),
            ),
            // Row 2: Horizontal Bar Graph Breakdown
            Column(
              children: List.generate(sorted.length, (index) {
                final entry = sorted[index];
                final percent = total > 0 ? entry.value / total : 0.0;
                final color = colors[index % colors.length];

                return Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            entry.key,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: kTextCharcoal,
                            ),
                          ),
                          Text(
                            '₱${entry.value.toStringAsFixed(0)}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: kTextCharcoal,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Stack(
                        children: [
                          Container(
                            height: 7,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: kMutedBg.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          FractionallySizedBox(
                            widthFactor: percent,
                            child: Container(
                              height: 7,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [color, color.withValues(alpha: 0.7)],
                                ),
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: color.withValues(alpha: 0.15),
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
            ),
          ],
        ],
      ),
    );
  }
}

class _HistoryList extends StatefulWidget {
  final List<GroceryList> recentLists;
  const _HistoryList({required this.recentLists});

  @override
  State<_HistoryList> createState() => _HistoryListState();
}

class _HistoryListState extends State<_HistoryList> {
  int _visibleCount = 3;

  @override
  Widget build(BuildContext context) {
    if (widget.recentLists.isEmpty) {
      return Container(
        margin: const EdgeInsets.only(top: 12),
        decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [kShadowSoft],
        ),
        child: Column(
          children: [
            const _HistoryHeaderRow(),
            Divider(color: kBorder, height: 1),
            SizedBox(
              height: 88,
              child: Center(
                child: Text(
                  'No data available',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: kMuted,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final displayedLists = widget.recentLists.take(_visibleCount).toList();
    final hasMore = widget.recentLists.length > _visibleCount;

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.only(top: 12),
          decoration: BoxDecoration(
            color: kCardBg,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [kShadowSoft],
          ),
          child: const _HistoryHeaderRow(),
        ),
        ...displayedLists.map((l) {
          final total = l.items.fold(
            0.0,
            (s, i) => s + getItemTotal(i.price, i.qty, i.unit),
          );
          return GestureDetector(
            onTap: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => _HistoryBreakdownSheet(list: l),
              );
            },
            child: Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: kCardBg,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [kShadowSoft],
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: kPrimary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.shopping_bag_outlined,
                            color: kPrimary,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l.name,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: kTextCharcoal,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 1),
                              Text(
                                l.store.trim().isNotEmpty ? l.store : 'General Store',
                                style: TextStyle(
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
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '₱${total.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: kTextCharcoal,
                          ),
                        ),
                        Text(
                          'Completed',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: kPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
        if (hasMore)
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 8),
            child: Center(
              child: TextButton(
                onPressed: () {
                  setState(() => _visibleCount += 3);
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 12,
                  ),
                  backgroundColor: kCardBg,
                  elevation: 2,
                  shadowColor: Colors.black.withValues(alpha: 0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: kBorder.withValues(alpha: 0.5)),
                  ),
                ),
                child: Text(
                  'Show Previous',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: kPrimary,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _HistoryHeaderRow extends StatelessWidget {
  const _HistoryHeaderRow();

  @override
  Widget build(BuildContext context) {
    TextStyle headerStyle = TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w800,
      color: kMuted,
      letterSpacing: 0.6,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(flex: 5, child: Text('LIST', style: headerStyle)),
          Expanded(
            flex: 2,
            child: Text('TOTAL', textAlign: TextAlign.end, style: headerStyle),
          ),
        ],
      ),
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
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    margin: const EdgeInsets.only(left: 10, top: 0, right: 0),
                  child: _isLoading
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(kPrimary),
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

class _HistoryBreakdownSheet extends StatelessWidget {
  final GroceryList list;
  const _HistoryBreakdownSheet({required this.list});

  @override
  Widget build(BuildContext context) {
    // 1. Group by category
    final Map<String, double> catTotals = {};
    final Map<String, int> catCounts = {};
    final Map<String, List<GroceryItem>> catItems = {};
    double totalSpend = 0.0;

    for (var i in list.items) {
      final t = getItemTotal(i.price, i.qty, i.unit);
      catTotals[i.category] = (catTotals[i.category] ?? 0) + t;
      catCounts[i.category] = (catCounts[i.category] ?? 0) + 1;
      catItems.putIfAbsent(i.category, () => []).add(i);
      totalSpend += t;
    }

    final sorted = catTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final colors = [
      const Color(0xFF3B82F6), // Blue
      const Color(0xFFEF4444), // Red
      const Color(0xFF10B981), // Emerald
      const Color(0xFFF59E0B), // Amber
      const Color(0xFF8B5CF6), // Violet
      const Color(0xFFEC4899), // Pink
    ];

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
          // Header with Close Button
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
              physics: const BouncingScrollPhysics(),
              children: [
                // 2. Large Donut Chart
                SizedBox(
                  height: 240,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        PieChartData(
                          sectionsSpace: 4,
                          centerSpaceRadius: 80,
                          sections: List.generate(sorted.length, (index) {
                            return PieChartSectionData(
                              color: colors[index % colors.length],
                              value: sorted[index].value,
                              title: '',
                              radius: 28,
                            );
                          }),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '₱${totalSpend.toStringAsFixed(0)}',
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

                // 3. Comparison Callout
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const PriceComparisonPage()),
                    );
                  },
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

                // 4. "What you bought" Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'What you bought',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: kTextCharcoal,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: kCardBg,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: kBorder),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.filter_list_rounded,
                            size: 14,
                            color: kTextCharcoal,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Highest Spent',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: kTextCharcoal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // 5. Category List Items
                ...List.generate(sorted.length, (index) {
                  final entry = sorted[index];
                  final color = colors[index % colors.length];
                  final percent = totalSpend > 0 ? entry.value / totalSpend : 0.0;
                  final items = catItems[entry.key] ?? [];

                  return _CategoryBreakdownItem(
                    category: entry.key,
                    spent: entry.value,
                    itemsCount: catCounts[entry.key] ?? 0,
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
        curve: Curves.easeOut,
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
                        '${widget.itemsCount} item${widget.itemsCount == 1 ? '' : 's'}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: kMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '₱${widget.spent.toStringAsFixed(2)}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: kTextCharcoal,
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedRotation(
                  turns: _isExpanded ? 0.25 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(Icons.chevron_right_rounded, size: 20, color: kMuted),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: widget.proportion,
                minHeight: 8,
                backgroundColor: kMutedBg,
                valueColor: AlwaysStoppedAnimation<Color>(widget.color),
              ),
            ),
            if (_isExpanded) ...[
              const SizedBox(height: 16),
              Divider(color: kBorder),
              const SizedBox(height: 8),
              ...widget.items.map((item) {
                return Padding(
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
                        '₱${getItemTotal(item.price, item.qty, item.unit).toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: kTextCharcoal,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}
