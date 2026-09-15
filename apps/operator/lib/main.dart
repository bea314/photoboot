import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:fotoboot_operator/router/app_router.dart';
import 'package:fotoboot_operator/theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(FotobootOperatorApp(router: createAppRouter()));
}

class FotobootOperatorApp extends StatelessWidget {
  const FotobootOperatorApp({super.key, required this.router});

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
