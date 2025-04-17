import 'package:http/http.dart' as http;
import 'dart:convert';

class ApicbaseService {
  final String clientId = 'YOUR_CLIENT_ID';
  final String clientSecret = 'YOUR_CLIENT_SECRET';

  String? _accessToken;

  Future<void> authenticate() async {
    final response = await http.post(
      Uri.parse('https://id.apicbase.com/oauth2/token'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'grant_type': 'client_credentials',
        'client_id': clientId,
        'client_secret': clientSecret,
      },
    );

    final data = json.decode(response.body);
    _accessToken = data['access_token'];
  }

  Future<List<dynamic>> fetchIngredients() async {
    if (_accessToken == null) await authenticate();

    final response = await http.get(
      Uri.parse('https://api.apicbase.com/v1/ingredients'),
      headers: {'Authorization': 'Bearer $_accessToken'},
    );

    return json.decode(response.body)['data'];
  }
}
