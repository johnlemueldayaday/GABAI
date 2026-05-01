import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:image_picker/image_picker.dart';
import '../config/ai_config.dart';

class ScannerService {
  static Future<Map<String, dynamic>?> scanProduct(XFile image) async {
    if (!AIConfig.hasGeminiApiKey) return null;

    final model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: AIConfig.geminiApiKey,
    );

    final bytes = await image.readAsBytes();
    
    final prompt = [
      Content.multi([
        TextPart("Analyze this image of a product. Extract the product name and its price in Philippine Peso (₱). Return the result in this exact JSON format: {\"name\": \"Product Name\", \"price\": 0.0}. If no price is found, return 0.0. If no product name is found, return 'Unknown Product'. Do not include any other text, only the JSON block."),
        DataPart('image/jpeg', bytes),
      ])
    ];

    try {
      final response = await model.generateContent(prompt);
      final text = response.text;
      if (text == null) {
        debugPrint('ScannerService: No text in response');
        return null;
      }

      debugPrint('ScannerService: AI Response: $text');

      // Extract JSON from response
      final jsonMatch = RegExp(r'\{.*\}', dotAll: true).firstMatch(text);
      if (jsonMatch != null) {
        try {
          return jsonDecode(jsonMatch.group(0)!);
        } catch (je) {
          debugPrint('ScannerService: JSON decode error: $je');
        }
      } else {
        debugPrint('ScannerService: No JSON found in response');
      }
    } catch (e) {
      debugPrint('ScannerService: Error generating content: $e');
      debugPrint('ScannerService: API Key length: ${AIConfig.geminiApiKey.length}');
      if (AIConfig.geminiApiKey.length > 4) {
        debugPrint('ScannerService: API Key prefix: ${AIConfig.geminiApiKey.substring(0, 4)}...');
      }
    }
    return null;


  }
}
