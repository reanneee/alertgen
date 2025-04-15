import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class GeminiService {
  final String apiKey = 'AIzaSyATGAQK5mH4g1pSRnzc2HAYHyoOztO_SDI';

  // Use valid Gemini model names
  final String textModel = 'gemini-pro';
  final String visionModel = 'gemini-pro-vision';

  Future<String> analyzeIngredients(List<String> ingredients) async {
    try {
      final prompt = '''
  You are an allergen detection assistant. Analyze the following ingredients and label each one whether it:

  ✅ Contains an allergen (specify which one: dairy, eggs, peanuts, tree nuts, fish, shellfish, wheat, soy, sesame, etc.)
  ⚠️ May contain an allergen (specify which one might be present)
  ➖ No common allergen detected

  Ingredients:
  ${ingredients.join('\n')}

  Respond in this format:
  Ingredient - Label with any relevant allergen information
  ''';

      // Initialize the model object with the text model
      final genAI = GenerativeModel(model: textModel, apiKey: apiKey);

      final response = await genAI.generateContent([Content.text(prompt)]);
      return response.text ?? 'No response';
    } catch (e) {
      debugPrint("Gemini API Error: $e");
      return "Error analyzing ingredients: $e";
    }
  }

  Future<String> analyzeFoodImage(File imageFile, String description) async {
    try {
      // Read image bytes
      final Uint8List imageBytes = await imageFile.readAsBytes();

      // Create the prompt text
      final prompt = '''
Analyze this food image and the provided description. 
Description: $description

Identify all potential ingredients and allergens. For each identified ingredient, label whether it:

✅ Contains an allergen (specify which common allergen)
⚠️ May contain an allergen
➖ No common allergen detected

Common allergens include: dairy, eggs, peanuts, tree nuts, fish, shellfish, wheat/gluten, soy, sesame.

List each ingredient on a separate line with its allergen status.
''';

      // Initialize the vision model
      final model = GenerativeModel(model: visionModel, apiKey: apiKey);

      // Create content with text and image parts
      final content = Content.multi([
        TextPart(prompt),
        DataPart('image/jpeg', imageBytes),
      ]);

      // Generate content using the multimodal content
      final response = await model.generateContent([content]);

      return response.text ?? 'No response';
    } catch (e) {
      debugPrint("Gemini Vision API Error: $e");
      // Fallback to text analysis if image analysis fails
      return analyzeIngredients([
        description,
        "This is a food dish that might contain common allergens.",
      ]);
    }
  }

  Future<String> identifyDish(File imageFile) async {
    try {
      // Read image bytes
      final Uint8List imageBytes = await imageFile.readAsBytes();

      // Create the prompt text
      const prompt = '''
Identify what dish or food item is shown in this image. 
Provide a brief description including:
1. The name of the dish
2. What cuisine it belongs to
3. A brief list of its typical main ingredients
''';

      // Initialize the vision model
      final model = GenerativeModel(model: visionModel, apiKey: apiKey);

      // Create content with text and image parts
      final content = Content.multi([
        TextPart(prompt),
        DataPart('image/jpeg', imageBytes),
      ]);

      // Generate content using the multimodal content
      final response = await model.generateContent([content]);

      return response.text ?? 'No response';
    } catch (e) {
      debugPrint("Gemini Vision API Error: $e");
      return "Unidentified Food Dish\n\nPotential common ingredients that may contain allergens: wheat, dairy, eggs, nuts";
    }
  }
}
