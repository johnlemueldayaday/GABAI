import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'safe_to_spend.dart';

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
  static const _keyDailySpendingAllocation =
      'settings_daily_spending_allocation';
  static const _keySalaryPaydayDays = 'settings_salary_payday_days';
  static const _keyPayFrequency = 'settings_pay_frequency';
  static const _keyPayday1 = 'settings_payday_1';
  static const _keyPayday2 = 'settings_payday_2';
  static const _keyPayIntervalDays = 'settings_pay_interval_days';
  static const _keyAnchorPayday = 'settings_anchor_payday';

  String _currency = '₱';
  double _dailySpendingAllocation = 172.30;
  List<int> _salaryPaydayDays = [30];
  PayFrequency _payFrequency = PayFrequency.monthly;
  int _payday1 = 30;
  int? _payday2;
  int? _intervalDays;
  DateTime? _anchorPayday;
  final ValueNotifier<double> dailySpendingAllocationNotifier = ValueNotifier(
    172.30,
  );
  ThemeMode _themeMode = ThemeMode.light;
  bool _budgetAlerts = true;
  bool _smartSuggestions = true;
  bool _compactView = false;
  bool _showSavingsTips = true;
  String _userName = '';
  bool _onboardingComplete = false;

  String get currency => _currency;
  double get dailySpendingAllocation => _dailySpendingAllocation;
  List<int> get salaryPaydayDays => List.unmodifiable(_salaryPaydayDays);
  PayFrequency get payFrequency => _payFrequency;
  int get payday1 => _payday1;
  int? get payday2 => _payday2;
  int? get intervalDays => _intervalDays;
  DateTime? get anchorPayday => _anchorPayday;
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
    _dailySpendingAllocation =
        prefs.getDouble(_keyDailySpendingAllocation) ?? 172.30;
    dailySpendingAllocationNotifier.value = _dailySpendingAllocation;
    final legacyPaydayDays =
        (prefs.getStringList(_keySalaryPaydayDays) ?? ['30'])
            .map(int.tryParse)
            .whereType<int>()
            .where((day) => day >= 1 && day <= 31)
            .toSet()
            .toList()
          ..sort();
    _salaryPaydayDays = legacyPaydayDays.isEmpty ? [30] : legacyPaydayDays;
    final storedFrequency = prefs.getString(_keyPayFrequency);
    _payFrequency = PayFrequency.values.firstWhere(
      (frequency) => frequency.name == storedFrequency,
      orElse: () => PayFrequency.monthly,
    );
    _payday1 = prefs.getInt(_keyPayday1) ?? _salaryPaydayDays.first;
    _payday2 =
        prefs.getInt(_keyPayday2) ??
        (_salaryPaydayDays.length > 1 ? _salaryPaydayDays[1] : null);
    _intervalDays = prefs.getInt(_keyPayIntervalDays);
    final storedAnchor = prefs.getString(_keyAnchorPayday);
    _anchorPayday = storedAnchor == null
        ? null
        : _dateOnly(DateTime.tryParse(storedAnchor));
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

  Future<void> setDailySpendingAllocation(double amount) async {
    if (!amount.isFinite || amount <= 0) {
      throw ArgumentError.value(amount, 'amount', 'Must be a positive number');
    }
    _dailySpendingAllocation = amount;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyDailySpendingAllocation, amount);
    dailySpendingAllocationNotifier.value = amount;
  }

  Future<void> setSalaryPaydayDays(List<int> days) async {
    final normalized =
        days.where((day) => day >= 1 && day <= 31).toSet().toList()..sort();
    if (normalized.isEmpty) {
      throw ArgumentError.value(
        days,
        'days',
        'At least one payday is required',
      );
    }
    _salaryPaydayDays = normalized;
    _payFrequency = PayFrequency.twiceMonthly;
    _payday1 = normalized.first;
    _payday2 = normalized.length > 1 ? normalized[1] : null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _keySalaryPaydayDays,
      normalized.map((day) => day.toString()).toList(),
    );
    await prefs.setString(_keyPayFrequency, _payFrequency.name);
    await prefs.setInt(_keyPayday1, _payday1);
    if (_payday2 case final payday2?) {
      await prefs.setInt(_keyPayday2, payday2);
    } else {
      await prefs.remove(_keyPayday2);
    }
  }

  Future<void> setPaySchedule({
    required PayFrequency frequency,
    required int payday1,
    int? payday2,
    int? intervalDays,
    DateTime? anchorPayday,
  }) async {
    if (payday1 < 1 ||
        payday1 > 31 ||
        (payday2 != null && (payday2 < 1 || payday2 > 31))) {
      throw ArgumentError('Calendar payday must be between 1 and 31.');
    }
    if (frequency == PayFrequency.twiceMonthly &&
        (payday2 == null || payday1 == payday2)) {
      throw ArgumentError('Twice-monthly paydays must be different.');
    }
    if (frequency == PayFrequency.custom &&
        (intervalDays == null || intervalDays < 1 || intervalDays > 90)) {
      throw ArgumentError('Custom interval must be between 1 and 90 days.');
    }

    final normalizedPayday1 =
        frequency == PayFrequency.twiceMonthly &&
            payday2 != null &&
            payday2 < payday1
        ? payday2
        : payday1;
    final normalizedPayday2 =
        frequency == PayFrequency.twiceMonthly &&
            payday2 != null &&
            payday2 < payday1
        ? payday1
        : payday2;
    _payFrequency = frequency;
    _payday1 = normalizedPayday1;
    _payday2 = normalizedPayday2;
    _intervalDays = intervalDays ?? _fixedIntervalFor(frequency);
    _anchorPayday = anchorPayday == null ? null : _dateOnly(anchorPayday);
    _salaryPaydayDays = frequency == PayFrequency.monthly
        ? [normalizedPayday1]
        : frequency == PayFrequency.twiceMonthly
        ? ([normalizedPayday1, normalizedPayday2!]..sort())
        : _salaryPaydayDays;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPayFrequency, frequency.name);
    await prefs.setInt(_keyPayday1, normalizedPayday1);
    if (_payday2 case final storedPayday2?) {
      await prefs.setInt(_keyPayday2, storedPayday2);
    } else {
      await prefs.remove(_keyPayday2);
    }
    if (_intervalDays case final interval?) {
      await prefs.setInt(_keyPayIntervalDays, interval);
    } else {
      await prefs.remove(_keyPayIntervalDays);
    }
    if (_anchorPayday case final anchor?) {
      await prefs.setString(_keyAnchorPayday, anchor.toIso8601String());
    } else {
      await prefs.remove(_keyAnchorPayday);
    }
    await prefs.setStringList(
      _keySalaryPaydayDays,
      _salaryPaydayDays.map((day) => day.toString()).toList(),
    );
  }

  static int? _fixedIntervalFor(PayFrequency frequency) => switch (frequency) {
    PayFrequency.weekly => 7,
    PayFrequency.everyTwoWeeks => 14,
    PayFrequency.every15Days => 15,
    PayFrequency.every30Days => 30,
    _ => null,
  };

  static DateTime? _dateOnly(DateTime? date) => date == null
      ? null
      : DateTime(date.toLocal().year, date.toLocal().month, date.toLocal().day);

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
    await prefs.remove(_keyDailySpendingAllocation);
    await prefs.remove(_keySalaryPaydayDays);
    await prefs.remove(_keyPayFrequency);
    await prefs.remove(_keyPayday1);
    await prefs.remove(_keyPayday2);
    await prefs.remove(_keyPayIntervalDays);
    await prefs.remove(_keyAnchorPayday);
    _currency = '₱';
    _dailySpendingAllocation = 172.30;
    _salaryPaydayDays = [30];
    _payFrequency = PayFrequency.monthly;
    _payday1 = 30;
    _payday2 = null;
    _intervalDays = null;
    _anchorPayday = null;
    dailySpendingAllocationNotifier.value = _dailySpendingAllocation;
    _themeMode = ThemeMode.light;
    _budgetAlerts = true;
    _smartSuggestions = true;
    _compactView = false;
    _showSavingsTips = true;
    _userName = '';
    notifyListeners();
  }
}
