import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'package:url_launcher/url_launcher.dart';

import 'food_search_page.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FatSecret API Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: OAuthPage(),
    );
  }
}

class OAuthPage extends StatefulWidget {
  @override
  _OAuthPageState createState() => _OAuthPageState();
}

class _OAuthPageState extends State<OAuthPage> {
  String accessToken = "";
  String accessTokenSecret = "";
  bool isLoading = false;
  String statusMessage = "";
  String detailedLog = "";

  // Replace with your FatSecret app credentials
  final String consumerKey = "cbd59e95b623491ca5d046d17a620735";
  final String consumerSecret = "aa5c5cbe567b4a3eb4652fc873a104df";
  final String callbackUrl = "myapp://oauth-callback";

  void updateStatus(String message) {
    setState(() {
      statusMessage = message;
      detailedLog += "$message\n";
    });
    print(message);
  }

  Future<void> startOAuthFlow() async {
    setState(() {
      isLoading = true;
      accessToken = "";
      accessTokenSecret = "";
      statusMessage = "Starting OAuth flow...";
      detailedLog = "";
    });

    try {
      // Step 1: Get request token
      updateStatus("Requesting temporary credentials...");

      final String apiUrl = 'https://platform.fatsecret.com/rest/server.api';
      final String timestamp =
          (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
      final String nonce = _generateNonce();

      // Parameters for request token
      Map<String, String> requestTokenParams = {
        'oauth_consumer_key': consumerKey,
        'oauth_signature_method': 'HMAC-SHA1',
        'oauth_timestamp': timestamp,
        'oauth_nonce': nonce,
        'oauth_version': '1.0',
        'oauth_callback': callbackUrl,
        'method': 'auth.gettoken',
        'format': 'json',
      };

      // Generate signature for request token
      String requestTokenSignature = _generateSignature(
        'POST',
        apiUrl,
        requestTokenParams,
        consumerSecret,
        "", // No token secret yet
      );
      requestTokenParams['oauth_signature'] = requestTokenSignature;

      // Log the parameters for debugging
      updateStatus(
        "Request Token Parameters: ${requestTokenParams.toString()}",
      );

      // Prepare body for POST request
      String requestBody = _buildRequestBody(requestTokenParams);
      updateStatus("Request Body: $requestBody");

      // Make the request
      var response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: requestBody,
      );

      updateStatus("Response Status: ${response.statusCode}");
      updateStatus("Response Headers: ${response.headers}");
      updateStatus("Response Body: ${response.body}");

      if (response.statusCode != 200) {
        throw Exception("Request failed with status: ${response.statusCode}");
      }

      // Parse response
      Map<String, dynamic> responseData;
      try {
        responseData = json.decode(response.body);
        if (responseData.containsKey('error')) {
          throw Exception(
            "API Error: ${responseData['error']['code']} - ${responseData['error']['message']}",
          );
        }
      } catch (e) {
        updateStatus("Failed to parse response: $e");
        if (response.body.contains('<?xml')) {
          updateStatus("Response is in XML format, not JSON.");
          // Try to extract token from XML (simplified)
          String body = response.body;
          if (body.contains('<auth_token>') && body.contains('<auth_secret>')) {
            String token = _extractValueFromXml(body, 'auth_token');
            String secret = _extractValueFromXml(body, 'auth_secret');
            responseData = {
              'auth_token': {'auth_token': token, 'auth_secret': secret},
            };
          } else {
            throw Exception("Could not parse XML response");
          }
        } else {
          throw Exception("Invalid response format");
        }
      }

      // Extract request token and secret
      String requestToken = responseData['auth_token']['auth_token'];
      String requestTokenSecret = responseData['auth_token']['auth_secret'];
      updateStatus("Got request token: $requestToken");

      // Step 2: Redirect for user authorization
      String authUrl =
          'https://www.fatsecret.com/oauth/authorize?oauth_token=$requestToken&oauth_callback=${Uri.encodeComponent(callbackUrl)}';
      updateStatus("Redirecting to authorization URL: $authUrl");

      // Launch the URL
      if (!await launchUrl(Uri.parse(authUrl))) {
        throw Exception("Could not launch authorization URL");
      }

      // Normally you would handle the callback through deep linking
      // For this example, we'll simulate it
      updateStatus("Waiting for authorization (simulated)...");
      await Future.delayed(Duration(seconds: 10));
      String verifier =
          "dummy_verifier"; // This would come from the callback URL
      updateStatus("Got verifier: $verifier");

      // Step 3: Get access token
      updateStatus("Requesting access token...");

      // Parameters for access token
      final String accessTimestamp =
          (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
      final String accessNonce = _generateNonce();

      Map<String, String> accessTokenParams = {
        'oauth_consumer_key': consumerKey,
        'oauth_signature_method': 'HMAC-SHA1',
        'oauth_timestamp': accessTimestamp,
        'oauth_nonce': accessNonce,
        'oauth_version': '1.0',
        'oauth_token': requestToken,
        'oauth_verifier': verifier,
        'method': 'auth.getaccesstoken',
        'format': 'json',
      };

      // Generate signature for access token
      String accessTokenSignature = _generateSignature(
        'POST',
        apiUrl,
        accessTokenParams,
        consumerSecret,
        requestTokenSecret,
      );
      accessTokenParams['oauth_signature'] = accessTokenSignature;

      // Log the parameters for debugging
      updateStatus("Access Token Parameters: ${accessTokenParams.toString()}");

      // Prepare body for POST request
      String accessBody = _buildRequestBody(accessTokenParams);
      updateStatus("Access Body: $accessBody");

      // Make the request
      var accessResponse = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: accessBody,
      );

      updateStatus("Access Response Status: ${accessResponse.statusCode}");
      updateStatus("Access Response Headers: ${accessResponse.headers}");
      updateStatus("Access Response Body: ${accessResponse.body}");

      if (accessResponse.statusCode != 200) {
        throw Exception(
          "Access token request failed with status: ${accessResponse.statusCode}",
        );
      }

      // Parse access token response
      Map<String, dynamic> accessData;
      try {
        accessData = json.decode(accessResponse.body);
        if (accessData.containsKey('error')) {
          throw Exception(
            "API Error: ${accessData['error']['code']} - ${accessData['error']['message']}",
          );
        }
      } catch (e) {
        updateStatus("Failed to parse access token response: $e");
        if (accessResponse.body.contains('<?xml')) {
          updateStatus("Access response is in XML format, not JSON.");
          // Try to extract token from XML (simplified)
          String body = accessResponse.body;
          if (body.contains('<auth_token>') && body.contains('<auth_secret>')) {
            String token = _extractValueFromXml(body, 'auth_token');
            String secret = _extractValueFromXml(body, 'auth_secret');
            accessData = {
              'access_token': {'auth_token': token, 'auth_secret': secret},
            };
          } else {
            throw Exception("Could not parse XML access response");
          }
        } else {
          throw Exception("Invalid access response format");
        }
      }

      // Extract access token and secret
      setState(() {
        accessToken = accessData['access_token']['auth_token'];
        accessTokenSecret = accessData['access_token']['auth_secret'];
        statusMessage = "Authentication successful!";
        isLoading = false;
      });

      // Navigate to the food search page
      if (accessToken.isNotEmpty && accessTokenSecret.isNotEmpty) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) => FoodSearchPage(
                  consumerKey: consumerKey,
                  consumerSecret: consumerSecret,
                  accessToken: accessToken,
                  accessTokenSecret: accessTokenSecret,
                ),
          ),
        );
      }
    } catch (e) {
      updateStatus("Error during OAuth flow: $e");
      setState(() {
        isLoading = false;
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

    updateStatus("Signature Base String: $baseString");

    // Create signing key
    String signingKey =
        '${Uri.encodeComponent(consumerSecret)}&${Uri.encodeComponent(tokenSecret)}';
    updateStatus("Signing Key: $signingKey");

    // Generate signature
    List<int> key = utf8.encode(signingKey);
    List<int> bytes = utf8.encode(baseString);
    Hmac hmac = Hmac(sha1, key);
    Digest digest = hmac.convert(bytes);
    String signature = base64.encode(digest.bytes);

    updateStatus("Generated Signature: $signature");
    return signature;
  }

  String _buildRequestBody(Map<String, String> parameters) {
    return parameters.entries
        .map(
          (e) =>
              '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}',
        )
        .join('&');
  }

  String _extractValueFromXml(String xml, String tag) {
    RegExp regex = RegExp("<$tag>(.*?)</$tag>");
    Match? match = regex.firstMatch(xml);
    if (match != null && match.groupCount >= 1) {
      return match.group(1) ?? "";
    }
    return "";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('FatSecret OAuth')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isLoading)
              Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(statusMessage),
                    SizedBox(height: 16),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Text(
                          detailedLog,
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (accessToken.isNotEmpty) ...[
                    Text(
                      'Authentication Successful!',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    SizedBox(height: 16),
                    Text('Access Token: $accessToken'),
                    SizedBox(height: 8),
                    Text('Access Token Secret: $accessTokenSecret'),
                    SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => FoodSearchPage(
                                  consumerKey: consumerKey,
                                  consumerSecret: consumerSecret,
                                  accessToken: accessToken,
                                  accessTokenSecret: accessTokenSecret,
                                ),
                          ),
                        );
                      },
                      child: Text('Search Foods'),
                    ),
                    SizedBox(height: 16),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Text(
                          detailedLog,
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  ] else ...[
                    Text(statusMessage),
                    SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: startOAuthFlow,
                      child: Text('Authenticate with FatSecret'),
                    ),
                    SizedBox(height: 16),
                    if (detailedLog.isNotEmpty)
                      Expanded(
                        child: SingleChildScrollView(
                          child: Text(
                            detailedLog,
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }
}
