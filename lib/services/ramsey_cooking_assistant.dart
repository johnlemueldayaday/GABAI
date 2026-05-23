import 'dart:math';

import 'package:gabay/data/grocery_database.dart';
import 'package:gabay/models/grocery_models.dart';
import 'package:gabay/models/bill_models.dart';

enum RamseyStep { mealPrompt, cravingPrompt, dishPrompt, cartPrompt }

class _SpendingSnapshot {
  final String label;
  final DateTime start;
  final DateTime end;
  final List<GroceryList> trips;

  const _SpendingSnapshot({
    required this.label,
    required this.start,
    required this.end,
    required this.trips,
  });
}

class RamseyDish {
  final String name;
  final String shortInfo;
  final List<String> ingredients;
  final List<String> instructions;
  final int minutes;
  final int servings;
  final Set<String> tags;
  final Set<String> meals;
  final Set<String> ingredientKeywords;

  const RamseyDish({
    required this.name,
    this.shortInfo = 'Classic Filipino favorite',
    required this.ingredients,
    required this.instructions,
    required this.minutes,
    required this.servings,
    required this.tags,
    required this.meals,
    required this.ingredientKeywords,
  });
}

class RamseyReply {
  final String text;
  final List<String>? extraTexts;
  final List<String> quickReplies;
  final String? navigateTo;

  const RamseyReply(this.text, {this.extraTexts, this.quickReplies = const [], this.navigateTo});
}

class RamseyCookingAssistant {
  final Random _random = Random();
  RamseyStep _step = RamseyStep.mealPrompt;
  String? _meal;
  String? _craving;
  List<RamseyDish> _currentOptions = [];
  List<String> _lastDishNames = [];
  _SpendingSnapshot? _lastSpending;
  List<Bill> _allBills = [];
  RamseyDish? _lastDish;
  final Set<String> _suggestedDishNames = {};

  void updateBills(List<Bill> bills) {
    _allBills = bills;
  }

  List<Bill> _getUpcomingBillsWithin7Days() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sevenDaysLater = today.add(const Duration(days: 7));
    
    final upcoming = _allBills.where((bill) {
      final billDate = DateTime(bill.dueDate.year, bill.dueDate.month, bill.dueDate.day);
      return (billDate.isAfter(today) || billDate.isAtSameMomentAs(today)) && 
             billDate.isBefore(sevenDaysLater.add(const Duration(days: 1))) &&
             !bill.isPaid;
    }).toList();
    
