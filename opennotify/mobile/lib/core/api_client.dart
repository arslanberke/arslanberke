import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;
  const ApiException(this.statusCode, this.message);

  @override
  String toString() => message;
}

/// Thin REST client with JWT storage and automatic refresh-token rotation.
class ApiClient {
  ApiClient({this.baseUrl = const String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://10.0.2.2:4000/api/v1',
  )});

  final String baseUrl;

  static const _accessKey = 'opennotify.access';
  static const _refreshKey = 'opennotify.refresh';

  Future<String?> get accessToken async =>
      (await SharedPreferences.getInstance()).getString(_accessKey);

  Future<void> saveTokens(Map<String, dynamic> pair) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessKey, pair['accessToken'] as String);
    await prefs.setString(_refreshKey, pair['refreshToken'] as String);
  }

  Future<void> clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessKey);
    await prefs.remove(_refreshKey);
  }

  Future<bool> _refresh() async {
    final prefs = await SharedPreferences.getInstance();
    final refreshToken = prefs.getString(_refreshKey);
    if (refreshToken == null) return false;
    final res = await http.post(
      Uri.parse('$baseUrl/auth/refresh'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refreshToken': refreshToken}),
    );
    if (res.statusCode != 200) {
      await clearTokens();
      return false;
    }
    await saveTokens(jsonDecode(res.body) as Map<String, dynamic>);
    return true;
  }

  Future<dynamic> request(
    String path, {
    String method = 'GET',
    Object? body,
    bool retry = true,
  }) async {
    final token = await accessToken;
    final uri = Uri.parse('$baseUrl$path');
    final headers = {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
    final encoded = body != null ? jsonEncode(body) : null;

    final res = await switch (method) {
      'POST' => http.post(uri, headers: headers, body: encoded),
      'PATCH' => http.patch(uri, headers: headers, body: encoded),
      'DELETE' => http.delete(uri, headers: headers),
      _ => http.get(uri, headers: headers),
    };

    if (res.statusCode == 401 && retry && await _refresh()) {
      return request(path, method: method, body: body, retry: false);
    }
    if (res.statusCode >= 400) {
      String message = 'Request failed (${res.statusCode})';
      try {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final raw = data['message'];
        message = raw is List ? raw.join(', ') : raw.toString();
      } catch (_) {}
      throw ApiException(res.statusCode, message);
    }
    if (res.body.isEmpty) return null;
    return jsonDecode(res.body);
  }
}
