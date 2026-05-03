import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/ai_config.dart';
import 'chat_ai_service.dart';

/// Direct HTTP-based Gemini API service.
/// Bypasses the google_generative_ai SDK to avoid v1beta model compatibility issues.
class GeminiHttpService implements ChatAiService {
  static const String _baseUrl = 'https://generativelanguage.googleapis.com/v1beta';
  static const String _model = 'gemini-2.5-flash';
  static const String _fallbackModel = 'gemini-2.5-flash-lite';

  final List<Map<String, dynamic>> _history = [];

  /// Initialize with a system prompt injected as the first user/model exchange.
  @override
  void initWithSystemPrompt(String systemPrompt) {
    _history.clear();
    _history.add({
      'role': 'user',
      'parts': [{'text': systemPrompt}]
    });
    _history.add({
      'role': 'model',
      'parts': [{'text': 'Understood. I am Ramsey, the smart grocery assistant. How can I help you today?'}]
    });
  }

  /// Load previous chat messages into history.
  @override
  void loadHistory(List<Map<String, String>> messages) {
    for (final msg in messages) {
      _history.add({
        'role': msg['role'] == 'user' ? 'user' : 'model',
        'parts': [{'text': msg['text'] ?? ''}]
      });
    }
  }

  /// Clear all history.
  @override
  void clearHistory() {
    _history.clear();
  }

  /// Send a message and get a response.
  @override
  Future<String> sendMessage(String userMessage) async {
    // Add user message to history
    _history.add({
      'role': 'user',
      'parts': [{'text': userMessage}]
    });

    // Try primary model first, then fallback
    String? response = await _callApi(_model);
    if (response == null) {
      debugPrint('⚠️ Primary model failed, trying fallback...');
      response = await _callApi(_fallbackModel);
    }

    if (response != null) {
      // Add model response to history
      _history.add({
        'role': 'model',
        'parts': [{'text': response}]
      });
      return response;
    }

    throw Exception('Failed to get response from Gemini API');
  }

  Future<String?> _callApi(String model) async {
    final url = '$_baseUrl/models/$model:generateContent?key=${AIConfig.geminiApiKey}';

    final body = jsonEncode({
      'contents': _history,
      'tools': [
        {
          'googleSearch': {}
        }
      ],
      'generationConfig': {
        'temperature': 0.8,
        'topP': 0.95,
        'topK': 40,
        'maxOutputTokens': 2048,
      },
    });

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: body,
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final candidates = data['candidates'] as List<dynamic>?;
        if (candidates != null && candidates.isNotEmpty) {
          final content = candidates[0]['content'];
          final parts = content['parts'] as List<dynamic>?;
          if (parts != null && parts.isNotEmpty) {
            return parts[0]['text'] as String?;
          }
        }
        debugPrint('GeminiHttp: No text in response: ${response.body}');
        return null;
      } else if (response.statusCode == 429) {
        debugPrint('GeminiHttp: Rate limited (429). Retrying after delay...');
        await Future.delayed(const Duration(seconds: 3));
        // Retry once
        final retry = await http.post(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
          body: body,
        ).timeout(const Duration(seconds: 30));
        if (retry.statusCode == 200) {
          final data = jsonDecode(retry.body);
          final candidates = data['candidates'] as List<dynamic>?;
          if (candidates != null && candidates.isNotEmpty) {
            final content = candidates[0]['content'];
            final parts = content['parts'] as List<dynamic>?;
            if (parts != null && parts.isNotEmpty) {
              return parts[0]['text'] as String?;
            }
          }
        }
        final errBody = jsonDecode(retry.body);
        throw Exception(errBody['error']?['message'] ?? 'Rate limit exceeded');
      } else {
        final errBody = jsonDecode(response.body);
        final errMsg = errBody['error']?['message'] ?? 'Unknown error (${response.statusCode})';
        debugPrint('GeminiHttp: Error $model: $errMsg');
        throw Exception(errMsg);
      }
    } catch (e) {
      if (e is Exception && e.toString().contains('Exception:')) {
        rethrow;
      }
      debugPrint('GeminiHttp: Network error for $model: $e');
      return null;
    }
  }

  /// One-shot image analysis (for scanner).
  static Future<Map<String, dynamic>?> analyzeImage({
    required Uint8List imageBytes,
    required String prompt,
  }) async {
    final url = '$_baseUrl/models/$_model:generateContent?key=${AIConfig.geminiApiKey}';
    final base64Image = base64Encode(imageBytes);

    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': prompt},
            {
              'inline_data': {
                'mime_type': 'image/jpeg',
                'data': base64Image,
              }
            }
          ]
        }
      ],
    });

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: body,
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final candidates = data['candidates'] as List<dynamic>?;
        if (candidates != null && candidates.isNotEmpty) {
          final content = candidates[0]['content'];
          final parts = content['parts'] as List<dynamic>?;
          if (parts != null && parts.isNotEmpty) {
            final text = parts[0]['text'] as String?;
            if (text != null) {
              final jsonMatch = RegExp(r'\{.*\}', dotAll: true).firstMatch(text);
              if (jsonMatch != null) {
                return jsonDecode(jsonMatch.group(0)!);
              }
            }
          }
        }
      } else {
        debugPrint('GeminiHttp: Image analysis error: ${response.body}');
      }
    } catch (e) {
      debugPrint('GeminiHttp: Image analysis exception: $e');
    }
    return null;
  }
}
