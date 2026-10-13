import 'dart:convert';
import 'dart:typed_data';

import 'package:google_generative_ai/google_generative_ai.dart';

import 'gemini_api_key_resolver.dart';

class MissingGeminiApiKeyException implements Exception {
  const MissingGeminiApiKeyException();
}

class DetectedFoodItem {
  const DetectedFoodItem({
    required this.name,
    required this.servingSize,
    required this.quantity,
    required this.caloriesPerServing,
    required this.proteinGramsPerServing,
    required this.carbsGramsPerServing,
    required this.fatGramsPerServing,
  });

  final String name;
  final String servingSize;
  final double quantity;
  final double caloriesPerServing;
  final double proteinGramsPerServing;
  final double carbsGramsPerServing;
  final double fatGramsPerServing;
}

List<DetectedFoodItem> parseDetectedFoodJson(String rawJson) {
  final decoded = jsonDecode(rawJson.trim());
  if (decoded is! Map<String, dynamic> || decoded['items'] is! List) {
    throw const FormatException('Expected a JSON object with an items list.');
  }

  final items = decoded['items'] as List<dynamic>;
  if (items.isEmpty) {
    throw const FormatException('No food items were detected in this photo.');
  }

  final result = <DetectedFoodItem>[];
  for (final value in items) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Each detected food must be a JSON object.');
    }

    final name = value['name'];
    final servingSize = value['servingSize'];
    if (name is! String || name.trim().isEmpty) {
      throw const FormatException('A detected food is missing its name.');
    }
    if (servingSize is! String || servingSize.trim().isEmpty) {
      throw const FormatException(
        'A detected food is missing its serving size.',
      );
    }

    final quantity = _requiredNumber(value, 'quantity');
    if (quantity <= 0) {
      throw const FormatException('Food quantities must be greater than zero.');
    }

    result.add(
      DetectedFoodItem(
        name: name.trim(),
        servingSize: servingSize.trim(),
        quantity: quantity,
        caloriesPerServing: _requiredNumber(value, 'caloriesPerServing'),
        proteinGramsPerServing: _requiredNumber(
          value,
          'proteinGramsPerServing',
        ),
        carbsGramsPerServing: _requiredNumber(value, 'carbsGramsPerServing'),
        fatGramsPerServing: _requiredNumber(value, 'fatGramsPerServing'),
      ),
    );
  }
  return result;
}

double _requiredNumber(Map<String, dynamic> value, String field) {
  final number = value[field];
  if (number is! num || !number.toDouble().isFinite || number < 0) {
    throw FormatException('Expected a non-negative number for "$field".');
  }
  return number.toDouble();
}

class GeminiFoodDetectionService {
  Future<List<DetectedFoodItem>> detectFoods({
    required Uint8List imageBytes,
    required String mimeType,
    required Object? savedApiKey,
  }) async {
    final key = resolveGeminiApiKey(
      savedValue: savedApiKey,
      compiledDefault: kGeminiApiKey,
    ).key;
    if (key == null) {
      throw const MissingGeminiApiKeyException();
    }

    final model = GenerativeModel(
      model: kGeminiModelName,
      apiKey: key,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
        temperature: 0.2,
      ),
    );
    const prompt = '''
Identify each distinct food item visible in this photo. Estimate a realistic serving size and nutrition for each item. These are estimates, not exact measurements.

Return strict JSON only, with no markdown fences, in this format:
{"items":[{"name":"...","servingSize":"...","quantity":1,"caloriesPerServing":0,"proteinGramsPerServing":0,"carbsGramsPerServing":0,"fatGramsPerServing":0}]}

Use numbers for quantity and every nutrition value. Nutrition values must be for one serving described by servingSize. Return an empty items list only if no food is visible.
''';
    final response = await model.generateContent([
      Content.multi([TextPart(prompt), DataPart(mimeType, imageBytes)]),
    ]);
    final text = response.text?.trim();
    if (text == null || text.isEmpty) {
      throw const FormatException('Gemini returned an empty response.');
    }
    return parseDetectedFoodJson(text);
  }
}
