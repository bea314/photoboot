import 'dart:convert';
import 'dart:typed_data';

import 'package:fotoboot_operator/config/app_config.dart';
import 'package:fotoboot_operator/services/token_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

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

class RemotePhoto {
  const RemotePhoto({
    required this.id,
    required this.eventId,
    required this.clientPhotoId,
    required this.takenAt,
    required this.thumbUrl,
    required this.originalUrl,
    this.printedAt,
  });

  final String id;
  final String eventId;
  final String clientPhotoId;
  final DateTime takenAt;
  final DateTime? printedAt;
  final String thumbUrl;
  final String originalUrl;

  factory RemotePhoto.fromJson(Map<String, dynamic> json) {
    return RemotePhoto(
      id: json['id'] as String,
      eventId: json['eventId'] as String,
      clientPhotoId: json['clientPhotoId'] as String,
      takenAt: DateTime.parse(json['takenAt'] as String),
      printedAt: json['printedAt'] == null
          ? null
          : DateTime.parse(json['printedAt'] as String),
      thumbUrl: json['thumbUrl'] as String,
      originalUrl: json['originalUrl'] as String,
    );
  }
}


class PrintJobInfo {
  const PrintJobInfo({
    required this.id,
    required this.eventId,
    required this.printerProfile,
    required this.type,
    required this.copies,
    required this.status,
    required this.photoIds,
    this.error,
  });

  final String id;
  final String eventId;
  final String printerProfile;
  final String type;
  final int copies;
  final String status;
  final List<String> photoIds;
  final String? error;

  factory PrintJobInfo.fromJson(Map<String, dynamic> json) {
    return PrintJobInfo(
      id: json['id'] as String,
      eventId: json['eventId'] as String,
      printerProfile: json['printerProfile'] as String,
      type: json['type'] as String? ?? 'photo',
      copies: json['copies'] as int? ?? 1,
      status: json['status'] as String? ?? 'queued',
      photoIds: (json['photoIds'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      error: json['error'] as String?,
    );
  }
}

class PrinterProfilesResponse {
  const PrinterProfilesResponse({
    required this.profiles,
    required this.defaultProfileId,
  });

  final List<Map<String, dynamic>> profiles;
  final String defaultProfileId;

  factory PrinterProfilesResponse.fromJson(Map<String, dynamic> json) {
    final list = (json['profiles'] as List<dynamic>? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    return PrinterProfilesResponse(
      profiles: list,
      defaultProfileId: json['defaultProfileId'] as String? ?? 'thermal_80',
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

  Future<List<RemotePhoto>> listPhotos(String eventId) async {
    final response = await _authorized((headers) {
      return _http.get(
        _uri('/v1/photos').replace(queryParameters: {'eventId': eventId}),
        headers: headers,
      );
    });
    if (response.statusCode != 200) {
      final body = _decode(response);
      throw ApiException(
        body['message']?.toString() ?? 'Could not list photos',
        statusCode: response.statusCode,
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! List) return [];
    return decoded
        .whereType<Map>()
        .map((item) => RemotePhoto.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<RemotePhoto> uploadPhoto({
    required String eventId,
    required String clientPhotoId,
    required DateTime takenAt,
    required Uint8List bytes,
  }) async {
    final response = await _authorizedMultipart((access) {
      final request = http.MultipartRequest('POST', _uri('/v1/photos'));
      request.headers['Authorization'] = 'Bearer $access';
      request.fields['eventId'] = eventId;
      request.fields['clientPhotoId'] = clientPhotoId;
      request.fields['takenAt'] = takenAt.toUtc().toIso8601String();
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: '$clientPhotoId.jpg',
          contentType: MediaType('image', 'jpeg'),
        ),
      );
      return request;
    });
    final body = _decode(response);
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw ApiException(
        body['message']?.toString() ?? 'Could not upload photo',
        statusCode: response.statusCode,
      );
    }
    return RemotePhoto.fromJson(body);
  }

  Future<void> deletePhoto(String id) async {
    final response = await _authorized((headers) {
      return _http.delete(_uri('/v1/photos/$id'), headers: headers);
    });
    if (response.statusCode == 204 || response.statusCode == 404) return;
    final body = _decode(response);
    throw ApiException(
      body['message']?.toString() ?? 'Could not delete photo',
      statusCode: response.statusCode,
    );
  }

  Future<Uint8List> downloadPhotoFile(
    String id, {
    String variant = 'thumb',
  }) async {
    final response = await _authorized((headers) {
      return _http.get(
        _uri('/v1/photos/$id/file').replace(
          queryParameters: {'variant': variant},
        ),
        headers: headers,
      );
    });
    if (response.statusCode != 200) {
      throw ApiException(
        'Could not download photo',
        statusCode: response.statusCode,
      );
    }
    return response.bodyBytes;
  }


  Future<PrinterProfilesResponse> getPrinterProfiles() async {
    final response = await _authorized((headers) {
      return _http.get(_uri('/v1/printer/profiles'), headers: headers);
    });
    final body = _decode(response);
    if (response.statusCode != 200) {
      throw ApiException(
        body['message']?.toString() ?? 'Could not load printer profiles',
        statusCode: response.statusCode,
      );
    }
    return PrinterProfilesResponse.fromJson(body);
  }

  Future<PrintJobInfo> createPrintJob({
    required String eventId,
    required String printerProfile,
    List<String> photoIds = const [],
    String type = 'photo',
    int copies = 1,
    String localStatus = 'queued',
    String? error,
  }) async {
    final payload = <String, dynamic>{
      'eventId': eventId,
      'printerProfile': printerProfile,
      'type': type,
      'copies': copies,
      'localStatus': localStatus,
      if (photoIds.isNotEmpty) 'photoIds': photoIds,
      if (error != null) 'error': error,
    };

    final response = await _authorized((headers) {
      return _http.post(
        _uri('/v1/print-jobs'),
        headers: {
          ...headers,
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );
    });
    final body = _decode(response);
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw ApiException(
        body['message']?.toString() ?? 'Could not create print job',
        statusCode: response.statusCode,
      );
    }
    return PrintJobInfo.fromJson(body);
  }

  Future<PrintJobInfo> updatePrintJob(
    String id, {
    required String localStatus,
    String? error,
  }) async {
    final payload = <String, dynamic>{
      'localStatus': localStatus,
      if (error != null) 'error': error,
    };
    final response = await _authorized((headers) {
      return _http.patch(
        _uri('/v1/print-jobs/$id'),
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
        body['message']?.toString() ?? 'Could not update print job',
        statusCode: response.statusCode,
      );
    }
    return PrintJobInfo.fromJson(body);
  }

  Future<http.Response> _authorizedMultipart(
    http.MultipartRequest Function(String access) build,
  ) async {
    var access = await _tokens.readAccessToken();
    if (access == null || access.isEmpty) {
      await refresh();
      access = await _tokens.readAccessToken();
    }

    Future<http.Response> send(String token) async {
      final streamed = await _http.send(build(token));
      return http.Response.fromStream(streamed);
    }

    var response = await send(access!);
    if (response.statusCode == 401) {
      await refresh();
      access = await _tokens.readAccessToken();
      response = await send(access!);
    }
    return response;
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
