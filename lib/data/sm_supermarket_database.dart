/// SM Supermarket price catalog — sourced from smmarkets.ph.
///
/// Each entry maps to the same [GroceryDatabase] category taxonomy so that
/// items can be matched and displayed in the correct section of the
/// Add-Item sheet.
///
/// Prices here are injected into [PriceStorage] once on app start
/// (see [SmSupermarketPriceSeeder]) so they are automatically applied
/// whenever the user sets their cart store to "SM Supermarket".
class SmSupermarketDatabase {
  static const String storeName = 'SM Supermarket';

  // ─── 1. Fresh Meat & Poultry → category: 'Fridge' ────────────────────────
  static const List<Map<String, dynamic>> freshMeat = [
    {
      'name': 'Chicken',
      'price': 190.0,
      'unit': 'kg',
      'category': 'Fridge',
      'note': 'SM Bonus Fresh Chilled Chicken ₱190/KG',
    },
    {
      'name': 'Chicken Breast Fillet',
      'price': 380.0,
      'unit': 'kg',
      'category': 'Fridge',
      'note': 'Magnolia Chicken Breast Fillet ₱380/KG',
    },
    {
      'name': 'Chicken Drumstick',
      'price': 280.0,
      'unit': 'kg',
      'category': 'Fridge',
      'note': 'Magnolia Chicken Drumstick ₱280/KG',
    },
    {
      'name': 'Chicken Wings',
      'price': 285.0,
      'unit': 'kg',
      'category': 'Fridge',
      'note': 'Magnolia CS Chicken Wings ₱285/KG',
    },
    {
      'name': 'Chicken Thighs',
      'price': 288.0,
      'unit': 'kg',
      'category': 'Fridge',
      'note': 'Magnolia CS Chicken Thighs ₱288/KG',
    },
    {
      'name': 'Ground Chicken',
      'price': 360.0,
      'unit': 'kg',
      'category': 'Fridge',
      'note': 'Magnolia Chicken Lean Ground ₱360/KG',
    },
    {
      'name': 'Pork',
      'price': 268.0,
      'unit': 'kg',
      'category': 'Fridge',
      'note': 'SM Bonus Lean Ground Pork ₱268/KG',
    },
    {
      'name': 'Pork Cubes',
      'price': 305.0,
      'unit': 'kg',
      'category': 'Fridge',
      'note': 'SM Bonus C Pork Cubes ₱305/KG',
    },
    {
      'name': 'Ground Pork',
      'price': 268.0,
      'unit': 'kg',
      'category': 'Fridge',
      'note': 'SM Bonus C Lean Ground Pork ₱268/KG',
    },
    {
      'name': 'Pork Spareribs',
      'price': 270.0,
      'unit': 'kg',
      'category': 'Fridge',
      'note': 'United Steak Pork Spareribs ₱270/KG',
    },
    {
      'name': 'Beef',
      'price': 380.0,
      'unit': 'kg',
      'category': 'Fridge',
      'note': 'SM Bonus C Ground Round ₱380/KG',
    },
    {
      'name': 'Caldereta Cut',
      'price': 355.0,
      'unit': 'kg',
      'category': 'Fridge',
      'note': 'SM Bonus C Caldereta Cut ₱355/KG',
    },
  ];

  // ─── 2. Fresh & Frozen Seafood → category: 'Fridge' ──────────────────────
  static const List<Map<String, dynamic>> freshSeafood = [
    {
      'name': 'Bangus',
      'price': 375.0,
      'unit': 'kg',
      'category': 'Fridge',
      'note': 'NSJ Bangus Boneless ₱375/KG',
    },
    {
      'name': 'Tilapia',
      'price': 178.0,
      'unit': 'kg',
      'category': 'Fridge',
      'note': 'NSJ Tilapia Large ₱178/KG',
    },
    {
      'name': 'Galunggong',
      'price': 367.0,
      'unit': 'kg',
      'category': 'Fridge',
      'note': 'NSI Galunggong Tunay ₱367/KG',
    },
    {
      'name': 'Salmon',
      'price': 984.0,
      'unit': 'kg',
      'category': 'Fridge',
      'note': 'NSI Pink Salmon Steak ₱984/KG',
    },
  ];

