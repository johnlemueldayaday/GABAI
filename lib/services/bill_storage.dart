import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/bill_models.dart';

class BillStorage {
  static const _key = 'bills_data';

  static Future<void> saveBills(List<Bill> bills) async {
    final prefs = await SharedPreferences.getInstance();
    final data = bills.map((b) => b.toJson()).toList();
    await prefs.setString(_key, jsonEncode(data));
  }

  static Future<List<Bill>> loadBills() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_key);
    if (str == null) return [];
    try {
      final List<dynamic> data = jsonDecode(str);
      return data.map((b) => Bill.fromJson(b)).toList();
    } catch (e) {
      return [];
    }
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
