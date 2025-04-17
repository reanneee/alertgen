// main.dart
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import 'package:intl/intl.dart';
import 'package:oauth1/oauth1.dart' as oauth1;
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
        primarySwatch: Colors.blue,
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
  List<dynamic>? _searchResults;
  Map<String, dynamic>? _foodDetails;
  String? _errorMessage;
  String? _debugInfo; // Added for debugging purposes

  // FatSecret API credentials
  final String consumerKey = 'cbd59e95b623491ca5d046d17a620735';
  final String consumerSecret = '00c417cd3b104216a796cfa36f3a2787';

  // OAuth client setup
  late oauth1.Platform _platform;
  late oauth1.Client _client;

  @override
  void initState() {
    super.initState();
    _initOAuth();
  }

  void _initOAuth() {
    // Configure the OAuth platform
    _platform = oauth1.Platform(
      'https://platform.fatsecret.com/rest/server.api', // Request token URL
      'https://platform.fatsecret.com/rest/server.api', // Authorize URL
      'https://platform.fatsecret.com/rest/server.api', // Access token URL
      oauth1.SignatureMethods.hmacSha1,
    );

    // Create client credentials with consumer key and secret
    final clientCredentials = oauth1.ClientCredentials(
      consumerKey,
      consumerSecret,
    );

    // Create the OAuth client (using two-legged OAuth without token)
    _client = oauth1.Client(
      _platform.signatureMethod,
      clientCredentials,
      oauth1.Credentials('', ''), // Empty credentials for two-legged OAuth
    );
  }

  Future<Map<String, dynamic>> _searchFood(String query) async {
    final baseUrl = 'https://platform.fatsecret.com/rest/server.api';

    // Create parameters for the food search
    final Map<String, String> params = {
      'method': 'foods.search',
      'search_expression': query,
      'format': 'json',
      'max_results': '50',
      'page_number': '0',
    };

    try {
      // Use a simple URL with parameters approach instead of the oauth1 package's methods
      final signedUrl = await _getSignedUrl('GET', baseUrl, params);

      // Debug the signed URL
      print(
        'Signed URL: ${signedUrl.substring(0, min(200, signedUrl.length))}...',
      );

      // Make the API request with the signed URL
      final response = await http.get(Uri.parse(signedUrl));

      // Debug output
      print('Response status: ${response.statusCode}');
      print(
        'Response body: ${response.body.substring(0, min(500, response.body.length))}...',
      );

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);

        // Check if the response contains an error
        if (decoded.containsKey('error')) {
          throw Exception('API Error: ${decoded['error']['message']}');
        }

        return decoded;
      } else {
        throw Exception('Failed to search food: ${response.body}');
      }
    } catch (e) {
      print('Exception during search: $e');
      rethrow;
    }
  }

  String _encode(String value) {
    return Uri.encodeComponent(
      value,
    ).replaceAll('+', '%20').replaceAll('*', '%2A').replaceAll('%7E', '~');
  }

  // Add a helper method to generate signed URLs
  Future<String> _getSignedUrl(
    String method,
    String baseUrl,
    Map<String, String> params,
  ) async {
    // Add OAuth parameters required by FatSecret
    final oauthParams = {
      'oauth_consumer_key': consumerKey,
      'oauth_nonce': _generateNonce(),
      'oauth_signature_method': 'HMAC-SHA1',
      'oauth_timestamp':
          (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString(),
      'oauth_version': '1.0',
    };

    // Combine all params
    final allParams = {...params, ...oauthParams};

    // Sort parameters alphabetically as required by OAuth
    final List<MapEntry<String, String>> sortedParams =
        allParams.entries.toList()..sort((a, b) => a.key.compareTo(b.key));

    // Create parameter string (key=value&key=value...)
    final paramString = sortedParams
        .map((e) => '${_encode(e.key)}=${_encode(e.value)}')
        .join('&');

    // Create the base string for signing
    final baseString = [
      method.toUpperCase(),
      _encode(baseUrl),
      _encode(paramString),
    ].join('&');

    // Generate the signature
    final signingKey = '$consumerSecret&'; // No token secret for 2-legged OAuth
    final hmacSha1 = Hmac(sha1, utf8.encode(signingKey));
    final digest = hmacSha1.convert(utf8.encode(baseString));
    final signature = base64.encode(digest.bytes);

    // Add signature to parameters
    allParams['oauth_signature'] = signature;

    // Build the final URL with parameters
    final queryString = allParams.entries
        .map(
          (e) =>
              '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}',
        )
        .join('&');

    return '$baseUrl?$queryString';
  }

  // Generate a random nonce
  String _generateNonce() {
    final random = Random();
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return List.generate(16, (_) => chars[random.nextInt(chars.length)]).join();
  }

  // URL encode function compatible with OAuth requirements
  String _encodeURIComponent(String component) {
    return Uri.encodeComponent(
      component,
    ).replaceAll('+', '%20').replaceAll('%7E', '~').replaceAll('*', '%2A');
  }

  // Generate HMAC-SHA1 signature
  String _generateSignature(String baseString, String key) {
    final hmacSha1 = Hmac(sha1, utf8.encode(key));
    final digest = hmacSha1.convert(utf8.encode(baseString));
    return base64.encode(digest.bytes);
  }

  Future<Map<String, dynamic>> _getFoodDetails(String foodId) async {
    final baseUrl = 'https://platform.fatsecret.com/rest/server.api';

    // Create parameters for getting food details
    final Map<String, String> params = {
      'method': 'food.get.v2',
      'food_id': foodId,
      'format': 'json',
    };

    try {
      // Use the helper method to get a signed URL
      final signedUrl = await _getSignedUrl('GET', baseUrl, params);

      // Make the API request with the signed URL
      final response = await http.get(Uri.parse(signedUrl));

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);

        // Check if the response contains an error
        if (decoded.containsKey('error')) {
          throw Exception('API Error: ${decoded['error']['message']}');
        }

        return decoded;
      } else {
        throw Exception('Failed to get food details: ${response.body}');
      }
    } catch (e) {
      print('Exception during getting details: $e');
      rethrow;
    }
  }

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
      _debugInfo = null;
      _searchResults = null;
      _foodDetails = null;
    });

    try {
      // Search for foods matching the query
      final searchData = await _searchFood(query);

      // Enhanced error checking with more details
      if (searchData['foods'] == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'API response does not contain foods data';
          _debugInfo =
              'Raw response: ${json.encode(searchData).substring(0, 300)}...';
        });
        return;
      }

      // Check for empty results in different formats
      if (searchData['foods']['total_results'] == '0' ||
          searchData['foods']['food'] == null) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              'No ingredients found for "$query". Try a more general term.';
          _debugInfo =
              'Total results: ${searchData['foods']['total_results'] ?? "unknown"}';
        });
        return;
      }

      // Handle both single result (object) and multiple results (array)
      final foods = searchData['foods']['food'];
      final foodsList = foods is List ? foods : [foods];

      setState(() {
        _searchResults = foodsList;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error: ${e.toString()}';
      });
    }
  }

  Future<void> _getDetails(String foodId) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _foodDetails = null;
    });

    try {
      final detailsData = await _getFoodDetails(foodId);

      setState(() {
        _foodDetails = detailsData['food'];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error getting details: ${e.toString()}';
      });
    }
  }

  List<String>? _getAllergens() {
    if (_foodDetails == null) return null;

    // Extract potential allergens from the food details
    List<String> allergens = [];
    final String name = _foodDetails!['food_name'].toString().toLowerCase();
    final String description =
        _foodDetails!['food_description']?.toString().toLowerCase() ?? '';

    // Common allergens detection - based on the name and description
    if (_containsAllergen(name, description, [
      'milk',
      'dairy',
      'lactose',
      'cheese',
      'cream',
      'butter',
      'whey',
    ])) {
      allergens.add('Milk/Dairy');
    }
    if (_containsAllergen(name, description, ['peanut'])) {
      allergens.add('Peanuts');
    }
    if (_containsAllergen(name, description, [
      'tree nut',
      'almond',
      'cashew',
      'walnut',
      'hazelnut',
      'pecan',
      'pistachio',
    ])) {
      allergens.add('Tree Nuts');
    }
    if (_containsAllergen(name, description, ['egg', 'eggs'])) {
      allergens.add('Eggs');
    }
    if (_containsAllergen(name, description, [
      'wheat',
      'gluten',
      'bread',
      'flour',
      'pasta',
      'cereal',
    ])) {
      allergens.add('Wheat/Gluten');
    }
    if (_containsAllergen(name, description, [
      'soy',
      'soya',
      'tofu',
      'edamame',
    ])) {
      allergens.add('Soy');
    }
    if (_containsAllergen(name, description, [
      'fish',
      'salmon',
      'tuna',
      'cod',
      'tilapia',
      'bass',
    ])) {
      allergens.add('Fish');
    }
    if (_containsAllergen(name, description, [
      'shellfish',
      'shrimp',
      'crab',
      'lobster',
      'clam',
      'mussel',
      'oyster',
    ])) {
      allergens.add('Shellfish');
    }
    if (_containsAllergen(name, description, ['sesame'])) {
      allergens.add('Sesame');
    }

    return allergens.isEmpty ? ['No common allergens detected'] : allergens;
  }

  bool _containsAllergen(
    String name,
    String description,
    List<String> allergenTerms,
  ) {
    for (final term in allergenTerms) {
      if (name.contains(term) || description.contains(term)) {
        return true;
      }
    }
    return false;
  }

  // Calculate min value (helper function)
  int min(int a, int b) {
    return a < b ? a : b;
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
                hintText: 'Enter a food or ingredient name',
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _errorMessage!,
                      style: TextStyle(color: Colors.red.shade800),
                    ),
                    if (_errorMessage!.contains('No ingredients found'))
                      TextButton(
                        onPressed: () {
                          // Suggest common search terms
                          _searchController.text = 'apple';
                          _searchIngredient('apple');
                        },
                        child: const Text('Try searching for "apple"'),
                      ),
                  ],
                ),
              ),

            // Debug info - only show in debug mode
            if (_debugInfo != null)
              Container(
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.only(top: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Debug Info:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(_debugInfo!, style: const TextStyle(fontSize: 10)),
                  ],
                ),
              ),

            // Search results
            if (_searchResults != null && _foodDetails == null && !_isLoading)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(
                        'Found ${_searchResults!.length} results:',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _searchResults!.length,
                        itemBuilder: (context, index) {
                          final food = _searchResults![index];
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            child: ListTile(
                              title: Text(food['food_name']),
                              subtitle: Text(
                                food['food_description'] ??
                                    'No description available',
                              ),
                              onTap: () => _getDetails(food['food_id']),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),

            // Food details
            if (_foodDetails != null && !_isLoading)
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
                          // Food name
                          Text(
                            _foodDetails!['food_name'] ?? 'Unknown Food',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Divider(),

                          // Food description
                          if (_foodDetails!['food_description'] != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Text(
                                _foodDetails!['food_description'],
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),

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

                          // Nutrition information
                          if (_foodDetails!['servings'] != null &&
                              _foodDetails!['servings']['serving'] != null)
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

                                // Display nutrition information
                                _buildNutritionTable(
                                  _foodDetails!['servings']['serving'],
                                ),
                              ],
                            ),

                          const SizedBox(height: 20),

                          // Back to search results button
                          ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _foodDetails = null;
                              });
                            },
                            child: const Text('Back to Search Results'),
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

  Widget _buildNutritionTable(dynamic serving) {
    // Handle both single serving (object) and multiple servings (array)
    final servingData = serving is List ? serving[0] : serving;

    return Table(
      border: TableBorder.all(color: Colors.grey.shade300),
      children: [
        TableRow(
          decoration: BoxDecoration(color: Colors.grey.shade200),
          children: const [
            Padding(
              padding: EdgeInsets.all(8.0),
              child: Text(
                'Nutrient',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(8.0),
              child: Text(
                'Amount',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        if (servingData['calories'] != null)
          _buildNutritionRow('Calories', '${servingData['calories']} kcal'),
        if (servingData['carbohydrate'] != null)
          _buildNutritionRow(
            'Carbohydrates',
            '${servingData['carbohydrate']} g',
          ),
        if (servingData['protein'] != null)
          _buildNutritionRow('Protein', '${servingData['protein']} g'),
        if (servingData['fat'] != null)
          _buildNutritionRow('Fat', '${servingData['fat']} g'),
        if (servingData['sugar'] != null)
          _buildNutritionRow('Sugar', '${servingData['sugar']} g'),
        if (servingData['fiber'] != null)
          _buildNutritionRow('Fiber', '${servingData['fiber']} g'),
        if (servingData['sodium'] != null)
          _buildNutritionRow('Sodium', '${servingData['sodium']} mg'),
        if (servingData['cholesterol'] != null)
          _buildNutritionRow('Cholesterol', '${servingData['cholesterol']} mg'),
      ],
    );
  }

  TableRow _buildNutritionRow(String nutrient, String value) {
    return TableRow(
      children: [
        Padding(padding: const EdgeInsets.all(8.0), child: Text(nutrient)),
        Padding(padding: const EdgeInsets.all(8.0), child: Text(value)),
      ],
    );
  }
}
