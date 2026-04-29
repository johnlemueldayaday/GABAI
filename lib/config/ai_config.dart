class AIConfig {
  const AIConfig._();

  static const String geminiApiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: 'AIzaSyCipKlF93bKuuOUmmJxolx_RsDdqY4-YSk',
  );

  static bool get hasGeminiApiKey => geminiApiKey.trim().isNotEmpty;
}
