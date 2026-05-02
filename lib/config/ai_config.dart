import 'package:flutter/foundation.dart';

class AIConfig {
  const AIConfig._();

  static const String _rawAiProvider = String.fromEnvironment(
    'AI_PROVIDER',
    defaultValue: 'gemini',
  );

  static const String _rawLocalAiBaseUrl = String.fromEnvironment(
    'LOCAL_AI_BASE_URL',
    defaultValue: 'http://localhost:11434/v1',
  );

  static const String _rawLocalAiModel = String.fromEnvironment(
    'LOCAL_AI_MODEL',
    defaultValue: 'llama3.2:3b',
  );

  static const String _rawLocalAiApiKey = String.fromEnvironment(
    'LOCAL_AI_API_KEY',
    defaultValue: 'local-ai',
  );

  static const String _rawGeminiApiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: '',
  );

  static String get aiProvider => _rawAiProvider.trim().toLowerCase();

  static bool get useLocalAi => aiProvider != 'gemini';

  static String get localAiBaseUrl => _rawLocalAiBaseUrl.trim();

  static String get localAiModel => _rawLocalAiModel.trim();

  static String get localAiApiKey => _rawLocalAiApiKey.trim();

  static bool get hasLocalAiConfig =>
      localAiBaseUrl.isNotEmpty && localAiModel.isNotEmpty;

  static String get geminiApiKey => _rawGeminiApiKey.trim();

  static bool get hasGeminiApiKey {
    final hasKey = geminiApiKey.isNotEmpty;
    if (!hasKey) {
      debugPrint(
        'DEBUG: Gemini API Key is missing. Please run with --dart-define=GEMINI_API_KEY=your_key',
      );
    }
    return hasKey;
  }

}
