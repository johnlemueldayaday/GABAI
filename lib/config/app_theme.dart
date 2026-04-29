import 'package:flutter/material.dart';

final Color kPrimary = HSLColor.fromAHSL(1.0, 152, 0.45, 0.42).toColor();
final Color kBackground = HSLColor.fromAHSL(1.0, 40, 0.20, 0.97).toColor();
final Color kTextCharcoal = HSLColor.fromAHSL(1.0, 220, 0.20, 0.14).toColor();
final Color kMuted = HSLColor.fromAHSL(1.0, 220, 0.10, 0.50).toColor();
final Color kPrimaryLight = HSLColor.fromAHSL(1.0, 152, 0.40, 0.55).toColor();
final Color kPrimarySoft = HSLColor.fromAHSL(1.0, 152, 0.35, 0.92).toColor();
final Color kCardBg = Colors.white;

final Color kMutedBg = const Color(0xFFE5E7EB);
final Color kBorder = const Color(0xFFE5E7EB);

final BoxShadow kShadowSoft = BoxShadow(
  color: kTextCharcoal.withValues(alpha: 0.06),
  offset: const Offset(0, 2),
  blurRadius: 20,
  spreadRadius: -4,
);
