import 'package:flutter/material.dart';
import 'package:fotoboot_operator/screens/camera_screen.dart';
import 'package:fotoboot_operator/screens/event_screen.dart';
import 'package:fotoboot_operator/screens/gallery_screen.dart';
import 'package:fotoboot_operator/screens/login_screen.dart';
import 'package:fotoboot_operator/screens/photo_detail_screen.dart';
import 'package:fotoboot_operator/screens/printer_screen.dart';
import 'package:fotoboot_operator/screens/templates_screen.dart';
import 'package:fotoboot_operator/services/auth_controller.dart';
import 'package:fotoboot_operator/services/photo_controller.dart';
import 'package:go_router/go_router.dart';

GoRouter createAppRouter(AuthController auth, PhotoController photos) {
  return GoRouter(
    initialLocation: '/login',
    refreshListenable: auth,
    redirect: (context, state) {
      if (!auth.ready) return null;
      final loggingIn = state.matchedLocation == '/login';
      if (!auth.authenticated && !loggingIn) return '/login';
      if (auth.authenticated && loggingIn) return '/camera';
      // Legacy Gestión path → templates hub.
      if (state.matchedLocation == '/printer') return '/templates';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => LoginScreen(auth: auth),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return OperatorShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/camera',
                name: 'camera',
                builder: (context, state) => CameraScreen(photos: photos),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/gallery',
                name: 'gallery',
                builder: (context, state) => GalleryScreen(photos: photos),
                routes: [
                  GoRoute(
                    path: 'detail/:clientPhotoId',
                    name: 'detail',
                    builder: (context, state) => PhotoDetailScreen(
                      photos: photos,
                      auth: auth,
                      clientPhotoId: state.pathParameters['clientPhotoId']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/templates',
                name: 'templates',
                builder: (context, state) => const TemplatesScreen(),
                routes: [
                  GoRoute(
                    path: 'printer',
                    name: 'templates-printer',
                    builder: (context, state) => PrinterScreen(auth: auth),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/event',
                name: 'event',
                builder: (context, state) => EventScreen(auth: auth),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

class OperatorShell extends StatelessWidget {
  const OperatorShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _onTap(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    final onPhotoDetail = path.contains('/gallery/detail/');
    final onAdvancedPrinter = path == '/templates/printer';

    return Scaffold(
      extendBody: navigationShell.currentIndex == 0 && !onPhotoDetail,
      body: navigationShell,
      bottomNavigationBar: (onPhotoDetail || onAdvancedPrinter)
          ? null
          : NavigationBar(
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: _onTap,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.photo_camera_outlined),
                  selectedIcon: Icon(Icons.photo_camera),
                  label: 'Cámara',
                ),
                NavigationDestination(
                  icon: Icon(Icons.photo_library_outlined),
                  selectedIcon: Icon(Icons.photo_library),
                  label: 'Galería',
                ),
                NavigationDestination(
                  icon: Icon(Icons.dashboard_customize_outlined),
                  selectedIcon: Icon(Icons.dashboard_customize),
                  label: 'Gestión',
                ),
                NavigationDestination(
                  icon: Icon(Icons.qr_code_2),
                  selectedIcon: Icon(Icons.qr_code_2),
                  label: 'Evento',
                ),
              ],
            ),
    );
  }
}
