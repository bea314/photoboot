import 'package:flutter/foundation.dart';
import 'package:fotoboot_operator/services/api_client.dart';
import 'package:fotoboot_operator/services/token_storage.dart';

class AuthController extends ChangeNotifier {
  AuthController({
    required TokenStorage tokenStorage,
    required ApiClient apiClient,
  })  : _tokens = tokenStorage,
        _api = apiClient;

  final TokenStorage _tokens;
  final ApiClient _api;

  bool _ready = false;
  bool _authenticated = false;
  String? _email;
  String? _error;
  bool _busy = false;

  bool get ready => _ready;
  bool get authenticated => _authenticated;
  String? get email => _email;
  String? get error => _error;
  bool get busy => _busy;
  ApiClient get api => _api;

  Future<void> bootstrap() async {
    _authenticated = await _tokens.hasSession();
    _email = await _tokens.readEmail();
    if (_authenticated) {
      try {
        await _api.refresh();
        _email = await _tokens.readEmail();
        _authenticated = true;
      } catch (_) {
        await _tokens.clear();
        _authenticated = false;
        _email = null;
      }
    }
    _ready = true;
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      final session = await _api.login(email: email, password: password);
      _authenticated = true;
      _email = session.email;
      _busy = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      _busy = false;
      notifyListeners();
      return false;
    } catch (_) {
      _error = 'No se pudo conectar con la API';
      _busy = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    _busy = true;
    notifyListeners();
    await _api.logout();
    _authenticated = false;
    _email = null;
    _busy = false;
    notifyListeners();
  }
}
