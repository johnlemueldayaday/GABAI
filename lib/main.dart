import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gabay/pages/cart.dart';
import 'package:gabay/services/grocery_storage.dart';
import 'package:gabay/services/price_storage.dart';
import 'package:gabay/services/settings_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
  );

  // Load persisted data
  await GroceryStorage.loadAll();
  await PriceStorage.load();
  await SettingsService().load();

  runApp(const GroceryApp());
}

