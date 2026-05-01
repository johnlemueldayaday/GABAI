import 'package:flutter/material.dart';

// Core Application Colors
Color kPrimary = HSLColor.fromAHSL(1.0, 152, 0.45, 0.42).toColor();
Color kBackground = HSLColor.fromAHSL(1.0, 40, 0.20, 0.97).toColor();
Color kTextCharcoal = HSLColor.fromAHSL(1.0, 220, 0.20, 0.14).toColor();
Color kMuted = HSLColor.fromAHSL(1.0, 220, 0.10, 0.50).toColor();
Color kPrimaryLight = HSLColor.fromAHSL(1.0, 152, 0.40, 0.55).toColor();
Color kPrimarySoft = HSLColor.fromAHSL(1.0, 152, 0.35, 0.92).toColor();
Color kCardBg = Colors.white;

Color kMutedBg = const Color(0xFFE5E7EB);
Color kBorder = const Color(0xFFE5E7EB);

BoxShadow get kShadowSoft => BoxShadow(
  color: kTextCharcoal.withValues(alpha: 0.06),
  offset: const Offset(0, 2),
  blurRadius: 20,
  spreadRadius: -4,
);

void updateAppTheme(ThemeMode mode) {
  if (mode == ThemeMode.dark) {
    kBackground = const Color(0xFF111827); // Darker gray
    kTextCharcoal = const Color(0xFFF9FAFB); // Almost white
    kCardBg = const Color(0xFF1F2937); // Lighter dark gray
    kMuted = const Color(0xFF9CA3AF);
    kMutedBg = const Color(0xFF374151);
    kBorder = const Color(0xFF374151);
    // Keep primary colors the same to retain branding
    kPrimary = HSLColor.fromAHSL(1.0, 152, 0.45, 0.42).toColor();
    kPrimaryLight = HSLColor.fromAHSL(1.0, 152, 0.40, 0.55).toColor();
    kPrimarySoft = HSLColor.fromAHSL(1.0, 152, 0.35, 0.15).toColor(); // Darker soft variant for dark mode
  } else {
    // Light Mode (Default)
    kPrimary = HSLColor.fromAHSL(1.0, 152, 0.45, 0.42).toColor();
    kBackground = HSLColor.fromAHSL(1.0, 40, 0.20, 0.97).toColor();
    kTextCharcoal = HSLColor.fromAHSL(1.0, 220, 0.20, 0.14).toColor();
    kMuted = HSLColor.fromAHSL(1.0, 220, 0.10, 0.50).toColor();
    kPrimaryLight = HSLColor.fromAHSL(1.0, 152, 0.40, 0.55).toColor();
    kPrimarySoft = HSLColor.fromAHSL(1.0, 152, 0.35, 0.92).toColor();
    kCardBg = Colors.white;
    kMutedBg = const Color(0xFFE5E7EB);
    kBorder = const Color(0xFFE5E7EB);
  }
}
