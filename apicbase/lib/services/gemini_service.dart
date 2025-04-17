import 'package:google_generative_ai/google_generative_ai.dart';

class IngredientExpansion {
  final String ingredient;
  final String expanded;

  IngredientExpansion({required this.ingredient, required this.expanded});
}

class GeminiService {
  final String apiKey;
  late final GenerativeModel model;

  GeminiService(this.apiKey) {
    model = GenerativeModel(model: 'gemini-1.5-pro', apiKey: apiKey);
  }

  Future<List<IngredientExpansion>> expandIngredients(String rawText) async {
    final prompt = '''
Clean and expand each ingredient in this list. 
If an ingredient is ambiguous (e.g., "natural flavors"), explain or guess what it might contain.
Return the list in this format: `Original: Expanded`.

Ingredients:
$rawText
''';

    final content = [Content.text(prompt)];
    final response = await model.generateContent(content);

    final lines = response.text?.split('\n') ?? [];
    return lines.where((line) => line.contains(':')).map((line) {
      final parts = line.split(':');
      return IngredientExpansion(
        ingredient: parts[0].trim(),
        expanded: parts[1].trim(),
      );
    }).toList();
  }
}
