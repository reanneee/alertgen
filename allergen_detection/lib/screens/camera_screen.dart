import 'package:flutter/material.dart';
import 'dart:io';

class AnalysisScreen extends StatelessWidget {
  final String imagePath;
  final List<Map<String, dynamic>> detectedIngredients;
  final String dishDescription;

  const AnalysisScreen({
    Key? key,
    required this.imagePath,
    required this.detectedIngredients,
    required this.dishDescription,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Allergen Analysis'),
        backgroundColor: Colors.teal,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Display the captured image
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  File(imagePath),
                  height: 200,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Display dish description
            Text(
              'Dish Information',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(dishDescription, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 20),

            // Display ingredients and allergen information
            Text(
              'Allergen Analysis',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // Display allergen warnings if any
            if (detectedIngredients.any((item) => item['allergen'] == true))
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.red.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Allergens detected! Please review the ingredients below.',
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 16),

            // Ingredient list with allergen status
            ...detectedIngredients.map((ingredient) {
              final bool isAllergen = ingredient['allergen'] ?? false;
              final String label = ingredient['label'] ?? 'No allergen info';

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                color: isAllergen ? Colors.red.shade50 : Colors.green.shade50,
                child: ListTile(
                  leading: Icon(
                    isAllergen ? Icons.warning_amber : Icons.check_circle,
                    color: isAllergen ? Colors.red : Colors.green,
                  ),
                  title: Text(
                    ingredient['name'] ?? 'Unknown ingredient',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(label),
                ),
              );
            }).toList(),

            // Empty state if no ingredients detected
            if (detectedIngredients.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Text(
                    'No ingredients detected. Try taking a clearer photo of the food or ingredient list.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
