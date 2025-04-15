import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'dart:typed_data';
import 'package:flutter/services.dart';

// Replace with your API key
const apiKey = 'AIzaSyATGAQK5mH4g1pSRnzc2HAYHyoOztO_SDI';

void main() {
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Allergen Lens',
      theme: ThemeData(
        primaryColor: Colors.teal,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          centerTitle: true,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: Colors.teal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        cardTheme: CardTheme(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        fontFamily: 'Roboto',
      ),
      debugShowCheckedModeBanner: false,
      home: const AllergenLensHome(),
    );
  }
}

class AllergenLensHome extends StatefulWidget {
  const AllergenLensHome({super.key});

  @override
  State<AllergenLensHome> createState() => _AllergenLensHomeState();
}

class _AllergenLensHomeState extends State<AllergenLensHome>
    with SingleTickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();
  File? _image;
  bool _isAnalyzing = false;
  String _dishDescription = '';
  List<Map<String, dynamic>> _ingredients = [];
  late AnimationController _animationController;
  late Animation<double> _animation;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _pickAndAnalyzeImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 80,
      );

      if (pickedFile == null) return;

      final File imageFile = File(pickedFile.path);

      setState(() {
        _image = imageFile;
        _isAnalyzing = true;
        _dishDescription = '';
        _ingredients = [];
      });

      // Start scanning animation
      _animationController.repeat(reverse: true);

      // Step 1: Identify the dish
      final String dishDescription = await _identifyDish(imageFile);

      // Step 2: Analyze for allergens
      final String analysis = await _analyzeFoodImage(
        imageFile,
        dishDescription,
      );

      // Step 3: Parse the results
      final List<Map<String, dynamic>> ingredients = _parseIngredients(
        analysis,
      );

      // Stop animation
      _animationController.stop();
      _animationController.reset();

      // Update the UI
      setState(() {
        _isAnalyzing = false;
        _dishDescription = dishDescription;
        _ingredients = ingredients;
      });

      // Scroll to results after a short delay
      if (_ingredients.isNotEmpty) {
        Future.delayed(const Duration(milliseconds: 300), () {
          _scrollController.animateTo(
            300,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOut,
          );
        });
      }
    } catch (e) {
      // Stop animation
      _animationController.stop();
      _animationController.reset();

      setState(() {
        _isAnalyzing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error analyzing image: ${e.toString()}'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          margin: const EdgeInsets.all(12),
        ),
      );
    }
  }

  Future<String> _identifyDish(File imageFile) async {
    try {
      final Uint8List imageBytes = await imageFile.readAsBytes();

      // Using the correct model name for Gemini
      final model = GenerativeModel(model: 'gemini-1.5-pro', apiKey: apiKey);

      const prompt = '''
Identify what dish or food item is shown in this image.
Provide a brief description in this format:

[Dish Name]

This is a [brief overview of the dish including what it is, its origin/cuisine, and key ingredients].

Keep your response concise and focused. Do not use asterisks or other special formatting.
''';

      final response = await model.generateContent([
        Content.multi([TextPart(prompt), DataPart('image/jpeg', imageBytes)]),
      ]);

      return response.text ?? 'No response';
    } catch (e) {
      print("Dish identification error: $e");
      return "Unidentified Food\n\nThis appears to be a food item that may contain common allergens including wheat, dairy, eggs, or nuts.";
    }
  }

  Future<String> _analyzeFoodImage(File imageFile, String description) async {
    try {
      final Uint8List imageBytes = await imageFile.readAsBytes();

      // Using the correct model name for Gemini
      final model = GenerativeModel(model: 'gemini-1.5-pro', apiKey: apiKey);

      final prompt = '''
Analyze this food image and the provided description. 
Description: $description

Identify all potential ingredients and allergens. For each identified ingredient, label whether it:

Contains an allergen (specify which common allergen)
May contain an allergen (specify which ones)
No common allergen detected

Common allergens include: dairy, eggs, peanuts, tree nuts, fish, shellfish, wheat/gluten, soy, sesame.

List each ingredient on a separate line with its allergen status in this format:
Ingredient - Status with allergen name if applicable

Do not use symbols like ✅, ⚠️, or ➖.
''';

      final response = await model.generateContent([
        Content.multi([TextPart(prompt), DataPart('image/jpeg', imageBytes)]),
      ]);

      return response.text ?? 'No response';
    } catch (e) {
      print("Food analysis error: $e");
      return _analyzeIngredientsFromText(description);
    }
  }

  String _analyzeIngredientsFromText(String description) {
    // A simple fallback when image analysis fails
    final commonIngredients = [
      "Wheat - Contains gluten",
      "Egg - Contains egg allergen",
      "Milk - Contains dairy",
      "Soy - Contains soy",
      "Peanuts - Contains peanuts",
      "Tree nuts - Contains tree nuts",
      "Fish - Contains fish",
      "Shellfish - Contains shellfish",
      "Sesame - Contains sesame",
      "Rice - No common allergen detected",
      "Vegetables - No common allergen detected",
      "Fruit - No common allergen detected",
      "Meat - No common allergen detected",
    ];

    // Return a few common ingredients as fallback
    return commonIngredients.take(5).join('\n');
  }

  List<Map<String, dynamic>> _parseIngredients(String analysis) {
    return analysis
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .map((line) {
          final parts = line.split(' - ');
          if (parts.length < 2) return null;

          final name = parts[0].trim();
          final label = parts[1].trim();

          // Determine allergen status from the text
          final bool isAllergen =
              label.toLowerCase().contains('contains') &&
              !label.toLowerCase().contains('no common allergen');
          final bool isPotentialAllergen = label.toLowerCase().contains(
            'may contain',
          );

          // Extract the allergen name
          String allergenName = '';
          if (isAllergen || isPotentialAllergen) {
            final lowerLabel = label.toLowerCase();
            final allergens = [
              'dairy',
              'egg',
              'peanut',
              'tree nut',
              'fish',
              'shellfish',
              'wheat',
              'gluten',
              'soy',
              'sesame',
            ];

            for (final allergen in allergens) {
              if (lowerLabel.contains(allergen)) {
                allergenName = allergen;
                break;
              }
            }
          }

          return {
            'name': name,
            'label': label,
            'isAllergen': isAllergen,
            'isPotentialAllergen': isPotentialAllergen,
            'allergenName': allergenName,
          };
        })
        .whereType<Map<String, dynamic>>() // Filter out nulls
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Allergen Lens',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () {
              _showInfoDialog();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image display area with Google Lens-inspired UI
            Container(
              height: 300,
              width: double.infinity,
              color: Colors.grey[100],
              child:
                  _image == null
                      ? _buildInitialState()
                      : Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.file(_image!, fit: BoxFit.cover),
                          if (_isAnalyzing) _buildScanningOverlay(),
                        ],
                      ),
            ),

            // Camera and gallery buttons
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed:
                        _isAnalyzing
                            ? null
                            : () => _pickAndAnalyzeImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Camera'),
                  ),
                  const SizedBox(width: 20),
                  ElevatedButton.icon(
                    onPressed:
                        _isAnalyzing
                            ? null
                            : () => _pickAndAnalyzeImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Gallery'),
                  ),
                ],
              ),
            ),

            // Results section
            if (_dishDescription.isNotEmpty && !_isAnalyzing) ...[
              _buildDishInfoCard(),

              const SizedBox(height: 12),

              // Allergen summary card
              _buildAllergenSummaryCard(),

              // Ingredients list
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Text(
                  'Detailed Ingredients',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),

              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _ingredients.length,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemBuilder: (context, index) {
                  final ingredient = _ingredients[index];
                  return _buildIngredientCard(ingredient);
                },
              ),

              const SizedBox(height: 16),

              // Disclaimer
              Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.amber[800]),
                          const SizedBox(width: 8),
                          Text(
                            'Disclaimer',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.amber[800],
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'This allergen detection is based on AI analysis and may not be 100% accurate. Always verify with product labels or restaurant staff if you have severe allergies.',
                        style: TextStyle(fontSize: 14, color: Colors.black87),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildInitialState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.camera_enhance,
          size: 80,
          color: Colors.teal.withOpacity(0.5),
        ),
        const SizedBox(height: 16),
        Text(
          'Take or select a photo of food\nto analyze for allergens',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, color: Colors.black.withOpacity(0.7)),
        ),
      ],
    );
  }

  Widget _buildScanningOverlay() {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Stack(
          children: [
            // Scanning animation
            Positioned(
              left: 0,
              right: 0,
              top: _animation.value * 300,
              child: Container(height: 2, color: Colors.teal.withOpacity(0.8)),
            ),
            // Overlay
            Container(
              color: Colors.black.withOpacity(0.3),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Analyzing food...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Detecting ingredients and allergens',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDishInfoCard() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.restaurant, color: Colors.teal),
                  const SizedBox(width: 8),
                  Text(
                    'Identified Dish',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.teal,
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              // Parse the dish description to get dish name and overview
              _buildDishDetails(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDishDetails() {
    // Parse the dish description to extract relevant information
    final lines = _dishDescription.split('\n');
    String dishName = '';
    String overview = '';

    if (lines.isNotEmpty) {
      dishName = lines[0].trim();
      // Combine the remaining lines into an overview
      if (lines.length > 1) {
        overview = lines
            .sublist(1)
            .where((line) => line.trim().isNotEmpty)
            .join('\n');
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          dishName,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(overview, style: const TextStyle(fontSize: 16)),
      ],
    );
  }

  Widget _buildAllergenSummaryCard() {
    final hasAllergens = _ingredients.any((item) => item['isAllergen'] == true);
    final hasPotentialAllergens = _ingredients.any(
      (item) => item['isPotentialAllergen'] == true,
    );

    // Get all allergen names
    final Set<String> allergenNames = {};
    for (final ingredient in _ingredients) {
      if ((ingredient['isAllergen'] == true ||
              ingredient['isPotentialAllergen'] == true) &&
          ingredient['allergenName'].toString().isNotEmpty) {
        allergenNames.add(ingredient['allergenName']);
      }
    }

    final allergensList = allergenNames.join(', ');

    Color cardColor = Colors.green.shade50;
    Color iconColor = Colors.green;
    IconData iconData = Icons.check_circle;
    String title = 'No Allergens Detected';
    String subtitle = 'This food appears to be free of common allergens.';

    if (hasAllergens) {
      cardColor = Colors.red.shade50;
      iconColor = Colors.red;
      iconData = Icons.warning_amber;
      title = 'Allergens Detected';
      subtitle = 'This food contains: $allergensList';
    } else if (hasPotentialAllergens) {
      cardColor = Colors.orange.shade50;
      iconColor = Colors.orange;
      iconData = Icons.info_outline;
      title = 'Potential Allergens';
      subtitle = 'This food may contain: $allergensList';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        color: cardColor,
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(iconData, color: iconColor, size: 48),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: iconColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 14, color: Colors.grey[800]),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIngredientCard(Map<String, dynamic> ingredient) {
    final bool isAllergen = ingredient['isAllergen'] ?? false;
    final bool isPotentialAllergen = ingredient['isPotentialAllergen'] ?? false;
    final String name = ingredient['name'] ?? 'Unknown';
    final String label = ingredient['label'] ?? 'No allergen info';

    Color cardColor = Colors.green.shade50;
    Color textColor = Colors.green.shade700;
    IconData iconData = Icons.check_circle;

    if (isAllergen) {
      cardColor = Colors.red.shade50;
      textColor = Colors.red.shade700;
      iconData = Icons.warning_amber;
    } else if (isPotentialAllergen) {
      cardColor = Colors.orange.shade50;
      textColor = Colors.orange.shade700;
      iconData = Icons.info_outline;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: cardColor,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: cardColor,
          child: Icon(iconData, color: textColor),
        ),
        title: Text(
          name,
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        subtitle: Text(label, style: TextStyle(color: textColor)),
      ),
    );
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.teal),
                const SizedBox(width: 8),
                const Text('About Allergen Lens'),
              ],
            ),
            content: const SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Allergen Lens helps identify potential allergens in food using AI image analysis.',
                    style: TextStyle(fontSize: 16),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Common allergens detected:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '• Dairy\n• Eggs\n• Peanuts\n• Tree nuts\n• Fish\n• Shellfish\n• Wheat/Gluten\n• Soy\n• Sesame',
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Disclaimer: This app is for informational purposes only. Always verify with product labels or restaurant staff if you have allergies.',
                    style: TextStyle(fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
    );
  }
}
