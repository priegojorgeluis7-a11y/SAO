// lib/core/routing/app_router.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../features/home/home_page.dart';
import '../../features/home/models/today_activity.dart';
import '../../features/settings/settings_page.dart';
import '../../features/agenda/agenda_equipo_page.dart';
import '../../features/activities/wizard/activity_detail_page.dart';
import '../../features/activities/wizard/wizard_page.dart';
import '../../features/activities/wizard/register_wizard_page.dart';
import '../../features/catalog/catalog_repository.dart';
import '../../features/evidence/pending_evidence_store.dart';
import '../../features/auth/ui/login_page.dart';
import '../../features/auth/application/auth_providers.dart';
import '../../features/sync/sync_center_page.dart';
import '../../features/tutorial/tutorial_mode_page.dart';
import '../../ui/bootstrap/catalog_bootstrap_screen.dart';

/// Provider for GoRouter with authentication redirect
final goRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authControllerProvider);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: GoRouterRefreshStream(ref.watch(authControllerProvider.notifier).stream),
    redirect: (context, state) {
      final isAuthenticated = authState.isAuthenticated;
      final isLoading = authState.isLoading;
      final isLoginRoute = state.uri.path == '/login';
      final isTutorialRoute = state.uri.path == '/tutorial';
      final isTutorialGuest = state.uri.queryParameters['tutorial'] == '1';
      final isTutorialGuestShellRoute = isTutorialGuest &&
          (state.uri.path == '/' ||
              state.uri.path == '/sync' ||
              state.uri.path == '/agenda' ||
              state.uri.path == '/settings');

      // If still loading, don't redirect yet
      if (isLoading) {
        return null;
      }

      // If not authenticated and not on login route, redirect to login
      if (!isAuthenticated &&
          !isLoginRoute &&
          !isTutorialRoute &&
          !isTutorialGuestShellRoute) {
        return '/login';
      }

      // If authenticated and on login route, redirect to home
      if (isAuthenticated && isLoginRoute) {
        return '/';
      }

      return null;
    },
    routes: [
      // Login route (outside Shell)
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginPage(),
      ),
      ShellRoute(
        builder: (context, state, child) {
          // Shell with bottom navigation
          return ShellWithBottomNav(child: child);
        },
        routes: [
          GoRoute(
            path: '/',
            name: 'home',
            pageBuilder: (context, state) {
              final projectCode = state.uri.queryParameters['project'] ?? 'TMQ';
              final isTutorialGuest = state.uri.queryParameters['tutorial'] == '1';

              if (isTutorialGuest) {
                return NoTransitionPage(
                  child: HomePage(
                    selectedProject: projectCode,
                    onTapProject: () {},
                  ),
                );
              }

              return NoTransitionPage(
                child: CatalogBootstrapScreen(
                  projectId: projectCode,
                  childWhenReady: HomePage(
                    selectedProject: projectCode,
                    onTapProject: () {}, // No project switching functionality
                  ),
                ),
              );
            },
          ),
          GoRoute(
            path: '/projects',
            name: 'projects',
            pageBuilder: (context, state) {
              // Redirect to home if someone accesses this obsolete route
              WidgetsBinding.instance.addPostFrameCallback((_) {
                context.go('/');
              });
              return const NoTransitionPage(child: SizedBox.shrink());
            },
          ),
          GoRoute(
            path: '/agenda',
            name: 'agenda',
            pageBuilder: (context, state) {
              return const NoTransitionPage(
                child: AgendaEquipoPage(),
              );
            },
          ),
          GoRoute(
            path: '/sync',
            name: 'sync',
            pageBuilder: (context, state) {
              return const NoTransitionPage(
                child: SyncCenterPage(),
              );
            },
          ),
          GoRoute(
            path: '/settings',
            name: 'settings',
            pageBuilder: (context, state) {
              return const NoTransitionPage(
                child: SettingsPage(),
              );
            },
          ),
        ],
      ),

      // Rutas fuera del Shell (fullscreen)
      GoRoute(
        path: '/activity/:id',
        name: 'activity-detail',
        builder: (context, state) {
          final activityId = state.pathParameters['id']!;
          final projectCode = state.uri.queryParameters['project'] ?? 'TMQ';

          final activity = TodayActivity(
            id: activityId,
            title: 'Actividad',
            frente: 'Frente A',
            municipio: 'Municipio',
            estado: 'Estado',
            status: ActivityStatus.hoy,
          );

          return ActivityDetailPage(
            activity: activity,
            projectCode: projectCode,
          );
        },
      ),
      GoRoute(
        path: '/activity/:id/wizard',
        name: 'activity-wizard',
        builder: (context, state) {
          final activityId = state.pathParameters['id']!;
          final projectCode = state.uri.queryParameters['project'] ?? 'TMQ';

          final catalogRepo = GetIt.I<CatalogRepository>();
          final pendingStore = GetIt.I<PendingEvidenceStore>();

          final activity = state.extra as TodayActivity? ??
              TodayActivity(
                id: activityId,
                title: 'Actividad',
                frente: 'Frente A',
                municipio: 'Municipio',
                estado: 'Estado',
                status: ActivityStatus.hoy,
              );

          return ActivityWizardPage(
            activity: activity,
            projectCode: projectCode,
            catalogRepo: catalogRepo,
            pendingStore: pendingStore,
          );
        },
      ),
      GoRoute(
        path: '/wizard/register',
        name: 'register-wizard',
        builder: (context, state) {
          final projectCode = state.uri.queryParameters['project'] ?? 'TMQ';

          final catalogRepo = GetIt.I<CatalogRepository>();
          final pendingStore = GetIt.I<PendingEvidenceStore>();

          final newActivity = TodayActivity(
            id: 'new-${DateTime.now().millisecondsSinceEpoch}',
            title: 'Nueva actividad',
            frente: 'Frente A',
            municipio: 'Municipio',
            estado: 'Estado',
            status: ActivityStatus.hoy,
          );

          return RegisterWizardPage(
            activity: newActivity,
            projectCode: projectCode,
            catalogRepo: catalogRepo,
            pendingStore: pendingStore,
          );
        },
      ),
      GoRoute(
        path: '/tutorial',
        name: 'tutorial-mode',
        builder: (context, state) => const TutorialModePage(),
      ),
    ],
    errorBuilder: (context, state) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Página no encontrada: ${state.uri}'),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => context.go('/'),
                child: const Text('Volver al inicio'),
              ),
            ],
          ),
        ),
      );
    },
  );
});

