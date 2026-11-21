/// Puregold price catalog — sourced from Puregold branch pricing data.
///
/// Each entry maps to the same [GroceryDatabase] category taxonomy so that
/// items can be matched and displayed in the correct section of the
/// Add-Item sheet.
///
/// Prices here are injected into [PriceStorage] once on app start
/// (see [PuregoldPriceSeeder]) so they are automatically applied
/// whenever the user sets their cart store to "Puregold".
class PuregoldDatabase {
  static const String storeName = 'Puregold';

  // ─── 1. Fridge — Canned Meats & Deli ─────────────────────────────────────
  // Maps to GroceryDatabase category: 'Fridge'
  static const List<Map<String, dynamic>> cannedMeatsDeli = [
    {
      'name': 'Corned Beef',
      'price': 66.0,
      'unit': 'can',
      'category': 'Fridge',
      'note': 'Purefoods Corned Beef 210g ₱66',
    },
    {
      'name': 'Luncheon Meat',
      'price': 19.0,
      'unit': 'can',
      'category': 'Fridge',
      'note': 'Argentina Meatloaf ₱19 / CDO Meatloaf 150g ₱18',
    },
    {
      'name': 'Hotdog',
      'price': 85.0,
      'unit': 'pack',
      'category': 'Fridge',
      "note": "Pampanga's Best Hotdog ₱85",
    },
    {
      'name': 'Longganisa',
      'price': 100.0,
      'unit': 'pack',
      'category': 'Fridge',
      "note": "Pampanga's Best Pork Longganiza ₱100",
    },
    {
      'name': 'Tocino',
      'price': 55.0,
      'unit': 'pack',
      'category': 'Fridge',
      "note": "Pampanga's Best Tocino 1/4 ₱55",
    },
    {
      'name': 'Ham',
      'price': 43.0,
      'unit': 'pack',
      'category': 'Fridge',
      "note": "Pampanga's Best Sweet Ham Regular ₱43",
    },
    {
      'name': 'Chicken Nuggets',
      'price': 85.0,
      'unit': 'pack',
      'category': 'Fridge',
      "note": "Pampanga's Best Hotdog (proxy — no nuggets listed) ₱85",
    },
  ];

  // ─── 2. Fridge — Dairy & Eggs ─────────────────────────────────────────────
  // Maps to GroceryDatabase category: 'Fridge'
  static const List<Map<String, dynamic>> dairy = [
    {
      'name': 'Eggs',
      'price': 6.0,
      'unit': 'pcs',
      'category': 'Fridge',
      'note': 'Itlog ₱6/pc (per piece)',
    },
    {
      'name': 'Evaporated Milk',
      'price': 25.0,
      'unit': 'can',
      'category': 'Fridge',
      'note': 'Alaska Evap 370mL ₱25',
    },
    {
      'name': 'Condensed Milk',
      'price': 37.0,
      'unit': 'can',
      'category': 'Fridge',
      'note': 'Alaska Condensada 300mL ₱37',
    },
    {
      'name': 'All-Purpose Cream',
      'price': 48.0,
      'unit': 'pcs',
      'category': 'Fridge',
      'note': 'Nestle All Purpose Cream 250mL ₱48',
    },
    {
      'name': 'Cheese',
      'price': 42.0,
      'unit': 'pcs',
      'category': 'Fridge',
      'note': 'Eden Cheese 175g ₱42 / Magnolia Cheeze Plain 120g ₱42',
    },
    {
      'name': 'Quickmelt Cheese',
      'price': 42.0,
      'unit': 'pcs',
      'category': 'Fridge',
      'note': 'Magnolia Cheeze Plain 120g ₱42',
    },
    {
      'name': 'Cream Cheese',
      'price': 72.0,
      'unit': 'pcs',
      'category': 'Fridge',
      'note': 'Cheez Whiz 220g ₱72 (closest spread match)',
    },
    {
      'name': 'Butter',
      'price': 7.0,
      'unit': 'pcs',
      'category': 'Fridge',
      'note': 'Lily Butter 20g sachet ₱7',
    },
    {
      'name': 'Yogurt',
      'price': 9.0,
      'unit': 'pcs',
      'category': 'Fridge',
      'note': 'Yakult Probiotics ₱9/pc',
    },
  ];

