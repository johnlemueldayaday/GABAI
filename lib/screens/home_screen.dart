import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:gabay/models/grocery_models.dart';
import 'package:gabay/config/app_theme.dart';
import 'package:gabay/widgets/app_drawer.dart';
import 'package:gabay/services/grocery_storage.dart';
import 'package:gabay/widgets/home/home_app_bar.dart';
import 'package:gabay/widgets/home/home_body.dart';
import 'package:gabay/widgets/home/home_helpers.dart';
import 'package:gabay/widgets/home/sections/add_item_sheet.dart';
import 'package:gabay/widgets/home/sections/home_fab_stack.dart';
import 'package:gabay/widgets/home/sections/numeric_keypad_sheet.dart';
import 'package:gabay/pages/recent.dart';

// Renders the grocery wallet app shell and theme.
class GroceryApp extends StatelessWidget {
  const GroceryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: GoogleFonts.plusJakartaSans().fontFamily,
        scaffoldBackgroundColor: kBackground,
        colorScheme: ColorScheme.fromSeed(seedColor: kPrimary),
        appBarTheme: AppBarTheme(
          backgroundColor: kBackground,
          elevation: 0,
          foregroundColor: kTextCharcoal,
          centerTitle: false,
          titleTextStyle: GoogleFonts.plusJakartaSans(
            color: kTextCharcoal,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

// Renders the stateful home shopping screen.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

// Keeps home screen state and passes values and callbacks to child widgets.
class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  String get _listName => AppState.currentList?.name ?? _fallbackName;
  set _listName(String v) {
    if (AppState.currentList != null) {
      AppState.currentList!.name = v;
    } else {
      _fallbackName = v;
    }
  }

  String _fallbackName = 'New List';

  double get _budget => AppState.currentList?.budget ?? _fallbackBudget;
  set _budget(double v) {
    if (AppState.currentList != null) {
      AppState.currentList!.budget = v;
    } else {
      _fallbackBudget = v;
    }
  }

  double _fallbackBudget = 0;

  List<GroceryItem> get _items => AppState.currentList?.items ?? _fallbackItems;
  final List<GroceryItem> _fallbackItems = [];
  final List<Map<String, dynamic>> _customItems = [];
  final List<String> _recentItemNames = [];
  final Map<String, double> _lastPrices = {};
  bool _isInit = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() => _isInit = true);
    });
  }

  double get _checkedTotal =>
      _doneItems.fold(0.0, (s, i) => s + getItemTotal(i.price, i.qty, i.unit));
  double get _plannedTotal =>
      _items.fold(0.0, (s, i) => s + getItemTotal(i.price, i.qty, i.unit));
  double get _left => _budget - _checkedTotal;
  double get _progress => (_budget > 0 && _checkedTotal > 0)
      ? (_checkedTotal / _budget).clamp(0.0, 1.0)
      : 0.0;

  List<GroceryItem> get _toBuy => _items.where((i) => !i.isDone).toList();
  List<GroceryItem> get _doneItems => _items.where((i) => i.isDone).toList();

  void _editListName() async {
    final ctrl = TextEditingController(text: _listName);
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Rename List',
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
      setState(() => _listName = result);
      GroceryStorage.saveAll();
    }
  }

  void _editItemName(GroceryItem item) async {
    final ctrl = TextEditingController(text: item.name);
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Edit Name',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: 'Item name',
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
      setState(() => item.name = result);
      GroceryStorage.saveAll();
    }
  }

  void _editBudget() async {
    final result = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => NumericKeypadSheet(
        initialValue: _budget,
        itemName: 'Budget Overview',
      ),
    );
    if (result != null) {
      setState(() => _budget = result);
      GroceryStorage.saveAll();
    }
  }

  void _showAddItemSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      transitionAnimationController: AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 500),
      ),
      builder: (_) => AddItemSheet(
        customItems: _customItems,
        recentItemNames: _recentItemNames,
        lastPrices: _lastPrices,
        onAdd: (item) {
          setState(() => _items.add(item));
          GroceryStorage.saveAll();
        },
        onSaveCustom: (customItem) =>
            setState(() => _customItems.add(customItem)),
        onRecordUsage: (name, price) {
          setState(() {
            _recentItemNames.remove(name);
            _recentItemNames.insert(0, name);
            _lastPrices[name] = price;
          });
        },
      ),
    );
  }

  void _toggleItem(GroceryItem item) {
    setState(() {
      item.isDone = !item.isDone;
    });
    GroceryStorage.saveAll();
  }

  void _deleteItem(GroceryItem item) {
    setState(() {
      _items.remove(item);
    });
    GroceryStorage.saveAll();
  }

  void _changeQty(GroceryItem item, int delta) {
    setState(() {
      item.qty = stepQty(item.qty, delta, item.unit);
    });
    GroceryStorage.saveAll();
  }

  void _editPrice(GroceryItem item) async {
    final result = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          NumericKeypadSheet(initialValue: item.price, itemName: item.name),
    );
    if (result != null) {
      setState(() => item.price = result);
      GroceryStorage.saveAll();
    }
  }

  void _showUnitPicker(GroceryItem item) async {
    final List<String> units = [
      'pcs',
      'kg',
      'g',
      'L',
      'mL',
      'pack',
      'bottle',
      'can',
      'box',
      'bundle',
    ];
    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
        decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: kMuted.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Select Unit',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: kTextCharcoal,
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: units.map((u) {
                  final isSelected = item.unit == u;
                  return GestureDetector(
                    onTap: () => Navigator.pop(context, u),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? kPrimary
                            : kMutedBg.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected
                              ? kPrimary
                              : kBorder.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Text(
                        u,
                        style: TextStyle(
                          color: isSelected ? Colors.white : kTextCharcoal,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );

    if (result != null) {
      setState(() => item.unit = result);
      GroceryStorage.saveAll();
    }
  }

  void _finishList() {
    final checkedItems = _items.where((i) => i.isDone).toList();
    if (checkedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please check off items before finishing.'),
          backgroundColor: kPrimary,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final double totalSpent = checkedItems.fold(
      0.0,
      (s, i) => s + getItemTotal(i.price, i.qty, i.unit),
    );

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: kCardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Finish Shopping?',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            color: kTextCharcoal,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You are about to save this trip to history.',
              style: GoogleFonts.plusJakartaSans(
                color: kTextCharcoal.withValues(alpha: 0.7),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: kPrimary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kPrimary.withValues(alpha: 0.1)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'TOTAL SPENT:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: kMuted,
                      letterSpacing: 1.1,
                    ),
                  ),
                  Text(
                    '₱${totalSpent.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: kPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '${checkedItems.length} items will be moved to history. Unchecked items will stay in your list.',
              style: TextStyle(
                fontSize: 12,
                color: kTextCharcoal.withValues(alpha: 0.5),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: kMuted),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                final recent = GroceryList(_listName);
                recent.budget = _budget;
                recent.items = checkedItems
                    .map(
                      (e) => GroceryItem(
                        id: e.id,
                        name: e.name,
                        qty: e.qty,
                        unit: e.unit,
                        price: e.price,
                        isDone: true,
                        category: e.category,
                      ),
                    )
                    .toList();

                AppState.recentLists.insert(0, recent);

                // Remove only the finished items from current list
                _items.removeWhere((i) => i.isDone);

                GroceryStorage.saveAll();
              });

              Navigator.pop(context);

              // Navigate to Recent Page
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RecentPage()),
              );
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: kPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Finish & Save'),
          ),
        ],
      ),
    );
  }

  void _clearAllItems() {
    if (_items.isEmpty) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: kCardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Clear All Items?',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            color: kTextCharcoal,
          ),
        ),
        content: Text(
          'This will permanently remove all items from this list.',
          style: GoogleFonts.plusJakartaSans(
            color: kTextCharcoal.withValues(alpha: 0.7),
            fontWeight: FontWeight.w500,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: kMuted),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _items.clear();
                GroceryStorage.saveAll();
              });
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const HomeAppBar(),
      drawer: const AppDrawer(currentPage: 'Cart'),
      body: HomeBody(
        isInit: _isInit,
        listName: _listName,
        budget: _budget,
        checkedTotal: _checkedTotal,
        plannedTotal: _plannedTotal,
        left: _left,
        progress: _progress,
        allItems: _items,
        toBuy: _toBuy,
        doneItems: _doneItems,
        onEditListName: _editListName,
        onFinishList: _finishList,
        onClearAll: _clearAllItems,
        onEditBudget: _editBudget,
        onToggleItem: _toggleItem,
        onDeleteItem: _deleteItem,
        onChangeQty: _changeQty,
        onEditPrice: _editPrice,
        onEditUnit: _showUnitPicker,
        onEditItemName: _editItemName,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: HomeFabStack(onAddPressed: _showAddItemSheet),
    );
  }
}
