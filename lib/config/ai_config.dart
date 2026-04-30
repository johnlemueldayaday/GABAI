class AIConfig {
  const AIConfig._();

  static const String geminiApiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
  );

  static bool get hasGeminiApiKey => geminiApiKey.trim().isNotEmpty;
}
