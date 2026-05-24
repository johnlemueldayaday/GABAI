import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/finance_models.dart';

class FutureEventStorage {
  static const String _key = 'future_events';

  static Future<List<FutureEvent>> loadEvents() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(_key);
    if (data == null) return [];

    final List<dynamic> json = jsonDecode(data);
    return json.map((e) => FutureEvent.fromJson(e)).toList();
  }

  static Future<void> saveEvents(List<FutureEvent> events) async {
    final prefs = await SharedPreferences.getInstance();
    final String data = jsonEncode(events.map((e) => e.toJson()).toList());
    await prefs.setString(_key, data);
  }

  static Future<void> addEvent(FutureEvent event) async {
    final events = await loadEvents();
    events.add(event);
    await saveEvents(events);
  }

  static Future<void> removeEvent(String id) async {
    final events = await loadEvents();
    events.removeWhere((e) => e.id == id);
    await saveEvents(events);
  }

  static Future<void> updateEvent(FutureEvent event) async {
    final events = await loadEvents();
    final index = events.indexWhere((e) => e.id == event.id);
    if (index != -1) {
      events[index] = event;
      await saveEvents(events);
    }
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  static Future<List<FutureEvent>> getUpcomingEvents() async {
    final events = await loadEvents();
    return events.where((e) => e.isUpcoming && !e.isCompleted).toList()
      ..sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));
  }

  static Future<List<FutureEvent>> getDueEvents() async {
    final events = await loadEvents();
    return events.where((e) => e.isDue && !e.isCompleted).toList()
      ..sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));
  }
}
