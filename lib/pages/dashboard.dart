import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:gabay/models/bill_models.dart';
import 'package:gabay/models/grocery_models.dart';
import 'package:gabay/config/app_theme.dart';
import 'package:gabay/services/bill_storage.dart';
import 'package:gabay/widgets/app_drawer.dart';
import 'package:gabay/widgets/home/home_helpers.dart';

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
            icon: Icon(Icons.menu_rounded, color: kTextCharcoal),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: const Text('Dashboard'),
      ),
      drawer: const AppDrawer(currentPage: 'Dashboard'),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        children: [
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
    double quarterlySpend = totalSpend;

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'WEEKLY',
            value: '₱${weeklySpend.toStringAsFixed(0)}',
            icon: Icons.calendar_view_week,
            color: kPrimary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: 'MONTHLY',
            value: '₱${monthlySpend.toStringAsFixed(0)}',
            icon: Icons.calendar_month,
            color: const Color(0xFF6366F1),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: 'QUARTERLY',
            value: '₱${quarterlySpend.toStringAsFixed(0)}',
            icon: Icons.assessment,
            color: const Color(0xFFF59E0B),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [kShadowSoft],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: kMuted,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: kTextCharcoal,
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
  return SideTitleWidget(
    meta: meta,
    child: Text(
      value.toInt().toString(),
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: kMuted,
      ),
    ),
  );
}

Widget _leftTitle(double value, TitleMeta meta) {
  return SideTitleWidget(
    meta: meta,
    child: Text(
      value.toInt().toString(),
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: kMuted,
      ),
    ),
  );
}

class _TrendCard extends StatelessWidget {
  final List<GroceryList> recentLists;
  const _TrendCard({required this.recentLists});

  @override
  Widget build(BuildContext context) {
    final points = recentLists.reversed.toList();
    final spots = List.generate(points.length, (i) {
      final total = points[i].items.fold(
        0.0,
        (s, item) => s + getItemTotal(item.price, item.qty, item.unit),
      );
      return FlSpot(i.toDouble(), total);
    });
    final maxSpend = spots.fold(
      0.0,
      (max, spot) => spot.y > max ? spot.y : max,
    );
    final canPlotTrend = spots.length >= 2;

    return Container(
      height: 260,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [kShadowSoft],
      ),
      child: Stack(
        children: [
          LineChart(
            LineChartData(
              minX: 0,
              maxX: canPlotTrend ? (spots.length - 1).toDouble() : 4,
              minY: 0,
              maxY: canPlotTrend && maxSpend > 0 ? maxSpend * 1.2 : 100,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: canPlotTrend && maxSpend > 0
                    ? (maxSpend * 1.2) / 4
                    : 25,
                getDrawingHorizontalLine: (_) =>
                    FlLine(color: kBorder, strokeWidth: 1),
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 26,
                    interval: 1,
                    getTitlesWidget: _bottomTitle,
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 34,
                    interval: canPlotTrend && maxSpend > 0
                        ? (maxSpend * 1.2) / 4
                        : 25,
                    getTitlesWidget: _leftTitle,
                  ),
                ),
              ),
              borderData: FlBorderData(
                show: true,
                border: Border(
                  left: BorderSide(color: kBorder),
                  bottom: BorderSide(color: kBorder),
                ),
              ),
              lineBarsData: canPlotTrend
                  ? [
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        color: kPrimary,
                        barWidth: 4,
                        isStrokeCapRound: true,
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, barData, index) =>
                              FlDotCirclePainter(
                                radius: 4,
                                color: Colors.white,
                                strokeWidth: 3,
                                strokeColor: kPrimary,
                              ),
                        ),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            colors: [
                              kPrimary.withValues(alpha: 0.2),
                              kPrimary.withValues(alpha: 0),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ]
                  : [],
            ),
          ),
          if (!canPlotTrend) const _NoDataOverlay(),
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
        borderRadius: BorderRadius.circular(24),
        boxShadow: [kShadowSoft],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            height: 140,
            child: hasCategories
                ? PieChart(
                    PieChartData(
                      sectionsSpace: 4,
                      centerSpaceRadius: 40,
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [kShadowSoft],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            height: 140,
            child: hasBills
                ? PieChart(
                    PieChartData(
                      sectionsSpace: 4,
                      centerSpaceRadius: 40,
                      sections: List.generate(sorted.length.clamp(0, 6), (
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
                  )
                : DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: kBorder, width: 12),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.receipt_long_outlined,
                        size: 28,
                        color: kMuted.withValues(alpha: 0.35),
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: hasBills
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: List.generate(sorted.length.clamp(0, 6), (index) {
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
                              'â‚±${sorted[index].value.toStringAsFixed(0)}',
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

class _HistoryList extends StatelessWidget {
  final List<GroceryList> recentLists;
  const _HistoryList({required this.recentLists});

  @override
  Widget build(BuildContext context) {
    if (recentLists.isEmpty) {
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
        ...recentLists.map((l) {
          final total = l.items.fold(
            0.0,
            (s, i) => s + getItemTotal(i.price, i.qty, i.unit),
          );
          return GestureDetector(
            onTap: () {
              // Show Breakdown Modal
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.8,
                  ),
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).padding.bottom,
                  ),
                  decoration: BoxDecoration(
                    color: kCardBg,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Row(
                          children: [
                            Text(
                              l.name,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: kTextCharcoal,
                              ),
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
                      Flexible(
                        child: ListView.separated(
                          padding: const EdgeInsets.all(24),
                          itemCount: l.items.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, i) {
                            final item = l.items[i];
                            return Row(
                              children: [
                                Text(
                                  '${item.qty.toInt()} ${item.unit}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: kMuted,
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
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
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
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: kPrimary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.shopping_bag_outlined,
                      color: kPrimary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.name,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: kTextCharcoal,
                          ),
                        ),
                        Text(
                          '${l.items.length} items',
                          style: TextStyle(
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
                    children: [
                      Text(
                        '₱${total.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: kTextCharcoal,
                        ),
                      ),
                      Text(
                        'Completed',
                        style: TextStyle(
                          fontSize: 10,
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
          Expanded(flex: 3, child: Text('LIST', style: headerStyle)),
          Expanded(flex: 2, child: Text('ITEMS', style: headerStyle)),
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
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: kMuted,
        letterSpacing: 1.5,
      ),
    );
  }
}
