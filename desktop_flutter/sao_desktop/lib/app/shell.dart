import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/dashboard/dashboard_page.dart';
import '../features/operations/validation_page_new_design.dart';
import '../features/planning/planning_page.dart';
import '../features/catalogs/catalogs_page.dart';
import '../features/users/users_page.dart';
import '../features/events/events_page.dart';
import '../features/reports/reports_page.dart';
import '../features/ui_catalog/ui_catalog_page.dart';
import '../features/auth/app_session_controller.dart';
import '../core/theme/app_colors.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _selectedIndex = 1; // Start on Operations
  int _refreshToken = 0;

  List<_NavItem> get _navItems {
    final items = [
      _NavItem(
        icon: Icons.dashboard_rounded,
        label: 'Dashboard',
        page: const DashboardPage(),
      ),
      _NavItem(
        icon: Icons.railway_alert,
        label: 'Operaciones',
        page: const ValidationPageNewDesign(),
      ),
      _NavItem(
        icon: Icons.calendar_month_rounded,
        label: 'Planeación',
        page: const PlanningPage(),
      ),
      _NavItem(
        icon: Icons.category_rounded,
        label: 'Catálogos',
        page: const CatalogsPage(),
      ),
      _NavItem(
        icon: Icons.people_rounded,
        label: 'Usuarios',
        page: const UsersPage(),
      ),
      _NavItem(
        icon: Icons.campaign_rounded,
        label: 'Eventos',
        page: const EventsPage(),
      ),
      _NavItem(
        icon: Icons.description_rounded,
        label: 'Reportes',
        page: const ReportsPage(),
      ),
      // Design system storybook — only in debug builds
      if (kDebugMode)
        _NavItem(
          icon: Icons.palette_rounded,
          label: 'UI Catalog',
          page: const UiCatalogPage(),
        ),
    ];
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentAppUserProvider);
    final navItems = _navItems;

    // Clamp index in case UiCatalog was removed in release builds
    final safeIndex = _selectedIndex.clamp(0, navItems.length - 1);

    return CallbackShortcuts(
      bindings: {
        SingleActivator(LogicalKeyboardKey.f5): () {
          if (!mounted) return;
          setState(() => _refreshToken++);
        },
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          body: Row(
            children: [
          // Navigation Rail
          NavigationRail(
            selectedIndex: safeIndex,
            onDestinationSelected: (index) {
              setState(() => _selectedIndex = index);
            },
            labelType: NavigationRailLabelType.all,
            destinations: navItems.map((item) {
              return NavigationRailDestination(
                icon: Icon(item.icon),
                label: Text(item.label),
              );
            }).toList(),
            leading: const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  Icon(
                    Icons.apartment_rounded,
                    size: 40,
                    color: AppColors.primary,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'SAO',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const VerticalDivider(thickness: 1, width: 1),

          // Main Content
          Expanded(
            child: Column(
              children: [
                // Top Bar
                Container(
                  height: 60,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    border: Border(
                      bottom: BorderSide(color: AppColors.border),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        navItems[safeIndex].label,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.refresh_rounded),
                        tooltip: 'Actualizar vista',
                        onPressed: () {
                          setState(() => _refreshToken++);
                        },
                      ),
                      // User info
                      const CircleAvatar(
                        backgroundColor: AppColors.primary,
                        child: Icon(Icons.person, color: AppColors.onPrimary),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.fullName.isNotEmpty == true
                                ? user!.fullName
                                : (user?.email ?? 'Usuario'),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            user?.role.isNotEmpty == true ? user!.role : 'SAO',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.gray500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 8),
                      // Logout button
                      IconButton(
                        icon: const Icon(Icons.logout_rounded),
                        tooltip: 'Cerrar sesión',
                        onPressed: () => _confirmLogout(context),
                      ),
                    ],
                  ),
                ),

                // Page Content
                Expanded(
                  child: KeyedSubtree(
                    key: ValueKey('page-$safeIndex-$_refreshToken'),
                    child: navItems[safeIndex].page,
                  ),
                ),
              ],
            ),
          ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Estás seguro de que deseas cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    ).then((confirmed) {
      if (confirmed == true && mounted) {
        ref.read(appSessionControllerProvider.notifier).logout();
      }
    });
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  final Widget page;

  _NavItem({
    required this.icon,
    required this.label,
    required this.page,
  });
}