  // ─── 3. Frozen Foods & Deli → category: 'Fridge' ─────────────────────────
  static const List<Map<String, dynamic>> frozenDeli = [
    {
      'name': 'Hotdog',
      'price': 189.0,
      'unit': 'kg',
      'category': 'Fridge',
      'note': 'PureFoods Tender Juicy Hotdog Classic 1kg ₱189',
    },
    {
      'name': 'Longganisa',
      'price': 83.0,
      'unit': 'pack',
      'category': 'Fridge',
      'note': 'CDO Pork Longganisa 250g ₱83',
    },
    {
      'name': 'Tocino',
      'price': 88.5,
      'unit': 'pack',
      'category': 'Fridge',
      'note': 'CDO Funtastyk Young Pork Tocino 225g ₱88.50',
    },
    {
      'name': 'Luncheon Meat',
      'price': 72.5,
      'unit': 'can',
      'category': 'Fridge',
      'note': 'SM Bonus Pork Luncheon Meat 340g ₱72.50',
    },
    {
      'name': 'Corned Beef',
      'price': 119.0,
      'unit': 'can',
      'category': 'Fridge',
      'note': 'Purefoods Corned Beef 210g ₱119',
    },
    {
      'name': 'Ham',
      'price': 115.0,
      'unit': 'pack',
      'category': 'Fridge',
      'note': 'CDO Classic Ham Sliced 250g ₱115',
    },
    {
      'name': 'Chicken Nuggets',
      'price': 199.5,
      'unit': 'pack',
      'category': 'Fridge',
      'note': 'SM Bonus Chicken Nuggets 453g ₱199.50',
    },
    {
      'name': 'Ice Cream',
      'price': 260.0,
      'unit': 'pcs',
      'category': 'Fridge',
      'note': 'Selecta Cookies & Cream 1.25L ₱260',
    },
  ];

  // ─── 4. Dairy, Cheese, Butter & Eggs → category: 'Fridge' ────────────────
  static const List<Map<String, dynamic>> dairy = [
    {
      'name': 'Eggs',
      'price': 330.0,
      'unit': 'tray',
      'category': 'Fridge',
      'note': 'Bounty Fresh Large Eggs 30pcs ₱330',
    },
    {
      'name': 'Milk',
      'price': 105.95,
      'unit': 'L',
      'category': 'Fridge',
      'note': 'Alaska Fresh Milk 1L ₱105.95',
    },
    {
      'name': 'Evaporated Milk',
      'price': 61.0,
      'unit': 'can',
      'category': 'Fridge',
      'note': 'Alaska Classic Evaporated Milk 370ml ₱61',
    },
    {
      'name': 'All-Purpose Cream',
      'price': 71.0,
      'unit': 'pcs',
      'category': 'Fridge',
      'note': 'Nestle All-Purpose Cream 250ml ₱71',
    },
    {
      'name': 'Cheese',
      'price': 97.0,
      'unit': 'pcs',
      'category': 'Fridge',
      'note': 'Eden Meltsarap Cheese 160g ₱97 / Magnolia Quickmelt 165g ₱97',
    },
    {
      'name': 'Quickmelt Cheese',
      'price': 97.0,
      'unit': 'pcs',
      'category': 'Fridge',
      'note': 'Magnolia Quickmelt Cheese 165g ₱97',
    },
    {
      'name': 'Cream Cheese',
      'price': 190.0,
      'unit': 'pcs',
      'category': 'Fridge',
      'note': 'Magnolia Cream Cheese 225g ₱190',
    },
    {
      'name': 'Butter',
      'price': 179.0,
      'unit': 'pcs',
      'category': 'Fridge',
      'note': 'Magnolia Gold Butter 225g ₱179',
    },
    {
      'name': 'Yogurt',
      'price': 50.0,
      'unit': 'pcs',
      'category': 'Fridge',
      'note': 'Yakult Regular 90ml 5pcs ₱50',
    },
    {
      'name': 'Condensed Milk',
      'price': 39.75,
      'unit': 'can',
      'category': 'Fridge',
      'note': 'Jersey Sweetened Condensed Milk 302ml ₱39.75',
    },
  ];

