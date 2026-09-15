import 'package:flutter/material.dart';
import 'package:fotoboot_operator/router/app_router.dart';
import 'package:fotoboot_operator/services/api_client.dart';
import 'package:fotoboot_operator/services/auth_controller.dart';
import 'package:fotoboot_operator/services/photo_controller.dart';
import 'package:fotoboot_operator/services/token_storage.dart';
import 'package:fotoboot_operator/theme/app_theme.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  final tokens = TokenStorage();
  final api = ApiClient(tokenStorage: tokens);
  final auth = AuthController(tokenStorage: tokens, apiClient: api);
  await auth.bootstrap();
  final photos = PhotoController(api: api, auth: auth);
  await photos.bind();

  runApp(FotobootOperatorApp(auth: auth, photos: photos));
}

class FotobootOperatorApp extends StatelessWidget {
  FotobootOperatorApp({
    super.key,
    required this.auth,
    required this.photos,
  }) : router = createAppRouter(auth, photos);

  final AuthController auth;
  final PhotoController photos;
  final GoRouter router;

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Fotoboot',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      routerConfig: router,
    );
  }
}
