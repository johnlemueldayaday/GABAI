/// Represents a single price record for an item at a specific store.
class PriceRecord {
  final String store;
  final double price;
  final String unit;
  final DateTime date;

  PriceRecord({
    required this.store,
    required this.price,
    required this.unit,
    DateTime? date,
  }) : date = date ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'store': store,
    'price': price,
    'unit': unit,
    'date': date.toIso8601String(),
  };

  factory PriceRecord.fromJson(Map<String, dynamic> json) => PriceRecord(
    store: json['store'] as String,
    price: (json['price'] as num).toDouble(),
    unit: json['unit'] as String? ?? 'pcs',
    date: DateTime.parse(json['date'] as String),
  );
}

/// Manages price history for all items across all stores.
class PriceHistory {
  /// itemName (lowercase) → list of price records
  final Map<String, List<PriceRecord>> _records = {};

  PriceHistory();

  Map<String, List<PriceRecord>> get records => _records;

  /// Record a price for an item at a store.
  void recordPrice(String itemName, String store, double price, String unit) {
    final key = itemName.toLowerCase();
    _records.putIfAbsent(key, () => []);
    _records[key]!.add(PriceRecord(
      store: store,
      price: price,
      unit: unit,
    ));
  }

  /// Get the last recorded price for an item at a specific store.
  double? getLastPrice(String itemName, String store) {
    final key = itemName.toLowerCase();
    final list = _records[key];
    if (list == null || list.isEmpty) return null;

    // Find the most recent record for this store
    final storeRecords = list.where(
      (r) => r.store.toLowerCase() == store.toLowerCase(),
    ).toList();

    if (storeRecords.isEmpty) return null;
    storeRecords.sort((a, b) => b.date.compareTo(a.date));
    return storeRecords.first.price;
  }

  /// Get the last recorded price for an item (any store).
  double? getLastPriceAny(String itemName) {
    final key = itemName.toLowerCase();
    final list = _records[key];
    if (list == null || list.isEmpty) return null;
    final sorted = List<PriceRecord>.from(list)
      ..sort((a, b) => b.date.compareTo(a.date));
    return sorted.first.price;
  }

  /// Get full price history for an item.
  List<PriceRecord> getHistory(String itemName) {
    final key = itemName.toLowerCase();
    return List.unmodifiable(_records[key] ?? []);
  }

  /// Get all unique stores that have recorded a price for an item.
  Set<String> getStoresForItem(String itemName) {
    final key = itemName.toLowerCase();
    final list = _records[key];
    if (list == null) return {};
    return list.map((r) => r.store).toSet();
  }

  /// Get all unique item names that have price history.
  List<String> get allItemNames {
    return _records.keys.toList()..sort();
  }

  /// Serialize to JSON.
  Map<String, dynamic> toJson() {
    return _records.map(
      (key, value) => MapEntry(key, value.map((r) => r.toJson()).toList()),
    );
  }

  /// Deserialize from JSON.
  factory PriceHistory.fromJson(Map<String, dynamic> json) {
    final history = PriceHistory();
    json.forEach((key, value) {
      final list = (value as List<dynamic>)
          .map((e) => PriceRecord.fromJson(e as Map<String, dynamic>))
          .toList();
      history._records[key] = list;
    });
    return history;
  }
}
