import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../features/dashboard/dashboard_page.dart';
import '../features/operations/validation_page_new_design.dart'; // 🎯 NUEVO DISEÑO UX con tarjetas inteligentes
import '../features/planning/planning_page.dart';
import '../features/catalogs/catalogs_page.dart';
import '../features/users/users_page.dart';
import '../features/reports/reports_page.dart';
import '../features/ui_catalog/ui_catalog_page.dart'; // 🎨 UI Catalog
import '../core/theme/app_colors.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 1; // Empezar en Operaciones/Validación

  final List<_NavItem> _navItems = [
    _NavItem(
      icon: Icons.dashboard_rounded,
      label: 'Dashboard',
      page: const DashboardPage(),
    ),
    _NavItem(
      icon: Icons.railway_alert,  // 🎯 Ícono más apropiado para operaciones ferroviarias
      label: 'Operaciones',
      page: const ValidationPageNewDesign(), // 🎯 NUEVO DISEÑO UX con tarjetas inteligentes
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
      icon: Icons.description_rounded,
      label: 'Reportes',
      page: const ReportsPage(),
    ),
    _NavItem(
      icon: Icons.palette_rounded,
      label: 'Catálogo de Diseño',
      page: const UiCatalogPage(),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Navigation Rail
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) {
              setState(() => _selectedIndex = index);
            },
            labelType: NavigationRailLabelType.all,
            destinations: _navItems.map((item) {
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
                        _navItems[_selectedIndex].label,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.sync_rounded),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Sincronización iniciada'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        tooltip: 'Sincronizar',
                      ),
                      const SizedBox(width: 8),
                      const CircleAvatar(
                        backgroundColor: AppColors.primary,
                        child: Icon(Icons.person, color: AppColors.onPrimary),
                      ),
                      const SizedBox(width: 12),
                      const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Usuario Admin',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'Coordinador',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.gray500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Page Content
                Expanded(
                  child: _navItems[_selectedIndex].page,
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
