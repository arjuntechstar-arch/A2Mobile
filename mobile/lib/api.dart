import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

const apiBaseUrl = String.fromEnvironment('API_BASE_URL',
    defaultValue:
        kIsWeb ? 'http://localhost:8000/api' : 'http://10.0.2.2:8000/api');

class ApiException implements Exception {
  const ApiException(this.status, this.message);
  final int status;
  final String message;
  @override
  String toString() => message;
}

String apiErrorMessage(dynamic detail) {
  if (detail is String) return detail;
  if (detail is List) {
    final messages = <String>[];
    for (final error in detail) {
      if (error is! Map || error['msg'] is! String) continue;
      final location = error['loc'];
      final field = location is List && location.isNotEmpty
          ? location.last.toString()
          : 'Field';
      messages.add(field == 'phone'
          ? 'Phone: enter a valid Indian mobile number, for example +919876543210.'
          : '$field: ${error['msg']}');
    }
    if (messages.isNotEmpty) return messages.join('\n');
  }
  return 'Please check the form and try again.';
}

class AuthService {
  AuthService({http.Client? client, FlutterSecureStorage? storage})
      : _client = client ?? http.Client(),
        _storage = storage ?? const FlutterSecureStorage();
  final http.Client _client;
  final FlutterSecureStorage _storage;
  Future<bool>? _refreshing;
  Future<dynamic> request(String path,
      {String method = 'GET',
      Map<String, dynamic>? body,
      Map<String, String>? headers,
      bool retry = true}) async {
    final access = await _storage.read(key: 'access_token');
    final uri = Uri.parse('$apiBaseUrl$path');
    final request = http.Request(method, kIsWeb ? Uri.base.resolveUri(uri) : uri);
    request.headers.addAll({
      'Content-Type': 'application/json',
      if (access != null) 'Authorization': 'Bearer $access',
      ...?headers
    });
    if (body != null) request.body = jsonEncode(body);
    final response = await http.Response.fromStream(
        await _client.send(request).timeout(const Duration(seconds: 30)));
    if (response.statusCode == 401 && retry && access != null) {
      _refreshing ??= _refresh();
      bool refreshed;
      try {
        refreshed = await _refreshing!;
      } finally {
        _refreshing = null;
      }
      if (refreshed) {
        return this.request(path,
            method: method, body: body, headers: headers, retry: false);
      }
    }
    dynamic data;
    try {
      data = response.body.isEmpty ? null : jsonDecode(response.body);
    } on FormatException {
      throw ApiException(response.statusCode,
          'The service is temporarily unavailable. Please retry.');
    }
    if (response.statusCode >= 400) {
      final detail = data is Map ? data['detail'] : null;
      throw ApiException(response.statusCode, apiErrorMessage(detail));
    }
    return data;
  }

  Future<void> _store(Map<String, dynamic> data) async {
    await _storage.write(
        key: 'access_token', value: data['access_token'] as String);
    await _storage.write(
        key: 'refresh_token', value: data['refresh_token'] as String);
  }

  Future<String> login(String email, String password) async {
    await _store(Map<String, dynamic>.from(await request('/auth/login',
        method: 'POST',
        body: {'email': email, 'password': password},
        retry: false)));
    return (await request('/auth/me'))['email'] as String;
  }

  Future<String?> restoreEmail() async {
    if (await _storage.read(key: 'access_token') == null) return null;
    try {
      return (await request('/auth/me'))['email'] as String;
    } on ApiException catch (error) {
      if (error.status == 401) {
        await _clear();
        return null;
      }
      rethrow;
    }
  }

  Future<bool> _refresh() async {
    final token = await _storage.read(key: 'refresh_token');
    if (token == null) return false;
    try {
      await _store(Map<String, dynamic>.from(await request('/auth/refresh',
          method: 'POST', body: {'refresh_token': token}, retry: false)));
      return true;
    } on ApiException catch (error) {
      if (error.status == 401) {
        await _clear();
        return false;
      }
      rethrow;
    }
  }

  Future<void> _clear() async {
    await _storage.delete(key: 'access_token');
    await _storage.delete(key: 'refresh_token');
  }

  Future<void> registerPush(String token, String platform) async {
    await request('/notifications/devices',
        method: 'POST', body: {'token': token, 'platform': platform});
    await _storage.write(
        key: 'push_registration',
        value: jsonEncode({'token': token, 'platform': platform}));
  }

  Future<void> logout() async {
    final token = await _storage.read(key: 'refresh_token');
    final registration = await _storage.read(key: 'push_registration');
    if (registration != null) {
      try {
        await request('/notifications/devices',
            method: 'DELETE',
            body: Map<String, dynamic>.from(jsonDecode(registration)));
      } catch (_) {/* Session revocation still proceeds. */}
      await _storage.delete(key: 'push_registration');
    }
    try {
      if (token != null) {
        await request('/auth/logout',
            method: 'POST', body: {'refresh_token': token}, retry: false);
      }
    } finally {
      await _clear();
    }
  }
}
