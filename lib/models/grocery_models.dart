
class GroceryItem {
  final String id;
  String name;
  double qty;
  String unit;
  double price;
  bool isDone;
  final String category;

  GroceryItem({
    required this.id,
    required this.name,
    this.qty = 1.0,
    this.unit = 'pcs',
    this.price = 0,
    this.isDone = false,
    this.category = 'All',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'qty': qty,
        'unit': unit,
        'price': price,
        'isDone': isDone,
        'category': category,
      };

  factory GroceryItem.fromJson(Map<String, dynamic> json) => GroceryItem(
        id: json['id'] as String,
        name: json['name'] as String,
        qty: (json['qty'] as num).toDouble(),
        unit: json['unit'] as String,
        price: (json['price'] as num).toDouble(),
        isDone: json['isDone'] as bool,
        category: json['category'] as String? ?? 'All',
      );
}

class GroceryList {
  String name;
  double budget;
  List<GroceryItem> items;
  DateTime date;

  GroceryList(this.name, {this.budget = 0.0, List<GroceryItem>? items, DateTime? date})
      : items = items ?? [],
        date = date ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'name': name,
        'budget': budget,
        'items': items.map((e) => e.toJson()).toList(),
        'date': date.toIso8601String(),
      };

  factory GroceryList.fromJson(Map<String, dynamic> json) => GroceryList(
        json['name'] as String,
        budget: (json['budget'] as num).toDouble(),
        items: (json['items'] as List<dynamic>)
            .map((e) => GroceryItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        date: DateTime.parse(json['date'] as String),
      );
}

class AppState {
  static List<GroceryList> lists = [];
  static List<GroceryList> recentLists = [];
  static List<GroceryItem> inventory = [];
  static int activeIndex = -1;
  static GroceryList? get currentList =>
      activeIndex >= 0 && activeIndex < lists.length
          ? lists[activeIndex]
          : null;
}

