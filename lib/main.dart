import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gabay/pages/home.dart';
import 'package:gabay/services/grocery_storage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark.copyWith(
    statusBarColor: Colors.transparent,
  ));

  // Load persisted data
  await GroceryStorage.loadAll();
  
  runApp(const GroceryApp());
}
