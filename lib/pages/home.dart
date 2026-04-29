import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'package:gabay/pages/ramsey.dart';
import 'package:gabay/models/grocery_models.dart';
import 'package:gabay/config/app_theme.dart';
import 'package:gabay/widgets/app_drawer.dart';
import 'package:gabay/services/grocery_storage.dart';

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

// Models and AppState moved to lib/models/grocery_models.dart

// ─── Helpers ───────────────────────────────────────────────────────────────
String _formatQty(double q) {
  if ((q - 0.125).abs() < 0.001) return '⅛';
  if ((q - 0.25).abs() < 0.001) return '¼';
  if ((q - 0.333).abs() < 0.001) return '⅓';
  if ((q - 0.5).abs() < 0.001) return '½';
  if ((q - 0.666).abs() < 0.001) return '⅔';
  if ((q - 0.75).abs() < 0.001) return '¾';
  if ((q - 1.25).abs() < 0.001) return '1¼';
  if ((q - 1.5).abs() < 0.001) return '1½';
  if ((q - 1.75).abs() < 0.001) return '1¾';
  if (q == q.truncateToDouble()) return q.toInt().toString();
  return q
      .toStringAsFixed(3)
      .replaceAll(RegExp(r'0*$'), '')
      .replaceAll(RegExp(r'\.$'), '');
}

double _stepQty(double current, int dir, String unit) {
  if (unit == 'kg') {
    const steps = [
      0.125,
      0.25,
      0.5,
      0.75,
      1.0,
      1.25,
      1.5,
      1.75,
      2.0,
      2.5,
      3.0,
      4.0,
      5.0,
    ];
    if (dir > 0) {
      for (double s in steps) {
        if (s > current + 0.001) return s;
      }
      return current + 1.0;
    } else {
      for (int i = steps.length - 1; i >= 0; i--) {
        if (steps[i] < current - 0.001) return steps[i];
      }
      return current > 1.0 ? current - 1.0 : 0.125;
    }
  } else {
    return (current + dir).clamp(1.0, 999.0);
  }
}

