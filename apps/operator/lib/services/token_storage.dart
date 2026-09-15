import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  TokenStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _accessKey = 'fotoboot_access_token';
  static const _refreshKey = 'fotoboot_refresh_token';
  static const _emailKey = 'fotoboot_user_email';

  final FlutterSecureStorage _storage;

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    String? email,
  }) async {
    await _storage.write(key: _accessKey, value: accessToken);
    await _storage.write(key: _refreshKey, value: refreshToken);
    if (email != null) {
      await _storage.write(key: _emailKey, value: email);
    }
  }

  Future<String?> readAccessToken() => _storage.read(key: _accessKey);

  Future<String?> readRefreshToken() => _storage.read(key: _refreshKey);

  Future<String?> readEmail() => _storage.read(key: _emailKey);

  Future<bool> hasSession() async {
    final access = await readAccessToken();
    final refresh = await readRefreshToken();
    return (access != null && access.isNotEmpty) ||
        (refresh != null && refresh.isNotEmpty);
  }

  Future<void> clear() async {
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
    await _storage.delete(key: _emailKey);
  }
}