  // ─── 5. Fresh Fruits → category: 'Fruits' ────────────────────────────────
  static const List<Map<String, dynamic>> freshFruits = [
    {
      'name': 'Banana',
      'price': 128.0,
      'unit': 'kg',
      'category': 'Fruits',
      'note': 'Choice Harvest Banana Lacatan ₱128/KG',
    },
    {
      'name': 'Mango',
      'price': 264.0,
      'unit': 'kg',
      'category': 'Fruits',
      'note': 'NVD Mango Ripe Large ₱264/KG',
    },
    {
      'name': 'Papaya',
      'price': 100.0,
      'unit': 'kg',
      'category': 'Fruits',
      'note': 'Dizon Red Lady Papaya ₱100/KG',
    },
    {
      'name': 'Pineapple',
      'price': 230.0,
      'unit': 'pcs',
      'category': 'Fruits',
      'note': 'Dizon Honey Gold Pineapple Jumbo ₱230/pc',
    },
    {
      'name': 'Watermelon',
      'price': 64.0,
      'unit': 'kg',
      'category': 'Fruits',
      'note': 'CH Watermelon Sugarbaby ₱64/KG',
    },
    {
      'name': 'Avocado',
      'price': 320.0,
      'unit': 'kg',
      'category': 'Fruits',
      'note': 'Dizon Avocado ₱320/KG',
    },
    {
      'name': 'Calamansi',
      'price': 99.0,
      'unit': 'kg',
      'category': 'Fruits',
      'note': 'SS Calamansi ₱99/KG',
    },
    {
      'name': 'Coconut',
      'price': 40.0,
      'unit': 'pcs',
      'category': 'Fruits',
      'note': 'No SM listing — keeping default price',
    },
    {
      'name': 'Guava',
      'price': 198.0,
      'unit': 'kg',
      'category': 'Fruits',
      'note': 'Dizon Guava ₱198/KG',
    },
    {
      'name': 'Guyabano',
      'price': 199.0,
      'unit': 'kg',
      'category': 'Fruits',
      'note': 'Dizon Guyabano ₱199/KG',
    },
    {
      'name': 'Pomelo',
      'price': 282.0,
      'unit': 'kg',
      'category': 'Fruits',
      'note': 'NVD Peeled Pomelo Regular ₱282/KG',
    },
    {
      'name': 'Grapes',
      'price': 265.0,
      'unit': 'kg',
      'category': 'Fruits',
      'note': 'Choice Harvest Crimson Seedless Grapes ₱265/KG',
    },
    {
      'name': 'Apple',
      'price': 230.0,
      'unit': 'pack',
      'category': 'Fruits',
      'note': 'NVD Gala Apple 10pcs ₱230',
    },
  ];

