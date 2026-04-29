import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:gabay/pages/ramsey.dart';
import 'package:gabay/models/grocery_models.dart';
import 'package:gabay/config/app_theme.dart';
import 'package:gabay/widgets/app_drawer.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  @override
  Widget build(BuildContext context) {
    final recentLists = AppState.recentLists;
    bool hasData = recentLists.isNotEmpty;

    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(Icons.menu_rounded, color: kTextCharcoal),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: const Text('Insights'),
      ),
      drawer: const AppDrawer(currentPage: 'Insights'),
      body: hasData
          ? ListView(
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
                _SectionHeader(title: 'Budget vs Actual'),
                _BudgetComparisonCard(recentLists: recentLists),
                const SizedBox(height: 24),
                _SectionHeader(title: 'History Breakdown'),
                _HistoryList(recentLists: recentLists),
              ],
            )
          : _EmptyState(),
      floatingActionButton: const RamseyFab(),
    );
  }

  Widget _buildSummaryGrid(List<GroceryList> lists) {
    double totalSpend = lists.fold(0.0, (s, l) => s + l.items.fold(0.0, (si, i) => si + (i.price * i.qty)));
    
    // Grouping by time (Mock for demo since we only have now(), but structured correctly)
    double weeklySpend = totalSpend; // Filter by date logic would go here
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
  const _StatCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [kShadowSoft],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(height: 12),
          Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: kMuted, letterSpacing: 0.5)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: kTextCharcoal)),
        ],
      ),
    );
  }
}

class _TrendCard extends StatelessWidget {
  final List<GroceryList> recentLists;
  const _TrendCard({required this.recentLists});

  @override
  Widget build(BuildContext context) {
    // Reverse so chronologically L to R
    final points = recentLists.reversed.toList();

    return Container(
      height: 260,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [kShadowSoft]),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: false),
          titlesData: FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: List.generate(points.length, (i) {
                final total = points[i].items.fold(0.0, (s, item) => s + (item.price * item.qty));
                return FlSpot(i.toDouble(), total);
              }),
              isCurved: true,
              color: kPrimary,
              barWidth: 4,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                  radius: 4,
                  color: Colors.white,
                  strokeWidth: 3,
                  strokeColor: kPrimary,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [kPrimary.withValues(alpha: 0.2), kPrimary.withValues(alpha: 0)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
        ),
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
        catSpent[i.category] = (catSpent[i.category] ?? 0) + (i.price * i.qty);
      }
    }

    final sorted = catSpent.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final colors = [kPrimary, const Color(0xFF6366F1), const Color(0xFFF59E0B), const Color(0xFFEC4899), const Color(0xFF06B6D4)];

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [kShadowSoft]),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            height: 140,
            child: PieChart(
              PieChartData(
                sectionsSpace: 4,
                centerSpaceRadius: 40,
                sections: List.generate(sorted.length.clamp(0, 5), (index) {
                  return PieChartSectionData(
                    color: colors[index % colors.length],
                    value: sorted[index].value,
                    title: '',
                    radius: 12,
                  );
                }),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(sorted.length.clamp(0, 5), (index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(width: 8, height: 8, decoration: BoxDecoration(color: colors[index % colors.length], shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          sorted[index].key,
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kTextCharcoal),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '₱${sorted[index].value.toStringAsFixed(0)}',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kTextCharcoal),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _BudgetComparisonCard extends StatelessWidget {
  final List<GroceryList> recentLists;
  const _BudgetComparisonCard({required this.recentLists});

  @override
  Widget build(BuildContext context) {
    final displayLists = recentLists.take(5).toList().reversed.toList();

    return Container(
      height: 220,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [kShadowSoft]),
      child: BarChart(
        BarChartData(
          gridData: FlGridData(show: false),
          titlesData: FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(displayLists.length, (i) {
            final budget = displayLists[i].budget;
            final actual = displayLists[i].items.fold(0.0, (s, item) => s + (item.price * item.qty));
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(toY: budget, color: kMuted.withValues(alpha: 0.2), width: 12, borderRadius: BorderRadius.circular(6)),
                BarChartRodData(toY: actual, color: actual > budget ? Colors.red.withValues(alpha: 0.8) : kPrimary, width: 12, borderRadius: BorderRadius.circular(6)),
              ],
            );
          }),
        ),
      ),
    );
  }
}

class _HistoryList extends StatelessWidget {
  final List<GroceryList> recentLists;
  const _HistoryList({required this.recentLists});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: recentLists.map((l) {
        final total = l.items.fold(0.0, (s, i) => s + (i.price * i.qty));
        return GestureDetector(
          onTap: () {
             // Show Breakdown Modal
             showModalBottomSheet(
               context: context,
               isScrollControlled: true,
               backgroundColor: Colors.transparent,
               builder: (_) => Container(
                 constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
                 padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
                 decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
                 child: Column(
                   mainAxisSize: MainAxisSize.min,
                   children: [
                     Padding(
                       padding: const EdgeInsets.all(24),
                       child: Row(
                         children: [
                           Text(l.name, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: kTextCharcoal)),
                           const Spacer(),
                           IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.close, color: kMuted)),
                         ],
                       ),
                     ),
                     Divider(color: kBorder, height: 1),
                     Flexible(
                       child: ListView.separated(
                         padding: const EdgeInsets.all(24),
                         itemCount: l.items.length,
                         separatorBuilder: (_, _) => const SizedBox(height: 12),
                         itemBuilder: (context, i) {
                           final item = l.items[i];
                           return Row(
                             children: [
                               Text('${item.qty.toInt()} ${item.unit}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kMuted)),
                               const SizedBox(width: 12),
                               Expanded(child: Text(item.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kTextCharcoal))),
                               Text('₱${(item.price * item.qty).toStringAsFixed(2)}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kTextCharcoal)),
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
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [kShadowSoft]),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: kPrimary.withValues(alpha: 0.1), shape: BoxShape.circle),
                  child: Icon(Icons.shopping_bag_outlined, color: kPrimary, size: 20),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: kTextCharcoal)),
                      Text('${l.items.length} items', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: kMuted)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('₱${total.toStringAsFixed(2)}', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: kTextCharcoal)),
                    Text('Completed', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: kPrimary)),
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
    return Text(
      title.toUpperCase(),
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kMuted, letterSpacing: 1.5),
    );
  }
}

// _AppDrawer removed as it is now shared in lib/widgets/app_drawer.dart

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.insights_rounded, size: 64, color: kMuted.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text('No Insights Yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: kTextCharcoal)),
          const SizedBox(height: 8),
          Text('Finish a shopping list to see your analytics.', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: kMuted)),
        ],
      ),
    );
  }
}
