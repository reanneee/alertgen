import 'package:http/http.dart' as http;
import 'dart:convert';

class SpoonacularService {
  final String apiKey = 'f3b08408937d4ef7b9a0d2897b4809b3'; // replace this

  // Search for an ingredient and return its ID
  Future<int?> searchIngredientId(String name) async {
    final response = await http.get(
      Uri.parse(
        'https://api.spoonacular.com/food/ingredients/search?query=$name&apiKey=$apiKey',
      ),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final results = data['results'] as List;
      if (results.isNotEmpty) {
        return results[0]['id'];
      }
    }

    return null;
  }

  Future<String?> autocompleteIngredient(String query) async {
    final response = await http.get(
      Uri.parse(
        'https://api.spoonacular.com/food/ingredients/autocomplete?query=$query&number=1&apiKey=$apiKey',
      ),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data.isNotEmpty) {
        return data[0]['name'];
      }
    }
    return null;
  }

  // Get detailed info (like possible allergens)
  Future<Map<String, dynamic>?> getIngredientInfo(int id) async {
    final response = await http.get(
      Uri.parse(
        'https://api.spoonacular.com/food/ingredients/$id/information?amount=1&apiKey=$apiKey',
      ),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    }

    return null;
  }
}
