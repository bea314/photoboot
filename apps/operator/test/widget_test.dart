import 'package:flutter_test/flutter_test.dart';
import 'package:fotoboot_operator/main.dart';
import 'package:fotoboot_operator/services/api_client.dart';
import 'package:fotoboot_operator/services/auth_controller.dart';
import 'package:fotoboot_operator/services/photo_controller.dart';
import 'package:fotoboot_operator/services/token_storage.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class _MemoryStorage extends FlutterSecureStorage {
  final Map<String, String> _data = {};

  @override
  Future<void> write({
    required String key,
    required String? value,
    AndroidOptions? aOptions,
    IOSOptions? iOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      _data.remove(key);
    } else {
      _data[key] = value;
    }
  }

  @override
  Future<String?> read({
    required String key,
    AndroidOptions? aOptions,
    IOSOptions? iOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      _data[key];

  @override
  Future<void> delete({
    required String key,
    AndroidOptions? aOptions,
    IOSOptions? iOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _data.remove(key);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app boots on login screen', (tester) async {
    final tokens = TokenStorage(storage: _MemoryStorage());
    final api = ApiClient(tokenStorage: tokens);
    final auth = AuthController(tokenStorage: tokens, apiClient: api);
    final photos = PhotoController(api: api, auth: auth);
    await auth.bootstrap();

    await tester.pumpWidget(FotobootOperatorApp(auth: auth, photos: photos));
    await tester.pumpAndSettle();

    expect(find.text('Fotoboot'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
  });
}
