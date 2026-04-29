import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mobile_aismartwallet/pages/home.dart';
import 'package:mobile_aismartwallet/pages/ramsey.dart';
import 'package:mobile_aismartwallet/models/grocery_models.dart';
import 'package:mobile_aismartwallet/config/app_theme.dart';
import 'package:mobile_aismartwallet/widgets/app_drawer.dart';
import 'package:mobile_aismartwallet/services/grocery_storage.dart';

class RecentPage extends StatefulWidget {
  const RecentPage({super.key});

  @override
  State<RecentPage> createState() => _RecentPageState();
}

class _RecentPageState extends State<RecentPage> {
  void _showItemsSheet(BuildContext context, GroceryList recent) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${recent.name} Receipt',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: kTextCharcoal),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: kMuted),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            Divider(color: kBorder, height: 1),
            Flexible(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                itemCount: recent.items.length,
                shrinkWrap: true,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  final item = recent.items[i];
                  return Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: kMutedBg.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(6)),
                        child: Text(
                          '${item.qty == item.qty.truncateToDouble() ? item.qty.toInt() : item.qty} ${item.unit}', 
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kTextCharcoal)
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(item.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kTextCharcoal)),
                      ),
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
  }

  void _editRecentName(GroceryList recent) async {
    final ctrl = TextEditingController(text: recent.name);
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Rename History',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: 'List name',
            hintStyle: TextStyle(color: kMuted),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: kPrimary, width: 2),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: kMuted),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            style: TextButton.styleFrom(foregroundColor: kPrimary),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      setState(() => recent.name = result);
      GroceryStorage.saveAll();
    }
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
        title: const Text('Recent'),
        elevation: 0,
        backgroundColor: kBackground,
        foregroundColor: kTextCharcoal,
        centerTitle: false,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          color: kTextCharcoal,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      drawer: const AppDrawer(currentPage: 'Recent'),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'HISTORY',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: kMuted,
                letterSpacing: 2.0,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Recent Groceries',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: kTextCharcoal,
              ),
            ),
            const SizedBox(height: 24),

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
              ...AppState.recentLists.map((recent) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
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
                                    Icon(Icons.edit_outlined, size: 16, color: kMuted),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          IconButton(
                            onPressed: () => _showItemsSheet(context, recent),
                            icon: Icon(Icons.remove_red_eye_outlined, color: kTextCharcoal, size: 24),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 32),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${recent.items.length} items · ₱${recent.items.fold(0.0, (double s, i) => s + (i.price * i.qty)).toStringAsFixed(2)}',
                        style: TextStyle(
                          color: kMuted,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            // Clone it for Shopping
                            final clone = GroceryList('${recent.name} (Clone)');
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
                                builder: (_) => const HomePage(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.copy, size: 16),
                          label: const Text(
                            'Buy Again',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kPrimary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                              vertical: 0,
                              horizontal: 8,
                            ),
                            minimumSize: const Size(0, 48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
      floatingActionButton: const RamseyFab(),
    );
  }
}
