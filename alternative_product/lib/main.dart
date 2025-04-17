import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Allergen Food Scanner',
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
      useMaterial3: true,
    ),
    home: HomePage(),
  );
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String scannedText = '';
  List<String> userAllergens = ['peanut'];
  List<String> matchedAllergens = [];
  List<String> safeAlternatives = [];
  bool isLoading = false;
  // Cache for storing alternative products
  Map<String, List<String>> _alternativesCache = {};

  @override
  void initState() {
    super.initState();
    _loadAllergens();
  }

  Future<void> _loadAllergens() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        userAllergens = prefs.getStringList('userAllergens') ?? ['peanut'];
      });
    } catch (e) {
      print('Error loading allergens: $e');
    }
  }

  Future<void> scanTextFromImage() async {
    setState(() {
      isLoading = true;
      scannedText = '';
      matchedAllergens.clear();
      safeAlternatives.clear();
    });

    final picker = ImagePicker();
    final pickedImage = await picker.pickImage(source: ImageSource.camera);

    if (pickedImage != null) {
      final inputImage = InputImage.fromFilePath(pickedImage.path);
      final textRecognizer = TextRecognizer();
      final recognizedText = await textRecognizer.processImage(inputImage);
      final text = recognizedText.text.toLowerCase();

      List<String> detectedAllergens =
          userAllergens
              .where((allergen) => text.contains(allergen.toLowerCase()))
              .toList();

      setState(() {
        scannedText = text;
        matchedAllergens = detectedAllergens;
      });

      if (matchedAllergens.isNotEmpty) {
        fetchAlternatives(matchedAllergens.first);
      }

      textRecognizer.close();
    }

    setState(() => isLoading = false);
  }

  void scanBarcode() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (context) => BarcodeScannerPage(
              onBarcodeDetected: (barcode) async {
                Navigator.of(context).pop(); // Close scanner page

                setState(() {
                  isLoading = true;
                  scannedText = '';
                  matchedAllergens.clear();
                  safeAlternatives.clear();
                });

                try {
                  // Fetch product data using the barcode
                  final url =
                      'https://world.openfoodfacts.org/api/v0/product/$barcode.json';
                  final response = await http.get(Uri.parse(url));

                  if (response.statusCode == 200) {
                    final data = json.decode(response.body);
                    if (data['status'] == 1) {
                      final product = data['product'];

                      // Check if ingredients text is available
                      String ingredientsText = '';
                      if (product['ingredients_text'] != null) {
                        ingredientsText =
                            product['ingredients_text']
                                .toString()
                                .toLowerCase();
                      } else if (product['ingredients_text_en'] != null) {
                        ingredientsText =
                            product['ingredients_text_en']
                                .toString()
                                .toLowerCase();
                      }

                      // Check for allergens
                      List<String> detectedAllergens =
                          userAllergens
                              .where(
                                (allergen) => ingredientsText.contains(
                                  allergen.toLowerCase(),
                                ),
                              )
                              .toList();

                      setState(() {
                        scannedText =
                            ingredientsText.isNotEmpty
                                ? ingredientsText
                                : 'No ingredients found for this product';
                        matchedAllergens = detectedAllergens;
                      });

                      if (matchedAllergens.isNotEmpty) {
                        fetchAlternatives(matchedAllergens.first);
                      }
                    } else {
                      setState(() {
                        scannedText = 'Product not found in database';
                      });
                    }
                  } else {
                    setState(() {
                      scannedText = 'Failed to fetch product data';
                    });
                  }
                } catch (e) {
                  setState(() {
                    scannedText = 'Error processing barcode: $e';
                  });
                }

                setState(() => isLoading = false);
              },
            ),
      ),
    );
  }

  Future<void> fetchAlternatives(
    String allergen, {
    String query = 'snack',
  }) async {
    // Check cache first
    final cacheKey = '$allergen-$query';
    if (_alternativesCache.containsKey(cacheKey)) {
      setState(() {
        safeAlternatives = _alternativesCache[cacheKey]!;
      });
      return;
    }

    final allergenFormatted = allergen.toLowerCase().replaceAll(' ', '-');
    final url =
        'https://world.openfoodfacts.org/cgi/search.pl?search_terms=$query&tagtype_0=allergens&tag_contains_0=does_not_contain&tag_0=$allergenFormatted&json=1';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List products = data['products'];
        final suggestions =
            products
                .where((p) => p['product_name'] != null)
                .map<String>((p) => p['product_name'].toString())
                .take(5)
                .toList();

        // Store in cache
        _alternativesCache[cacheKey] = suggestions;

        setState(() {
          safeAlternatives = suggestions;
        });
      }
    } catch (e) {
      print('Error fetching alternatives: $e');
    }
  }

  void _manageAllergens() {
    final TextEditingController _controller = TextEditingController();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Manage Allergens'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    labelText: 'Add new allergen',
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 16),
                Container(
                  height: 200,
                  width: double.maxFinite,
                  child: ListView.builder(
                    itemCount: userAllergens.length,
                    itemBuilder: (context, index) {
                      return ListTile(
                        title: Text(userAllergens[index]),
                        trailing: IconButton(
                          icon: Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            setState(() {
                              userAllergens.removeAt(index);
                            });
                            _saveAllergens();
                            Navigator.of(context).pop();
                            _manageAllergens();
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (_controller.text.isNotEmpty) {
                    setState(() {
                      userAllergens.add(_controller.text.trim());
                    });
                    _saveAllergens();
                  }
                  Navigator.of(context).pop();
                },
                child: Text('Add'),
              ),
            ],
          ),
    );
  }

  Future<void> _saveAllergens() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('userAllergens', userAllergens);
    } catch (e) {
      print('Error saving allergens: $e');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text('Allergen Food Scanner'),
      centerTitle: true,
      backgroundColor: Colors.teal,
      foregroundColor: Colors.white,
      actions: [
        IconButton(icon: Icon(Icons.settings), onPressed: _manageAllergens),
      ],
    ),
    body: Padding(
      padding: const EdgeInsets.all(16.0),
      child:
          isLoading
              ? Center(child: CircularProgressIndicator())
              : ListView(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 14),
                            textStyle: TextStyle(fontSize: 16),
                          ),
                          onPressed: scanTextFromImage,
                          icon: Icon(Icons.camera_alt_outlined),
                          label: Text('Scan Ingredients'),
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.indigo,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 14),
                            textStyle: TextStyle(fontSize: 16),
                          ),
                          onPressed: scanBarcode,
                          icon: Icon(Icons.qr_code_scanner),
                          label: Text('Scan Barcode'),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 24),
                  userAllergens.isNotEmpty
                      ? Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children:
                            userAllergens
                                .map(
                                  (allergen) => Chip(
                                    label: Text(allergen),
                                    backgroundColor: Colors.teal.shade100,
                                  ),
                                )
                                .toList(),
                      )
                      : Text('No allergens added. Tap settings to add.'),
                  SizedBox(height: 24),
                  Text(
                    "Scanned Text",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  SizedBox(height: 8),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.teal.shade100),
                    ),
                    child: Text(
                      scannedText.isNotEmpty
                          ? scannedText
                          : 'No text scanned yet.',
                    ),
                  ),
                  if (matchedAllergens.isNotEmpty) ...[
                    SizedBox(height: 24),
                    Text(
                      "❗ Allergen Detected",
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    ...matchedAllergens.map(
                      (a) => Text('• $a', style: TextStyle(fontSize: 16)),
                    ),
                  ],
                  if (safeAlternatives.isNotEmpty) ...[
                    SizedBox(height: 24),
                    Text(
                      "✅ Safe Alternatives",
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    ...safeAlternatives.map(
                      (p) => Text('• $p', style: TextStyle(fontSize: 16)),
                    ),
                  ],
                ],
              ),
    ),
  );
}

