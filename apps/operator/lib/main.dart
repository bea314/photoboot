import 'package:flutter/material.dart';
import 'package:fotoboot_operator/router/app_router.dart';
import 'package:fotoboot_operator/services/api_client.dart';
import 'package:fotoboot_operator/services/auth_controller.dart';
import 'package:fotoboot_operator/services/token_storage.dart';
import 'package:fotoboot_operator/theme/app_theme.dart';
import 'package:go_router/go_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final tokens = TokenStorage();
  final api = ApiClient(tokenStorage: tokens);
  final auth = AuthController(tokenStorage: tokens, apiClient: api);
  await auth.bootstrap();

  runApp(FotobootOperatorApp(auth: auth));
}

class FotobootOperatorApp extends StatelessWidget {
  FotobootOperatorApp({super.key, required this.auth})
      : router = createAppRouter(auth);

  final AuthController auth;
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