  // ─── 6. Fresh Vegetables → category: 'Vegetables' ────────────────────────
  static const List<Map<String, dynamic>> freshVegetables = [
    {
      'name': 'Kangkong',
      'price': 53.0,
      'unit': 'kg',
      'category': 'Vegetables',
      'note': 'SS Kangkong ₱53/KG',
    },
    {
      'name': 'Pechay',
      'price': 118.0,
      'unit': 'kg',
      'category': 'Vegetables',
      'note': 'SS Pechay Taiwan ₱118/KG',
    },
    {
      'name': 'Tomato (kg)',
      'price': 190.0,
      'unit': 'kg',
      'category': 'Vegetables',
      'note': 'Global Tomato ₱190/KG',
    },
    {
      'name': 'Tomato (pc)',
      'price': 10.0,
      'unit': 'pcs',
      'category': 'Vegetables',
      'note': 'Approx. per piece based on SS Native ₱123/KG',
    },
    {
      'name': 'Potato',
      'price': 170.0,
      'unit': 'kg',
      'category': 'Vegetables',
      'note': 'SS Potato Regular ₱170/KG',
    },
    {
      'name': 'Carrot',
      'price': 245.0,
      'unit': 'kg',
      'category': 'Vegetables',
      'note': 'Global Carrots ₱245/KG',
    },
    {
      'name': 'Cabbage',
      'price': 157.0,
      'unit': 'kg',
      'category': 'Vegetables',
      'note': 'SS Cabbage ₱157/KG',
    },
    {
      'name': 'Sayote',
      'price': 116.0,
      'unit': 'kg',
      'category': 'Vegetables',
      'note': 'Global Sayote Fruit ₱116/KG',
    },
    {
      'name': 'Okra',
      'price': 108.0,
      'unit': 'kg',
      'category': 'Vegetables',
      'note': 'SS Okra ₱108/KG',
    },
    {
      'name': 'Sitaw',
      'price': 100.0,
      'unit': 'kg',
      'category': 'Vegetables',
      'note': 'SS Stringbeans ₱100/KG',
    },
    {
      'name': 'Squash',
      'price': 60.0,
      'unit': 'kg',
      'category': 'Vegetables',
      'note': 'SS Squash ₱60/KG',
    },
    {
      'name': 'Cauliflower',
      'price': 703.0,
      'unit': 'kg',
      'category': 'Vegetables',
      'note': 'Global Cauliflower ₱703/KG',
    },
    {
      'name': 'Pepper',
      'price': 130.0,
      'unit': 'kg',
      'category': 'Vegetables',
      'note': 'SS Pepper Red ₱130/KG',
    },
  ];

  // ─── 7. Spices → category: 'Spices' ──────────────────────────────────────
  static const List<Map<String, dynamic>> spices = [
    {
      'name': 'Garlic (kg)',
      'price': 160.0,
      'unit': 'kg',
      'category': 'Spices',
      'note': 'SS Garlic Taiwan ₱160/KG',
    },
    {
      'name': 'Onion (kg)',
      'price': 116.0,
      'unit': 'kg',
      'category': 'Spices',
      'note': 'SS Onion Red Local ₱116/KG',
    },
    {
      'name': 'Ginger',
      'price': 338.0,
      'unit': 'kg',
      'category': 'Spices',
      'note': 'Global Ginger ₱338/KG',
    },
  ];

