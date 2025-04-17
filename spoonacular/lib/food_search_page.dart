// Food Search Page
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'package:url_launcher/url_launcher.dart';
class FoodSearchPage extends StatefulWidget {
  final String consumerKey;
  final String consumerSecret;
  final String accessToken;
  final String accessTokenSecret;

  FoodSearchPage({
    required this.consumerKey,
    required this.consumerSecret,
    required this.accessToken,
    required this.accessTokenSecret,
  });

  @override
  _FoodSearchPageState createState() => _FoodSearchPageState();
}

class _FoodSearchPageState extends State<FoodSearchPage> {
  TextEditingController _searchController = TextEditingController();
  List<FoodItem> _searchResults = [];
  bool _isSearching = false;
  String _errorMessage = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchFood(String query) async {
    if (query.trim().isEmpty) return;

    setState(() {
      _isSearching = true;
      _errorMessage = '';
      _searchResults = [];
    });

    try {
      final String apiUrl = 'https://platform.fatsecret.com/rest/server.api';
      final String timestamp =
          (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
      final String nonce = _generateNonce();

      // Parameters for food search
      Map<String, String> searchParams = {
        'oauth_consumer_key': widget.consumerKey,
        'oauth_signature_method': 'HMAC-SHA1',
        'oauth_timestamp': timestamp,
        'oauth_nonce': nonce,
        'oauth_token': widget.accessToken,
        'oauth_version': '1.0',
        'method': 'foods.search',
        'search_expression': query,
        'format': 'json',
        'max_results': '50',
      };

      // Generate signature
      String signature = _generateSignature(
        'GET',
        apiUrl,
        searchParams,
        widget.consumerSecret,
        widget.accessTokenSecret,
      );
      searchParams['oauth_signature'] = signature;

      // Build query string
      String queryString = _buildQueryString(searchParams);
      String fullUrl = '$apiUrl?$queryString';

      // Make the request
      var response = await http.get(Uri.parse(fullUrl));

      if (response.statusCode != 200) {
        throw Exception("Search failed with status: ${response.statusCode}");
      }

      // Parse the response
      Map<String, dynamic> responseData = json.decode(response.body);
      if (responseData.containsKey('error')) {
        throw Exception(
          "API Error: ${responseData['error']['code']} - ${responseData['error']['message']}",
        );
      }

      List<FoodItem> foods = [];
      if (responseData.containsKey('foods') &&
          responseData['foods'].containsKey('food')) {
        var foodData = responseData['foods']['food'];

        // Handle single food result (not in array)
        if (foodData is Map) {
          foods.add(FoodItem.fromJson(Map<String, dynamic>.from(foodData)));
        }
        // Handle multiple food results (in array)
        else if (foodData is List) {
          for (var food in foodData) {
            if (food is Map) {
              foods.add(FoodItem.fromJson(Map<String, dynamic>.from(food)));
            }
          }
        }
      }

      setState(() {
        _searchResults = foods;
        _isSearching = false;
        if (_searchResults.isEmpty) {
          _errorMessage = 'No foods found for "$query"';
        }
      });
    } catch (e) {
      setState(() {
        _isSearching = false;
        _errorMessage = 'Error searching for foods: $e';
      });
    }
  }

  String _generateNonce() {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    Random random = Random.secure();
    return List.generate(
      16,
      (index) => chars[random.nextInt(chars.length)],
    ).join();
  }

  String _generateSignature(
    String method,
    String url,
    Map<String, String> parameters,
    String consumerSecret,
    String tokenSecret,
  ) {
    // Make a copy of parameters without oauth_signature
    Map<String, String> params = Map.from(parameters);
    params.remove('oauth_signature');

    // Sort parameters alphabetically by key
    List<String> parameterStrings = [];
    params.forEach((key, value) {
      parameterStrings.add(
        '${Uri.encodeComponent(key)}=${Uri.encodeComponent(value)}',
      );
    });
    parameterStrings.sort();

    // Create base string
    String parameterString = parameterStrings.join('&');
    String baseString =
        '$method&${Uri.encodeComponent(url)}&${Uri.encodeComponent(parameterString)}';

    // Create signing key
    String signingKey =
        '${Uri.encodeComponent(consumerSecret)}&${Uri.encodeComponent(tokenSecret)}';

    // Generate signature
    List<int> key = utf8.encode(signingKey);
    List<int> bytes = utf8.encode(baseString);
    Hmac hmac = Hmac(sha1, key);
    Digest digest = hmac.convert(bytes);
    String signature = base64.encode(digest.bytes);

    return signature;
  }

  String _buildQueryString(Map<String, String> parameters) {
    return parameters.entries
        .map(
          (e) =>
              '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}',
        )
        .join('&');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Food Search')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search for foods',
                hintText: 'E.g., apple, chicken breast, pasta',
                suffixIcon: IconButton(
                  icon: Icon(Icons.search),
                  onPressed: () => _searchFood(_searchController.text),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
              onSubmitted: _searchFood,
            ),
            SizedBox(height: 16),
            if (_isSearching)
              Center(child: CircularProgressIndicator())
            else if (_errorMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(_errorMessage, style: TextStyle(color: Colors.red)),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    FoodItem food = _searchResults[index];
                    return Card(
                      margin: EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        title: Text(food.name),
                        subtitle: Text(
                          'Brand: ${food.brandName.isNotEmpty ? food.brandName : 'Generic'}\n'
                          'Calories: ${food.calories}',
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) => FoodDetailPage(
                                    foodId: food.id,
                                    consumerKey: widget.consumerKey,
                                    consumerSecret: widget.consumerSecret,
                                    accessToken: widget.accessToken,
                                    accessTokenSecret: widget.accessTokenSecret,
                                  ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// Food Detail Page
class FoodDetailPage extends StatefulWidget {
  final String foodId;
  final String consumerKey;
  final String consumerSecret;
  final String accessToken;
  final String accessTokenSecret;

  FoodDetailPage({
    required this.foodId,
    required this.consumerKey,
    required this.consumerSecret,
    required this.accessToken,
    required this.accessTokenSecret,
  });

  @override
  _FoodDetailPageState createState() => _FoodDetailPageState();
}

class _FoodDetailPageState extends State<FoodDetailPage> {
  bool _isLoading = true;
  String _errorMessage = '';
  FoodDetail? _foodDetail;

  @override
  void initState() {
    super.initState();
    _fetchFoodDetails();
  }

  Future<void> _fetchFoodDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final String apiUrl = 'https://platform.fatsecret.com/rest/server.api';
      final String timestamp =
          (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
      final String nonce = _generateNonce();

      // Parameters for food details
      Map<String, String> detailParams = {
        'oauth_consumer_key': widget.consumerKey,
        'oauth_signature_method': 'HMAC-SHA1',
        'oauth_timestamp': timestamp,
        'oauth_nonce': nonce,
        'oauth_token': widget.accessToken,
        'oauth_version': '1.0',
        'method': 'food.get.v2',
        'food_id': widget.foodId,
        'format': 'json',
      };

      // Generate signature
      String signature = _generateSignature(
        'GET',
        apiUrl,
        detailParams,
        widget.consumerSecret,
        widget.accessTokenSecret,
      );
      detailParams['oauth_signature'] = signature;

      // Build query string
      String queryString = _buildQueryString(detailParams);
      String fullUrl = '$apiUrl?$queryString';

      // Make the request
      var response = await http.get(Uri.parse(fullUrl));

      if (response.statusCode != 200) {
        throw Exception("Request failed with status: ${response.statusCode}");
      }

      // Parse the response
      Map<String, dynamic> responseData = json.decode(response.body);
      if (responseData.containsKey('error')) {
        throw Exception(
          "API Error: ${responseData['error']['code']} - ${responseData['error']['message']}",
        );
      }

      if (responseData.containsKey('food')) {
        setState(() {
          _foodDetail = FoodDetail.fromJson(responseData['food']);
          _isLoading = false;
        });
      } else {
        throw Exception("Food details not found in response");
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error fetching food details: $e';
      });
    }
  }

  String _generateNonce() {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    Random random = Random.secure();
    return List.generate(
      16,
      (index) => chars[random.nextInt(chars.length)],
    ).join();
  }

  String _generateSignature(
    String method,
    String url,
    Map<String, String> parameters,
    String consumerSecret,
    String tokenSecret,
  ) {
    // Make a copy of parameters without oauth_signature
    Map<String, String> params = Map.from(parameters);
    params.remove('oauth_signature');

    // Sort parameters alphabetically by key
    List<String> parameterStrings = [];
    params.forEach((key, value) {
      parameterStrings.add(
        '${Uri.encodeComponent(key)}=${Uri.encodeComponent(value)}',
      );
    });
    parameterStrings.sort();

    // Create base string
    String parameterString = parameterStrings.join('&');
    String baseString =
        '$method&${Uri.encodeComponent(url)}&${Uri.encodeComponent(parameterString)}';

    // Create signing key
    String signingKey =
        '${Uri.encodeComponent(consumerSecret)}&${Uri.encodeComponent(tokenSecret)}';

    // Generate signature
    List<int> key = utf8.encode(signingKey);
    List<int> bytes = utf8.encode(baseString);
    Hmac hmac = Hmac(sha1, key);
    Digest digest = hmac.convert(bytes);
    String signature = base64.encode(digest.bytes);

    return signature;
  }

  String _buildQueryString(Map<String, String> parameters) {
    return parameters.entries
        .map(
          (e) =>
              '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}',
        )
        .join('&');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_foodDetail?.name ?? 'Food Details')),
      body:
          _isLoading
              ? Center(child: CircularProgressIndicator())
              : _errorMessage.isNotEmpty
              ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    _errorMessage,
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              )
              : _buildFoodDetailView(),
    );
  }

