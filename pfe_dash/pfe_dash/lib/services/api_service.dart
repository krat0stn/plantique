import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'http://localhost:4000/api';
  static String? _token;

  // ← ADD: set token after login
  static void setToken(String token) {
    _token = token;
    print('Token set: $_token');
  }

  static String? get token => _token; // ← ADD THIS getter

  static Map<String, String> _headers() {
    print('Token in headers: $_token');
    return {
      'Content-Type': 'application/json',
      if (_token != null) 'Authorization': 'Bearer $_token', // ← ADD
    };
  }

  static Future<dynamic> get(String endpoint) async {
    final response = await http.get(
      Uri.parse('$baseUrl$endpoint'),
      headers: _headers(), // ← CHANGED
    );
    return _handleResponse(response);
  }

  static Future<dynamic> post(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl$endpoint'),
      headers: _headers(), // ← CHANGED
      body: jsonEncode(body),
    );
    return _handleResponse(response);
  }

  static Future<dynamic> put(String endpoint, Map<String, dynamic> body) async {
    final response = await http.put(
      Uri.parse('$baseUrl$endpoint'),
      headers: _headers(), // ← CHANGED
      body: jsonEncode(body),
    );
    return _handleResponse(response);
  }

  static Future<dynamic> delete(String endpoint) async {
    final response = await http.delete(
      Uri.parse('$baseUrl$endpoint'),
      headers: _headers(), // ← CHANGED
    );
    return _handleResponse(response);
  }

  static dynamic _handleResponse(http.Response response) {
    final data = jsonDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    } else {
      throw Exception(
        data['errormessage'] ?? data['message'] ?? 'Request failed',
      );
    }
  }
}