  // ─── 8. Pantry, Canned Goods & Cooking Essentials → category: 'Pantry' ───
  static const List<Map<String, dynamic>> pantry = [
    {
      'name': 'Rice',
      'price': 68.8,
      'unit': 'kg',
      'category': 'Pantry',
      'note': 'SM Bonus Premium Angelika 25kg = ₱1,720 → ₱68.80/KG',
    },
    {
      'name': 'Bread',
      'price': 52.5,
      'unit': 'loaf',
      'category': 'Pantry',
      'note': 'Gardenia Pinoy Tasty 450g ₱52.50',
    },
    {
      'name': 'Cooking Oil',
      'price': 137.25,
      'unit': 'L',
      'category': 'Pantry',
      'note': 'SM Bonus Palm Cooking Oil 2L ₱274.50 → ₱137.25/L',
    },
    {
      'name': 'Sugar',
      'price': 80.0,
      'unit': 'kg',
      'category': 'Pantry',
      'note': 'SM Bonus Refined Sugar White 1kg ₱80',
    },
    {
      'name': 'Soy Sauce',
      'price': 59.0,
      'unit': 'bottle',
      'category': 'Pantry',
      'note': 'Datu Puti Soy Sauce 1L ₱59',
    },
    {
      'name': 'Ketchup',
      'price': 30.75,
      'unit': 'bottle',
      'category': 'Pantry',
      'note': 'Del Monte Tomato Ketchup 320g pouch ₱30.75',
    },
    {
      'name': 'Mayonnaise',
      'price': 99.25,
      'unit': 'jar',
      'category': 'Pantry',
      'note': "Lady's Choice Chicken Sandwich Spread 220ml ₱99.25",
    },
    {
      'name': 'Sardines',
      'price': 24.0,
      'unit': 'can',
      'category': 'Pantry',
      'note': '555 Sardines in Tomato Sauce 155g ₱24',
    },
    {
      'name': 'Canned Tuna',
      'price': 38.5,
      'unit': 'can',
      'category': 'Pantry',
      'note': 'Century Tuna Flakes in Vegetable Oil 155g ₱38.50',
    },
    {
      'name': 'Noodles',
      'price': 14.75,
      'unit': 'pack',
      'category': 'Pantry',
      'note': 'Lucky Me Instant Mami Beef 55g ≈ ₱9/pc (₱54/6pcs)',
    },
    {
      'name': 'Instant Noodles',
      'price': 14.5,
      'unit': 'pack',
      'category': 'Pantry',
      'note': 'Lucky Me Pancit Canton 60g 6pcs ₱69 → ₱11.5/pack',
    },
    {
      'name': 'Oats',
      'price': 139.5,
      'unit': 'pack',
      'category': 'Pantry',
      'note': 'Quaker Oats Instant Oatmeal 800g ₱139.50',
    },
    {
      'name': 'Pancake Mix',
      'price': 69.5,
      'unit': 'pack',
      'category': 'Pantry',
      'note': 'Maya The Original Hot Cake Mix 500g ₱69.50',
    },
    {
      'name': 'Cornstarch',
      'price': 36.5,
      'unit': 'pack',
      'category': 'Pantry',
      'note': 'SM Bonus Pure Cornstarch 400g ₱36.50',
    },
    {
      'name': 'Peanut Butter',
      'price': 227.75,
      'unit': 'jar',
      'category': 'Pantry',
      'note': "Lily's Peanut Butter 504g ₱227.75",
    },
  ];

  // ─── 9. Snacks, Biscuits & Confectionery → category: 'Snacks' ────────────
  static const List<Map<String, dynamic>> snacks = [
    {
      'name': 'Chips',
      'price': 42.5,
      'unit': 'pack',
      'category': 'Snacks',
      'note': 'Jack & Jill Vcut Spicy Barbecue 60g ₱42.50',
    },
    {
      'name': 'Crackers',
      'price': 67.5,
      'unit': 'pack',
      'category': 'Snacks',
      'note': 'M.Y. San SkyFlakes 25g 10pcs ₱67.50',
    },
    {
      'name': 'Biscuits',
      'price': 72.5,
      'unit': 'pack',
      'category': 'Snacks',
      'note': 'Rebisco Bravo Biscuit 10pcs ₱72.50',
    },
    {
      'name': 'Chicharon',
      'price': 29.95,
      'unit': 'pack',
      'category': 'Snacks',
      'note': "Marty's Crackling Vegetable Chicharon 90g ₱29.95",
    },
    {
      'name': 'Candy',
      'price': 20.0,
      'unit': 'pack',
      'category': 'Snacks',
      'note': 'No direct SM listing — keeping default',
    },
    {
      'name': 'Chocolate',
      'price': 89.95,
      'unit': 'pcs',
      'category': 'Snacks',
      'note': 'Jack & Jill Cloud 9 Classic 7g 36pcs ₱89.95',
    },
    {
      'name': 'Polvoron',
      'price': 55.0,
      'unit': 'pack',
      'category': 'Snacks',
      'note': 'No direct SM listing — keeping default',
    },
    {
      'name': 'Peanuts',
      'price': 45.0,
      'unit': 'pack',
      'category': 'Snacks',
      'note': 'No direct SM listing — keeping default',
    },
  ];