  Widget _buildFoodDetailView() {
    if (_foodDetail == null) {
      return Center(child: Text('No food details available'));
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Food name and basic info
          Text(
            _foodDetail!.name,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          if (_foodDetail!.brandName.isNotEmpty) ...[
            Text(
              'Brand: ${_foodDetail!.brandName}',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 8),
          ],
          Text(
            'Food ID: ${_foodDetail!.id}',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          SizedBox(height: 24),

          // Nutritional information
          Text(
            'Nutritional Information',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Card(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Per Serving (${_foodDetail!.servingDescription})',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  _buildNutritionRow(
                    'Calories',
                    '${_foodDetail!.calories} kcal',
                  ),
                  _buildNutritionRow('Protein', '${_foodDetail!.protein}g'),
                  _buildNutritionRow('Fat', '${_foodDetail!.fat}g'),
                  _buildNutritionRow('Carbohydrates', '${_foodDetail!.carbs}g'),
                  if (_foodDetail!.fiber.isNotEmpty)
                    _buildNutritionRow('Fiber', '${_foodDetail!.fiber}g'),
                  if (_foodDetail!.sugar.isNotEmpty)
                    _buildNutritionRow('Sugar', '${_foodDetail!.sugar}g'),
                  if (_foodDetail!.sodium.isNotEmpty)
                    _buildNutritionRow('Sodium', '${_foodDetail!.sodium}mg'),
                  if (_foodDetail!.cholesterol.isNotEmpty)
                    _buildNutritionRow(
                      'Cholesterol',
                      '${_foodDetail!.cholesterol}mg',
                    ),
                  if (_foodDetail!.saturatedFat.isNotEmpty)
                    _buildNutritionRow(
                      'Saturated Fat',
                      '${_foodDetail!.saturatedFat}g',
                    ),
                ],
              ),
            ),
          ),
          SizedBox(height: 24),

          // Serving sizes
          if (_foodDetail!.servingSizes.isNotEmpty) ...[
            Text(
              'Available Serving Sizes',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Card(
              child: ListView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: _foodDetail!.servingSizes.length,
                itemBuilder: (context, index) {
                  ServingSize serving = _foodDetail!.servingSizes[index];
                  return ListTile(
                    title: Text(serving.description),
                    subtitle: Text('${serving.amount} (${serving.unit})'),
                  );
                },
              ),
            ),
            SizedBox(height: 24),
          ],

          // Ingredients if available
          if (_foodDetail!.ingredients.isNotEmpty) ...[
            Text(
              'Ingredients',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(_foodDetail!.ingredients),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNutritionRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

// Food Item Model - For search results
class FoodItem {
  final String id;
  final String name;
  final String brandName;
  final String calories;
  final String description;

  FoodItem({
    required this.id,
    required this.name,
    required this.brandName,
    required this.calories,
    required this.description,
  });

  factory FoodItem.fromJson(Map<String, dynamic> json) {
    String caloriesInfo = 'N/A';
    if (json['food_description'] != null) {
      String description = json['food_description'].toString();
      if (description.contains('cal')) {
        caloriesInfo = description.split('|')[0].trim();
      }
    }

    return FoodItem(
      id: json['food_id'] ?? '',
      name: json['food_name'] ?? '',
      brandName: json['brand_name'] ?? '',
      calories: caloriesInfo,
      description: json['food_description'] ?? '',
    );
  }
}

// Food Detail Model - For detailed food information
class FoodDetail {
  final String id;
  final String name;
  final String brandName;
  final String calories;
  final String protein;
  final String fat;
  final String carbs;
  final String fiber;
  final String sugar;
  final String sodium;
  final String cholesterol;
  final String saturatedFat;
  final String servingDescription;
  final String ingredients;
  final List<ServingSize> servingSizes;

  FoodDetail({
    required this.id,
    required this.name,
    required this.brandName,
    required this.calories,
    required this.protein,
    required this.fat,
    required this.carbs,
    required this.fiber,
    required this.sugar,
    required this.sodium,
    required this.cholesterol,
    required this.saturatedFat,
    required this.servingDescription,
    required this.ingredients,
    required this.servingSizes,
  });

  factory FoodDetail.fromJson(Map<String, dynamic> json) {
    List<ServingSize> servings = [];

    // Parse serving sizes if available
    if (json.containsKey('servings') &&
        json['servings'].containsKey('serving')) {
      var servingData = json['servings']['serving'];
      // Handle single serving case
      if (servingData is Map<dynamic, dynamic>) {
        // Convert to Map<String, dynamic> before passing to fromJson
        Map<String, dynamic> stringServingData = {};
        servingData.forEach((key, value) {
          if (key is String) {
            stringServingData[key] = value;
          }
        });
        servings.add(ServingSize.fromJson(stringServingData));
      }
      // Handle multiple servings case
      else if (servingData is List) {
        for (var serving in servingData) {
          if (serving is Map<dynamic, dynamic>) {
            // Convert to Map<String, dynamic> before passing to fromJson
            Map<String, dynamic> stringServing = {};
            serving.forEach((key, value) {
              if (key is String) {
                stringServing[key] = value;
              }
            });
            servings.add(ServingSize.fromJson(stringServing));
          }
        }
      }
    }

    // Get primary serving for nutritional info
    Map<String, dynamic> primaryServing = {};
    if (servings.isNotEmpty) {
      // Find the serving with is_default = 1 if possible
      var defaultServing = servings.firstWhere(
        (serving) => serving.isDefault,
        orElse: () => servings.first,
      );

      // Get the JSON for this serving
      if (json['servings']['serving'] is List) {
        for (var serving in json['servings']['serving']) {
          if ((serving['is_default'] == '1' && defaultServing.isDefault) ||
              (servings.first.description == serving['serving_description'])) {
            primaryServing = serving;
            break;
          }
        }
      } else {
        primaryServing = json['servings']['serving'];
      }
    }

    return FoodDetail(
      id: json['food_id'] ?? '',
      name: json['food_name'] ?? '',
      brandName: json['brand_name'] ?? '',
      calories: primaryServing['calories'] ?? 'N/A',
      protein: primaryServing['protein'] ?? 'N/A',
      fat: primaryServing['fat'] ?? 'N/A',
      carbs: primaryServing['carbohydrate'] ?? 'N/A',
      fiber: primaryServing['fiber'] ?? '',
      sugar: primaryServing['sugar'] ?? '',
      sodium: primaryServing['sodium'] ?? '',
      cholesterol: primaryServing['cholesterol'] ?? '',
      saturatedFat: primaryServing['saturated_fat'] ?? '',
      servingDescription:
          primaryServing['serving_description'] ?? 'Standard Serving',
      ingredients:
          json['food_type'] == 'Brand' ? (json['ingredients'] ?? '') : '',
      servingSizes: servings,
    );
  }
}

// Serving Size Model
class ServingSize {
  final String description;
  final String amount;
  final String unit;
  final bool isDefault;

  ServingSize({
    required this.description,
    required this.amount,
    required this.unit,
    required this.isDefault,
  });

  factory ServingSize.fromJson(Map<String, dynamic> json) {
    return ServingSize(
      description: json['serving_description'] ?? '',
      amount: json['metric_serving_amount'] ?? '',
      unit: json['metric_serving_unit'] ?? '',
      isDefault: json['is_default'] == '1',
    );
  }
}