// ─── Grocery Database ──────────────────────────────────────────────────────
final List<Map<String, dynamic>> kGroceryDatabase = [
  // Fridge
  {'name': 'Chicken', 'price': 220.0, 'unit': 'kg', 'category': 'Fridge'},
  {'name': 'Milk', 'price': 75.0, 'unit': 'L', 'category': 'Fridge'},
  {'name': 'Eggs', 'price': 180.0, 'unit': 'dozen', 'category': 'Fridge'},
  {'name': 'Beef', 'price': 420.0, 'unit': 'kg', 'category': 'Fridge'},
  {'name': 'Pork', 'price': 320.0, 'unit': 'kg', 'category': 'Fridge'},
  {'name': 'Butter', 'price': 110.0, 'unit': 'pcs', 'category': 'Fridge'},
  {'name': 'Cheese', 'price': 165.0, 'unit': 'pcs', 'category': 'Fridge'},
  {'name': 'Yogurt', 'price': 85.0, 'unit': 'pcs', 'category': 'Fridge'},
  {'name': 'Tofu', 'price': 40.0, 'unit': 'pcs', 'category': 'Fridge'},
  {'name': 'Tilapia', 'price': 130.0, 'unit': 'kg', 'category': 'Fridge'},
  {'name': 'Bangus', 'price': 180.0, 'unit': 'kg', 'category': 'Fridge'},
  {'name': 'Galunggong', 'price': 200.0, 'unit': 'kg', 'category': 'Fridge'},
  {'name': 'Squid', 'price': 280.0, 'unit': 'kg', 'category': 'Fridge'},
  {'name': 'Shrimp', 'price': 380.0, 'unit': 'kg', 'category': 'Fridge'},
  {'name': 'Hotdog', 'price': 85.0, 'unit': 'pack', 'category': 'Fridge'},
  {'name': 'Longganisa', 'price': 95.0, 'unit': 'pack', 'category': 'Fridge'},
  {'name': 'Tocino', 'price': 110.0, 'unit': 'pack', 'category': 'Fridge'},
  {'name': 'Corned Beef', 'price': 75.0, 'unit': 'can', 'category': 'Fridge'},
  {'name': 'Luncheon Meat', 'price': 85.0, 'unit': 'can', 'category': 'Fridge'},

  // Pantry
  {'name': 'Rice', 'price': 58.0, 'unit': 'kg', 'category': 'Pantry'},
  {'name': 'Pasta', 'price': 55.0, 'unit': 'pack', 'category': 'Pantry'},
  {'name': 'Cooking Oil', 'price': 90.0, 'unit': 'L', 'category': 'Pantry'},
  {'name': 'Flour', 'price': 52.0, 'unit': 'kg', 'category': 'Pantry'},
  {'name': 'Sugar', 'price': 75.0, 'unit': 'kg', 'category': 'Pantry'},
  {'name': 'Soy Sauce', 'price': 42.0, 'unit': 'bottle', 'category': 'Pantry'},
  {'name': 'Vinegar', 'price': 32.0, 'unit': 'bottle', 'category': 'Pantry'},
  {'name': 'Canned Tuna', 'price': 48.0, 'unit': 'can', 'category': 'Pantry'},
  {'name': 'Noodles', 'price': 15.0, 'unit': 'pack', 'category': 'Pantry'},
  {'name': 'Sardines', 'price': 28.0, 'unit': 'can', 'category': 'Pantry'},
  {'name': 'Tomato Sauce', 'price': 22.0, 'unit': 'can', 'category': 'Pantry'},
  {'name': 'Coconut Milk', 'price': 38.0, 'unit': 'can', 'category': 'Pantry'},
  {'name': 'Bread', 'price': 55.0, 'unit': 'loaf', 'category': 'Pantry'},
  {'name': 'Oats', 'price': 85.0, 'unit': 'pack', 'category': 'Pantry'},
  {
    'name': 'Instant Noodles',
    'price': 12.0,
    'unit': 'pack',
    'category': 'Pantry',
  },
  {'name': 'Pancake Mix', 'price': 65.0, 'unit': 'pack', 'category': 'Pantry'},
  {
    'name': 'Oyster Sauce',
    'price': 52.0,
    'unit': 'bottle',
    'category': 'Pantry',
  },
  {'name': 'Fish Sauce', 'price': 38.0, 'unit': 'bottle', 'category': 'Pantry'},
  {'name': 'Ketchup', 'price': 48.0, 'unit': 'bottle', 'category': 'Pantry'},
  {'name': 'Mayonnaise', 'price': 72.0, 'unit': 'jar', 'category': 'Pantry'},

  // Vegetables
  {
    'name': 'Kangkong',
    'price': 20.0,
    'unit': 'bundle',
    'category': 'Vegetables',
  },
  {'name': 'Pechay', 'price': 25.0, 'unit': 'bundle', 'category': 'Vegetables'},
  {'name': 'Ampalaya', 'price': 60.0, 'unit': 'kg', 'category': 'Vegetables'},
  {'name': 'Sitaw', 'price': 50.0, 'unit': 'bundle', 'category': 'Vegetables'},
  {'name': 'Okra', 'price': 55.0, 'unit': 'kg', 'category': 'Vegetables'},
  {'name': 'Eggplant', 'price': 60.0, 'unit': 'kg', 'category': 'Vegetables'},
  {'name': 'Tomato', 'price': 70.0, 'unit': 'kg', 'category': 'Vegetables'},
  {'name': 'Potato', 'price': 80.0, 'unit': 'kg', 'category': 'Vegetables'},
  {'name': 'Carrot', 'price': 75.0, 'unit': 'kg', 'category': 'Vegetables'},
  {'name': 'Cabbage', 'price': 55.0, 'unit': 'kg', 'category': 'Vegetables'},
  {'name': 'Sayote', 'price': 40.0, 'unit': 'kg', 'category': 'Vegetables'},
  {
    'name': 'Malunggay',
    'price': 15.0,
    'unit': 'bundle',
    'category': 'Vegetables',
  },
  {'name': 'Camote', 'price': 45.0, 'unit': 'kg', 'category': 'Vegetables'},

  // Fruits
  {'name': 'Banana', 'price': 60.0, 'unit': 'kg', 'category': 'Fruits'},
  {'name': 'Mango', 'price': 120.0, 'unit': 'kg', 'category': 'Fruits'},
  {'name': 'Papaya', 'price': 50.0, 'unit': 'kg', 'category': 'Fruits'},
  {'name': 'Pineapple', 'price': 65.0, 'unit': 'pcs', 'category': 'Fruits'},
  {'name': 'Watermelon', 'price': 35.0, 'unit': 'kg', 'category': 'Fruits'},
  {'name': 'Calamansi', 'price': 80.0, 'unit': 'kg', 'category': 'Fruits'},
  {'name': 'Avocado', 'price': 110.0, 'unit': 'kg', 'category': 'Fruits'},
  {'name': 'Coconut', 'price': 40.0, 'unit': 'pcs', 'category': 'Fruits'},

  // Spices
  {'name': 'Salt', 'price': 20.0, 'unit': 'pack', 'category': 'Spices'},
  {'name': 'Pepper', 'price': 50.0, 'unit': 'pack', 'category': 'Spices'},
  {'name': 'Garlic', 'price': 120.0, 'unit': 'kg', 'category': 'Spices'},
  {'name': 'Onion', 'price': 90.0, 'unit': 'kg', 'category': 'Spices'},
  {'name': 'Ginger', 'price': 80.0, 'unit': 'kg', 'category': 'Spices'},
  {'name': 'Bay Leaves', 'price': 18.0, 'unit': 'pack', 'category': 'Spices'},
  {'name': 'Paprika', 'price': 60.0, 'unit': 'pack', 'category': 'Spices'},
  {'name': 'Chili', 'price': 150.0, 'unit': 'kg', 'category': 'Spices'},
  {'name': 'Turmeric', 'price': 55.0, 'unit': 'pack', 'category': 'Spices'},
  {
    'name': 'Seasoning Granules',
    'price': 12.0,
    'unit': 'pack',
    'category': 'Spices',
  },

  // Snacks
  {'name': 'Chips', 'price': 52.0, 'unit': 'pack', 'category': 'Snacks'},
  {'name': 'Biscuits', 'price': 42.0, 'unit': 'pack', 'category': 'Snacks'},
  {'name': 'Chocolate', 'price': 78.0, 'unit': 'pcs', 'category': 'Snacks'},
  {'name': 'Crackers', 'price': 38.0, 'unit': 'pack', 'category': 'Snacks'},
  {'name': 'Nuts', 'price': 95.0, 'unit': 'pack', 'category': 'Snacks'},
  {'name': 'Polvoron', 'price': 55.0, 'unit': 'pack', 'category': 'Snacks'},
  {'name': 'Chicharon', 'price': 65.0, 'unit': 'pack', 'category': 'Snacks'},
  {'name': 'Peanuts', 'price': 45.0, 'unit': 'pack', 'category': 'Snacks'},
  {'name': 'Popcorn', 'price': 35.0, 'unit': 'pack', 'category': 'Snacks'},
  {'name': 'Candy', 'price': 20.0, 'unit': 'pack', 'category': 'Snacks'},

  // Drinks
  {'name': 'Coffee', 'price': 145.0, 'unit': 'pack', 'category': 'Drinks'},
  {'name': 'Tea', 'price': 72.0, 'unit': 'box', 'category': 'Drinks'},
  {'name': 'Juice', 'price': 85.0, 'unit': 'L', 'category': 'Drinks'},
  {'name': 'Soda', 'price': 55.0, 'unit': 'bottle', 'category': 'Drinks'},
  {'name': 'Water', 'price': 30.0, 'unit': 'bottle', 'category': 'Drinks'},
  {'name': 'Energy Drink', 'price': 45.0, 'unit': 'can', 'category': 'Drinks'},
  {
    'name': 'Chocolate Drink',
    'price': 95.0,
    'unit': 'pack',
    'category': 'Drinks',
  },
  {
    'name': 'Powdered Juice',
    'price': 18.0,
    'unit': 'pack',
    'category': 'Drinks',
  },
  {
    'name': 'Bottled Iced Tea',
    'price': 38.0,
    'unit': 'bottle',
    'category': 'Drinks',
  },
  {
    'name': 'Coconut Water',
    'price': 45.0,
    'unit': 'bottle',
    'category': 'Drinks',
  },

  // Household
  {
    'name': 'Dishwashing Liquid',
    'price': 58.0,
    'unit': 'bottle',
    'category': 'Household',
  },
  {
    'name': 'Laundry Detergent',
    'price': 75.0,
    'unit': 'pack',
    'category': 'Household',
  },
  {
    'name': 'Fabric Conditioner',
    'price': 65.0,
    'unit': 'pack',
    'category': 'Household',
  },
  {'name': 'Bleach', 'price': 42.0, 'unit': 'bottle', 'category': 'Household'},
  {
    'name': 'Toilet Paper',
    'price': 55.0,
    'unit': 'roll',
    'category': 'Household',
  },
  {
    'name': 'Trash Bags',
    'price': 48.0,
    'unit': 'pack',
    'category': 'Household',
  },
  {'name': 'Soap', 'price': 28.0, 'unit': 'pcs', 'category': 'Household'},
  {'name': 'Shampoo', 'price': 12.0, 'unit': 'sachet', 'category': 'Household'},
  {'name': 'Toothpaste', 'price': 65.0, 'unit': 'pcs', 'category': 'Household'},
  {'name': 'Alcohol', 'price': 72.0, 'unit': 'bottle', 'category': 'Household'},
];

