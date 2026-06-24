import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService extends ChangeNotifier {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  static const _keyCurrency = 'settings_currency';
  static const _keyThemeMode = 'settings_theme_mode';
  static const _keyBudgetAlerts = 'settings_budget_alerts';
  static const _keySmartSuggestions = 'settings_smart_suggestions';
  static const _keyCompactView = 'settings_compact_view';
  static const _keyShowSavingsTips = 'settings_show_savings_tips';
  static const _keyUserName = 'settings_user_name';
  static const _keyOnboardingComplete = 'settings_onboarding_complete';

  String _currency = '₱';
  ThemeMode _themeMode = ThemeMode.light;
  bool _budgetAlerts = true;
  bool _smartSuggestions = true;
  bool _compactView = false;
  bool _showSavingsTips = true;
  String _userName = '';
  bool _onboardingComplete = false;

  String get currency => _currency;
  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;
  bool get budgetAlerts => _budgetAlerts;
  bool get smartSuggestions => _smartSuggestions;
  bool get compactView => _compactView;
  bool get showSavingsTips => _showSavingsTips;
  String get userName => _userName;
  bool get onboardingComplete => _onboardingComplete;

  static const List<Map<String, String>> availableCurrencies = [
    {'symbol': '₱', 'name': 'Philippine Peso (PHP)'},
    {'symbol': '\$', 'name': 'US Dollar (USD)'},
    {'symbol': '€', 'name': 'Euro (EUR)'},
    {'symbol': '£', 'name': 'British Pound (GBP)'},
    {'symbol': '¥', 'name': 'Japanese Yen (JPY)'},
    {'symbol': '₩', 'name': 'South Korean Won (KRW)'},
    {'symbol': 'S\$', 'name': 'Singapore Dollar (SGD)'},
    {'symbol': '₹', 'name': 'Indian Rupee (INR)'},
    {'symbol': 'RM', 'name': 'Malaysian Ringgit (MYR)'},
    {'symbol': '฿', 'name': 'Thai Baht (THB)'},
  ];

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _currency = prefs.getString(_keyCurrency) ?? '₱';
    final themeIndex = prefs.getInt(_keyThemeMode) ?? 0;
    _themeMode =
        ThemeMode.values[themeIndex.clamp(0, ThemeMode.values.length - 1)];
    _budgetAlerts = prefs.getBool(_keyBudgetAlerts) ?? true;
    _smartSuggestions = prefs.getBool(_keySmartSuggestions) ?? true;
    _compactView = prefs.getBool(_keyCompactView) ?? false;
    _showSavingsTips = prefs.getBool(_keyShowSavingsTips) ?? true;
    _userName = prefs.getString(_keyUserName) ?? '';
    _onboardingComplete = prefs.getBool(_keyOnboardingComplete) ?? false;
    notifyListeners();
  }

  Future<void> setCurrency(String symbol) async {
    _currency = symbol;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCurrency, symbol);
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyThemeMode, mode.index);
    notifyListeners();
  }

  Future<void> setBudgetAlerts(bool value) async {
    _budgetAlerts = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyBudgetAlerts, value);
    notifyListeners();
  }

  Future<void> setSmartSuggestions(bool value) async {
    _smartSuggestions = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySmartSuggestions, value);
    notifyListeners();
  }

  Future<void> setCompactView(bool value) async {
    _compactView = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyCompactView, value);
    notifyListeners();
  }

  Future<void> setShowSavingsTips(bool value) async {
    _showSavingsTips = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyShowSavingsTips, value);
    notifyListeners();
  }

  Future<void> setUserName(String name) async {
    _userName = name;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserName, name);
    notifyListeners();
  }

  Future<void> setOnboardingComplete(bool value) async {
    _onboardingComplete = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyOnboardingComplete, value);
    notifyListeners();
  }

  Future<void> resetAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyCurrency);
    await prefs.remove(_keyThemeMode);
    await prefs.remove(_keyBudgetAlerts);
    await prefs.remove(_keySmartSuggestions);
    await prefs.remove(_keyCompactView);
    await prefs.remove(_keyShowSavingsTips);
    await prefs.remove(_keyUserName);
    await prefs.remove(_keyOnboardingComplete);
    _currency = '₱';
    _themeMode = ThemeMode.light;
    _budgetAlerts = true;
    _smartSuggestions = true;
    _compactView = false;
    _showSavingsTips = true;
    _userName = '';
    notifyListeners();
  }
}
