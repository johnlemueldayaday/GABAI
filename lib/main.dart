import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gabay/pages/home.dart';
import 'package:gabay/services/chat_storage.dart';
import 'package:gabay/services/grocery_storage.dart';
import 'package:gabay/services/settings_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark.copyWith(
    statusBarColor: Colors.transparent,
  ));

  // Load persisted data
  await GroceryStorage.loadAll();
  await SettingsService().load();
  
  // Exclusively for Ramsey: Reset conversation history on app reopen
  await ChatStorage.clear();
  
  runApp(const GroceryApp());
}

