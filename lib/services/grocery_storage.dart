import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/grocery_models.dart';

class GroceryStorage {
  static const _activeListsKey = 'grocery_active_lists';
  static const _recentListsKey = 'grocery_recent_lists';
  static const _activeIndexKey = 'grocery_active_index';
  static const _inventoryKey = 'grocery_virtual_fridge';

  static Timer? _saveTimer;

  static void saveAll() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 500), () async {
      final prefs = await SharedPreferences.getInstance();
      
      final activeJson = jsonEncode(AppState.lists.map((e) => e.toJson()).toList());
      final recentJson = jsonEncode(AppState.recentLists.map((e) => e.toJson()).toList());
      final inventoryJson = jsonEncode(AppState.inventory.map((e) => e.toJson()).toList());
      
      await prefs.setString(_activeListsKey, activeJson);
      await prefs.setString(_recentListsKey, recentJson);
      await prefs.setString(_inventoryKey, inventoryJson);
      await prefs.setInt(_activeIndexKey, AppState.activeIndex);
    });
  }


  static Future<void> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    
    final activeRaw = prefs.getString(_activeListsKey);
    if (activeRaw != null) {
      try {
        final list = jsonDecode(activeRaw) as List<dynamic>;
        AppState.lists = list.map((e) => GroceryList.fromJson(e as Map<String, dynamic>)).toList();
      } catch (e) {
        AppState.lists = [];
      }
    }

    final recentRaw = prefs.getString(_recentListsKey);
    if (recentRaw != null) {
      try {
        final list = jsonDecode(recentRaw) as List<dynamic>;
        AppState.recentLists = list.map((e) => GroceryList.fromJson(e as Map<String, dynamic>)).toList();
      } catch (e) {
        AppState.recentLists = [];
      }
    }

    final inventoryRaw = prefs.getString(_inventoryKey);
    if (inventoryRaw != null) {
      try {
        final list = jsonDecode(inventoryRaw) as List<dynamic>;
        AppState.inventory = list.map((e) => GroceryItem.fromJson(e as Map<String, dynamic>)).toList();
      } catch (e) {
        AppState.inventory = [];
      }
    }

    AppState.activeIndex = prefs.getInt(_activeIndexKey) ?? -1;
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_activeListsKey);
    await prefs.remove(_recentListsKey);
    await prefs.remove(_inventoryKey);
    await prefs.remove(_activeIndexKey);
    AppState.lists = [];
    AppState.recentLists = [];
    AppState.inventory = [];
    AppState.activeIndex = -1;
  }
}
