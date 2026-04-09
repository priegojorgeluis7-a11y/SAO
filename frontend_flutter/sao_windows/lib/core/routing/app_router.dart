// lib/core/routing/app_router.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../features/home/home_page.dart';
import '../../features/home/completed_synced_activities_page.dart';
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
import '../constants.dart';
import '../../features/projects/projects_page.dart';
import '../../features/tutorial/tutorial_mode_page.dart';
import '../../ui/bootstrap/catalog_bootstrap_screen.dart';
import '../../features/admin/history/admin_activity_history_page.dart';
import '../../features/admin/admin_activity_detail.dart';
import '../../features/admin/stats/admin_activity_stats_page.dart';
import '../../features/profile/profile_page.dart';
import '../../ui/theme/sao_colors.dart';
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
              final normalizedProject = projectCode.trim().toUpperCase();
              final isTutorialGuest = state.uri.queryParameters['tutorial'] == '1';

              if (isTutorialGuest) {
                return NoTransitionPage(
                  child: HomePage(
                    selectedProject: normalizedProject,
                    onTapProject: () async {
                      final selected = await context.push<String>(
                        '/projects?selected=${Uri.encodeQueryComponent(normalizedProject)}&tutorial=1',
                      );
                      if (!context.mounted || selected == null || selected.trim().isEmpty) {
                        return;
                      }
                      final normalized = selected.trim().toUpperCase();
                      if (normalized == normalizedProject) {
                        return;
                      }
                      context.go('/?project=${Uri.encodeQueryComponent(normalized)}&tutorial=1');
                    },
                  ),
                );
              }

              if (normalizedProject == kAllProjects) {
                return NoTransitionPage(
                  child: HomePage(
                    selectedProject: normalizedProject,
                    onTapProject: () async {
                      final selected = await context.push<String>(
                        '/projects?selected=${Uri.encodeQueryComponent(normalizedProject)}',
                      );
                      if (!context.mounted || selected == null || selected.trim().isEmpty) {
                        return;
                      }
                      final normalized = selected.trim().toUpperCase();
                      if (normalized == normalizedProject) {
                        return;
                      }
                      context.go('/?project=${Uri.encodeQueryComponent(normalized)}');
                    },
                  ),
                );
              }

              return NoTransitionPage(
                child: CatalogBootstrapScreen(
                  projectId: normalizedProject,
                  childWhenReady: HomePage(
                    selectedProject: normalizedProject,
                    onTapProject: () async {
                      final selected = await context.push<String>(
                        '/projects?selected=${Uri.encodeQueryComponent(normalizedProject)}',
                      );
                      if (!context.mounted || selected == null || selected.trim().isEmpty) {
                        return;
                      }
                      final normalized = selected.trim().toUpperCase();
                      if (normalized == normalizedProject) {
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
            path: '/settings',
            name: 'settings',
            pageBuilder: (context, state) {
              return const NoTransitionPage(
                child: SettingsPage(),
              );
            },
          ),
          GoRoute(
            path: '/history/completed',
            name: 'history-completed',
            pageBuilder: (context, state) {
              final projectCode = state.uri.queryParameters['project'] ?? 'TMQ';
              return NoTransitionPage(
                child: CompletedSyncedActivitiesPage(
                  selectedProject: projectCode.trim().toUpperCase(),
                ),
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

          final activity = state.extra as TodayActivity? ??
              TodayActivity(
                id: activityId,
                title: '',
                frente: '',
                municipio: '',
                estado: '',
                status: ActivityStatus.hoy,
                createdAt: DateTime.now(),
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
                createdAt: DateTime.now(),
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
            createdAt: DateTime.now(),
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
      GoRoute(
        path: '/admin/history',
        name: 'admin-history',
        builder: (context, state) => const AdminActivityHistoryPage(),
      ),
      GoRoute(
        path: '/admin/history/:activityId',
        name: 'admin-history-detail',
        builder: (context, state) {
          final activityId = state.pathParameters['activityId'] ?? '';
          final projectCode = (state.uri.queryParameters['project'] ?? '').trim().toUpperCase();
          return AdminActivityDetailPage(
            activityId: activityId,
            projectCode: projectCode,
          );
        },
      ),
      GoRoute(
        path: '/admin/activity-history',
        redirect: (context, state) => '/admin/history',
      ),
      GoRoute(
        path: '/admin/stats',
        name: 'admin-stats',
        builder: (context, state) => const AdminActivityStatsPage(),
      ),
      GoRoute(
        path: '/profile',
        name: 'profile',
        builder: (context, state) => const ProfilePage(),
      ),
      GoRoute(
        path: '/home/completed',
        redirect: (context, state) {
          final query = state.uri.query;
          return query.isEmpty ? '/history/completed' : '/history/completed?$query';
        },
      ),
      GoRoute(
        path: '/events',
        redirect: (context, state) {
          final query = state.uri.query;
          return query.isEmpty ? '/' : '/?$query';
        },
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

  int _calculateSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    if (location.startsWith('/sync')) return 1;
    if (location.startsWith('/agenda')) return 2;
    if (location.startsWith('/history')) return 3;
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
        context.go('/history/completed$suffix');
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
        selectedItemColor: SaoColors.brandPrimary,
        unselectedItemColor: SaoColors.gray500,
        selectedFontSize: 11,
        unselectedFontSize: 11,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700),
        items: const [
          BottomNavigationBarItem(
            label: 'Inicio',
            icon: _NavItemIcon(icon: Icons.home_outlined),
            activeIcon: _NavItemIcon(icon: Icons.home, active: true),
          ),
          BottomNavigationBarItem(
            label: 'Sincro',
            icon: _NavItemIcon(icon: Icons.sync_outlined),
            activeIcon: _NavItemIcon(icon: Icons.sync, active: true),
          ),
          BottomNavigationBarItem(
            label: 'Agenda',
            icon: _NavItemIcon(icon: Icons.calendar_today_outlined),
            activeIcon: _NavItemIcon(icon: Icons.calendar_today, active: true),
          ),
          BottomNavigationBarItem(
            label: 'Historial',
            icon: _NavItemIcon(icon: Icons.history_outlined),
            activeIcon: _NavItemIcon(icon: Icons.history, active: true),
          ),
          BottomNavigationBarItem(
            label: 'Ajustes',
            icon: _NavItemIcon(icon: Icons.settings_outlined),
            activeIcon: _NavItemIcon(icon: Icons.settings, active: true),
          ),
        ],
      ),
    );
  }
}

class _NavItemIcon extends StatelessWidget {
  final IconData icon;
  final bool active;

  const _NavItemIcon({
    required this.icon,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      // Active layout uses 3 + 4 + 24 = 31px, keep one extra pixel to avoid
      // RenderFlex overflow on high-density Android devices.
      height: active ? 31 : 24,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (active)
            Container(
              width: 18,
              height: 3,
              decoration: BoxDecoration(
                color: SaoColors.brandPrimary,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          if (active) const SizedBox(height: 4),
          Icon(icon),
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
