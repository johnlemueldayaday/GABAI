import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';

import 'package:gabay/pages/cart.dart' show CartDetailPage;
import 'package:gabay/models/grocery_models.dart';
import 'package:gabay/pages/price_comparison.dart';
import 'package:gabay/config/app_theme.dart';
import 'package:gabay/navigation/app_routes.dart';
import 'package:gabay/widgets/app_drawer.dart';
import 'package:gabay/services/grocery_storage.dart';
import 'package:gabay/widgets/home/home_helpers.dart';

class RecentPage extends StatefulWidget {
  const RecentPage({super.key});

  @override
  State<RecentPage> createState() => _RecentPageState();
}

class _RecentPageState extends State<RecentPage> {
  void _showItemsSheet(BuildContext context, GroceryList recent) {
    // 1. Group items by category
    final categoryTotals = <String, double>{};
    final categoryCounts = <String, int>{};
    final categoryItems = <String, List<GroceryItem>>{};
    double totalSpent = 0.0;

    for (final item in recent.items) {
      final itemTotal = getItemTotal(item.price, item.qty, item.unit);
      categoryTotals[item.category] = (categoryTotals[item.category] ?? 0) + itemTotal;
      categoryCounts[item.category] = (categoryCounts[item.category] ?? 0) + 1;
      categoryItems.putIfAbsent(item.category, () => []).add(item);
      totalSpent += itemTotal;
    }

    final sortedCategories = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final colors = [
      kPrimary, // green
      const Color(0xFFF59E0B), // orange/yellow
      const Color(0xFF6366F1), // purple/blue
      const Color(0xFFEC4899), // pink
      const Color(0xFF06B6D4), // cyan
      const Color(0xFFEF4444), // red
    ];

    final categoryColorMap = <String, Color>{};
    for (int i = 0; i < sortedCategories.length; i++) {
      categoryColorMap[sortedCategories[i].key] = colors[i % colors.length];
    }

    double maxItemSpent = 0.0;
    for (final item in recent.items) {
      final t = getItemTotal(item.price, item.qty, item.unit);
      if (t > maxItemSpent) maxItemSpent = t;
    }

    bool highestFirst = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          final items = [...recent.items];
          items.sort((a, b) {
            final ta = getItemTotal(a.price, a.qty, a.unit);
            final tb = getItemTotal(b.price, b.qty, b.unit);
            return highestFirst ? tb.compareTo(ta) : ta.compareTo(tb);
          });

          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.9,
            ),
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
            decoration: BoxDecoration(
              color: kCardBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Close Button
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 16, right: 16),
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close, color: kMuted),
                    ),
                  ),
                ),
                
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Donut Chart
                        SizedBox(
                          height: 240,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              PieChart(
                                PieChartData(
                                  sectionsSpace: 4,
                                  centerSpaceRadius: 80,
                                  startDegreeOffset: -90,
                                  sections: sortedCategories.isEmpty 
                                    ? [PieChartSectionData(color: kMutedBg, value: 1, title: '', radius: 24)]
                                    : List.generate(sortedCategories.length, (index) {
                                      return PieChartSectionData(
                                        color: colors[index % colors.length],
                                        value: sortedCategories[index].value,
                                        title: '',
                                        radius: 24,
                                      );
                                    }),
                                ),
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '₱${totalSpent.toStringAsFixed(0)}',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 32,
                                      fontWeight: FontWeight.w900,
                                      color: kTextCharcoal,
                                      letterSpacing: -1,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Spent Total',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: kMuted,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    recent.store.isEmpty ? 'General Store' : recent.store,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: kPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Banner
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const PriceComparisonPage()),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: kCardBg,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.02),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
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
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: kTextCharcoal,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'View spending recap by category, item, and store',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: const Color(0xFF6B7280),
                                          height: 1.4,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Icon(Icons.chevron_right_rounded, color: Color(0xFF9CA3AF)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),

                        // "What you bought" Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'What you bought',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: kTextCharcoal,
                              ),
                            ),
                            GestureDetector(
                              onTap: () => setSheetState(() => highestFirst = !highestFirst),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: kCardBg,
                                  borderRadius: BorderRadius.circular(100),
                                  border: Border.all(color: kBorder),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      highestFirst ? Icons.south_rounded : Icons.north_rounded,
                                      size: 14,
                                      color: kMuted,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      highestFirst ? 'Highest Spent' : 'Lowest Spent',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: kMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Items List
                        ...items.map((item) {
                          final itemTotal = getItemTotal(item.price, item.qty, item.unit);
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: kCardBg,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: kBorder.withValues(alpha: 0.5)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.name,
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                              color: kTextCharcoal,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${formatQty(item.qty)} ${item.unit} @ ₱${item.price.toStringAsFixed(2)}',
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
                                      '₱${itemTotal.toStringAsFixed(2)}',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: kTextCharcoal,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                // Category color bar
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(2),
                                  child: LinearProgressIndicator(
                                    value: maxItemSpent > 0 ? (itemTotal / maxItemSpent).clamp(0.05, 1.0) : 0.0,
                                    backgroundColor: kMuted.withValues(alpha: 0.1),
                                    color: categoryColorMap[item.category] ?? kMuted.withValues(alpha: 0.2),
                                    minHeight: 3,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
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

  void _editRecentName(GroceryList recent) async {
    final ctrl = TextEditingController(text: recent.name);
    ctrl.selection = TextSelection(baseOffset: 0, extentOffset: ctrl.text.length);
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: kCardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Rename History', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: 'List name',
            hintStyle: TextStyle(color: kMuted),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: kPrimary, width: 2)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: TextStyle(color: kMuted))),
          TextButton(onPressed: () => Navigator.pop(context, ctrl.text.trim()), child: Text('Save', style: TextStyle(color: kPrimary))),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      setState(() => recent.name = result);
      GroceryStorage.saveAll();
    }
  }

  void _deleteRecent(int index) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: kCardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete History?', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: Colors.red)),
        content: Text('This will permanently delete this shopping trip from your history.', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w500)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: TextStyle(color: kMuted))),
          TextButton(
            onPressed: () {
              setState(() {
                AppState.recentLists.removeAt(index);
                GroceryStorage.saveAll();
              });
              Navigator.pop(context);
            },
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(Icons.menu_rounded, color: kTextCharcoal),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: const Text('Recent Groceries'),
        elevation: 0,
        backgroundColor: kBackground,
        foregroundColor: kTextCharcoal,
        centerTitle: false,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          color: kTextCharcoal,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      drawer: const AppDrawer(currentPage: 'Recent'),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),

            if (AppState.recentLists.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Text(
                    'No recent groceries yet.',
                    style: TextStyle(
                      color: kMuted,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: AppState.recentLists.length,
                itemBuilder: (context, index) {
                  final recent = AppState.recentLists[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: kCardBg,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [kShadowSoft],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _editRecentName(recent),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: kMutedBg.withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        recent.name,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                          color: kTextCharcoal,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Icon(
                                      Icons.edit_outlined,
                                      size: 16,
                                      color: kMuted,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: () => _showItemsSheet(context, recent),
                            icon: Icon(
                              Icons.remove_red_eye_outlined,
                              color: kMuted,
                              size: 22,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 32),
                          ),
                          PopupMenuButton<String>(
                            icon: Icon(Icons.more_vert_rounded, color: kMuted, size: 22),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            onSelected: (value) {
                              if (value == 'delete') {
                                _deleteRecent(index);
                              } else if (value == 'rename') {
                                _editRecentName(recent);
                              }
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'rename',
                                child: Text('Rename', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600)),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.red)),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${recent.items.length} items · ₱${recent.items.fold(0.0, (double s, i) => s + getItemTotal(i.price, i.qty, i.unit)).toStringAsFixed(2)}',
                                  style: TextStyle(
                                    color: kMuted,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  recent.store.isEmpty ? 'General Store' : recent.store,
                                  style: TextStyle(
                                    color: kPrimary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: () {
                              // Clone it for Shopping
                              final clone = GroceryList(recent.name);
                              clone.store = recent.store;
                              clone.budget = recent.budget;
                              clone.items = recent.items
                                  .map(
                                    (i) => GroceryItem(
                                      id: '${i.id}-clone-${DateTime.now().millisecondsSinceEpoch}',
                                      name: i.name,
                                      qty: i.qty,
                                      unit: i.unit,
                                      price: i.price,
                                      isDone: false, // Reset completion status
                                      category: i.category,
                                    ),
                                  )
                                  .toList();

                              // Load clone into Shopping session
                              AppState.lists.clear();
                              AppState.lists.add(clone);
                              AppState.activeIndex = 0;
                              GroceryStorage.saveAll();

                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  settings: const RouteSettings(
                                    name: kCartDetailRouteName,
                                  ),
                                  builder: (_) => const CartDetailPage(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.copy, size: 14),
                            label: const Text(
                              'Buy Again',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kPrimary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              minimumSize: Size.zero,
                              padding: const EdgeInsets.symmetric(
                                vertical: 6,
                                horizontal: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
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
        ),
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
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
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
                      '${widget.itemsCount} items',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Text(
                      '₱${widget.spent.toStringAsFixed(2)}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: kTextCharcoal,
                      ),
                    ),
                    const SizedBox(width: 4),
                    AnimatedRotation(
                      turns: _isExpanded ? 0.25 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: const Icon(Icons.chevron_right_rounded, color: Color(0xFF9CA3AF), size: 20),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Stack(
              children: [
                Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: widget.proportion,
                  child: Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: widget.color,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ],
            ),
            if (_isExpanded) ...[
              const SizedBox(height: 16),
              const Divider(color: Color(0xFFE5E7EB)),
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
