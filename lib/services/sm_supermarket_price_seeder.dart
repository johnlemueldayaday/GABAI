import '../data/sm_supermarket_database.dart';
import 'price_storage.dart';

/// Seeds SM Supermarket reference prices into [PriceStorage] once per app
/// install so that when a user creates or switches a cart to "SM Supermarket",
/// the item prices are pre-filled with accurate catalog values.
///
/// Seeding is **additive and idempotent**: it only writes a price entry when
/// no existing entry for that item + store combination is present, so any
/// price the user has manually recorded is never overwritten.
class SmSupermarketPriceSeeder {
  static const _store = SmSupermarketDatabase.storeName;

  /// Call this once during app startup (after [PriceStorage.load()]).
  static void seed() {
    for (final item in SmSupermarketDatabase.allItems) {
      final name = item['name'] as String;
      final price = (item['price'] as num).toDouble();
      final unit = item['unit'] as String;

      // Only seed if no price has been recorded yet for this item at SM.
      final existing = PriceStorage.getLastPrice(name, _store);
      if (existing == null || existing <= 0) {
        PriceStorage.recordPrice(name, _store, price, unit);
      }
    }
  }
}