/// Shell personalizado con bottom navigation
class ShellWithBottomNav extends StatefulWidget {
  final Widget child;
  
  const ShellWithBottomNav({
    super.key,
    required this.child,
  });

  @override
  State<ShellWithBottomNav> createState() => _ShellWithBottomNavState();
}

class _ShellWithBottomNavState extends State<ShellWithBottomNav> {
  bool _isTutorialGuest(BuildContext context) {
    final uri = GoRouterState.of(context).uri;
    return uri.queryParameters['tutorial'] == '1';
  }

  int _calculateSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    if (location.startsWith('/sync')) return 1;
    if (location.startsWith('/agenda')) return 2;
    if (location.startsWith('/settings')) return 3;
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    final tutorialQuery = _isTutorialGuest(context) ? '?tutorial=1' : '';
    switch (index) {
      case 0:
        context.go('/$tutorialQuery');
        break;
      case 1:
        context.go('/sync$tutorialQuery');
        break;
      case 2:
        context.go('/agenda$tutorialQuery');
        break;
      case 3:
        context.go('/settings$tutorialQuery');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _calculateSelectedIndex(context);
    
    return Scaffold(
      body: widget.child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: selectedIndex,
        onTap: (index) => _onItemTapped(index, context),
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(
            label: 'Inicio',
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
          ),
          BottomNavigationBarItem(
            label: 'Sincronizar',
            icon: Icon(Icons.sync_outlined),
            activeIcon: Icon(Icons.sync),
          ),
          BottomNavigationBarItem(
            label: 'Agenda',
            icon: Icon(Icons.calendar_today_outlined),
            activeIcon: Icon(Icons.calendar_today),
          ),
          BottomNavigationBarItem(
            label: 'Ajustes',
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
          ),
        ],
      ),
    );
  }
}

/// Helper class to make GoRouter reactive to stream changes
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen(
          (dynamic _) => notifyListeners(),
        );
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
