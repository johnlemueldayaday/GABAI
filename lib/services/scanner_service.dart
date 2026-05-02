import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../config/ai_config.dart';
import 'gemini_http_service.dart';

class ScannerService {
  static Future<Map<String, dynamic>?> scanProduct(XFile image) async {
    if (!AIConfig.hasGeminiApiKey) return null;

    final bytes = await image.readAsBytes();

    try {
      final result = await GeminiHttpService.analyzeImage(
        imageBytes: bytes,
        prompt: "Analyze this image of a product. Extract the product name and its price in Philippine Peso (₱). Return the result in this exact JSON format: {\"name\": \"Product Name\", \"price\": 0.0}. If no price is found, return 0.0. If no product name is found, return 'Unknown Product'. Do not include any other text, only the JSON block.",
      );

      if (result != null) {
        debugPrint('ScannerService: AI Response: $result');
      } else {
        debugPrint('ScannerService: No result from AI');
      }

      return result;
    } catch (e) {
      debugPrint('ScannerService: Error generating content: $e');
    }
    return null;
  }
}
