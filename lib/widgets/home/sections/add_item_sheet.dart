import 'package:flutter/material.dart';
import 'package:gabay/config/app_theme.dart';
import 'package:gabay/models/grocery_models.dart';
import 'package:gabay/data/grocery_database.dart';
import 'package:gabay/services/price_storage.dart';
import 'package:gabay/widgets/home/sections/add_item_category_tabs.dart';
import 'package:gabay/widgets/home/sections/sheet_handle.dart';
import 'package:gabay/widgets/home/sections/spring_curve.dart';
import 'package:google_fonts/google_fonts.dart';

/// Multi-select Add Item sheet.
/// Users tap chips to toggle selection (green = selected).
/// "Done" button confirms batch addition. Price/qty editing is deferred.
class AddItemSheet extends StatefulWidget {
  final void Function(List<GroceryItem>) onAddBatch;
  final void Function(Map<String, dynamic>) onSaveCustom;
  final List<Map<String, dynamic>> customItems;
  final List<String> recentItemNames;
  final String storeName;

  const AddItemSheet({
    super.key,
    required this.onAddBatch,
    required this.onSaveCustom,
    required this.customItems,
    required this.recentItemNames,
    this.storeName = '',
  });

  @override
  State<AddItemSheet> createState() => _AddItemSheetState();
}