  // ─── 3. Pantry — Canned Goods ─────────────────────────────────────────────
  // Maps to GroceryDatabase category: 'Pantry'
  static const List<Map<String, dynamic>> cannedGoods = [
    {
      'name': 'Sardines',
      'price': 15.0,
      'unit': 'can',
      'category': 'Pantry',
      'note': 'Ligo Sardines / Mega Sardines Tomato 155g ₱15',
    },
    {
      'name': 'Canned Tuna',
      'price': 28.0,
      'unit': 'can',
      'category': 'Pantry',
      'note': 'Century Tuna Flakes in Oil ₱28',
    },
    {
      'name': 'Tomato Sauce',
      'price': 18.0,
      'unit': 'can',
      'category': 'Pantry',
      'note': 'Del Monte Tomato Sauce 200g ₱18',
    },
    {
      'name': 'Coconut Milk',
      'price': 24.0,
      'unit': 'can',
      'category': 'Pantry',
      'note': 'Dairy Cream 100g ₱24 (closest proxy)',
    },
  ];

  // ─── 4. Pantry — Cooking Essentials ──────────────────────────────────────
  // Maps to GroceryDatabase category: 'Pantry'
  static const List<Map<String, dynamic>> cookingEssentials = [
    {
      'name': 'Cooking Oil',
      'price': 17.5,
      'unit': 'bottle',
      'category': 'Pantry',
      'note': 'Jolly Oil ₱17.50 (small bottle); Spring Oil 1 bote ₱21',
    },
    {
      'name': 'Sugar',
      'price': 25.0,
      'unit': 'kg',
      'category': 'Pantry',
      'note': 'Sugar White ½kg ₱25 → ₱50/kg (avg ₱25 for ½)',
    },
    {
      'name': 'Soy Sauce',
      'price': 16.0,
      'unit': 'bottle',
      'category': 'Pantry',
      'note': 'Datu Puti Soy Sauce 340mL ₱16 / Silver Swan 340mL ₱15',
    },
    {
      'name': 'Vinegar',
      'price': 14.0,
      'unit': 'bottle',
      'category': 'Pantry',
      'note': 'Datu Puti Vinegar 350mL ₱14',
    },
    {
      'name': 'Fish Sauce',
      'price': 20.0,
      'unit': 'bottle',
      'category': 'Pantry',
      'note': 'Datu Puti Patis 350mL ₱20 / Lorins Patis ₱20',
    },
    {
      'name': 'Ketchup',
      'price': 18.0,
      'unit': 'bottle',
      'category': 'Pantry',
      'note': 'Papa Banana Ketchup 320g ₱18 / UFC Banana Ketchup 200g ₱20',
    },
    {
      'name': 'Mayonnaise',
      'price': 75.0,
      'unit': 'jar',
      'category': 'Pantry',
      'note': "Lady's Choice Mayonnaise 220g ₱75",
    },
    {
      'name': 'Oyster Sauce',
      'price': 27.0,
      'unit': 'bottle',
      'category': 'Pantry',
      'note': 'Mang Tomas 330g ₱27 (closest proxy)',
    },
    {
      'name': 'Cornstarch',
      'price': 15.0,
      'unit': 'pack',
      'category': 'Pantry',
      'note': 'Emperor Cornstarch 100g ₱15 / Cream Cornstarch 75g ₱12',
    },
    {
      'name': 'Bread',
      'price': 35.0,
      'unit': 'loaf',
      'category': 'Pantry',
      'note': 'Fiesta Spaghetti 450g ₱35 (no direct bread listing; approx)',
    },
    {
      'name': 'Pasta',
      'price': 35.0,
      'unit': 'pack',
      'category': 'Pantry',
      'note': 'Fiesta Spaghetti 450g ₱35',
    },
    {
      'name': 'Noodles',
      'price': 9.0,
      'unit': 'pack',
      'category': 'Pantry',
      'note': 'Lucky Me Pancit Canton ₱9/pc',
    },
    {
      'name': 'Instant Noodles',
      'price': 9.0,
      'unit': 'pack',
      'category': 'Pantry',
      'note': 'Lucky Me Beef na Beef / Chicken ₱9/pc',
    },
    {
      'name': 'Oats',
      'price': 85.0,
      'unit': 'pack',
      'category': 'Pantry',
      'note': 'No direct listing — keeping default',
    },
    {
      'name': 'Pancake Mix',
      'price': 30.0,
      'unit': 'pack',
      'category': 'Pantry',
      'note': 'Maya Hot Cake Original ₱30',
    },
    {
      'name': 'Peanut Butter',
      'price': 67.0,
      'unit': 'jar',
      'category': 'Pantry',
      "note": "Lady's Choice Peanut Butter ₱67",
    },
    {
      'name': 'Seasoning Granules',
      'price': 3.0,
      'unit': 'pack',
      'category': 'Pantry',
      'note': 'Magic Sarap sachet ₱3',
    },
  ];

