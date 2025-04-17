// main.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Allergen Detector',
      theme: ThemeData(
        primarySwatch: Colors.green,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = false;
  Map<String, dynamic>? _ingredientData;
  String? _errorMessage;

  // TODO: Replace with your actual Spoonacular API key
  final String apiKey = 'f3b08408937d4ef7b9a0d2897b4809b3';

  Future<void> _searchIngredient(String query) async {
    if (query.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter an ingredient to search';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _ingredientData = null;
    });

    try {
      // First, search for the ingredient
      final searchUrl = Uri.parse(
        'https://api.spoonacular.com/food/ingredients/search?query=$query&apiKey=$apiKey',
      );
      final searchResponse = await http.get(searchUrl);

      if (searchResponse.statusCode != 200) {
        throw Exception('Failed to search ingredient: ${searchResponse.body}');
      }

      final searchData = json.decode(searchResponse.body);
      if (searchData['results'] == null || searchData['results'].isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'No ingredients found for "$query"';
        });
        return;
      }

      // Get the first result's ID
      final int ingredientId = searchData['results'][0]['id'];

      // Then, get detailed information about the ingredient
      final infoUrl = Uri.parse(
        'https://api.spoonacular.com/food/ingredients/$ingredientId/information?amount=1&apiKey=$apiKey',
      );
      final infoResponse = await http.get(infoUrl);

      if (infoResponse.statusCode != 200) {
        throw Exception('Failed to get ingredient info: ${infoResponse.body}');
      }

      final infoData = json.decode(infoResponse.body);
      setState(() {
        _ingredientData = infoData;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error: ${e.toString()}';
      });
    }
  }

  List<String>? _getAllergens() {
    if (_ingredientData == null) return null;

    // Extract common allergens from the ingredient data
    List<String> allergens = [];

    // Check for common allergens in the ingredient information
    // Note: This is a simplified example - you may need to adjust based on the actual API response
    if (_ingredientData!['name'] != null) {
      final String name = _ingredientData!['name'].toString().toLowerCase();

      // Common allergens detection
      if (name.contains('milk') ||
          name.contains('dairy') ||
          name.contains('lactose')) {
        allergens.add('Milk/Dairy');
      }
      if (name.contains('peanut')) {
        allergens.add('Peanuts');
      }
      if (name.contains('tree nut') ||
          name.contains('almond') ||
          name.contains('cashew') ||
          name.contains('walnut') ||
          name.contains('hazelnut')) {
        allergens.add('Tree Nuts');
      }
      if (name.contains('egg')) {
        allergens.add('Eggs');
      }
      if (name.contains('wheat') || name.contains('gluten')) {
        allergens.add('Wheat/Gluten');
      }
      if (name.contains('soy') || name.contains('soya')) {
        allergens.add('Soy');
      }
      if (name.contains('fish') ||
          name.contains('salmon') ||
          name.contains('tuna')) {
        allergens.add('Fish');
      }
      if (name.contains('shellfish') ||
          name.contains('shrimp') ||
          name.contains('crab') ||
          name.contains('lobster')) {
        allergens.add('Shellfish');
      }
      if (name.contains('sesame')) {
        allergens.add('Sesame');
      }
    }

    return allergens.isEmpty ? ['No common allergens detected'] : allergens;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Allergen Detector'), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Search bar
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Enter an ingredient name',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () => _searchIngredient(_searchController.text),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onSubmitted: _searchIngredient,
            ),
            const SizedBox(height: 20),

            // Loading indicator
            if (_isLoading) const Center(child: CircularProgressIndicator()),

            // Error message
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: Colors.red.shade800),
                ),
              ),

            // Results
            if (_ingredientData != null && !_isLoading)
              Expanded(
                child: SingleChildScrollView(
                  child: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Ingredient name
                          Text(
                            _ingredientData!['name'] ?? 'Unknown Ingredient',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Divider(),

                          // Ingredient image if available
                          if (_ingredientData!['image'] != null)
                            Center(
                              child: Image.network(
                                'https://spoonacular.com/cdn/ingredients_250x250/${_ingredientData!['image']}',
                                height: 150,
                                width: 150,
                                fit: BoxFit.contain,
                                errorBuilder:
                                    (context, _, __) => const Icon(
                                      Icons.image_not_supported,
                                      size: 150,
                                      color: Colors.grey,
                                    ),
                              ),
                            ),
                          const SizedBox(height: 16),

                          // Allergen information
                          const Text(
                            'Potential Allergens:',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ..._getAllergens()!
                              .map(
                                (allergen) => Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        allergen ==
                                                'No common allergens detected'
                                            ? Icons.check_circle
                                            : Icons.warning,
                                        color:
                                            allergen ==
                                                    'No common allergens detected'
                                                ? Colors.green
                                                : Colors.orange,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        allergen,
                                        style: TextStyle(
                                          fontSize: 16,
                                          color:
                                              allergen ==
                                                      'No common allergens detected'
                                                  ? Colors.green
                                                  : Colors.orange,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                              .toList(),

                          const SizedBox(height: 16),

                          // Additional information
                          if (_ingredientData!['nutrition'] != null &&
                              _ingredientData!['nutrition']['nutrients'] !=
                                  null)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Nutrition Facts:',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ...((_ingredientData!['nutrition']['nutrients']
                                        as List)
                                    .take(5)
                                    .map(
                                      (nutrient) => Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 2,
                                        ),
                                        child: Text(
                                          '${nutrient['name']}: ${nutrient['amount']} ${nutrient['unit']}',
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                      ),
                                    )).toList(),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
