import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Food Scanner',
      theme: ThemeData(primarySwatch: Colors.green, useMaterial3: true),
      home: const HomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? barcode;
  Map<String, dynamic>? product;
  List<String> userAllergens = ['peanuts', 'gluten'];
  List<dynamic> alternatives = [];

  Future<void> fetchProduct(String barcode) async {
    final url =
        'https://world.openfoodfacts.net/api/v2/product/$barcode?fields=product_name,image_url,ingredients_text,allergens_tags';
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final productData = data['product'];
      final productAllergens = productData['allergens_tags'] ?? [];
      final detectedAllergens =
          productAllergens
              .where((a) => userAllergens.contains(a.replaceAll('en:', '')))
              .toList();

      setState(() {
        product = {
          'name': productData['product_name'] ?? 'Unknown Product',
          'image': productData['image_url'],
          'ingredients':
              productData['ingredients_text'] ?? 'No ingredients found',
          'allergens': detectedAllergens,
        };
      });

      fetchAlternatives();
    } else {
      setState(() {
        product = null;
        alternatives = [];
      });
    }
  }

  Future<void> fetchAlternatives() async {
    final url =
        'https://world.openfoodfacts.net/cgi/search.pl?search_terms=snacks&fields=product_name,image_url,ingredients_text,allergens_tags&json=true';
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final altList =
          data['products'].where((prod) {
            final allergenTags = prod['allergens_tags'] ?? [];
            return !allergenTags.any(
              (a) => userAllergens.contains(a.replaceAll('en:', '')),
            );
          }).toList();

      setState(() {
        alternatives = altList;
      });
    }
  }

  void openScanner() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const BarcodeScannerScreen()),
    );

    if (result != null) {
      setState(() => barcode = result);
      fetchProduct(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Food Scanner')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (barcode != null) Text('Scanned Barcode: $barcode'),
            const SizedBox(height: 20),
            if (product != null)
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (product!['image'] != null)
                        Image.network(product!['image'], height: 100),
                      const SizedBox(height: 8),
                      Text(
                        'Name: ${product!['name']}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('Ingredients: ${product!['ingredients']}'),
                      const SizedBox(height: 8),
                      if (product!['allergens'].isNotEmpty)
                        Text(
                          'Allergens Detected: ${product!['allergens'].join(", ")}',
                        ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            if (alternatives.isNotEmpty) ...[
              const Text(
                'Food Alternatives:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              ...alternatives
                  .take(3)
                  .map(
                    (alt) => ListTile(
                      leading:
                          alt['image_url'] != null
                              ? Image.network(alt['image_url'], width: 50)
                              : null,
                      title: Text(alt['product_name'] ?? 'Unnamed'),
                      subtitle: Text(
                        alt['ingredients_text'] ?? 'No ingredients',
                      ),
                    ),
                  ),
            ],
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: openScanner,
        label: const Text('Scan'),
        icon: const Icon(Icons.qr_code_scanner),
      ),
    );
  }
}

class BarcodeScannerScreen extends StatelessWidget {
  const BarcodeScannerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          MobileScanner(
            controller: MobileScannerController(
              detectionSpeed: DetectionSpeed.normal,
            ),
            onDetect: (capture) {
              final barcode = capture.barcodes.first.rawValue;
              if (barcode != null) {
                Navigator.pop(context, barcode);
              }
            },
          ),
          Align(
            alignment: Alignment.topLeft,
            child: SafeArea(
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