// ─── HomePage ─────────────────────────────────────────────────────────────
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

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
      _doneItems.fold(0.0, (s, i) => s + i.price * i.qty);
  double get _plannedTotal => _items.fold(0.0, (s, i) => s + i.price * i.qty);
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
      builder: (_) => _NumericKeypadSheet(
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
      builder: (_) => _AddItemSheet(
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
      item.qty = _stepQty(item.qty, delta, item.unit);
    });
    GroceryStorage.saveAll();
  }

  void _editPrice(GroceryItem item) async {
    final result = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _NumericKeypadSheet(initialValue: item.price, itemName: item.name),
    );
    if (result != null) {
      setState(() => item.price = result);
      GroceryStorage.saveAll();
    }
  }

  void _finishList() {
    if (_items.isEmpty) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Finish Shopping?',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'This will mark all items as done and clear the list.',
          style: GoogleFonts.plusJakartaSans(
            color: kMuted,
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
                if (_items.isNotEmpty) {
                  final recent = GroceryList(_listName);
                  recent.budget = _budget;
                  recent.items = _items
                      .map(
                        (e) => GroceryItem(
                          id: e.id,
                          name: e.name,
                          qty: e.qty,
                          unit: e.unit,
                          price: e.price,
                          isDone:
                              true, // Optional: freeze them as done since it's history
                          category: e.category,
                        ),
                      )
                      .toList();
                  AppState.recentLists.insert(0, recent);
                }

                _items.clear();
                _listName = 'New List';
                if (AppState.currentList != null) {
                  AppState.lists.removeAt(AppState.activeIndex);
                  AppState.activeIndex = -1;
                }
                GroceryStorage.saveAll();
              });
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: kPrimary),
            child: const Text('Finish'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(Icons.menu_rounded, color: kTextCharcoal),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: const Text('Shopping'),
      ),
      drawer: const AppDrawer(currentPage: 'Shopping'),
      body: AnimatedOpacity(
        duration: const Duration(milliseconds: 600),
        opacity: _isInit ? 1.0 : 0.0,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic,
          transform: Matrix4.translationValues(0, _isInit ? 0 : 20, 0),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      Text(
                        'SHOPPING',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: kMuted,
                          letterSpacing: 2.0,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          GestureDetector(
                            onTap: _editListName,
                            child: Row(
                              children: [
                                Text(
                                  _listName,
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w800,
                                    color: kTextCharcoal,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.edit_outlined,
                                  size: 20,
                                  color: kMuted,
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          _TactileButton(
                            onTap: _finishList,
                            child: Container(
                              decoration: BoxDecoration(
                                color: kPrimary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.check_circle,
                                      size: 16,
                                      color: kPrimary,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Finish',
                                      style: TextStyle(
                                        color: kPrimary,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _BudgetCard(
                        budget: _budget,
                        total: _checkedTotal,
                        plannedTotal: _plannedTotal,
                        left: _left,
                        progress: _progress,
                        onTap: _editBudget,
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
                // ─── "To Buy" Section ─────────────────────────────────
                if (_items.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptyState(),
                  )
                else ...[
                  if (_toBuy.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          'TO BUY',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: kMuted,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _ItemTile(
                          item: _toBuy[index],
                          onToggle: () => _toggleItem(_toBuy[index]),
                          onDelete: () => _deleteItem(_toBuy[index]),
                          onQtyChange: (delta) =>
                              _changeQty(_toBuy[index], delta),
                          onPriceEdit: () => _editPrice(_toBuy[index]),
                          onNameEdit: () => _editItemName(_toBuy[index]),
                        ),
                      );
                    }, childCount: _toBuy.length),
                  ),
                ],
                // ─── "Done" Section ───────────────────────────────────
                if (_doneItems.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 16, bottom: 12),
                      child: Text(
                        'DONE',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: kMuted,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),
                if (_doneItems.isNotEmpty)
                  SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _ItemTile(
                          item: _doneItems[index],
                          onToggle: () => _toggleItem(_doneItems[index]),
                          onDelete: () => _deleteItem(_doneItems[index]),
                          onQtyChange: (delta) =>
                              _changeQty(_doneItems[index], delta),
                          onPriceEdit: () => _editPrice(_doneItems[index]),
                        ),
                      );
                    }, childCount: _doneItems.length),
                  ),
                const SliverToBoxAdapter(
                  child: SizedBox(height: 100),
                ), // Space for FAB
              ],
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const RamseyFab(),
          const SizedBox(height: 12),
          _BouncingFAB(onPressed: _showAddItemSheet),
        ],
      ),
    );
  }
}