  // ─── 10. Beverages → category: 'Drinks' ──────────────────────────────────
  static const List<Map<String, dynamic>> drinks = [
    {
      'name': 'Coffee',
      'price': 70.0,
      'unit': 'pack',
      'category': 'Drinks',
      'note': 'Kopiko Brown 3-in-1 Twin Pack 53g 5pcs ₱70',
    },
    {
      'name': 'Tea',
      'price': 234.5,
      'unit': 'box',
      'category': 'Drinks',
      'note': 'Heath & Heather Organic Tea 2g 20pcs ₱234.50',
    },
    {
      'name': 'Powdered Juice',
      'price': 20.5,
      'unit': 'pack',
      'category': 'Drinks',
      'note': 'Tang Powder Juice Pomelo 19g ₱20.50',
    },
    {
      'name': 'Chocolate Drink',
      'price': 124.5,
      'unit': 'pack',
      'category': 'Drinks',
      'note': 'Chuckie Chocolate Milk Drink 1L ₱124.50',
    },
  ];

  // ─── 11. Household / Home Care → category: 'Household' ───────────────────
  static const List<Map<String, dynamic>> household = [
    {
      'name': 'Dishwashing Liquid',
      'price': 79.0,
      'unit': 'bottle',
      'category': 'Household',
      'note': 'SM Bonus Dishwashing Liquid Lemon 1L ₱79',
    },
    {
      'name': 'Laundry Detergent',
      'price': 194.5,
      'unit': 'pack',
      'category': 'Household',
      'note': 'Champion Detergent Powder 1.6kg ₱194.50',
    },
    {
      'name': 'Fabric Conditioner',
      'price': 346.75,
      'unit': 'pack',
      'category': 'Household',
      'note': 'Downy Fabric Conditioner Sunrise Fresh Refill 1.48L ₱346.75',
    },
    {
      'name': 'Bleach',
      'price': 47.5,
      'unit': 'bottle',
      'category': 'Household',
      'note': 'Zonrox Bleach Lemon 1L ₱47.50',
    },
    {
      'name': 'Toilet Paper',
      'price': 132.75,
      'unit': 'roll',
      'category': 'Household',
      'note': 'SM Bonus Bathroom Tissue 2ply 9pcs ₱132.75',
    },
    {
      'name': 'Trash Bags',
      'price': 55.0,
      'unit': 'pack',
      'category': 'Household',
      'note': 'SM Bonus Garbage Bag Large 10pcs ₱55',
    },
    {
      'name': 'Soap',
      'price': 106.75,
      'unit': 'pcs',
      'category': 'Household',
      'note': 'Safeguard Soap Pure White 85g 3pcs ₱106.75',
    },
    {
      'name': 'Toothpaste',
      'price': 160.0,
      'unit': 'pcs',
      'category': 'Household',
      'note': 'Colgate Toothpaste GRF 132g 2pcs ₱160',
    },
    {
      'name': 'Alcohol',
      'price': 91.25,
      'unit': 'bottle',
      'category': 'Household',
      'note': 'Cleene Ethyl Alcohol 70% 500ml ₱91.25',
    },
    {
      'name': 'Shampoo',
      'price': 12.0,
      'unit': 'sachet',
      'category': 'Household',
      'note': 'No direct SM sachet listing — keeping default',
    },
  ];

  /// All SM Supermarket price entries, flattened into a single list.
  static List<Map<String, dynamic>> get allItems => [
    ...freshMeat,
    ...freshSeafood,
    ...frozenDeli,
    ...dairy,
    ...freshFruits,
    ...freshVegetables,
    ...spices,
    ...pantry,
    ...snacks,
    ...drinks,
    ...household,
  ];
}
