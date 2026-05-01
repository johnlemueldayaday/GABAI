import 'package:flutter/foundation.dart';

class AIConfig {
  const AIConfig._();

  static const String _rawGeminiApiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: 'AIzaSyD04AGxXTVY5boDIDQdmi3HHudkuMSgAuc',
  );

  static String get geminiApiKey => _rawGeminiApiKey.trim();

  static bool get hasGeminiApiKey {
    final hasKey = geminiApiKey.isNotEmpty;
    if (!hasKey) {
      debugPrint('DEBUG: Gemini API Key is missing. Please run with --dart-define=GEMINI_API_KEY=your_key');
    }
    return hasKey;
  }


}