    upcoming.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return upcoming;
  }

  RamseyReply get greeting {
    return const RamseyReply(
      "Kumusta! I'm Ramsey, your all-in-one smart assistant. 🇵🇭",
      extraTexts: ["How can I help you today?"],
    );
  }

  String _formatDateNicely(DateTime date) {
    final monthNames = ['January', 'February', 'March', 'April', 'May', 'June',
                       'July', 'August', 'September', 'October', 'November', 'December'];
    return '${monthNames[date.month - 1]} ${date.day}';
  }

  bool get hasRecentFridgeItems => _recentIngredientKeywords().isNotEmpty;

  RamseyReply handle(String rawInput) {
    final input = rawInput.trim();
    final normalized = input.toLowerCase();

    if (_isBreakdownAsk(normalized) && _lastSpending != null) {
      return _spendingBreakdownReply(_lastSpending!);
    }

    if (_isSpendingAsk(normalized)) {
      _resetCooking();
      return _spendingSummaryReply(normalized);
    }

    if (_isExplicitBudgetAsk(normalized)) {
      final amount = _parseAmount(normalized);
      if (amount != null) {
        _meal = RamseyCookingAssistant.detectMeal(DateTime.now());
        _currentOptions = _pickDishesByBudget(amount);
        _step = RamseyStep.dishPrompt;
        return _dishOptionsReply();
      }
    }

    if (_isMealPlanAsk(normalized)) {
      _resetCooking();
      final amount = _parseAmount(normalized);
      if (amount != null && (normalized.contains('budget') || normalized.contains('amount'))) {
        return _budgetMealPlanReply(amount);
      }
      return _weeklyMealPlanReply();
    }

    if (_isWeeklyBillAsk(normalized)) {
      return _weeklyBillsSummaryReply();
    }

    if (_isBillAsk(normalized)) {
      return _billsSummaryReply();
    }

    if (_isBudgetAsk(normalized)) {
      return _budgetSummaryReply();
    }

    if (_isAnalyticsAsk(normalized)) {
      return _analyticsSummaryReply();
    }

    // Direct recipe request: "i want to cook caldereta", "give me the recipe of adobo", etc.
    final directDish = _findDirectRecipeRequest(normalized);
    if (directDish != null) {
      _lastDish = directDish;
      _step = RamseyStep.cartPrompt;
      return _recipeReply(directDish);
    }

    if (normalized == 'start over') {
      _resetCooking();
      _suggestedDishNames.clear();
      return greeting;
    }

    final explicitMeal = _explicitMeal(normalized);
    if (explicitMeal != null) {
      return _handleMealInquiry(explicitMeal, 'Anything');
    }

    if (_step == RamseyStep.mealPrompt) {
      final selectedCraving = _cravingFromInput(normalized);
      if (selectedCraving != null) {
        return _handleMealInquiry(RamseyCookingAssistant.detectMeal(DateTime.now()), selectedCraving);
      }

      if (_looksLikeCookingAsk(normalized)) {
        return _handleMealInquiry(RamseyCookingAssistant.detectMeal(DateTime.now()), 'Anything');
      }
      return const RamseyReply(
        "I'd love to help! I can assist with cooking, grocery tracking, or managing your budget. What's on your mind?",
        quickReplies: ['What can I cook?', 'How much did I spend this week?'],
      );
    }

    if (_step == RamseyStep.cravingPrompt) {
      final selectedCraving = _cravingFromInput(normalized);
      if (selectedCraving == null) {
        return _cravingPrompt();
      }
      return _handleMealInquiry(_meal!, selectedCraving);
    }

    if (_step == RamseyStep.dishPrompt) {
      if (normalized == 'yes' ||
          normalized == 'more' ||
          normalized.contains('suggest more') ||
          _isYes(normalized)) {
        return _handleMealInquiry(_meal ?? 'Anything', _craving ?? 'Anything');
      }

      final number = int.tryParse(normalized);
      if (number != null && number >= 1 && number <= _currentOptions.length) {
        _lastDish = _currentOptions[number - 1];
        _step = RamseyStep.cartPrompt;
        return _recipeReply(_lastDish!);
      }

      final selectedCraving = _cravingFromInput(normalized);
      if (selectedCraving != null) {
        return _handleMealInquiry(_meal!, selectedCraving);
      }

      return const RamseyReply(
        "Type the dish number you want to cook. Sarap nyan soon.",
      );
    }

    if (_step == RamseyStep.cartPrompt) {
      if (normalized == 'yes' || _isYes(normalized)) {
        if (_lastDish != null) {
          _addIngredientsToCart(_lastDish!);
          _step = RamseyStep.mealPrompt;
          return RamseyReply(
            "Done! I've created a new list for ${_lastDish!.name} and added all the ingredients. Opening it for you now... 🛒",
            navigateTo: 'cart_detail',
          );
        }
      }
      _step = RamseyStep.mealPrompt;
      return const RamseyReply(
        "No problem! I'm here if you need more suggestions or help with your budget.",
        quickReplies: ['What can I cook?', 'Show my budget'],
      );
    }

    if (normalized.contains('notify me')) {
      return const RamseyReply(
        "Got it! I've set a reminder for you. I'll make sure to notify you 3 days before the due date so you never miss a payment! 🔔",
        quickReplies: ['Show my budget', 'What can I cook for dinner?'],
      );
    }

    if (normalized.contains('show all bills')) {
      return const RamseyReply(
        "You can see all your recorded bills in the Bills Tracker section. It has a full calendar view and payment status for each one!",
      );
    }

    return const RamseyReply(
      "I'd love to help! I can assist with cooking, grocery tracking, or managing your budget. What's on your mind?",
      quickReplies: ['What can I cook?', 'How much did I spend this week?'],
    );
  }

  static String detectMeal(DateTime time) {
    // Force Philippine Time (UTC+8) for accurate local meal suggestions
    final phTime = time.toUtc().add(const Duration(hours: 8));
    final hour = phTime.hour;

    if (hour >= 5 && hour < 10) {
      return 'Breakfast';
    } else if (hour >= 10 && hour < 14) {
      return 'Lunch';
    } else if (hour >= 14 && hour < 18) {
      return 'Snack';
    } else if (hour >= 18 && hour < 22) {
      return 'Dinner';
    }
    return 'Midnight Snack';
  }

  void _resetCooking() {
    _step = RamseyStep.mealPrompt;
    _meal = null;
    _craving = null;
    _currentOptions = [];
  }

  bool _isSpendingAsk(String input) {
    return input.contains('spend') ||
        input.contains('spending') ||
        input.contains('gastos') ||
        input.contains('purchase') ||
        input.contains('how much did i');
  }

  bool _isBreakdownAsk(String input) {
    return input == 'yes' ||
        input == 'oo' ||
        input.contains('breakdown') ||
        input.contains('full breakdown') ||
        input.contains('show');
  }

  bool _isMealPlanAsk(String input) {
    return input.contains('weekly meal plan') ||
        input.contains('meal plan') ||
        input.contains('plan my meals') ||
        input.contains('meal prep');
  }

  String? _explicitMeal(String input) {
    if (input.contains('breakfast') || input.contains('almusal')) {
      return 'Breakfast';
    } else if (input.contains('lunch') || input.contains('tanghalian')) {
      return 'Lunch';
    } else if (input.contains('dinner') || input.contains('hapunan')) {
      return 'Dinner';
    } else if (input.contains('midnight')) {
      return 'Midnight Snack';
    } else if (input.contains('snack') || input.contains('merienda')) {
      return 'Snack';
    }
    return null;
  }

  bool _looksLikeCookingAsk(String input) {
    return input.contains('cook') ||
        input.contains('dish') ||
        input.contains('suggest') ||
        input.contains('luto') ||
        input.contains('ulam') ||
        input.contains('kain') ||
        input.contains('recipe') ||
        input.contains('what can i');
  }

  bool _isWeeklyBillAsk(String input) {
    return (input.contains('how much') && input.contains('bill')) ||
           input.contains('total bills this week') ||
           input.contains('bills this week') ||
           input.contains('bills for this week');
  }

  bool _isBillAsk(String input) {
    return input.contains('upcoming bills') ||
        input.contains('do i have bills') ||
        input.contains('any bills') ||
        input.contains('bayad') ||
        input.contains('overdue');
  }

  bool _isAnalyticsAsk(String input) {
    return input.contains('analytics') ||
        input.contains('insight') ||
        input.contains('habit') ||
        input.contains('chart') ||
        input.contains('summary');
  }

  bool _isBudgetAsk(String input) {
    return input.contains('budget') ||
        input.contains('limit') ||
        input.contains('magkano nalang');
  }

  bool _isExplicitBudgetAsk(String input) {
    return input.contains('my budget is') || input.contains('budget ko lang');
  }

  double? _parseAmount(String input) {
    final match = RegExp(r'(\d+)').firstMatch(input);
    if (match != null) {
      return double.tryParse(match.group(1)!);
    }
    return null;
  }

  RamseyReply _cravingPrompt() {
    return const RamseyReply(
      "What are you craving for?\n\n"
      "1. Healthy\n"
      "2. Soupy\n"
      "3. Spicy\n"
      "4. Anything\n"
      "5. Depends on what's in my fridge",
    );
  }

  String? _cravingFromInput(String input) {
    if (input == '1' || input.contains('healthy')) {
      return 'Healthy';
    } else if (input == '2' ||
        input.contains('soupy') ||
        input.contains('sabaw')) {
      return 'Soupy';
    } else if (input == '3' ||
        input.contains('spicy') ||
        input.contains('maanghang')) {
      return 'Spicy';
    } else if (input == '4' ||
        input.contains('anything') ||
        input.contains('kahit ano')) {
      return 'Anything';
    } else if (input == '5' ||
        input.contains('fridge') ||
        input.contains('ref')) {
      return "Depends on what's in my fridge";
    }
    return null;
  }

  List<RamseyDish> _pickDishes(String meal, String craving) {
    final pool = _candidateDishes(meal, craving);
    final shuffled = List<RamseyDish>.from(pool)..shuffle(_random);
    var picked = shuffled.take(5).toList();

    if (_sameAsLast(picked) && pool.length > 5) {
      shuffled.shuffle(_random);
      picked = shuffled.take(5).toList();
      if (_sameAsLast(picked)) {
        final first = picked.removeAt(0);
        picked.add(first);
      }
    }

    _lastDishNames = picked.map((dish) => dish.name).toList();
    return picked;
  }

  bool _sameAsLast(List<RamseyDish> dishes) {
    final names = dishes.map((dish) => dish.name).toSet();
    return names.length == _lastDishNames.length &&
        _lastDishNames.every(names.contains);
  }

  List<RamseyDish> _candidateDishes(String meal, String craving) {
    if (craving == "Depends on what's in my fridge") {
      final fridge = _recentIngredientKeywords();
      if (fridge.isEmpty) {
        return [];
      }
      final matches = _dishes.where((dish) {
        return dish.ingredientKeywords.any(fridge.contains);
      }).toList();
      if (matches.length >= 5) return matches;
      return matches;
    }

    if (craving == 'Anything') {
      return _dishes
          .where(
            (dish) => dish.meals.contains(meal) || dish.meals.contains('Any'),
          )
          .toList();
    }

    final matches = _dishes.where((dish) {
      final mealFits = dish.meals.contains(meal) || dish.meals.contains('Any');
      return mealFits && dish.tags.contains(craving);
    }).toList();

    if (matches.length >= 5) return matches;
    return _dishes.where((dish) => dish.tags.contains(craving)).toList();
  }

  Set<String> _recentIngredientKeywords() {
    final names = <String>{};
    final cutoff = _dateOnly(DateTime.now().subtract(const Duration(days: 5)));
    for (final list in AppState.recentLists) {
      if (_dateOnly(list.date).isBefore(cutoff)) continue;
      for (final item in list.items) {
        names.addAll(_keywordsFor(item.name));
      }
    }
    return names;
  }

  RamseyReply _spendingSummaryReply(String input) {
    final snapshot = _spendingSnapshot(input);
    _lastSpending = snapshot;
    if (snapshot.trips.isEmpty) {
      return RamseyReply(
        "Wala akong nakitang purchase data para sa ${snapshot.label}.\nMake sure your groceries are logged in the app.",
      );
    }

    final total = _tripTotal(snapshot.trips);
    final biggest = _biggestPurchase(snapshot.trips);
    final topCategory = _topCategory(snapshot.trips);

    return RamseyReply(
      "Here's your spending summary.\n\n"
      "Period: ${_formatRange(snapshot.start, snapshot.end)}\n"
      "Total spent: ₱${total.toStringAsFixed(2)}\n"
      "No. of trips: ${snapshot.trips.length}\n"
      "Biggest purchase: ${biggest.$1} - ₱${biggest.$2.toStringAsFixed(2)}\n"
      "Most bought category: $topCategory\n\n"
      "Want to see the full breakdown?",
      quickReplies: const ['Yes', 'Show breakdown'],
    );
  }

  RamseyReply _spendingBreakdownReply(_SpendingSnapshot snapshot) {
    if (snapshot.trips.isEmpty) {
      return RamseyReply(
        "Wala akong nakitang purchase data para sa ${snapshot.label}.\nMake sure your groceries are logged in the app.",
      );
    }

    final grouped = <String, List<GroceryItem>>{};
    for (final trip in snapshot.trips) {
      for (final item in trip.items) {
        grouped.putIfAbsent(item.category, () => []).add(item);
      }
    }

    final lines = <String>[];
    for (final entry in grouped.entries) {
      final subtotal = entry.value.fold(
        0.0,
        (sum, item) => sum + _itemTotal(item),
      );
      lines.add('${entry.key} - ₱${subtotal.toStringAsFixed(2)}');
      for (final item in entry.value.take(6)) {
        lines.add('- ${item.name}: ₱${_itemTotal(item).toStringAsFixed(2)}');
      }
    }

    return RamseyReply("Here's the full breakdown.\n\n${lines.join('\n')}");
  }

  _SpendingSnapshot _spendingSnapshot(String input) {
    final now = DateTime.now();
    late DateTime start;
    late DateTime end;
    late String label;

    if (input.contains('last week')) {
      final thisMonday = _mondayOf(now);
      start = thisMonday.subtract(const Duration(days: 7));
      end = thisMonday.subtract(const Duration(days: 1));
      label = 'last week';
    } else if (input.contains('this month')) {
      start = DateTime(now.year, now.month);
      end = _dateOnly(now);
      label = 'this month';
    } else if (input.contains('last month')) {
      final firstThisMonth = DateTime(now.year, now.month);
      start = DateTime(firstThisMonth.year, firstThisMonth.month - 1);
      end = firstThisMonth.subtract(const Duration(days: 1));
      label = 'last month';
    } else if (input.contains('this year')) {
      start = DateTime(now.year);
      end = _dateOnly(now);
      label = 'this year';
    } else {
      start = _mondayOf(now);
      end = _dateOnly(now);
      label = 'this week';
    }

    final trips = AppState.recentLists.where((trip) {
      final date = _dateOnly(trip.date);
      return !date.isBefore(start) && !date.isAfter(end);
    }).toList();

    return _SpendingSnapshot(
      label: label,
      start: start,
      end: end,
      trips: trips,
    );
  }

  DateTime _mondayOf(DateTime date) {
    final only = _dateOnly(date);
    return only.subtract(Duration(days: only.weekday - DateTime.monday));
  }

  DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  String _formatRange(DateTime start, DateTime end) {
    if (start.year == end.year && start.month == end.month) {
      return '${_monthName(start.month)} ${start.day} - ${end.day}, ${end.year}';
    }
    return '${_monthName(start.month)} ${start.day}, ${start.year} - ${_monthName(end.month)} ${end.day}, ${end.year}';
  }

  String _monthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[month - 1];
  }

  double _tripTotal(List<GroceryList> trips) {
    return trips.fold(
      0.0,
      (sum, trip) =>
          sum + trip.items.fold(0.0, (s, item) => s + _itemTotal(item)),
    );
  }

  double _itemTotal(GroceryItem item) {
    if (item.unit == 'g' || item.unit == 'mL') {
      return (item.price / 1000) * item.qty;
    }
    return item.price * item.qty;
  }

  (String, double) _biggestPurchase(List<GroceryList> trips) {
    GroceryItem? biggest;
    var biggestTotal = 0.0;
    for (final trip in trips) {
      for (final item in trip.items) {
        final total = _itemTotal(item);
        if (biggest == null || total > biggestTotal) {
          biggest = item;
          biggestTotal = total;
        }
      }
    }
    return (biggest?.name ?? 'None', biggestTotal);
  }

  String _topCategory(List<GroceryList> trips) {
    final totals = <String, double>{};
    for (final trip in trips) {
      for (final item in trip.items) {
        totals[item.category] = (totals[item.category] ?? 0) + _itemTotal(item);
      }
    }
    if (totals.isEmpty) return 'None';
    final entries = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.first.key;
  }

  double _calculateDishPrice(RamseyDish dish) {
    var total = 0.0;
    for (final ingredient in dish.ingredients) {
      final match = _findGroceryPrice(ingredient);
      if (match != null) {
        total += (match['price'] as num).toDouble();
      } else {
        total += 25.0; // Estimate for items with unknown prices
      }
    }
    return total;
  }

  List<RamseyDish> _pickDishesByBudget(double targetBudget) {
    final dishesWithPrices = _dishes.map((dish) {
      return (dish, _calculateDishPrice(dish));
    }).toList();

    // Sort by proximity to budget
    dishesWithPrices.sort((a, b) {
      final diffA = (a.$2 - targetBudget).abs();
      final diffB = (b.$2 - targetBudget).abs();
      return diffA.compareTo(diffB);
    });

    return dishesWithPrices.take(5).map((e) => e.$1).toList();
  }

  RamseyReply _budgetMealPlanReply(double weeklyBudget) {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final dailyBudget = weeklyBudget / 7;

    // Filter budget-friendly dishes for each category
    final bPool = _dishes.where((d) => d.meals.contains('Breakfast') && _calculateDishPrice(d) < (dailyBudget * 0.25)).toList()..shuffle(_random);
    final lPool = _dishes.where((d) => d.meals.contains('Lunch') && _calculateDishPrice(d) < (dailyBudget * 0.40)).toList()..shuffle(_random);
    final dPool = _dishes.where((d) => d.meals.contains('Dinner') && _calculateDishPrice(d) < (dailyBudget * 0.40)).toList()..shuffle(_random);

    // Fallback if pools are too small
    final fallbackPool = _dishes.toList()..shuffle(_random);

    final lines = <String>[];
    var estimatedTotal = 0.0;

    for (var i = 0; i < 7; i++) {
      final b = bPool.isNotEmpty ? bPool[i % bPool.length] : fallbackPool[i % fallbackPool.length];
      final l = lPool.isNotEmpty ? lPool[i % lPool.length] : fallbackPool[(i + 7) % fallbackPool.length];
      final d = dPool.isNotEmpty ? dPool[i % dPool.length] : fallbackPool[(i + 14) % fallbackPool.length];

      estimatedTotal += _calculateDishPrice(b) + _calculateDishPrice(l) + _calculateDishPrice(d);
      lines.add("**${days[i]}**: ${b.name}, ${l.name}, ${d.name}");
    }

    return RamseyReply(
      "I've designed a 7-day Filipino meal plan for your **₱${weeklyBudget.toStringAsFixed(0)}** budget! 🇵🇭\n\n"
      "${lines.join('\n')}\n\n"
      "**Estimated Total Cost**: ₱${estimatedTotal.toStringAsFixed(2)}\n\n"
      "Would you like me to generate a shopping list for these ingredients?",
    );
  }

  RamseyReply _weeklyMealPlanReply() {
    final days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    final breakfasts =
        _dishes.where((dish) => dish.meals.contains('Breakfast')).toList()
          ..shuffle(_random);
    final lunches =
        _dishes.where((dish) => dish.meals.contains('Lunch')).toList()
          ..shuffle(_random);
    final dinners =
        _dishes.where((dish) => dish.meals.contains('Dinner')).toList()
          ..shuffle(_random);

    final lines = <String>[];
    for (var i = 0; i < days.length; i++) {
      lines.add(
        '${days[i]}: ${breakfasts[i % breakfasts.length].name}, ${lunches[i % lunches.length].name}, ${dinners[i % dinners.length].name}',
      );
    }

    return RamseyReply(
      "Here's a simple weekly Filipino meal plan.\n\n${lines.join('\n')}",
    );
  }

  Set<String> _keywordsFor(String itemName) {
    final name = itemName.toLowerCase();
    final keywords = <String>{};
    final checks = {
      'egg': ['egg', 'itlog'],
      'rice': ['rice', 'bigas'],
      'chicken': ['chicken', 'manok'],
      'pork': ['pork', 'baboy', 'liempo'],
      'beef': ['beef', 'baka'],
      'fish': ['fish', 'tilapia', 'bangus', 'tuna', 'galunggong'],
      'shrimp': ['shrimp', 'hipon'],
      'tofu': ['tofu', 'tokwa'],
      'noodle': ['noodle', 'pancit', 'miki', 'bihon'],
      'vegetable': [
        'pechay',
        'kangkong',
        'sayote',
        'ampalaya',
        'okra',
        'talong',
        'eggplant',
        'malunggay',
        'cabbage',
        'sitaw',
        'squash',
        'kalabasa',
      ],
      'tomato': ['tomato', 'kamatis'],
      'coconut': ['coconut', 'gata'],
      'banana': ['banana', 'saba'],
      'bread': ['bread', 'pandesal'],
    };

    for (final entry in checks.entries) {
      if (entry.value.any(name.contains)) keywords.add(entry.key);
    }
    return keywords;
  }

  RamseyReply _handleMealInquiry(String meal, String craving) {
    _meal = meal;
    _craving = craving;
    
    final pool = _pickDishes(meal, craving).where((d) => 
      !_suggestedDishNames.contains(d.name)
    ).toList();

    if (pool.isEmpty) {
      _step = RamseyStep.mealPrompt;
      return const RamseyReply(
        "That's all I can find for now, sorry. 👨‍🍳 Is there anything else I can help you with?",
        quickReplies: ['Show my budget', 'Do I have upcoming bills?'],
      );
    }

    // Pick 3 new ones
    final count = min(3, pool.length);
    _currentOptions = pool.take(count).toList();
    for (final dish in _currentOptions) {
      _suggestedDishNames.add(dish.name);
    }

    _step = RamseyStep.dishPrompt;
    return _dishOptionsReply();
  }

  RamseyDish? _findDirectRecipeRequest(String input) {
    // Check if the input looks like a direct recipe request
    final hasRecipeKeyword = input.contains('recipe') ||
        input.contains('cook') ||
        input.contains('give') ||
        input.contains('want') ||
        input.contains('how to') ||
        input.contains('make') ||
        input.contains('prepare') ||
        input.contains('luto') ||
        input.contains('paano') ||
        input.contains('teach me') ||
        input.contains('lets') ||
        input.contains("let's") ||
        input.contains('cite') ||
        input.contains('ingredients') ||
        input.contains('whats the') ||
        input.contains("what's the");

    if (!hasRecipeKeyword) return null;

    // Try to match a dish name from our database
    RamseyDish? bestMatch;
    int bestMatchLength = 0;

    for (final dish in _dishes) {
      final dishName = dish.name.toLowerCase();
      if (input.contains(dishName) && dishName.length > bestMatchLength) {
        bestMatch = dish;
        bestMatchLength = dishName.length;
      }

      // Also try partial/common name matching
      // e.g. "adobo" matches "Chicken Adobo", "caldereta" matches "Chicken Afritada" won't
      final words = dishName.split(' ');
      for (final word in words) {
        if (word.length >= 4 && input.contains(word) && dishName.length > bestMatchLength) {
          bestMatch = dish;
          bestMatchLength = dishName.length;
        }
      }
    }

    return bestMatch;
  }

  RamseyReply _dishOptionsReply() {
    final meal = _meal ?? 'meal';
    final list = _currentOptions
        .asMap()
        .entries
        .map(
          (entry) =>
              "${entry.key + 1}. ${entry.value.name} - ${_shortInfo(entry.value)}",
        )
        .join('\n');

    return RamseyReply(
      "These are some excellent dishes you can cook for ${meal.toLowerCase()}...\n\n"
      "$list\n\n"
      "None of these suit your liking? Would you like me to suggest more? "
      "Or just type the number to see the recipe!",
      quickReplies: const ['Yes'],
    );
  }

  RamseyReply _recipeReply(RamseyDish dish) {
    final ingredients = dish.ingredients
        .map((item) => '- $item ${_ingredientPriceLabel(item)}')
        .join('\n');
    final steps = dish.instructions
        .asMap()
        .entries
        .map((entry) => '${entry.key + 1}. ${entry.value}')
        .join('\n');

    return RamseyReply(
      "Great choice! Here's how to cook ${dish.name}.\n\n"
      "Ingredients:\n"
      "$ingredients\n\n"
      "Instructions:\n"
      "$steps\n\n"
      "Cooking time: ${dish.minutes} mins\n"
      "Good for: ${dish.servings} servings\n\n"
      "Would you like me to add these ingredients to your cart?",
    );
  }

  void _addIngredientsToCart(RamseyDish dish) {
    final newList = GroceryList(
      dish.name,
      date: DateTime.now(),
      budget: 1000,
      items: [],
      store: 'Puregold',
    );

    for (final ingredient in dish.ingredients) {
      final dbMatch = _findGroceryPrice(ingredient);
      final price = (dbMatch?['price'] as num?)?.toDouble() ?? 25.0;
      final category = (dbMatch?['category'] as String?) ?? 'Other';
      final unit = (dbMatch?['unit'] as String?) ?? 'pc';

      newList.items.add(GroceryItem(
        id: DateTime.now().millisecondsSinceEpoch.toString() + ingredient.hashCode.toString(),
        name: ingredient.replaceAll(RegExp(r'\s*\[[^\]]*\]'), '').trim(),
        qty: 1,
        unit: unit,
        price: price,
        category: category,
      ));
    }

    AppState.lists.add(newList);
    AppState.activeIndex = AppState.lists.length - 1;
  }

  bool _isYes(String input) {
    final yesWords = [
      'yes', 'yea', 'yup', 'yess', 'yesss', 'yessss', 'yeas', 'yeah', 'yah', 'y',
      'opo', 'oo', 'sige', 'g', 'game', 'ok', 'okay', 'sure', 'add it', 'put it'
    ];
    return yesWords.any((w) => input.contains(w));
  }

  String _ingredientPriceLabel(String ingredient) {
    final match = _findGroceryPrice(ingredient);
    if (match == null) return '[price varies]';
    final price = (match['price'] as num).toDouble();
    final unit = match['unit'] as String;
    return '[~\u20B1${price.toStringAsFixed(0)}/$unit]';
  }

  Map<String, dynamic>? _findGroceryPrice(String ingredient) {
    final normalized = ingredient.toLowerCase();
    final exact = GroceryDatabase.items.where((item) {
      final name = (item['name'] as String).toLowerCase();
      final cleanedName = name.replaceAll(RegExp(r'\s*\([^)]*\)'), '');
      return normalized.contains(cleanedName) ||
          cleanedName.contains(normalized);
    }).toList();
    if (exact.isNotEmpty) return exact.first;

    final ingredientKeywords = _keywordsFor(ingredient);
    for (final item in GroceryDatabase.items) {
      final itemKeywords = _keywordsFor(item['name'] as String);
      if (itemKeywords.any(ingredientKeywords.contains)) return item;
    }
    return null;
  }

  String _shortInfo(RamseyDish dish) {
    if (dish.shortInfo != 'Classic Filipino favorite') {
      return dish.shortInfo;
    }
    if (dish.tags.contains('Soupy')) {
      return 'Comforting sabaw, perfect with rice';
    }
    if (dish.tags.contains('Spicy')) {
      return 'Maanghang and full of flavor';
    }
    if (dish.tags.contains('Healthy')) {
      return 'Light, gulay-forward, and filling';
    }
    return 'Easy Filipino favorite for any craving';
  }

  RamseyReply _weeklyBillsSummaryReply() {
    final upcoming = _getUpcomingBillsWithin7Days();
    if (upcoming.isEmpty) {
      return const RamseyReply(
        "You don't have any bills due for the next 7 days. You're all clear for now! \ud83d\ude4c",
      );
    }

    final total = upcoming.fold(0.0, (sum, bill) => sum + bill.amount);
    String list = '';
    for (final bill in upcoming) {
      final formatted = _formatDateNicely(bill.dueDate);
      list += "\u2022 ${bill.type}: \u20b1${bill.amount.toStringAsFixed(2)} ($formatted)\n";
    }

    return RamseyReply(
      "Your total bills for this week (next 7 days) is \u20b1${total.toStringAsFixed(2)}.\n\n"
      "Here's the breakdown:\n"
      "$list\n"
      "Make sure to settle them on time! \ud83d\udcb3",
    );
  }

  RamseyReply _billsSummaryReply() {
    if (_allBills.isEmpty) {
      return const RamseyReply(
        "I can help you keep track of your payments! \ud83d\udcc5\n\n"
        "Currently, you don't have any bills recorded. Head over to the Bills Tracker to add your first bill, and I'll help you monitor it!",
      );
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final upcoming = _allBills.where((b) => !b.isPaid && !b.dueDate.isBefore(today)).toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));

    if (upcoming.isEmpty) {
      return const RamseyReply(
        "Good news! You have no upcoming bills for now. \ud83d\udcc5\n\n"
        "You're all caught up! Is there anything else I can help you with?",
      );
    }

    final nextBill = upcoming.first;
    final dateStr = "${_monthName(nextBill.dueDate.month)} ${nextBill.dueDate.day}";

    return RamseyReply(
      "Your upcoming bill is ${nextBill.type} amounting to \u20b1${nextBill.amount.toStringAsFixed(2)} on $dateStr.\n\n"
      "Do you want me to notify you 3 days before the due date?",
      quickReplies: ['Yes, notify me', 'No, thanks'],
    );
  }

  RamseyReply _budgetSummaryReply() {
    final recent =
        AppState.recentLists.isNotEmpty ? AppState.recentLists.first : null;
    if (recent == null) {
      return const RamseyReply(
        "Wala pa akong nakitang active budget. Start a shopping list and set a budget so I can help you track it! 💰",
      );
    }

    final total = recent.items.fold(0.0, (s, i) => s + _itemTotal(i));
    final remaining = recent.budget - total;

    return RamseyReply(
      "Para sa list mong '${recent.name}':\n\n"
      "Budget: ₱${recent.budget.toStringAsFixed(2)}\n"
      "Spent so far: ₱${total.toStringAsFixed(2)}\n"
      "Remaining: ₱${remaining.toStringAsFixed(2)}\n\n"
      "${remaining < 0 ? 'Huy, over budget na tayo! 🚨' : 'Safe pa tayo! Tipid-tipid lang.'}",
      quickReplies: ['Suggest a dish based on this', 'Show analytics'],
    );
  }

  RamseyReply _analyticsSummaryReply() {
    final trips = AppState.recentLists;
    if (trips.isEmpty) {
      return const RamseyReply(
        "Wala pa akong enough data to show analytics. Finish more shopping trips para matulungan kita! 📊",
      );
    }

    final topCat = _topCategory(trips);
    final totalSpent = _tripTotal(trips);

    return RamseyReply(
      "I've checked your habits! 📊\n\n"
      "Total Recorded Spend: ₱${totalSpent.toStringAsFixed(2)}\n"
      "Top Category: $topCat\n\n"
      "You can see the full charts in the **Insights** tab!",
      quickReplies: ['Check budget', 'What can I luto?'],
    );
  }
}

