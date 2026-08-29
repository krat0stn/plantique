import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'http://localhost:4000/api';
  static String? _token;
  static bool _isAdmin = false;
  static String _role = 'User'; // 'Admin' | 'Supplier' | 'User'

  // ── Auth ─────────────────────────────────────────────────────────────────────

  static void setToken(String token) {
    _token = token;
    print('Token set: $_token');
  }

  static String? get token => _token;

  static void setIsAdmin(bool value) {
    _isAdmin = value;
    print('isAdmin set to: $_isAdmin');
  }

  static bool get isAdmin => _isAdmin;

  static void setRole(String role) {
    _role = role;
    print('role set to: $_role');
  }

  static String get role => _role;

  static void clearToken() {
    _token = null;
    _isAdmin = false;
    _role = 'User';
    print('Token cleared');
  }

  // ── Headers ──────────────────────────────────────────────────────────────────

  static Map<String, String> _headers() {
    print('Token in headers: $_token');
    return {
      'Content-Type': 'application/json',
      if (_token != null) 'Authorization': 'Bearer $_token',
    };
  }

  // ── HTTP Methods ─────────────────────────────────────────────────────────────

  static Future<dynamic> get(String endpoint) async {
    final response = await http.get(
      Uri.parse('$baseUrl$endpoint'),
      headers: _headers(),
    );
    return _handleResponse(response);
  }

  static Future<dynamic> post(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl$endpoint'),
      headers: _headers(),
      body: jsonEncode(body),
    );
    return _handleResponse(response);
  }

  static Future<dynamic> put(String endpoint, Map<String, dynamic> body) async {
    final response = await http.put(
      Uri.parse('$baseUrl$endpoint'),
      headers: _headers(),
      body: jsonEncode(body),
    );
    return _handleResponse(response);
  }

  static Future<dynamic> delete(String endpoint) async {
    final response = await http.delete(
      Uri.parse('$baseUrl$endpoint'),
      headers: _headers(),
    );
    return _handleResponse(response);
  }

  static dynamic _handleResponse(http.Response response) {
    final data = jsonDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    } else {
      throw Exception(
        data['errormessage'] ??
            data['error'] ??
            data['message'] ??
            'Request failed',
      );
    }
  }

  // ── Multipart ─────────────────────────────────────────────────────────────────

  // ── User Search ─────────────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    if (query.trim().isEmpty) return [];
    final response = await http.get(
      Uri.parse('$baseUrl/supplier-dashboard/users/search?q=${Uri.encodeComponent(query)}'),
      headers: _headers(),
    );
    final data = _handleResponse(response);
    final list = data['data'] as List<dynamic>? ?? [];
    return list.cast<Map<String, dynamic>>();
  }

  static Future<dynamic> postWithFile(
    String endpoint,
    Map<String, String> fields,
    List<http.MultipartFile> files,
  ) async {
    return multipartRequest('POST', endpoint, fields, files);
  }

  static Future<dynamic> multipartRequest(
    String method,
    String endpoint,
    Map<String, String> fields,
    List<http.MultipartFile> files,
  ) async {
    final request = http.MultipartRequest(
      method,
      Uri.parse('$baseUrl$endpoint'),
    );

    if (_token != null) {
      request.headers['Authorization'] = 'Bearer $_token';
    }

    fields.forEach((key, value) {
      request.fields[key] = value;
    });

    for (final file in files) {
      request.files.add(file);
    }

    final response = await request.send();
    final responseData = await response.stream.bytesToString();
    final data = jsonDecode(responseData);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    } else {
      throw Exception(
        data['errormessage'] ??
            data['error'] ??
            data['message'] ??
            'Request failed',
      );
    }
  }
}
