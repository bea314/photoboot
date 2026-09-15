import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:fotoboot_operator/screens/placeholder_screen.dart';
import 'package:fotoboot_operator/theme/app_colors.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();

GoRouter createAppRouter() {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/login',
    routes: [
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const _LoginPlaceholder(),
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
                builder: (context, state) => const PlaceholderScreen(
                  title: 'Evento / QR',
                  subtitle: 'Link público y QR del evento (Fase B).',
                  icon: Icons.qr_code_2,
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

class _LoginPlaceholder extends StatelessWidget {
  const _LoginPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              const Icon(Icons.lock_outline, size: 72, color: AppColors.red),
              const SizedBox(height: 24),
              Text(
                'Login',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: AppColors.red,
                      fontWeight: FontWeight.w700,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Email y password del operador (Fase B).',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.grey, fontSize: 16),
              ),
              const SizedBox(height: 8),
              const Text(
                'Fase A — placeholder',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () => context.go('/camera'),
                child: const Text('Entrar (demo)'),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
