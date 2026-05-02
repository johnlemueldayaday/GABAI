import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/ai_config.dart';
import 'chat_ai_service.dart';

/// Chat service for offline/local OpenAI-compatible servers.
///
/// Works with Ollama (`http://localhost:11434/v1`) and llama.cpp server
/// (`http://localhost:8080/v1`) once a model is already downloaded locally.
class LocalOpenAIChatService implements ChatAiService {
  final List<Map<String, String>> _messages = [];

  @override
  void initWithSystemPrompt(String systemPrompt) {
    _messages.clear();
    _messages.add({
      'role': 'system',
      'content': systemPrompt,
    });
  }

  @override
  void loadHistory(List<Map<String, String>> messages) {
    for (final msg in messages) {
      _messages.add({
        'role': msg['role'] == 'user' ? 'user' : 'assistant',
        'content': msg['text'] ?? '',
      });
    }
  }

  @override
  void clearHistory() {
    _messages.clear();
  }

  @override
  Future<String> sendMessage(String userMessage) async {
    _messages.add({
      'role': 'user',
      'content': userMessage,
    });

    final response = await _callApi();
    _messages.add({
      'role': 'assistant',
      'content': response,
    });
    return response;
  }

  Future<String> _callApi() async {
    final baseUrl = AIConfig.localAiBaseUrl.replaceFirst(RegExp(r'/+$'), '');
    final url = '$baseUrl/chat/completions';

    final body = jsonEncode({
      'model': AIConfig.localAiModel,
      'messages': _messages,
      'temperature': 0.7,
      'top_p': 0.9,
      'max_tokens': 2048,
      'stream': false,
    });

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${AIConfig.localAiApiKey}',
        },
        body: body,
      ).timeout(const Duration(seconds: 120));

      if (response.statusCode != 200) {
        debugPrint(
          'LocalOpenAI: Error ${response.statusCode}: ${response.body}',
        );
        throw Exception('Local AI server returned ${response.statusCode}');
      }

      final data = jsonDecode(response.body);
      final choices = data['choices'] as List<dynamic>?;
      if (choices == null || choices.isEmpty) {
        throw Exception('Local AI server returned no choices');
      }

      final message = choices[0]['message'] as Map<String, dynamic>?;
      final content = message?['content'];
      if (content is String && content.trim().isNotEmpty) {
        return content;
      }

      throw Exception('Local AI server returned an empty response');
    } catch (e) {
      debugPrint('LocalOpenAI: Request failed: $e');
      rethrow;
    }
  }
}
