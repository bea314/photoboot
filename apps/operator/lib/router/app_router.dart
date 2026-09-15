import 'package:flutter/material.dart';
import 'package:fotoboot_operator/screens/event_screen.dart';
import 'package:fotoboot_operator/screens/login_screen.dart';
import 'package:fotoboot_operator/screens/placeholder_screen.dart';
import 'package:fotoboot_operator/services/auth_controller.dart';
import 'package:fotoboot_operator/theme/app_colors.dart';
import 'package:go_router/go_router.dart';

GoRouter createAppRouter(AuthController auth) {
  return GoRouter(
    initialLocation: '/login',
    refreshListenable: auth,
    redirect: (context, state) {
      if (!auth.ready) return null;
      final loggingIn = state.matchedLocation == '/login';
      if (!auth.authenticated && !loggingIn) return '/login';
      if (auth.authenticated && loggingIn) return '/camera';
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
                builder: (context, state) => const PlaceholderScreen(
                  title: 'Cámara',
                  subtitle: 'Countdown 3-2-1 y captura (Fase C).',
                  icon: Icons.photo_camera_outlined,
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/gallery',
                name: 'gallery',
                builder: (context, state) => const PlaceholderScreen(
                  title: 'Galería',
                  subtitle: 'Masonry + selección múltiple (Fase C).',
                  icon: Icons.photo_library_outlined,
                ),
                routes: [
                  GoRoute(
                    path: 'detail',
                    name: 'detail',
                    builder: (context, state) => const PlaceholderScreen(
                      title: 'Detalle',
                      subtitle: 'Foto grande, imprimir y eliminar (Fase C/D).',
                      icon: Icons.image_outlined,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/printer',
                name: 'printer',
                builder: (context, state) => const PlaceholderScreen(
                  title: 'Gestión',
                  subtitle: 'Impresora térmica / L8050 y test print (Fase D).',
                  icon: Icons.print_outlined,
                ),
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
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
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
            icon: Icon(Icons.print_outlined),
            selectedIcon: Icon(Icons.print),
            label: 'Gestión',
          ),
          NavigationDestination(
            icon: Icon(Icons.qr_code_2),
            selectedIcon: Icon(Icons.qr_code_2),
            label: 'Evento',
          ),
        ],
      ),
      floatingActionButton: navigationShell.currentIndex == 1
          ? FloatingActionButton.extended(
              onPressed: () => context.go('/gallery/detail'),
              backgroundColor: AppColors.red,
              foregroundColor: AppColors.white,
              icon: const Icon(Icons.open_in_new),
              label: const Text('Detalle'),
            )
          : null,
    );
  }
}
