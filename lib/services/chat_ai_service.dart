abstract class ChatAiService {
  void initWithSystemPrompt(String systemPrompt);

  void loadHistory(List<Map<String, String>> messages);

  void clearHistory();

  Future<String> sendMessage(String userMessage);
}
