import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gabay/pages/cart.dart'
    show GroceryApp, groceryScaffoldMessengerKey;
import 'package:gabay/services/grocery_storage.dart';
import 'package:gabay/services/price_storage.dart';
import 'package:gabay/services/settings_service.dart';
import 'package:gabay/services/notification_service.dart';
import 'package:gabay/services/bill_calendar_service.dart';
import 'package:gabay/services/bill_storage.dart';
import 'package:gabay/services/sm_supermarket_price_seeder.dart';
import 'package:gabay/services/puregold_price_seeder.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
  );

  // Load persisted data
  await GroceryStorage.loadAll();
  await PriceStorage.load();
  SmSupermarketPriceSeeder.seed(); // Seed SM Supermarket reference prices
  PuregoldPriceSeeder.seed();       // Seed Puregold reference prices
  await SettingsService().load();

  await NotificationService().init();

  runApp(const GroceryApp());
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _restoreBillReminders();
  });
}

Future<void> _restoreBillReminders() async {
  final bills = await BillStorage.loadBills();
  if (bills.isEmpty) return;

  final errors = <String>[];
  try {
    await NotificationService().rescheduleAllBills(bills);
  } catch (error) {
    errors.add('Phone notifications: $error');
  }

  try {
    await BillCalendarService().syncAllBills(bills);
  } catch (error) {
    errors.add('Phone calendar: $error');
  }

  if (errors.isNotEmpty) {
    groceryScaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(content: Text('Reminder setup issue. ${errors.join(' ')}')),
    );
  }
}
