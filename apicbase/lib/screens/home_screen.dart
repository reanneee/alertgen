import 'dart:convert';
import 'dart:io';
import 'package:apicbase/services/gemini_service.dart';
import 'package:apicbase/services/spoonacular_service.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/ocr_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final OCRService ocrService = OCRService();
  File? _image;
  final TextEditingController _controller = TextEditingController();
  final geminiService = GeminiService(
    'AIzaSyBOUFBMNKjus6UpY8-77UFClCPoVtBKc-Q',
  );
  final spoonacularService = SpoonacularService();
  final userAllergens = ['milk', 'soy', 'peanut'];

  String result = '';
  bool isLoading = false;

  Future<void> pickImageAndScanText() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.camera);

    if (picked != null) {
      final imageFile = File(picked.path);
      final scannedText = await ocrService.extractText(imageFile);

      setState(() {
        _controller.text = scannedText;
      });
      runDetection(); // Automatically check allergens after scan
    }
  }

  Future<int?> tryGetIngredientId(String ingredient) async {
    // Step 1: Simplify the ingredient name using Gemini
    final simplifiedIngredient = await _simplifyUsingGemini(ingredient);

    // Step 2: Try searching for the simplified ingredient directly in Spoonacular
    var id = await spoonacularService.searchIngredientId(simplifiedIngredient);
    if (id != null) return id;

    // Step 3: Use autocomplete to guess a valid ingredient name if the initial search fails
    final suggestion = await spoonacularService.autocompleteIngredient(
      simplifiedIngredient,
    );
    if (suggestion != null) {
      id = await spoonacularService.searchIngredientId(suggestion);
      if (id != null) return id;
    }

    // Step 4: Attempt another search with a fallback ingredient name
    final fallback = simplifiedIngredient
        .toLowerCase()
        .split(RegExp(r'[\s,()-]+'))
        .take(2)
        .join(' ');
    if (fallback != simplifiedIngredient.toLowerCase()) {
      id = await spoonacularService.searchIngredientId(fallback);
      if (id != null) return id;
    }

    debugPrint('Ingredient "$ingredient" not found in Spoonacular.');

    return null; // Return null if no matches were found
  }

  // Helper function to simplify ingredients using Gemini
  Future<String> _simplifyUsingGemini(String ingredient) async {
    // Use Gemini to expand ingredients for better standardization
    final expandedIngredients = await geminiService.expandIngredients(
      ingredient,
    );

    // After expansion, take the first ingredient's simplified version
    final simplifiedIngredient =
        expandedIngredients.isNotEmpty
            ? expandedIngredients.first.expanded.isNotEmpty
                ? expandedIngredients.first.expanded
                : expandedIngredients.first.ingredient
            : ingredient;

    return simplifiedIngredient;
  }

  void runDetection() async {
    setState(() {
      isLoading = true;
      result = '';
    });

    final expandedIngredients = await geminiService.expandIngredients(
      _controller.text,
    );

    final ingredientNames =
        expandedIngredients
            .map((e) => e.expanded.isNotEmpty ? e.expanded : e.ingredient)
            .toList();

    final buffer = StringBuffer();
    buffer.writeln('🧾 **Ingredient Report**\n');

    for (var ingredient in ingredientNames) {
      buffer.writeln('🍽️ Ingredient: $ingredient');

      final id = await tryGetIngredientId(ingredient);
      if (id == null) {
        buffer.writeln('❌ Not found in Spoonacular\n');
        continue;
      }

      final info = await spoonacularService.getIngredientInfo(id);
      final possibleAllergens =
          userAllergens.where((allergen) {
            final text = json.encode(info).toLowerCase();
            return text.contains(allergen.toLowerCase());
          }).toList();

      buffer.writeln('📦 Found in Spoonacular');
      if (possibleAllergens.isNotEmpty) {
        buffer.writeln('⚠️ Allergen Match: ${possibleAllergens.join(', ')}\n');
      } else {
        buffer.writeln('✅ Allergen Match: None\n');
      }
    }

    setState(() {
      result = buffer.toString();
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("AlertGen")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'Paste ingredients here...',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: pickImageAndScanText,
              icon: Icon(Icons.camera_alt),
              label: Text('Scan Ingredient with Camera'),
            ),
            SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: runDetection,
              icon: Icon(Icons.search),
              label: Text('Check for Allergens'),
            ),
            SizedBox(height: 16),
            if (isLoading) CircularProgressIndicator(),
            if (result.isNotEmpty) Text(result, style: TextStyle(fontSize: 18)),
          ],
        ),
      ),
    );
  }
}