const List<RamseyDish> _dishes = [
  RamseyDish(
    name: 'Tortang Talong',
    ingredients: [
      '2 eggplants',
      '2 eggs',
      '1 tomato, chopped',
      '1 small onion, chopped',
      'Salt and pepper',
      'Cooking oil',
    ],
    instructions: [
      'Grill or boil eggplants until soft, then peel the skin.',
      'Flatten each eggplant with a fork.',
      'Beat eggs with tomato, onion, salt, and pepper.',
      'Dip eggplants in the egg mix.',
      'Pan-fry until golden on both sides.',
    ],
    minutes: 25,
    servings: 2,
    tags: {'Healthy', 'Anything'},
    meals: {'Breakfast', 'Lunch', 'Dinner'},
    ingredientKeywords: {'egg', 'vegetable', 'tomato'},
  ),
  RamseyDish(
    name: 'Arroz Caldo',
    ingredients: [
      '1 cup rice',
      '250g chicken pieces',
      'Ginger',
      'Garlic',
      'Onion',
      'Fish sauce',
      'Water or broth',
      'Boiled egg',
      'Spring onion',
    ],
    instructions: [
      'Saute garlic, onion, and ginger.',
      'Add chicken and fish sauce, then cook lightly.',
      'Add rice and broth.',
      'Simmer until rice is soft and creamy.',
      'Top with boiled egg and spring onion.',
    ],
    minutes: 45,
    servings: 4,
    tags: {'Soupy', 'Anything'},
    meals: {'Breakfast', 'Snack', 'Midnight Snack'},
    ingredientKeywords: {'rice', 'chicken', 'egg'},
  ),
  RamseyDish(
    name: 'Ginisang Ampalaya with Egg',
    ingredients: [
      '1 ampalaya, sliced',
      '2 eggs',
      'Tomato',
      'Onion',
      'Garlic',
      'Salt',
      'Cooking oil',
    ],
    instructions: [
      'Salt the ampalaya for 10 minutes, then rinse lightly.',
      'Saute garlic, onion, and tomato.',
      'Add ampalaya and cook until tender-crisp.',
      'Pour in beaten eggs.',
      'Stir gently until eggs set.',
    ],
    minutes: 25,
    servings: 3,
    tags: {'Healthy'},
    meals: {'Breakfast', 'Lunch', 'Dinner'},
    ingredientKeywords: {'egg', 'vegetable', 'tomato'},
  ),
  RamseyDish(
    name: 'Tinolang Manok',
    ingredients: [
      '500g chicken',
      'Ginger',
      'Garlic',
      'Onion',
      'Sayote or papaya',
      'Malunggay leaves',
      'Fish sauce',
      'Water',
    ],
    instructions: [
      'Saute ginger, garlic, and onion.',
      'Add chicken and fish sauce.',
      'Pour in water and simmer until chicken is tender.',
      'Add sayote or papaya.',
      'Finish with malunggay leaves.',
    ],
    minutes: 45,
    servings: 4,
    tags: {'Healthy', 'Soupy', 'Anything'},
    meals: {'Lunch', 'Dinner'},
    ingredientKeywords: {'chicken', 'vegetable'},
  ),
  RamseyDish(
    name: 'Sinigang na Bangus',
    ingredients: [
      'Bangus slices',
      'Tomato',
      'Onion',
      'Radish',
      'Kangkong',
      'Okra',
      'Sinigang mix or tamarind',
      'Fish sauce',
    ],
    instructions: [
      'Boil water with tomato and onion.',
      'Add bangus and simmer gently.',
      'Add radish and okra.',
      'Season with tamarind and fish sauce.',
      'Add kangkong before serving.',
    ],
    minutes: 35,
    servings: 4,
    tags: {'Healthy', 'Soupy', 'Anything'},
    meals: {'Lunch', 'Dinner'},
    ingredientKeywords: {'fish', 'vegetable', 'tomato'},
  ),
  RamseyDish(
    name: 'Laing',
    ingredients: [
      'Dried taro leaves',
      'Coconut milk',
      'Shrimp paste',
      'Garlic',
      'Onion',
      'Ginger',
      'Chili',
      'Pork or dried fish',
    ],
    instructions: [
      'Simmer coconut milk with aromatics and shrimp paste.',
      'Add pork or dried fish if using.',
      'Add taro leaves without stirring at first.',
      'Simmer until leaves soften.',
      'Add chili and cook until creamy.',
    ],
    minutes: 50,
    servings: 4,
    tags: {'Spicy', 'Anything'},
    meals: {'Lunch', 'Dinner'},
    ingredientKeywords: {'coconut', 'pork', 'fish', 'vegetable'},
  ),
  RamseyDish(
    name: 'Bicol Express',
    ingredients: [
      '500g pork belly',
      'Coconut milk',
      'Shrimp paste',
      'Garlic',
      'Onion',
      'Ginger',
      'Green chilies',
      'Red chilies',
    ],
    instructions: [
      'Saute garlic, onion, and ginger.',
      'Add pork and cook until lightly browned.',
      'Stir in shrimp paste.',
      'Pour coconut milk and simmer until pork is tender.',
      'Add chilies and reduce until saucy.',
    ],
    minutes: 55,
    servings: 4,
    tags: {'Spicy', 'Anything'},
    meals: {'Lunch', 'Dinner'},
    ingredientKeywords: {'pork', 'coconut'},
  ),
  RamseyDish(
    name: 'Pancit Bihon',
    ingredients: [
      'Bihon noodles',
      'Chicken or pork',
      'Cabbage',
      'Carrots',
      'Garlic',
      'Onion',
      'Soy sauce',
      'Broth',
    ],
    instructions: [
      'Saute garlic, onion, and meat.',
      'Add vegetables and cook briefly.',
      'Pour in broth and soy sauce.',
      'Add bihon and toss until noodles absorb liquid.',
      'Serve with calamansi.',
    ],
    minutes: 35,
    servings: 5,
    tags: {'Anything'},
    meals: {'Lunch', 'Snack', 'Dinner'},
    ingredientKeywords: {'noodle', 'chicken', 'pork', 'vegetable'},
  ),
  RamseyDish(
    name: 'Lumpiang Sariwa',
    ingredients: [
      'Fresh lumpia wrappers',
      'Ubod or mixed vegetables',
      'Tofu or shrimp',
      'Garlic',
      'Peanuts',
      'Lumpia sauce',
    ],
    instructions: [
      'Saute garlic, vegetables, and tofu or shrimp.',
      'Warm the wrappers.',
      'Fill each wrapper with cooked filling.',
      'Fold and plate.',
      'Top with sauce and peanuts.',
    ],
    minutes: 40,
    servings: 4,
    tags: {'Healthy', 'Anything'},
    meals: {'Snack', 'Lunch'},
    ingredientKeywords: {'tofu', 'shrimp', 'vegetable'},
  ),
  RamseyDish(
    name: 'Chicken Adobo',
    ingredients: [
      '500g chicken',
      'Soy sauce',
      'Vinegar',
      'Garlic',
      'Bay leaf',
      'Peppercorns',
      'Water',
      'Oil',
    ],
    instructions: [
      'Marinate chicken in soy sauce and garlic for 15 minutes.',
      'Sear chicken in a pan.',
      'Add marinade, vinegar, bay leaf, peppercorns, and water.',
      'Simmer until tender.',
      'Reduce sauce to your liking.',
    ],
    minutes: 50,
    servings: 4,
    tags: {'Anything'},
    meals: {'Lunch', 'Dinner'},
    ingredientKeywords: {'chicken'},
  ),
  RamseyDish(
    name: 'Ginisang Munggo',
    ingredients: [
      '1 cup mung beans',
      'Tinapa or pork',
      'Garlic',
      'Onion',
      'Tomato',
      'Malunggay or ampalaya leaves',
      'Fish sauce',
    ],
    instructions: [
      'Boil mung beans until soft.',
      'Saute garlic, onion, tomato, and tinapa or pork.',
      'Add cooked mung beans with broth.',
      'Simmer and season with fish sauce.',
      'Add greens before serving.',
    ],
    minutes: 60,
    servings: 4,
    tags: {'Healthy', 'Soupy', 'Anything'},
    meals: {'Lunch', 'Dinner'},
    ingredientKeywords: {'fish', 'pork', 'vegetable', 'tomato'},
  ),
  RamseyDish(
    name: 'Champorado',
    ingredients: [
      'Glutinous rice',
      'Tablea or cocoa powder',
      'Sugar',
      'Water',
      'Evaporated milk',
      'Tuyo on the side',
    ],
    instructions: [
      'Boil glutinous rice in water.',
      'Stir often until grains soften.',
      'Add tablea or cocoa powder.',
      'Sweeten to taste.',
      'Serve with milk and tuyo if you like.',
    ],
    minutes: 35,
    servings: 4,
    tags: {'Anything'},
    meals: {'Breakfast', 'Snack', 'Midnight Snack'},
    ingredientKeywords: {'rice'},
  ),
  RamseyDish(
    name: 'Pandesal Egg Sandwich',
    ingredients: [
      '4 pandesal',
      '2 eggs',
      'Mayonnaise',
      'Salt and pepper',
      'Cheese, optional',
    ],
    instructions: [
      'Boil or scramble the eggs.',
      'Mash eggs with mayonnaise, salt, and pepper.',
      'Toast pandesal lightly.',
      'Fill with egg mixture.',
      'Add cheese if desired.',
    ],
    minutes: 15,
    servings: 2,
    tags: {'Anything'},
    meals: {'Breakfast', 'Snack', 'Midnight Snack'},
    ingredientKeywords: {'egg', 'bread'},
  ),
  RamseyDish(
    name: 'Tuna Sisig',
    ingredients: [
      'Canned tuna',
      'Onion',
      'Chili',
      'Calamansi',
      'Mayonnaise',
      'Soy sauce',
      'Pepper',
      'Oil',
    ],
    instructions: [
      'Drain tuna well.',
      'Saute onion and chili.',
      'Add tuna and cook until lightly toasted.',
      'Season with soy sauce, calamansi, and pepper.',
      'Stir in mayonnaise off heat.',
    ],
    minutes: 20,
    servings: 2,
    tags: {'Spicy', 'Anything'},
    meals: {'Lunch', 'Dinner', 'Midnight Snack'},
    ingredientKeywords: {'fish'},
  ),
  RamseyDish(
    name: 'Tokwa at Baboy',
    ingredients: [
      'Tofu cubes',
      'Boiled pork belly',
      'Soy sauce',
      'Vinegar',
      'Onion',
      'Chili',
      'Sugar',
      'Pepper',
    ],
    instructions: [
      'Fry tofu until crisp.',
      'Slice boiled pork belly.',
      'Mix soy sauce, vinegar, onion, chili, sugar, and pepper.',
      'Combine tofu and pork.',
      'Pour sauce over before serving.',
    ],
    minutes: 35,
    servings: 4,
    tags: {'Spicy', 'Anything'},
    meals: {'Snack', 'Dinner', 'Midnight Snack'},
    ingredientKeywords: {'tofu', 'pork'},
  ),
  RamseyDish(
    name: 'Chicken Sopas',
    ingredients: [
      'Macaroni',
      'Shredded chicken',
      'Garlic',
      'Onion',
      'Carrots',
      'Cabbage',
      'Evaporated milk',
      'Broth',
    ],
    instructions: [
      'Saute garlic and onion.',
      'Add chicken and broth.',
      'Add macaroni and cook until tender.',
      'Stir in carrots, cabbage, and milk.',
      'Season and simmer briefly.',
    ],
    minutes: 40,
    servings: 5,
    tags: {'Soupy', 'Anything'},
    meals: {'Snack', 'Dinner', 'Midnight Snack'},
    ingredientKeywords: {'chicken', 'noodle', 'vegetable'},
  ),
  RamseyDish(
    name: 'Batchoy',
    ingredients: [
      'Miki noodles',
      'Pork slices',
      'Pork liver, optional',
      'Garlic',
      'Onion',
      'Broth',
      'Chicharon',
      'Spring onion',
    ],
    instructions: [
      'Prepare hot pork broth with garlic and onion.',
      'Cook pork and liver until tender.',
      'Blanch miki noodles.',
      'Pour broth over noodles and meat.',
      'Top with chicharon and spring onion.',
    ],
    minutes: 45,
    servings: 4,
    tags: {'Soupy', 'Anything'},
    meals: {'Snack', 'Dinner', 'Midnight Snack'},
    ingredientKeywords: {'noodle', 'pork'},
  ),
  RamseyDish(
    name: 'Spicy Gising-Gising',
    ingredients: [
      'Baguio beans or winged beans',
      'Ground pork',
      'Coconut milk',
      'Shrimp paste',
      'Garlic',
      'Onion',
      'Chili',
    ],
    instructions: [
      'Saute garlic, onion, and ground pork.',
      'Add shrimp paste.',
      'Add chopped beans.',
      'Pour coconut milk and simmer.',
      'Add chili and cook until creamy.',
    ],
    minutes: 35,
    servings: 4,
    tags: {'Spicy', 'Healthy'},
    meals: {'Lunch', 'Dinner'},
    ingredientKeywords: {'pork', 'coconut', 'vegetable'},
  ),
  RamseyDish(
    name: 'Ensaladang Talong with Salted Egg',
    ingredients: [
      'Grilled eggplant',
      'Salted egg',
      'Tomato',
      'Onion',
      'Vinegar',
      'Salt and pepper',
    ],
    instructions: [
      'Peel grilled eggplant and chop roughly.',
      'Dice salted egg, tomato, and onion.',
      'Combine everything in a bowl.',
      'Add vinegar, salt, and pepper.',
      'Chill or serve right away.',
    ],
    minutes: 20,
    servings: 3,
    tags: {'Healthy'},
    meals: {'Lunch', 'Dinner'},
    ingredientKeywords: {'egg', 'vegetable', 'tomato'},
  ),
  RamseyDish(
    name: 'Suman at Mangga',
    ingredients: [
      'Cooked suman',
      'Ripe mango',
      'Sugar, optional',
      'Hot chocolate, optional',
    ],
    instructions: [
      'Warm the suman.',
      'Slice ripe mango.',
      'Plate suman with mango slices.',
      'Sprinkle sugar if desired.',
      'Serve with hot chocolate if available.',
    ],
    minutes: 10,
    servings: 2,
    tags: {'Anything'},
    meals: {'Breakfast', 'Snack', 'Midnight Snack'},
    ingredientKeywords: {'rice'},
  ),
  RamseyDish(
    name: 'Banana Cue',
    ingredients: ['Saba bananas', 'Brown sugar', 'Cooking oil', 'Skewers'],
    instructions: [
      'Heat oil in a pan.',
      'Add saba bananas and fry briefly.',
      'Add brown sugar and let it caramelize.',
      'Coat bananas evenly.',
      'Skewer and serve warm.',
    ],
    minutes: 20,
    servings: 4,
    tags: {'Anything'},
    meals: {'Snack', 'Midnight Snack'},
    ingredientKeywords: {'banana'},
  ),
  RamseyDish(
    name: 'Nilagang Baka',
    ingredients: [
      'Beef shank or brisket',
      'Onion',
      'Peppercorns',
      'Potatoes',
      'Cabbage',
      'Pechay',
      'Fish sauce',
    ],
    instructions: [
      'Boil beef with onion and peppercorns until tender.',
      'Skim the broth as needed.',
      'Add potatoes and simmer.',
      'Season with fish sauce.',
      'Add cabbage and pechay before serving.',
    ],
    minutes: 90,
    servings: 5,
    tags: {'Soupy', 'Anything'},
    meals: {'Lunch', 'Dinner'},
    ingredientKeywords: {'beef', 'vegetable'},
  ),
  RamseyDish(
    name: 'Pinakbet',
    ingredients: [
      'Squash',
      'Eggplant',
      'Okra',
      'String beans',
      'Ampalaya',
      'Tomato',
      'Shrimp paste',
      'Pork, optional',
    ],
    instructions: [
      'Saute garlic, onion, tomato, and pork if using.',
      'Add shrimp paste.',
      'Add squash with a splash of water.',
      'Add remaining vegetables.',
      'Simmer until tender but not mushy.',
    ],
    minutes: 40,
    servings: 4,
    tags: {'Healthy', 'Anything'},
    meals: {'Lunch', 'Dinner'},
    ingredientKeywords: {'pork', 'vegetable', 'tomato'},
  ),
  RamseyDish(
    name: 'Sardinas Misua',
    ingredients: [
      'Canned sardines',
      'Misua',
      'Garlic',
      'Onion',
      'Tomato',
      'Water',
      'Pechay, optional',
    ],
    instructions: [
      'Saute garlic, onion, and tomato.',
      'Add sardines and water.',
      'Bring to a gentle boil.',
      'Add misua and pechay.',
      'Cook for 2 minutes and serve.',
    ],
    minutes: 20,
    servings: 3,
    tags: {'Soupy', 'Spicy', 'Anything'},
    meals: {'Breakfast', 'Lunch', 'Dinner', 'Midnight Snack'},
    ingredientKeywords: {'fish', 'noodle', 'tomato', 'vegetable'},
  ),
  RamseyDish(
    name: 'Daing na Bangus with Garlic Rice',
    ingredients: [
      'Daing na bangus',
      'Cooked rice',
      'Garlic',
      'Egg',
      'Tomato',
      'Oil',
    ],
    instructions: [
      'Fry daing na bangus until crisp.',
      'Saute garlic in a separate pan.',
      'Add rice and season lightly.',
      'Fry egg sunny-side up.',
      'Serve with tomato on the side.',
    ],
    minutes: 25,
    servings: 2,
    tags: {'Anything'},
    meals: {'Breakfast', 'Lunch'},
    ingredientKeywords: {'fish', 'rice', 'egg', 'tomato'},
  ),
  RamseyDish(
    name: 'Ginataang Kalabasa at Sitaw',
    ingredients: [
      'Squash',
      'String beans',
      'Coconut milk',
      'Shrimp or pork',
      'Garlic',
      'Onion',
      'Fish sauce',
    ],
    instructions: [
      'Saute garlic, onion, and shrimp or pork.',
      'Add squash and coconut milk.',
      'Simmer until squash softens.',
      'Add string beans.',
      'Season and cook until creamy.',
    ],
    minutes: 35,
    servings: 4,
    tags: {'Healthy', 'Anything'},
    meals: {'Lunch', 'Dinner'},
    ingredientKeywords: {'coconut', 'shrimp', 'pork', 'vegetable'},
  ),
  RamseyDish(
    name: 'Pork Sinigang',
    ingredients: [
      'Pork ribs or belly',
      'Tomato',
      'Onion',
      'Radish',
      'Okra',
      'Kangkong',
      'Sinigang mix or tamarind',
      'Fish sauce',
    ],
    instructions: [
      'Boil pork with tomato and onion until tender.',
      'Add radish and okra.',
      'Season with tamarind and fish sauce.',
      'Simmer until vegetables are done.',
      'Add kangkong last.',
    ],
    minutes: 70,
    servings: 5,
    tags: {'Soupy', 'Anything'},
    meals: {'Lunch', 'Dinner'},
    ingredientKeywords: {'pork', 'vegetable', 'tomato'},
  ),
  RamseyDish(
    name: 'Spicy Adobong Sitaw',
    ingredients: [
      'String beans',
      'Pork pieces',
      'Soy sauce',
      'Vinegar',
      'Garlic',
      'Chili',
      'Pepper',
    ],
    instructions: [
      'Saute garlic and pork.',
      'Add string beans and stir-fry.',
      'Pour soy sauce and vinegar.',
      'Add chili and pepper.',
      'Cook until beans are tender-crisp.',
    ],
    minutes: 30,
    servings: 4,
    tags: {'Spicy', 'Healthy'},
    meals: {'Lunch', 'Dinner'},
    ingredientKeywords: {'pork', 'vegetable'},
  ),
  RamseyDish(
    name: 'Longsilog',
    shortInfo: 'Sweet longganisa breakfast plate',
    ingredients: [
      'Longganisa',
      'Cooked rice',
      'Garlic',
      'Egg',
      'Tomato',
      'Cooking oil',
    ],
    instructions: [
      'Cook longganisa with a little water until the water dries up.',
      'Add oil and fry until browned.',
      'Saute garlic, then toss in cooked rice.',
      'Fry the egg sunny-side up.',
      'Serve longganisa with garlic rice, egg, and tomato.',
    ],
    minutes: 25,
    servings: 2,
    tags: {'Anything'},
    meals: {'Breakfast'},
    ingredientKeywords: {'pork', 'rice', 'egg', 'tomato'},
  ),
  RamseyDish(
    name: 'Tapsilog',
    shortInfo: 'Beef tapa with garlic rice and egg',
    ingredients: [
      'Beef tapa',
      'Cooked rice',
      'Garlic',
      'Egg',
      'Vinegar dip',
      'Cooking oil',
    ],
    instructions: [
      'Pan-fry beef tapa until caramelized and tender.',
      'Saute garlic until fragrant.',
      'Add cooked rice and season lightly.',
      'Fry the egg to your liking.',
      'Serve with vinegar dip on the side.',
    ],
    minutes: 30,
    servings: 2,
    tags: {'Anything'},
    meals: {'Breakfast', 'Lunch'},
    ingredientKeywords: {'beef', 'rice', 'egg'},
  ),
  RamseyDish(
    name: 'Paksiw na Isda',
    shortInfo: 'Tangy fish simmered in vinegar',
    ingredients: [
      'Fish slices',
      'Vinegar',
      'Ginger',
      'Garlic',
      'Onion',
      'Ampalaya or eggplant',
      'Chili',
    ],
    instructions: [
      'Arrange fish, ginger, garlic, onion, and vegetables in a pot.',
      'Pour in vinegar and a splash of water.',
      'Season with salt and pepper.',
      'Simmer without stirring until fish is cooked.',
      'Add chili and adjust seasoning.',
    ],
    minutes: 30,
    servings: 4,
    tags: {'Healthy', 'Spicy', 'Anything'},
    meals: {'Lunch', 'Dinner'},
    ingredientKeywords: {'fish', 'vegetable'},
  ),
  RamseyDish(
    name: 'Pork Giniling',
    shortInfo: 'Saucy ground pork with vegetables',
    ingredients: [
      'Ground pork',
      'Potato',
      'Carrot',
      'Tomato sauce',
      'Garlic',
      'Onion',
      'Soy sauce',
    ],
    instructions: [
      'Saute garlic and onion.',
      'Add ground pork and cook until no longer pink.',
      'Add potatoes and carrots.',
      'Pour in tomato sauce and a little water.',
      'Simmer until vegetables are tender.',
    ],
    minutes: 35,
    servings: 4,
    tags: {'Anything'},
    meals: {'Lunch', 'Dinner'},
    ingredientKeywords: {'pork', 'vegetable', 'tomato'},
  ),
  RamseyDish(
    name: 'Chicken Afritada',
    shortInfo: 'Tomato-based chicken ulam',
    ingredients: [
      'Chicken pieces',
      'Tomato sauce',
      'Potato',
      'Carrot',
      'Bell pepper',
      'Garlic',
      'Onion',
    ],
    instructions: [
      'Saute garlic and onion.',
      'Add chicken and brown lightly.',
      'Pour in tomato sauce and water.',
      'Add potatoes and carrots, then simmer.',
      'Finish with bell pepper and season to taste.',
    ],
    minutes: 50,
    servings: 4,
    tags: {'Anything'},
    meals: {'Lunch', 'Dinner'},
    ingredientKeywords: {'chicken', 'vegetable', 'tomato'},
  ),
  RamseyDish(
    name: 'Pesang Tilapia',
    shortInfo: 'Clean ginger fish soup',
    ingredients: [
      'Tilapia',
      'Ginger',
      'Onion',
      'Pechay',
      'Cabbage',
      'Potato',
      'Fish sauce',
    ],
    instructions: [
      'Boil water with ginger and onion.',
      'Add potatoes and simmer until almost tender.',
      'Add tilapia and cook gently.',
      'Season with fish sauce.',
      'Add pechay and cabbage before serving.',
    ],
    minutes: 35,
    servings: 4,
    tags: {'Healthy', 'Soupy'},
    meals: {'Lunch', 'Dinner'},
    ingredientKeywords: {'fish', 'vegetable'},
  ),
  RamseyDish(
    name: 'Beef Mami',
    shortInfo: 'Warm noodle soup for late cravings',
    ingredients: [
      'Beef slices',
      'Noodles',
      'Garlic',
      'Onion',
      'Broth',
      'Pechay',
      'Spring onion',
    ],
    instructions: [
      'Simmer beef in broth until tender.',
      'Saute garlic and onion, then add to the broth.',
      'Cook noodles separately.',
      'Place noodles in bowls with pechay.',
      'Pour hot beef broth over and top with spring onion.',
    ],
    minutes: 55,
    servings: 4,
    tags: {'Soupy', 'Anything'},
    meals: {'Snack', 'Dinner', 'Midnight Snack'},
    ingredientKeywords: {'beef', 'noodle', 'vegetable'},
  ),
  RamseyDish(
    name: 'Dinengdeng',
    shortInfo: 'Ilocano vegetable soup with fish',
    ingredients: [
      'Mixed vegetables',
      'Fried fish',
      'Bagoong isda',
      'Ginger',
      'Tomato',
      'Water',
    ],
    instructions: [
      'Boil water with ginger, tomato, and bagoong isda.',
      'Add firm vegetables first.',
      'Add leafy vegetables near the end.',
      'Place fried fish on top.',
      'Simmer briefly and serve hot.',
    ],
    minutes: 35,
    servings: 4,
    tags: {'Healthy', 'Soupy'},
    meals: {'Lunch', 'Dinner'},
    ingredientKeywords: {'fish', 'vegetable', 'tomato'},
  ),
  RamseyDish(
    name: 'Filipino Spaghetti',
    shortInfo: 'Sweet-style birthday party classic',
    ingredients: ['Spaghetti noodles', 'Ground pork', 'Hotdogs', 'Filipino sweet spaghetti sauce', 'Banana ketchup', 'Cheddar cheese', 'Garlic', 'Onion', 'Cooking oil'],
    instructions: ['Boil noodles until al dente, drain.', 'Saute garlic and onion, add ground pork.', 'Add sliced hotdogs and cook briefly.', 'Pour in spaghetti sauce and banana ketchup.', 'Simmer for 10 minutes.', 'Toss with noodles and top with cheese.'],
    minutes: 30, servings: 6,
    tags: {'Anything'}, meals: {'Lunch', 'Dinner', 'Snack'},
    ingredientKeywords: {'noodle', 'pork'},
  ),
  RamseyDish(
    name: 'Lumpiang Shanghai',
    shortInfo: 'Crispy spring rolls, fiesta must-have',
    ingredients: ['Ground pork', 'Carrots', 'Onion', 'Garlic', 'Egg', 'Soy sauce', 'Salt and pepper', 'Lumpia wrapper', 'Cooking oil'],
    instructions: ['Mix ground pork, minced carrots, onion, garlic, egg, and soy sauce.', 'Season with salt and pepper.', 'Wrap in lumpia wrappers, roll tightly.', 'Deep fry in hot oil until golden brown.', 'Drain on paper towels and serve with sweet chili sauce.'],
    minutes: 45, servings: 8,
    tags: {'Anything'}, meals: {'Lunch', 'Dinner', 'Snack'},
    ingredientKeywords: {'pork', 'egg'},
  ),
  RamseyDish(
    name: 'Beef Caldereta',
    shortInfo: 'Rich tomato beef stew, fiesta favorite',
    ingredients: ['Beef chunks', 'Potatoes', 'Carrots', 'Bell pepper', 'Tomato sauce', 'Liver spread', 'Garlic', 'Onion', 'Bay leaves', 'Soy sauce', 'Cooking oil'],
    instructions: ['Saute garlic and onion.', 'Brown beef on all sides.', 'Add soy sauce and tomato sauce, simmer until tender.', 'Add potatoes, carrots, and bell pepper.', 'Stir in liver spread to thicken.', 'Simmer until vegetables are cooked.'],
    minutes: 90, servings: 6,
    tags: {'Spicy', 'Anything'}, meals: {'Lunch', 'Dinner'},
    ingredientKeywords: {'beef', 'tomato'},
  ),
  RamseyDish(
    name: 'Kare-Kare',
    shortInfo: 'Peanut-based oxtail stew, special occasion dish',
    ingredients: ['Oxtail', 'Peanut butter', 'Eggplant', 'String beans', 'Pechay', 'Banana heart', 'Annatto powder', 'Toasted rice flour', 'Garlic', 'Onion', 'Bagoong alamang'],
    instructions: ['Boil oxtail until tender, reserve broth.', 'Saute garlic and onion, add annatto powder.', 'Add broth and peanut butter, stir well.', 'Add toasted rice flour to thicken.', 'Add vegetables and cook until tender.', 'Serve with bagoong alamang.'],
    minutes: 120, servings: 6,
    tags: {'Anything'}, meals: {'Lunch', 'Dinner'},
    ingredientKeywords: {'beef', 'vegetable'},
  ),
  RamseyDish(
    name: 'Menudo',
    shortInfo: 'Hearty pork and liver tomato stew',
    ingredients: ['Diced pork', 'Pork liver', 'Potatoes', 'Carrots', 'Tomato sauce', 'Soy sauce', 'Garlic', 'Onion', 'Bay leaves', 'Green peas', 'Hotdogs', 'Cooking oil'],
    instructions: ['Saute garlic and onion.', 'Add diced pork and cook until browned.', 'Add pork liver and cook briefly.', 'Pour in tomato sauce and soy sauce.', 'Add potatoes, carrots, and bay leaves, simmer.', 'Add hotdogs and green peas, cook until done.'],
    minutes: 50, servings: 5,
    tags: {'Anything'}, meals: {'Lunch', 'Dinner'},
    ingredientKeywords: {'pork'},
  ),
  RamseyDish(
    name: 'Bistek Tagalog',
    shortInfo: 'Filipino beef steak with onion rings',
    ingredients: ['Beef sirloin slices', 'Onion rings', 'Soy sauce', 'Calamansi juice', 'Garlic', 'Black pepper', 'Cooking oil'],
    instructions: ['Marinate beef in soy sauce, calamansi, and pepper for 30 mins.', 'Pan-fry beef slices until browned, set aside.', 'Saute onion rings until soft.', 'Return beef to pan with marinade.', 'Simmer until sauce thickens.', 'Top with onion rings and serve.'],
    minutes: 45, servings: 4,
    tags: {'Anything'}, meals: {'Lunch', 'Dinner'},
    ingredientKeywords: {'beef'},
  ),
  RamseyDish(
    name: 'Lechon Kawali',
    shortInfo: 'Crispy deep-fried pork belly',
    ingredients: ['Pork belly', 'Garlic', 'Bay leaves', 'Whole peppercorns', 'Salt', 'Cooking oil', 'Soy sauce', 'Vinegar'],
    instructions: ['Boil pork belly with garlic, bay leaves, peppercorns, and salt until tender.', 'Drain and let dry completely.', 'Deep fry in hot oil until golden and crispy.', 'Chop into pieces.', 'Serve with lechon sauce or spiced vinegar.'],
    minutes: 75, servings: 5,
    tags: {'Anything'}, meals: {'Lunch', 'Dinner'},
    ingredientKeywords: {'pork'},
  ),
  RamseyDish(
    name: 'Pancit Canton',
    shortInfo: 'Stir-fried egg noodles, party staple',
    ingredients: ['Pancit canton noodles', 'Pork slices', 'Shrimp', 'Cabbage', 'Carrots', 'Snow peas', 'Soy sauce', 'Oyster sauce', 'Garlic', 'Onion', 'Chicken broth'],
    instructions: ['Saute garlic and onion.', 'Cook pork slices until done, add shrimp.', 'Add vegetables and stir-fry briefly.', 'Add broth, soy sauce, and oyster sauce.', 'Add noodles and toss until cooked.', 'Serve hot with calamansi.'],
    minutes: 30, servings: 5,
    tags: {'Anything'}, meals: {'Lunch', 'Dinner'},
    ingredientKeywords: {'noodle', 'pork', 'shrimp'},
  ),
  RamseyDish(
    name: 'Sisig',
    shortInfo: 'Sizzling chopped pork, pulutan favorite',
    ingredients: ['Pork belly', 'Pork ears', 'Onion', 'Chili peppers', 'Calamansi', 'Soy sauce', 'Mayonnaise', 'Egg', 'Garlic', 'Cooking oil'],
    instructions: ['Boil pork belly and ears until tender.', 'Grill or broil until slightly charred.', 'Chop finely and set aside.', 'Saute onion and chili peppers.', 'Add chopped pork, soy sauce, and calamansi.', 'Top with egg and mayonnaise, serve sizzling.'],
    minutes: 60, servings: 4,
    tags: {'Spicy', 'Anything'}, meals: {'Lunch', 'Dinner', 'Midnight Snack'},
    ingredientKeywords: {'pork', 'egg'},
  ),
  RamseyDish(
    name: 'Bulalo',
    shortInfo: 'Beef shank bone marrow soup',
    ingredients: ['Beef shank with bone marrow', 'Corn on the cob', 'Napa cabbage', 'Green beans', 'Onion', 'Whole peppercorns', 'Fish sauce', 'Green onions'],
    instructions: ['Boil beef shank in water, skim off scum.', 'Add onion and peppercorns, simmer 2-3 hours.', 'Add corn and cook 10 minutes.', 'Add green beans and napa cabbage.', 'Season with fish sauce.', 'Garnish with green onions.'],
    minutes: 180, servings: 6,
    tags: {'Soupy', 'Anything'}, meals: {'Lunch', 'Dinner'},
    ingredientKeywords: {'beef'},
  ),
  RamseyDish(
    name: 'Pancit Palabok',
    shortInfo: 'Rice noodles in orange shrimp sauce',
    ingredients: ['Rice noodles', 'Shrimp', 'Ground pork', 'Annatto powder', 'Fish sauce', 'Garlic', 'Boiled eggs', 'Chicharon', 'Green onions', 'Calamansi', 'Cornstarch'],
    instructions: ['Boil noodles until tender, drain.', 'Make sauce: saute garlic, add broth with annatto and cornstarch.', 'Cook ground pork and shrimp separately.', 'Pour sauce over noodles.', 'Top with pork, shrimp, sliced eggs, and chicharon.', 'Garnish with green onions and calamansi.'],
    minutes: 40, servings: 5,
    tags: {'Anything'}, meals: {'Lunch', 'Dinner'},
    ingredientKeywords: {'noodle', 'shrimp', 'pork', 'egg'},
  ),
  RamseyDish(
    name: 'Leche Flan',
    shortInfo: 'Creamy caramel custard dessert',
    ingredients: ['Egg yolks', 'Condensed milk', 'Evaporated milk', 'Sugar', 'Vanilla extract', 'Calamansi rind'],
    instructions: ['Caramelize sugar in llanera until golden.', 'Mix egg yolks, condensed milk, evaporated milk, and vanilla.', 'Strain mixture and pour into llanera.', 'Cover with foil.', 'Steam for 30-40 minutes until set.', 'Let cool, then flip onto a plate.'],
    minutes: 50, servings: 8,
    tags: {'Anything'}, meals: {'Snack', 'Dinner'},
    ingredientKeywords: {'egg'},
  ),
  RamseyDish(
    name: 'Buko Salad',
    shortInfo: 'Sweet coconut fruit salad, fiesta dessert',
    ingredients: ['Young coconut strips', 'Fruit cocktail', 'Nata de coco', 'Kaong', 'All-purpose cream', 'Condensed milk'],
    instructions: ['Drain fruit cocktail, nata de coco, and kaong.', 'Combine all fruits and coconut strips in a bowl.', 'Add all-purpose cream and condensed milk.', 'Mix gently until well combined.', 'Chill in refrigerator for at least 2 hours.', 'Serve cold.'],
    minutes: 15, servings: 10,
    tags: {'Anything'}, meals: {'Snack', 'Dinner', 'Lunch'},
    ingredientKeywords: {'coconut'},
  ),
];