  // ─── 5. Spices ────────────────────────────────────────────────────────────
  // Maps to GroceryDatabase category: 'Spices'
  static const List<Map<String, dynamic>> spices = [
    {
      'name': 'Seasoning Granules',
      'price': 3.0,
      'unit': 'pack',
      'category': 'Spices',
      'note': 'Magic Sarap sachet ₱3',
    },
    {
      'name': 'Ginisa Mix',
      'price': 2.0,
      'unit': 'pack',
      'category': 'Spices',
      'note': 'Ginisa Mix ₱2',
    },
    {
      'name': 'Knorr Sinigang Mix',
      'price': 12.0,
      'unit': 'pack',
      'category': 'Spices',
      'note': 'Knorr Sinigang Mix 20g ₱12',
    },
  ];

  // ─── 6. Snacks ────────────────────────────────────────────────────────────
  // Maps to GroceryDatabase category: 'Snacks'
  static const List<Map<String, dynamic>> snacks = [
    {
      'name': 'Chips',
      'price': 12.0,
      'unit': 'pack',
      'category': 'Snacks',
      'note': 'Piattos ₱12 / Chippy ₱6',
    },
    {
      'name': 'Crackers',
      'price': 5.0,
      'unit': 'pack',
      'category': 'Snacks',
      'note': 'Sky Flakes ₱5 / Fita 30g ₱5',
    },
    {
      'name': 'Biscuits',
      'price': 6.0,
      'unit': 'pack',
      'category': 'Snacks',
      'note': 'Bravo Biscuit ₱6',
    },
    {
      'name': 'Chocolate',
      'price': 7.0,
      'unit': 'pcs',
      'category': 'Snacks',
      'note': 'Cloud9 ₱7 / Choco Mucho ₱7',
    },
    {
      'name': 'Candy',
      'price': 1.0,
      'unit': 'pack',
      'category': 'Snacks',
      'note': 'Various candy ₱1',
    },
    {
      'name': 'Chicharon',
      'price': 7.0,
      'unit': 'pack',
      'category': 'Snacks',
      'note': 'Mang Juan Chicharon ₱7',
    },
    {
      'name': 'Polvoron',
      'price': 55.0,
      'unit': 'pack',
      'category': 'Snacks',
      'note': 'No direct listing — keeping default',
    },
    {
      'name': 'Peanuts',
      'price': 1.0,
      'unit': 'pack',
      'category': 'Snacks',
      'note': 'Dingdong snack mix ₱1',
    },
    {
      'name': 'Popcorn',
      'price': 35.0,
      'unit': 'pack',
      'category': 'Snacks',
      'note': 'No direct listing — keeping default',
    },
  ];

  // ─── 7. Drinks ────────────────────────────────────────────────────────────
  // Maps to GroceryDatabase category: 'Drinks'
  static const List<Map<String, dynamic>> drinks = [
    {
      'name': 'Coffee',
      'price': 6.0,
      'unit': 'pack',
      'category': 'Drinks',
      'note': 'Kopiko / Nescafe Brown / Great Taste sachet ₱6',
    },
    {
      'name': 'Powdered Juice',
      'price': 10.0,
      'unit': 'pack',
      'category': 'Drinks',
      'note': 'Tang sachet ₱10',
    },
    {
      'name': 'Chocolate Drink',
      'price': 6.0,
      'unit': 'pack',
      'category': 'Drinks',
      'note': 'Milo Drink sachet ₱6',
    },
    {
      'name': 'Soda',
      'price': 45.0,
      'unit': 'bottle',
      'category': 'Drinks',
      'note': 'Sprite / Royal / Mountain Dew 1.5L ₱45',
    },
    {
      'name': 'Energy Drink',
      'price': 27.0,
      'unit': 'can',
      'category': 'Drinks',
      'note': 'Gatorade 500mL ₱27',
    },
    {
      'name': 'Juice',
      'price': 24.0,
      'unit': 'L',
      'category': 'Drinks',
      'note': 'Del Monte Pineapple Juice 240mL ₱24',
    },
    {
      'name': 'Bottled Iced Tea',
      'price': 10.0,
      'unit': 'bottle',
      'category': 'Drinks',
      'note': 'Nestea Lemon ₱10',
    },
  ];

  // ─── 8. Household ─────────────────────────────────────────────────────────
  // Maps to GroceryDatabase category: 'Household'
  static const List<Map<String, dynamic>> household = [
    {
      'name': 'Soap',
      'price': 28.0,
      'unit': 'pcs',
      'category': 'Household',
      'note': 'No direct listing — keeping default',
    },
    {
      'name': 'Alcohol',
      'price': 72.0,
      'unit': 'bottle',
      'category': 'Household',
      'note': 'No direct listing — keeping default',
    },
  ];

  /// All Puregold price entries, flattened into a single list.
  static List<Map<String, dynamic>> get allItems => [
    ...cannedMeatsDeli,
    ...dairy,
    ...cannedGoods,
    ...cookingEssentials,
    ...spices,
    ...snacks,
    ...drinks,
    ...household,
  ];
}