class _AddItemSheetState extends State<AddItemSheet>
    with TickerProviderStateMixin {
  final _searchCtrl = TextEditingController();
  String _selectedCategory = 'All';

  /// Set of selected item names (lowercase for matching).
  final Set<String> _selectedNames = {};

  late AnimationController _sheetAnimCtrl;
  late Animation<Offset> _slideAnimation;

  static const _categories = [
    'All',
    'Fridge',
    'Pantry',
    'Vegetables',
    'Fruits',
    'Spices',
    'Snacks',
    'Drinks',
    'Household',
    'Custom',
  ];

  @override
  void initState() {
    super.initState();
    _sheetAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _sheetAnimCtrl,
        curve: const SpringCurve(damping: 30, stiffness: 300),
      ),
    );
    _sheetAnimCtrl.forward();
    _searchCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _sheetAnimCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _allDatabase => [
        ...GroceryDatabase.items,
        ...widget.customItems,
      ];

  List<Map<String, dynamic>> get _filteredSuggestions {
    final query = _searchCtrl.text.trim().toLowerCase();
    final filtered = _allDatabase.where((item) {
      final matchesCategory =
          _selectedCategory == 'All' || item['category'] == _selectedCategory;
      final matchesSearch = query.isEmpty ||
          item['name'].toString().toLowerCase().contains(query);
      return matchesCategory && matchesSearch;
    }).toList();

    // Sort so recently used items appear first.
    final recentNames = widget.recentItemNames;
    filtered.sort((a, b) {
      final aName = a['name'].toString();
      final bName = b['name'].toString();
      final aIndex = recentNames.indexOf(aName);
      final bIndex = recentNames.indexOf(bName);
      if (aIndex != -1 && bIndex != -1) return aIndex.compareTo(bIndex);
      if (aIndex != -1) return -1;
      if (bIndex != -1) return 1;
      return 0;
    });

    return filtered;
  }

  void _toggleItem(String name) {
    setState(() {
      final key = name.toLowerCase();
      if (_selectedNames.contains(key)) {
        _selectedNames.remove(key);
      } else {
        _selectedNames.add(key);
      }
    });
  }

  bool _isCustomItem(String name) {
    return !_allDatabase.any(
      (item) => item['name'].toString().toLowerCase() == name.toLowerCase(),
    );
  }

  void _addCustomFromSearch() {
    final name = _searchCtrl.text.trim();
    if (name.isEmpty) return;
    if (_isCustomItem(name)) {
      widget.onSaveCustom({
        'name': name,
        'price': 0.0,
        'unit': 'pcs',
        'category': 'Custom',
      });
    }
    _toggleItem(name);
    _searchCtrl.clear();
  }

  void _confirmSelection() {
    final items = <GroceryItem>[];
    for (final name in _selectedNames) {
      // Find the database entry for this item.
      final dbItem = _allDatabase.firstWhere(
        (item) => item['name'].toString().toLowerCase() == name,
        orElse: () => {
          'name': name,
          'price': 0.0,
          'unit': 'pcs',
          'category': 'Custom',
        },
      );

      // Try to get the store-specific price first.
      final storeName = widget.storeName;
      double price = 0.0;
      if (storeName.isNotEmpty) {
        price = PriceStorage.getLastPrice(dbItem['name'], storeName) ?? 0.0;
      }
      if (price == 0.0) {
        price = PriceStorage.getLastPriceAny(dbItem['name']) ??
            (dbItem['price'] as num).toDouble();
      }

      items.add(GroceryItem(
        id: DateTime.now().millisecondsSinceEpoch.toString() +
            name.hashCode.toString(),
        name: dbItem['name'].toString(),
        qty: 1.0,
        unit: dbItem['unit'] as String? ?? 'pcs',
        price: price,
        category: dbItem['category'] as String? ?? 'Custom',
      ));
    }

    widget.onAddBatch(items);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final hasCustomText =
        _searchCtrl.text.trim().isNotEmpty && _isCustomItem(_searchCtrl.text.trim());

    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.92,
        ),
        decoration: BoxDecoration(
          color: kBackground,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Padding(
          padding: EdgeInsets.only(bottom: bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SheetHandle(),

              // Header: title + Done button
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
                child: Row(
                  children: [
                    Text(
                      'Add Items',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 19,
                        fontWeight: FontWeight.w600,
                        color: kTextCharcoal,
                      ),
                    ),
                    if (_selectedNames.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(left: 10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: kPrimary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${_selectedNames.length}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: kPrimary,
                            ),
                          ),
                        ),
                      ),
                    const Spacer(),
                    TextButton(
                      onPressed: _selectedNames.isNotEmpty
                          ? _confirmSelection
                          : () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        foregroundColor: kPrimary,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        _selectedNames.isNotEmpty ? 'Done' : 'Cancel',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Store context indicator
              if (widget.storeName.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Row(
                    children: [
                      Icon(Icons.storefront_rounded,
                          size: 14, color: kMuted),
                      const SizedBox(width: 6),
                      Text(
                        'Prices from ${widget.storeName}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: kMuted,
                        ),
                      ),
                    ],
                  ),
                ),

              // Search bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: kMutedBg.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: kTextCharcoal,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search or type a new item...',
                      hintStyle: GoogleFonts.plusJakartaSans(
                        color: kMuted,
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                      ),
                      prefixIcon:
                          Icon(Icons.search_rounded, color: kMuted, size: 20),
                      border: InputBorder.none,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ),

              // Custom item hint
              if (hasCustomText)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: GestureDetector(
                    onTap: _addCustomFromSearch,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: kPrimary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.add_circle_outline_rounded,
                              size: 18, color: kPrimary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Add "${_searchCtrl.text.trim()}" as custom item',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: kPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 12),

              // Category tabs
              AddItemCategoryTabs(
                categories: _categories,
                selectedCategory: _selectedCategory,
                onSelected: (cat) =>
                    setState(() => _selectedCategory = cat),
              ),

              const SizedBox(height: 16),

              // Suggestions label
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'SUGGESTIONS',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: kMuted,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // Scrollable suggestion chips
              Expanded(
                child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  physics: const BouncingScrollPhysics(),
                  child: _filteredSuggestions.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Text(
                            'No suggestions found',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              color: kMuted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        )
                      : Wrap(
                          spacing: 8,
                          runSpacing: 10,
                          children: _filteredSuggestions.map((item) {
                            final name = item['name'].toString();
                            final isSelected = _selectedNames
                                .contains(name.toLowerCase());

                            // Build price subtitle
                            String? priceHint;
                            if (widget.storeName.isNotEmpty) {
                              final p = PriceStorage.getLastPrice(
                                  name, widget.storeName);
                              if (p != null) {
                                priceHint = '₱${p.toStringAsFixed(0)}';
                              }
                            }

                            return GestureDetector(
                              onTap: () => _toggleItem(name),
                              child: AnimatedContainer(
                                duration:
                                    const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 9,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? kPrimary.withValues(alpha: 0.12)
                                      : Colors.white,
                                  borderRadius:
                                      BorderRadius.circular(22),
                                  border: Border.all(
                                    color: isSelected
                                        ? kPrimary
                                        : kBorder.withValues(alpha: 0.6),
                                    width: isSelected ? 1.5 : 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    AnimatedSwitcher(
                                      duration: const Duration(
                                          milliseconds: 200),
                                      child: Icon(
                                        isSelected
                                            ? Icons.check_rounded
                                            : Icons.add_rounded,
                                        key: ValueKey(isSelected),
                                        size: 16,
                                        color: isSelected
                                            ? kPrimary
                                            : kMuted,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      name,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 13,
                                        fontWeight: isSelected
                                            ? FontWeight.w600
                                            : FontWeight.w500,
                                        color: isSelected
                                            ? kPrimary
                                            : kTextCharcoal,
                                      ),
                                    ),
                                    if (priceHint != null) ...[
                                      const SizedBox(width: 6),
                                      Text(
                                        priceHint,
                                        style:
                                            GoogleFonts.plusJakartaSans(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          color: isSelected
                                              ? kPrimary
                                                  .withValues(alpha: 0.7)
                                              : kMuted,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                ),
              ),

              // Bottom: floating Done button when items are selected
              if (_selectedNames.isNotEmpty)
                Container(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    12,
                    20,
                    12 + MediaQuery.of(context).padding.bottom,
                  ),
                  decoration: BoxDecoration(
                    color: kBackground,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _confirmSelection,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        'Add ${_selectedNames.length} item${_selectedNames.length == 1 ? '' : 's'}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
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
