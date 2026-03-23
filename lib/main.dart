import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_aismartwallet/pages/home.dart';

void main() {
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark.copyWith(
    statusBarColor: Colors.transparent,
  ));
  runApp(const GroceryApp());
}