// Separate page for barcode scanning
class BarcodeScannerPage extends StatefulWidget {
  final void Function(String) onBarcodeDetected;

  const BarcodeScannerPage({Key? key, required this.onBarcodeDetected})
    : super(key: key);

  @override
  _BarcodeScannerPageState createState() => _BarcodeScannerPageState();
}

class _BarcodeScannerPageState extends State<BarcodeScannerPage> {
  MobileScannerController controller = MobileScannerController();
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Scan Barcode'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => controller.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_ios),
            onPressed: () => controller.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: controller,
            onDetect: (capture) {
              if (_isProcessing) return;

              final List<Barcode> barcodes = capture.barcodes;
              if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
                final String code = barcodes.first.rawValue!;
                debugPrint('Barcode detected: $code');

                setState(() {
                  _isProcessing = true;
                });

                widget.onBarcodeDetected(code);
              }
            },
          ),
          // Scanner overlay
          CustomPaint(painter: ScannerOverlay(), child: Container()),
          // Bottom info text
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'Position barcode within frame',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Custom painter for scanner overlay
class ScannerOverlay extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint borderPaint =
        Paint()
          ..color = Colors.teal
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.0;

    final Paint backgroundPaint =
        Paint()
          ..color = Colors.black.withOpacity(0.5)
          ..style = PaintingStyle.fill;

    const cornerRadius = 20.0;

    // Calculate the scan area size (70% of the smallest dimension)
    final scanAreaSize =
        size.width < size.height ? size.width * 0.7 : size.height * 0.7;

    final scanRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: scanAreaSize,
      height: scanAreaSize,
    );

    final borderRect = RRect.fromRectAndRadius(
      scanRect,
      const Radius.circular(cornerRadius),
    );

    // Draw the semi-transparent background
    final backgroundRect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRect(backgroundRect, backgroundPaint);

    // Create a path for the hole
    final transparentPath = Path()..addRRect(borderRect);

    // Cut out the hole
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(backgroundRect),
        transparentPath,
      ),
      backgroundPaint,
    );

    // Draw the corner lines
    final cornerLength = scanAreaSize * 0.15;

    // Top-left corner
    canvas.drawLine(
      Offset(scanRect.left, scanRect.top + cornerRadius),
      Offset(scanRect.left, scanRect.top + cornerLength),
      borderPaint,
    );
    canvas.drawLine(
      Offset(scanRect.left + cornerRadius, scanRect.top),
      Offset(scanRect.left + cornerLength, scanRect.top),
      borderPaint,
    );

    // Top-right corner
    canvas.drawLine(
      Offset(scanRect.right, scanRect.top + cornerRadius),
      Offset(scanRect.right, scanRect.top + cornerLength),
      borderPaint,
    );
    canvas.drawLine(
      Offset(scanRect.right - cornerRadius, scanRect.top),
      Offset(scanRect.right - cornerLength, scanRect.top),
      borderPaint,
    );

    // Bottom-left corner
    canvas.drawLine(
      Offset(scanRect.left, scanRect.bottom - cornerRadius),
      Offset(scanRect.left, scanRect.bottom - cornerLength),
      borderPaint,
    );
    canvas.drawLine(
      Offset(scanRect.left + cornerRadius, scanRect.bottom),
      Offset(scanRect.left + cornerLength, scanRect.bottom),
      borderPaint,
    );

    // Bottom-right corner
    canvas.drawLine(
      Offset(scanRect.right, scanRect.bottom - cornerRadius),
      Offset(scanRect.right, scanRect.bottom - cornerLength),
      borderPaint,
    );
    canvas.drawLine(
      Offset(scanRect.right - cornerRadius, scanRect.bottom),
      Offset(scanRect.right - cornerLength, scanRect.bottom),
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
