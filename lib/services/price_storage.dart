import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/price_history.dart';

/// Persists store-specific price history for all grocery items.
class PriceStorage {
  static const _key = 'store_price_history';
  static PriceHistory _history = PriceHistory();

  static PriceHistory get history => _history;

  /// Record a price and persist.
  static void recordPrice(String itemName, String store, double price, String unit) {
    if (store.trim().isEmpty || price <= 0) return;
    _history.recordPrice(itemName, store, price, unit);
    _save();
  }

  /// Get the last price for an item at a specific store.
  static double? getLastPrice(String itemName, String store) {
    return _history.getLastPrice(itemName, store);
  }

  /// Get the last price for an item at any store.
  static double? getLastPriceAny(String itemName) {
    return _history.getLastPriceAny(itemName);
  }

  /// Load from disk.
  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null) {
      try {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        _history = PriceHistory.fromJson(json);
      } catch (_) {
        _history = PriceHistory();
      }
    }
  }

  static Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(_history.toJson()));
  }

  static Future<void> clear() async {
    _history = PriceHistory();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
