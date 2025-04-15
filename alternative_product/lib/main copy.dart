import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Allergen Scanner',
      theme: ThemeData(primarySwatch: Colors.teal),
      home: AllergenScannerScreen(),
    );
  }
}

class AllergenScannerScreen extends StatefulWidget {
  @override
  State<AllergenScannerScreen> createState() => _AllergenScannerScreenState();
}

class _AllergenScannerScreenState extends State<AllergenScannerScreen> {
  String barcode = '';
  List<String> ingredients = [];
  List<String> alternatives = [];
  List<String> userAllergens = [
    'peanut',
    'gluten',
    'milk',
  ]; // Changeable by user
  bool hasAllergens = false;
  String scannedFood = '';
  bool isLoading = false;

  final String apiKey =
      'f3b08408937d4ef7b9a0d2897b4809b3'; // Replace with your actual key

  Future<void> getProductDetailsFromBarcode(String code) async {
    setState(() {
      isLoading = true;
      barcode = code;
      ingredients = [];
      alternatives = [];
      hasAllergens = false;
      scannedFood = '';
    });

    final url =
        'https://api.spoonacular.com/food/products/upc/$code?apiKey=$apiKey';

    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final productName = data['title'] ?? 'Unknown';
      final ingList =
          (data['ingredients'] as List?)
              ?.map((i) => i['name'].toString().toLowerCase())
              .toList() ??
          [];

      final allergenDetected = ingList.any(
        (ingredient) => userAllergens.any((a) => ingredient.contains(a)),
      );

      setState(() {
        scannedFood = productName;
        ingredients = ingList;
        hasAllergens = allergenDetected;
      });

      if (allergenDetected) {
        await getSafeAlternatives();
      }
    } else {
      setState(() {
        scannedFood = 'Unknown product';
        ingredients = [];
      });
    }

    setState(() {
      isLoading = false;
    });
  }

  Future<void> getSafeAlternatives() async {
    final intolerance = userAllergens.join(',');
    final url =
        'https://api.spoonacular.com/recipes/complexSearch?intolerances=$intolerance&number=5&apiKey=$apiKey';

    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final recipes =
          (data['results'] as List).map((r) => r['title'].toString()).toList();

      setState(() {
        alternatives = recipes;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Allergen Scanner')),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: MobileScanner(
              onDetect: (barcodeCapture) {
                final String? code = barcodeCapture.barcodes.first.rawValue;
                if (code != null && code != barcode) {
                  getProductDetailsFromBarcode(code);
                }
              },
            ),
          ),
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child:
                  isLoading
                      ? Center(child: CircularProgressIndicator())
                      : ListView(
                        children: [
                          Text(
                            "📦 Product: $scannedFood",
                            style: TextStyle(fontSize: 18),
                          ),
                          SizedBox(height: 10),
                          Text(
                            "🧾 Ingredients:",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          ...ingredients.map((e) => Text("- $e")),
                          if (hasAllergens) ...[
                            SizedBox(height: 20),
                            Text(
                              "⚠️ Allergen detected!",
                              style: TextStyle(color: Colors.red),
                            ),
                            Text(
                              "🥗 Safe Alternatives:",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            ...alternatives.map((alt) => Text("✔️ $alt")),
                          ] else if (ingredients.isNotEmpty) ...[
                            SizedBox(height: 10),
                            Text(
                              "✅ No allergens found!",
                              style: TextStyle(color: Colors.green),
                            ),
                          ],
                        ],
                      ),
            ),
          ),
        ],
      ),
    );
  }
}
