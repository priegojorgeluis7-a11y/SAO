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
import '../../features/auth/ui/signup_page.dart';
import '../../features/auth/ui/pin_unlock_page.dart';
import '../../features/auth/ui/pin_setup_page.dart';
import '../../features/auth/application/auth_providers.dart';
import '../../features/sync/sync_center_page.dart';
import '../../features/events/ui/events_list_page.dart';
import '../../features/projects/projects_page.dart';
import '../../features/tutorial/tutorial_mode_page.dart';
import '../../ui/bootstrap/catalog_bootstrap_screen.dart';
import 'auth_redirect_resolver.dart';

/// Provider for GoRouter with authentication redirect
final goRouterProvider = Provider<GoRouter>((ref) {
  final authStateAsync = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: GoRouterRefreshStream(ref.watch(authControllerProvider.notifier).stream),
    redirect: (context, state) {
      return resolveAuthRedirect(
        authStateAsync: authStateAsync,
        uri: state.uri,
      );
    },
    routes: [
      // Login route (outside Shell)
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/auth/login',
        name: 'auth-login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/auth/signup',
        name: 'auth-signup',
        builder: (context, state) => const SignupPage(),
      ),
      GoRoute(
        path: '/auth/pin-unlock',
        name: 'pin-unlock',
        builder: (context, state) => const PinUnlockPage(),
      ),
      GoRoute(
        path: '/auth/pin-setup',
        name: 'pin-setup',
        builder: (context, state) => const PinSetupPage(),
      ),
      GoRoute(
        path: '/home',
        redirect: (context, state) => '/',
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
                    onTapProject: () async {
                      final selected = await context.push<String>(
                        '/projects?selected=${Uri.encodeQueryComponent(projectCode)}&tutorial=1',
                      );
                      if (!context.mounted || selected == null || selected.trim().isEmpty) {
                        return;
                      }
                      final normalized = selected.trim().toUpperCase();
                      if (normalized == projectCode.toUpperCase()) {
                        return;
                      }
                      context.go('/?project=${Uri.encodeQueryComponent(normalized)}&tutorial=1');
                    },
                  ),
                );
              }

              return NoTransitionPage(
                child: CatalogBootstrapScreen(
                  projectId: projectCode,
                  childWhenReady: HomePage(
                    selectedProject: projectCode,
                    onTapProject: () async {
                      final selected = await context.push<String>(
                        '/projects?selected=${Uri.encodeQueryComponent(projectCode)}',
                      );
                      if (!context.mounted || selected == null || selected.trim().isEmpty) {
                        return;
                      }
                      final normalized = selected.trim().toUpperCase();
                      if (normalized == projectCode.toUpperCase()) {
                        return;
                      }
                      context.go('/?project=${Uri.encodeQueryComponent(normalized)}');
                    },
                  ),
                ),
              );
            },
          ),
          GoRoute(
            path: '/projects',
            name: 'projects',
            pageBuilder: (context, state) {
              final selected = state.uri.queryParameters['selected'] ??
                  state.uri.queryParameters['project'] ??
                  'TMQ';
              return NoTransitionPage(
                child: ProjectsPage(selectedCode: selected),
              );
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
            path: '/events',
            name: 'events',
            pageBuilder: (context, state) {
              final projectCode = state.uri.queryParameters['project'] ?? 'TMQ';
              return NoTransitionPage(
                child: EventsListPage(projectId: projectCode),
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
            title: '',
            frente: '',
            municipio: '',
            estado: '',
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
                title: '',
                frente: '',
                municipio: '',
                estado: '',
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
          final isUnplanned = state.uri.queryParameters['mode'] == 'unplanned';

          final catalogRepo = GetIt.I<CatalogRepository>();
          final pendingStore = GetIt.I<PendingEvidenceStore>();

          final newActivity = TodayActivity(
            id: 'new-${DateTime.now().millisecondsSinceEpoch}',
            title: '',
            frente: '',
            municipio: '',
            estado: '',
            status: ActivityStatus.hoy,
            isUnplanned: isUnplanned,
          );

          return RegisterWizardPage(
            activity: newActivity,
            projectCode: projectCode,
            catalogRepo: catalogRepo,
            pendingStore: pendingStore,
            isUnplanned: isUnplanned,
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
  String _buildNavQuery(BuildContext context) {
    final uri = GoRouterState.of(context).uri;
    final project = (uri.queryParameters['project'] ?? 'TMQ').trim();
    final tutorial = uri.queryParameters['tutorial'] == '1';

    final query = <String, String>{
      'project': project.isEmpty ? 'TMQ' : project,
    };
    if (tutorial) {
      query['tutorial'] = '1';
    }
    return Uri(queryParameters: query).query;
  }

  bool _isTutorialGuest(BuildContext context) {
    final uri = GoRouterState.of(context).uri;
    return uri.queryParameters['tutorial'] == '1';
  }

  int _calculateSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    if (location.startsWith('/sync')) return 1;
    if (location.startsWith('/agenda')) return 2;
    if (location.startsWith('/events')) return 3;
    if (location.startsWith('/settings')) return 4;
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    final query = _buildNavQuery(context);
    final suffix = query.isEmpty ? '' : '?$query';
    switch (index) {
      case 0:
        context.go('/$suffix');
        break;
      case 1:
        context.go('/sync$suffix');
        break;
      case 2:
        context.go('/agenda$suffix');
        break;
      case 3:
        context.go('/events$suffix');
        break;
      case 4:
        context.go('/settings$suffix');
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
            label: 'Eventos',
            icon: Icon(Icons.campaign_outlined),
            activeIcon: Icon(Icons.campaign),
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