// ─── Tactile Button Wrapper ──────────────────────────────────────────────────
class _TactileButton extends StatefulWidget {
  final VoidCallback onTap;
  final Widget child;
  const _TactileButton({required this.onTap, required this.child});

  @override
  State<_TactileButton> createState() => _TactileButtonState();
}

class _TactileButtonState extends State<_TactileButton> {
  bool _isDown = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isDown = true),
      onTapUp: (_) {
        setState(() => _isDown = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isDown = false),
      child: AnimatedScale(
        scale: _isDown ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

// ─── Budget Card ─────────────────────────────────────────────────────────────
class _BudgetCard extends StatelessWidget {
  final double budget, total, plannedTotal, left, progress;
  final VoidCallback onTap;

  const _BudgetCard({
    required this.budget,
    required this.total,
    required this.plannedTotal,
    required this.left,
    required this.progress,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    bool overBudget = total > budget && budget > 0;

    return _TactileButton(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [kPrimarySoft, Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [kShadowSoft],
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: kPrimary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Budget Overview',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: kTextCharcoal,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _BudgetCol(
                  label: 'BUDGET',
                  value: '₱${budget.toStringAsFixed(2)}',
                ),
                _BudgetCol(
                  label: 'TOTAL',
                  value: '₱${total.toStringAsFixed(2)}',
                  subValue: '₱${plannedTotal.toStringAsFixed(2)}',
                  valueColor: kPrimary,
                ),
                _BudgetCol(
                  label: 'LEFT',
                  value: '₱${left.toStringAsFixed(2)}',
                  valueColor: overBudget ? Colors.red : kTextCharcoal,
                ),
              ],
            ),
            if (overBudget)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_rounded,
                      color: Colors.red,
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'You\'ve exceeded your budget!',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            // Progress bar driven by checked items' total value vs budget
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                height: 10,
                color: kMutedBg,
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(
                    begin: 0.0,
                    end: progress.clamp(0.0, 1.0),
                  ),
                  duration: const Duration(seconds: 1),
                  curve: Curves.easeOut,
                  builder: (context, value, child) {
                    return FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: value,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: value >= 1.0
                                ? [
                                    const Color(0xFF4CAF50),
                                    const Color(0xFF388E3C),
                                  ]
                                : [kPrimary, kPrimaryLight],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BudgetCol extends StatelessWidget {
  final String label, value;
  final String? subValue;
  final Color? valueColor;
  const _BudgetCol({
    required this.label,
    required this.value,
    this.subValue,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: kMuted,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: valueColor ?? kTextCharcoal,
          ),
        ),
        if (subValue != null) ...[
          const SizedBox(height: 2),
          Text(
            subValue!,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: kMuted,
            ),
          ),
        ],
      ],
    );
  }
}

// ─── Empty State ─────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 500),
        builder: (context, value, child) {
          return Opacity(opacity: value, child: child);
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: kMutedBg,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.shopping_cart_outlined,
                size: 28,
                color: kMuted,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Your list is empty',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: kTextCharcoal,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Tap + to add items',
              style: TextStyle(
                fontSize: 14,
                color: kMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Item Tile ───────────────────────────────────────────────────────────────
class _ItemTile extends StatelessWidget {
  final GroceryItem item;
  final VoidCallback onToggle, onDelete;
  final void Function(int delta) onQtyChange;
  final VoidCallback onPriceEdit;
  final VoidCallback? onNameEdit;
  const _ItemTile({
    required this.item,
    required this.onToggle,
    required this.onDelete,
    required this.onQtyChange,
    required this.onPriceEdit,
    this.onNameEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.startToEnd,
      onDismissed: (_) => onDelete(),
      background: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.delete_outline, color: Colors.red.shade400),
            const SizedBox(width: 8),
            Text(
              'Remove',
              style: TextStyle(
                color: Colors.red.shade400,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: item.isDone ? 0.5 : 1.0,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [kShadowSoft],
          ),
          child: Column(
            children: [
              // ─── Top row: checkbox, name, total price ───
              Row(
                children: [
                  _TactileButton(
                    onTap: onToggle,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: item.isDone ? kPrimary : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: item.isDone ? kPrimary : kBorder,
                          width: 2,
                        ),
                      ),
                      child: item.isDone
                          ? const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 14,
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: GestureDetector(
                      onTap: onNameEdit,
                      child: Text(
                        item.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: kTextCharcoal,
                          decoration: item.isDone
                              ? TextDecoration.lineThrough
                              : null,
                          decorationColor: kMuted,
                        ),
                      ),
                    ),
                  ),
                  Text(
                    '₱${(item.price * item.qty).toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: item.isDone ? kMuted : kTextCharcoal,
                    ),
                  ),
                ],
              ),
              // ─── Bottom row: qty controls, unit price ───
              if (!item.isDone)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Row(
                    children: [
                      const SizedBox(width: 38), // align with text above
                      // Quantity controls
                      Container(
                        height: 32,
                        decoration: BoxDecoration(
                          color: kBackground,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: kBorder),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _TactileButton(
                              onTap: () => onQtyChange(-1),
                              child: Container(
                                width: 30,
                                height: 32,
                                alignment: Alignment.center,
                                child: Icon(
                                  Icons.remove,
                                  size: 14,
                                  color: kTextCharcoal,
                                ),
                              ),
                            ),
                            Container(
                              width: 52,
                              alignment: Alignment.center,
                              child: Text(
                                _formatQty(item.qty),
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: kTextCharcoal,
                                ),
                              ),
                            ),
                            _TactileButton(
                              onTap: () => onQtyChange(1),
                              child: Container(
                                width: 30,
                                height: 32,
                                alignment: Alignment.center,
                                child: Icon(
                                  Icons.add,
                                  size: 14,
                                  color: kTextCharcoal,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        item.unit,
                        style: TextStyle(
                          fontSize: 12,
                          color: kMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      // Tappable unit price
                      _TactileButton(
                        onTap: onPriceEdit,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: kPrimary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.edit_outlined,
                                size: 12,
                                color: kPrimary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '₱${item.price.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: kPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── FAB ───────────────────────────────────────────────────────────────────
class _BouncingFAB extends StatefulWidget {
  final VoidCallback onPressed;
  const _BouncingFAB({required this.onPressed});

  @override
  State<_BouncingFAB> createState() => _BouncingFABState();
}

class _BouncingFABState extends State<_BouncingFAB> {
  bool _isDown = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isDown = true),
      onTapUp: (_) {
        setState(() => _isDown = false);
        widget.onPressed();
      },
      onTapCancel: () => setState(() => _isDown = false),
      child: AnimatedScale(
        scale: _isDown ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutQuad,
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [kPrimary, kPrimaryLight],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: kPrimary.withValues(alpha: 0.3),
                offset: const Offset(0, 8),
                blurRadius: 16,
              ),
            ],
          ),
          child: const Icon(Icons.add, color: Colors.white, size: 28),
        ),
      ),
    );
  }
}

// ─── Add Item Sheet ──────────────────────────────────────────────────────────
class _AddItemSheet extends StatefulWidget {
  final void Function(GroceryItem) onAdd;
  final void Function(Map<String, dynamic>) onSaveCustom;
  final void Function(String name, double price) onRecordUsage;
  final List<Map<String, dynamic>> customItems;
  final List<String> recentItemNames;
  final Map<String, double> lastPrices;
  const _AddItemSheet({
    required this.onAdd,
    required this.onSaveCustom,
    required this.onRecordUsage,
    required this.customItems,
    required this.recentItemNames,
    required this.lastPrices,
  });

  @override
  State<_AddItemSheet> createState() => _AddItemSheetState();
}

class _AddItemSheetState extends State<_AddItemSheet>
    with TickerProviderStateMixin {
  final _searchCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final SpeechToText _speech = SpeechToText();
  double _qty = 1.0;
  String _unit = 'pcs';
  String _selectedCategory = 'All';
  bool _speechAvailable = false;
  bool _isListening = false;
  String? _speechErrorText;
  late AnimationController _sheetAnimCtrl;
  late AnimationController _micPulseCtrl;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _micPulseScale;

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
  static const _units = [
    'pcs',
    'kg',
    'g',
    'L',
    'mL',
    'pack',
    'box',
    'can',
    'bottle',
    'dozen',
    'bundle',
    'loaf',
    'jar',
    'roll',
    'sachet',
  ];

  @override
  void initState() {
    super.initState();
    _sheetAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _sheetAnimCtrl,
            // Spring-like curve in Flutter: use Curves.elasticOut or a custom SpringSimulation
            curve: const _SpringCurve(damping: 30, stiffness: 300),
          ),
        );
    _micPulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _micPulseScale = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _micPulseCtrl, curve: Curves.easeInOut),
    );
    _sheetAnimCtrl.forward();
    _initSpeech();
  }

  @override
  void dispose() {
    if (_speech.isListening) {
      _speech.stop();
    }
    _micPulseCtrl.dispose();
    _sheetAnimCtrl.dispose();
    _searchCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    final available = await _speech.initialize(
      onStatus: _onSpeechStatus,
      onError: _onSpeechError,
    );

    if (!mounted) return;

    setState(() {
      _speechAvailable = available;
      if (!available) {
        _speechErrorText = 'Voice input is unavailable on this device.';
      }
    });
  }

  Future<void> _toggleListening() async {
    FocusScope.of(context).unfocus();

    if (_isListening) {
      await _stopListening();
      return;
    }

    if (!_speechAvailable) {
      setState(() {
        _speechErrorText = 'Voice input is unavailable right now.';
      });
      return;
    }

    final started = await _speech.listen(
      onResult: _onSpeechResult,
      listenMode: ListenMode.dictation,
      partialResults: true,
      cancelOnError: true,
    );

    if (!mounted) return;

    setState(() {
      _isListening = started;
      _speechErrorText = started
          ? null
          : 'Could not start voice input. Please try again.';
    });

    if (started) {
      _micPulseCtrl.repeat(reverse: true);
    }
  }

  Future<void> _stopListening() async {
    if (_speech.isListening) {
      await _speech.stop();
    }

    if (!mounted) return;

    _micPulseCtrl.stop();
    _micPulseCtrl.value = 0;

    setState(() {
      _isListening = false;
    });
  }

  void _onSpeechStatus(String status) {
    final stillListening = status == 'listening';
    if (!mounted) return;

    if (!stillListening && _isListening) {
      _micPulseCtrl.stop();
      _micPulseCtrl.value = 0;
    }

    setState(() {
      _isListening = stillListening;
    });
  }

  void _onSpeechError(SpeechRecognitionError error) {
    if (!mounted) return;

    _micPulseCtrl.stop();
    _micPulseCtrl.value = 0;

    setState(() {
      _isListening = false;
      _speechErrorText = error.errorMsg.isEmpty
          ? 'Voice input failed. Please try again.'
          : error.errorMsg;
    });
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    final transcript = result.recognizedWords.trim();
    if (!mounted || transcript.isEmpty) return;

    _searchCtrl.value = TextEditingValue(
      text: transcript,
      selection: TextSelection.collapsed(offset: transcript.length),
    );

    setState(() {
      _speechErrorText = null;
    });
  }

  List<Map<String, dynamic>> get _allDatabase => [
    ...kGroceryDatabase,
    ...widget.customItems,
  ];

  List<Map<String, dynamic>> get _filteredSuggestions {
    final query = _searchCtrl.text.trim().toLowerCase();
    final filtered = _allDatabase.where((item) {
      final matchesCategory =
          _selectedCategory == 'All' || item['category'] == _selectedCategory;
      final matchesSearch =
          query.isEmpty ||
          item['name'].toString().toLowerCase().contains(query);
      return matchesCategory && matchesSearch;
    }).toList();

    // Sort so most recently added items appear first
    final recentNames = widget.recentItemNames;
    filtered.sort((a, b) {
      final aName = a['name'].toString();
      final bName = b['name'].toString();
      final aIndex = recentNames.indexOf(aName);
      final bIndex = recentNames.indexOf(bName);
      // Both recent: lower index = more recent = should come first
      if (aIndex != -1 && bIndex != -1) return aIndex.compareTo(bIndex);
      // Only one is recent: it goes first
      if (aIndex != -1) return -1;
      if (bIndex != -1) return 1;
      // Neither recent: keep original order
      return 0;
    });

    return filtered;
  }

  bool get _isCustomItem {
    final name = _searchCtrl.text.trim().toLowerCase();
    if (name.isEmpty) return false;
    return !_allDatabase.any(
      (item) => item['name'].toString().toLowerCase() == name,
    );
  }

  void _addToList() {
    final name = _searchCtrl.text.trim();
    if (name.isEmpty) return;
    final price = double.tryParse(_priceCtrl.text) ?? 0;

    if (_isListening) {
      _stopListening();
    }

    // Save custom item for future use
    if (_isCustomItem) {
      widget.onSaveCustom({
        'name': name,
        'price': price,
        'unit': _unit,
        'category': 'Custom',
      });
    }

    // Record this item as most recently used and remember its price
    widget.onRecordUsage(name, price);

    widget.onAdd(
      GroceryItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        qty: _qty,
        unit: _unit,
        price: price,
        category: _selectedCategory == 'All' ? 'Custom' : _selectedCategory,
      ),
    );
    Navigator.pop(context);
  }

  void _onSuggestionTap(Map<String, dynamic> item) {
    if (_isListening) {
      _stopListening();
    }

    setState(() {
      final name = item['name'].toString();
      _searchCtrl.text = name;
      // Use the last remembered price if available, otherwise fall back to DB
      final rememberedPrice = widget.lastPrices[name];
      _priceCtrl.text = rememberedPrice != null
          ? rememberedPrice.toStringAsFixed(2)
          : item['price'].toString();
      _unit = item['unit'];
      if (item['category'] != 'Custom') {
        _selectedCategory = item['category'];
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final hasText = _searchCtrl.text.trim().isNotEmpty;

    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Padding(
          padding: EdgeInsets.only(bottom: bottom),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── Handle Bar ─────────────────────────
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 10, bottom: 4),
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFDDDDDD),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // ─── Header ─────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                  child: Row(
                    children: [
                      Text(
                        'Add Item',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: kTextCharcoal,
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: kMutedBg,
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Icon(Icons.close, size: 16, color: kMuted),
                        ),
                      ),
                    ],
                  ),
                ),
                // ─── Search Bar ─────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: kBackground,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: kBorder),
                      boxShadow: _isListening
                          ? [
                              BoxShadow(
                                color: kPrimary.withValues(alpha: 0.16),
                                blurRadius: 18,
                                spreadRadius: 1,
                              ),
                            ]
                          : [],
                    ),
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (_) {
                        setState(() {
                          _speechErrorText = null;
                        });
                      },
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: kTextCharcoal,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search or type a new item...',
                        hintStyle: TextStyle(color: kMuted, fontSize: 14),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: kMuted,
                          size: 20,
                        ),
                        suffixIcon: Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Center(
                            child: ScaleTransition(
                              scale: _micPulseScale,
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: _toggleListening,
                                  borderRadius: BorderRadius.circular(20),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: _isListening
                                          ? kPrimary.withValues(alpha: 0.12)
                                          : Colors.transparent,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      _isListening
                                          ? Icons.graphic_eq_rounded
                                          : Icons.mic_none_rounded,
                                      size: 19,
                                      color: _isListening ? kPrimary : kMuted,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 14,
                        ),
                      ),
                    ),
                  ),
                ),
                // ─── Custom Item Badge ──────────────────
                if (_isListening || _speechErrorText != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    child: Row(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _isListening ? kPrimary : Colors.red.shade400,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _isListening
                                ? 'Listening... speak the item name'
                                : _speechErrorText!,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _isListening
                                  ? kPrimary
                                  : Colors.red.shade400,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_isCustomItem)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: kPrimary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.auto_awesome, size: 14, color: kPrimary),
                          const SizedBox(width: 6),
                          Text(
                            'New item — will be saved for future use',
                            style: TextStyle(
                              fontSize: 12,
                              color: kPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                // ─── Category Tabs ──────────────────────
                SizedBox(
                  height: 36,
                  child: ListView.separated(
                    physics: const BouncingScrollPhysics(),
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _categories.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final cat = _categories[i];
                      final selected = cat == _selectedCategory;
                      return _TactileButton(
                        onTap: () => setState(() => _selectedCategory = cat),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: selected ? kPrimary : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: selected ? kPrimary : kBorder,
                            ),
                          ),
                          child: Text(
                            cat,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: selected ? Colors.white : kMuted,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
                // ─── Suggestions ────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'SUGGESTIONS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: kMuted,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _filteredSuggestions.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            'No suggestions found',
                            style: TextStyle(
                              fontSize: 13,
                              color: kMuted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        )
                      : Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: List.generate(_filteredSuggestions.length, (
                            index,
                          ) {
                            final item = _filteredSuggestions[index];
                            return _StaggeredPop(
                              delay: index * 20,
                              child: _TactileButton(
                                onTap: () => _onSuggestionTap(item),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: kBorder),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.add, size: 14, color: kMuted),
                                      const SizedBox(width: 4),
                                      Text(
                                        item['name'],
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: kTextCharcoal,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                ),
                const SizedBox(height: 30),
                // ─── Qty / Unit / Price Row ─────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'QTY',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: kMuted,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              height: 48,
                              decoration: BoxDecoration(
                                color: kBackground,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: kBorder),
                              ),
                              child: Row(
                                children: [
                                  IconButton(
                                    onPressed: () => setState(
                                      () => _qty = _stepQty(_qty, -1, _unit),
                                    ),
                                    icon: Icon(
                                      Icons.remove,
                                      size: 16,
                                      color: kTextCharcoal,
                                    ),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                      minWidth: 32,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      _formatQty(_qty),
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                        color: kTextCharcoal,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () => setState(
                                      () => _qty = _stepQty(_qty, 1, _unit),
                                    ),
                                    icon: Icon(
                                      Icons.add,
                                      size: 16,
                                      color: kTextCharcoal,
                                    ),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                      minWidth: 32,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'UNIT',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: kMuted,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              height: 48,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                color: kBackground,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: kBorder),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _unit,
                                  isExpanded: true,
                                  icon: Icon(
                                    Icons.keyboard_arrow_down,
                                    size: 18,
                                    color: kMuted,
                                  ),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: kTextCharcoal,
                                  ),
                                  onChanged: (v) {
                                    setState(() {
                                      _unit = v!;
                                      if (_unit != 'kg') {
                                        _qty = _qty.truncateToDouble();
                                        if (_qty < 1.0) _qty = 1.0;
                                      }
                                    });
                                  },
                                  items: _units
                                      .map(
                                        (u) => DropdownMenuItem(
                                          value: u,
                                          child: Text(u),
                                        ),
                                      )
                                      .toList(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'PRICE (₱)',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: kMuted,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _TactileButton(
                              onTap: () async {
                                FocusScope.of(context).unfocus();
                                final double currentPrice =
                                    double.tryParse(_priceCtrl.text) ?? 0.0;
                                final itemName = _searchCtrl.text.trim();
                                final result =
                                    await showModalBottomSheet<double>(
                                      context: context,
                                      isScrollControlled: true,
                                      backgroundColor: Colors.transparent,
                                      builder: (_) => _NumericKeypadSheet(
                                        initialValue: currentPrice,
                                        itemName: itemName.isEmpty
                                            ? 'New Item'
                                            : itemName,
                                      ),
                                    );
                                if (result != null) {
                                  setState(
                                    () => _priceCtrl.text = result
                                        .toStringAsFixed(2),
                                  );
                                }
                              },
                              child: Container(
                                height: 48,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: kBackground,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: kBorder),
                                ),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    _priceCtrl.text.isEmpty
                                        ? '0.00'
                                        : _priceCtrl.text,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: _priceCtrl.text.isEmpty
                                          ? kMuted
                                          : kTextCharcoal,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                // ─── Add to List Button ─────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _TactileButton(
                    onTap: hasText ? _addToList : () {},
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: double.infinity,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: hasText
                            ? LinearGradient(
                                colors: [kPrimary, kPrimaryLight],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : null,
                        color: hasText ? null : kMutedBg,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: hasText
                            ? [
                                BoxShadow(
                                  color: kPrimary.withValues(alpha: 0.25),
                                  offset: const Offset(0, 6),
                                  blurRadius: 12,
                                ),
                              ]
                            : [],
                      ),
                      child: Center(
                        child: Text(
                          'Add to List',
                          style: TextStyle(
                            color: hasText ? Colors.white : kMuted,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Spring Curve ────────────────────────────────────────────────────────────
class _SpringCurve extends Curve {
  final double damping;
  final double stiffness;

  const _SpringCurve({this.damping = 30, this.stiffness = 300});

  @override
  double transformInternal(double t) {
    // Attempt to approximate a critically-damped spring with the given params
    final omega = stiffness / damping; // ~10
    final decay = -omega * t;
    return 1.0 -
        (1.0 + omega * t * 0.5) * (2.718281828 * decay).clamp(0.0, 1.0);
  }
}

// ─── Staggered Pop ──────────────────────────────────────────────────────────
class _StaggeredPop extends StatefulWidget {
  final Widget child;
  final int delay;
  const _StaggeredPop({required this.child, required this.delay});

  @override
  State<_StaggeredPop> createState() => _StaggeredPopState();
}

class _StaggeredPopState extends State<_StaggeredPop>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack);
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(scale: _scale, child: widget.child);
  }
}

// ─── Numeric Keypad Sheet ────────────────────────────────────────────────────
class _NumericKeypadSheet extends StatefulWidget {
  final double initialValue;
  final String itemName;
  const _NumericKeypadSheet({
    required this.initialValue,
    required this.itemName,
  });

  @override
  State<_NumericKeypadSheet> createState() => _NumericKeypadSheetState();
}

class _NumericKeypadSheetState extends State<_NumericKeypadSheet> {
  String _display = '';

  @override
  void initState() {
    super.initState();
    // Start blank as per user request
    _display = '';
  }

  double get _currentValue => double.tryParse(_display) ?? 0.0;

  void _onDigit(String digit) {
    setState(() {
      // If empty and typing '.', start with '0.'
      if (_display.isEmpty && digit == '.') {
        _display = '0.';
        return;
      }
      // If display is '0' and typing a non-dot digit, replace it
      if (_display == '0' && digit != '.') {
        _display = digit;
        return;
      }
      // Only allow one decimal point
      if (digit == '.' && _display.contains('.')) return;
      // Limit to 2 decimal places
      if (_display.contains('.')) {
        final decimals = _display.split('.').last;
        if (decimals.length >= 2) return;
      }
      // Limit total length
      if (_display.length >= 10) return;
      _display += digit;
    });
  }

  void _onBackspace() {
    setState(() {
      if (_display.isNotEmpty) {
        _display = _display.substring(0, _display.length - 1);
      }
    });
  }

  void _onClear() {
    setState(() => _display = '');
  }

  void _onConfirm() {
    Navigator.pop(context, _currentValue);
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ─── Handle Bar ──────────────────────────
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 4),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFDDDDDD),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // ─── Header ─────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Edit Price',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: kTextCharcoal,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.itemName,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: kMuted,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: kMutedBg,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Icon(Icons.close, size: 16, color: kMuted),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // ─── Price Display ───────────────────────
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [kPrimarySoft, Colors.white],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: kPrimary.withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '₱',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: kPrimary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _display.isEmpty ? '0.00' : _display,
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w800,
                      color: _display.isEmpty
                          ? kTextCharcoal.withValues(alpha: 0.3)
                          : kTextCharcoal,
                      letterSpacing: -1,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // ─── Keypad Grid ────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  _buildKeyRow(['1', '2', '3']),
                  const SizedBox(height: 10),
                  _buildKeyRow(['4', '5', '6']),
                  const SizedBox(height: 10),
                  _buildKeyRow(['7', '8', '9']),
                  const SizedBox(height: 10),
                  _buildKeyRow(['.', '0', '⌫']),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // ─── Action Buttons ──────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  // Clear button
                  Expanded(
                    flex: 1,
                    child: _TactileButton(
                      onTap: _onClear,
                      child: Container(
                        height: 52,
                        decoration: BoxDecoration(
                          color: kMutedBg,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(
                          child: Text(
                            'Clear',
                            style: TextStyle(
                              color: kMuted,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Confirm button
                  Expanded(
                    flex: 2,
                    child: _TactileButton(
                      onTap: _onConfirm,
                      child: Container(
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [kPrimary, kPrimaryLight],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: kPrimary.withValues(alpha: 0.25),
                              offset: const Offset(0, 6),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.check_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Confirm  ₱${_currentValue.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildKeyRow(List<String> keys) {
    return Row(
      children: keys.map((key) {
        final isBackspace = key == '⌫';
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              left: keys.indexOf(key) == 0 ? 0 : 5,
              right: keys.indexOf(key) == keys.length - 1 ? 0 : 5,
            ),
            child: _KeypadButton(
              label: key,
              isBackspace: isBackspace,
              onTap: isBackspace ? _onBackspace : () => _onDigit(key),
              onLongPress: isBackspace ? _onClear : null,
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─── Keypad Button ──────────────────────────────────────────────────────────
class _KeypadButton extends StatefulWidget {
  final String label;
  final bool isBackspace;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  const _KeypadButton({
    required this.label,
    this.isBackspace = false,
    required this.onTap,
    this.onLongPress,
  });

  @override
  State<_KeypadButton> createState() => _KeypadButtonState();
}

class _KeypadButtonState extends State<_KeypadButton> {
  bool _isDown = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isDown = true),
      onTapUp: (_) {
        setState(() => _isDown = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isDown = false),
      onLongPress: widget.onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        height: 56,
        decoration: BoxDecoration(
          color: _isDown ? kPrimary.withValues(alpha: 0.1) : kBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isDown ? kPrimary.withValues(alpha: 0.3) : kBorder,
          ),
        ),
        child: Center(
          child: widget.isBackspace
              ? Icon(Icons.backspace_outlined, size: 22, color: kTextCharcoal)
              : Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: kTextCharcoal,
                  ),
                ),
        ),
      ),
    );
  }
}
