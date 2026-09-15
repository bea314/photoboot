import 'dart:convert';

import 'package:fotoboot_operator/config/app_config.dart';
import 'package:fotoboot_operator/services/token_storage.dart';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.userId,
    required this.email,
  });

  final String accessToken;
  final String refreshToken;
  final String userId;
  final String email;
}

class EventInfo {
  const EventInfo({
    required this.id,
    required this.name,
    required this.slug,
    required this.isActive,
    required this.publicUrl,
    this.publicToken,
  });

  final String id;
  final String name;
  final String slug;
  final bool isActive;
  final String publicUrl;
  final String? publicToken;

  factory EventInfo.fromJson(Map<String, dynamic> json) {
    return EventInfo(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String,
      isActive: json['isActive'] as bool? ?? false,
      publicUrl: json['publicUrl'] as String,
      publicToken: json['publicToken'] as String?,
    );
  }
}

class ApiClient {
  ApiClient({
    required TokenStorage tokenStorage,
    http.Client? httpClient,
    String? baseUrl,
  })  : _tokens = tokenStorage,
        _http = httpClient ?? http.Client(),
        baseUrl = baseUrl ?? kApiBaseUrl;

  final TokenStorage _tokens;
  final http.Client _http;
  final String baseUrl;

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final response = await _http.post(
      _uri('/v1/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    final body = _decode(response);
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw ApiException(
        body['message']?.toString() ?? 'Login failed',
        statusCode: response.statusCode,
      );
    }

    final session = _sessionFromBody(body);
    await _tokens.saveTokens(
      accessToken: session.accessToken,
      refreshToken: session.refreshToken,
      email: session.email,
    );
    return session;
  }

  Future<AuthSession> refresh() async {
    final refreshToken = await _tokens.readRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      throw ApiException('No refresh token', statusCode: 401);
    }

    final response = await _http.post(
      _uri('/v1/auth/refresh'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refreshToken': refreshToken}),
    );
    final body = _decode(response);
    if (response.statusCode != 200 && response.statusCode != 201) {
      await _tokens.clear();
      throw ApiException(
        body['message']?.toString() ?? 'Session expired',
        statusCode: response.statusCode,
      );
    }

    final session = _sessionFromBody(body);
    await _tokens.saveTokens(
      accessToken: session.accessToken,
      refreshToken: session.refreshToken,
      email: session.email,
    );
    return session;
  }

  Future<void> logout() async {
    final refreshToken = await _tokens.readRefreshToken();
    if (refreshToken != null && refreshToken.isNotEmpty) {
      try {
        await _http.post(
          _uri('/v1/auth/logout'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'refreshToken': refreshToken}),
        );
      } catch (_) {
        // Local clear still happens.
      }
    }
    await _tokens.clear();
  }

  Future<EventInfo> getCurrentEvent() async {
    final response = await _authorized((headers) {
      return _http.get(_uri('/v1/events/current'), headers: headers);
    });
    final body = _decode(response);
    if (response.statusCode == 404) {
      throw ApiException('No active event', statusCode: 404);
    }
    if (response.statusCode != 200) {
      throw ApiException(
        body['message']?.toString() ?? 'Could not load event',
        statusCode: response.statusCode,
      );
    }
    return EventInfo.fromJson(body);
  }

  Future<EventInfo> updateEvent(
    String id, {
    String? name,
    String? slug,
    bool? isActive,
  }) async {
    final payload = <String, dynamic>{};
    if (name != null) payload['name'] = name;
    if (slug != null) payload['slug'] = slug;
    if (isActive != null) payload['isActive'] = isActive;

    final response = await _authorized((headers) {
      return _http.patch(
        _uri('/v1/events/$id'),
        headers: {
          ...headers,
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );
    });
    final body = _decode(response);
    if (response.statusCode != 200) {
      throw ApiException(
        body['message']?.toString() ?? 'Could not update event',
        statusCode: response.statusCode,
      );
    }
    return EventInfo.fromJson(body);
  }

  Future<http.Response> _authorized(
    Future<http.Response> Function(Map<String, String> headers) send,
  ) async {
    var access = await _tokens.readAccessToken();
    if (access == null || access.isEmpty) {
      await refresh();
      access = await _tokens.readAccessToken();
    }

    var response = await send({'Authorization': 'Bearer $access'});
    if (response.statusCode == 401) {
      await refresh();
      access = await _tokens.readAccessToken();
      response = await send({'Authorization': 'Bearer $access'});
    }
    return response;
  }

  AuthSession _sessionFromBody(Map<String, dynamic> body) {
    final user = body['user'] as Map<String, dynamic>? ?? {};
    return AuthSession(
      accessToken: body['accessToken'] as String,
      refreshToken: body['refreshToken'] as String,
      userId: user['id'] as String? ?? '',
      email: user['email'] as String? ?? '',
    );
  }

  Map<String, dynamic> _decode(http.Response response) {
    if (response.body.isEmpty) return {};
    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      if (decoded['message'] is List) {
        return {
          ...decoded,
          'message': (decoded['message'] as List).join(', '),
        };
      }
      return decoded;
    }
    return {'message': response.body};
  }
}
