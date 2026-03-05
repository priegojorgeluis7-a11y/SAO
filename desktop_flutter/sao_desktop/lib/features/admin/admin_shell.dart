import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';

import 'auth/session_controller.dart';
import 'data/admin_repositories.dart';
import 'pages/audit_page.dart';
import 'pages/dashboard_page.dart';
import 'pages/projects_page.dart';
import 'pages/settings_page.dart';
import 'pages/users_page.dart';

class AdminShell extends ConsumerStatefulWidget {
  const AdminShell({super.key});

  @override
  ConsumerState<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends ConsumerState<AdminShell> {
  int _selectedIndex = 0;
  String _selectedProject = 'ALL';
  int _refreshToken = 0;

  List<_NavItem> get _items => const [
        _NavItem(icon: Icons.dashboard, label: 'Dashboard', page: AdminDashboardPage()),
        _NavItem(icon: Icons.apartment, label: 'Projects', page: AdminProjectsPage()),
        _NavItem(icon: Icons.people, label: 'Users', page: AdminUsersPage()),
        _NavItem(icon: Icons.fact_check, label: 'Audit', page: AdminAuditPage()),
        _NavItem(icon: Icons.settings, label: 'Settings', page: AdminSettingsPage()),
      ];

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionControllerProvider);

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
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) => setState(() => _selectedIndex = index),
            labelType: NavigationRailLabelType.all,
            leading: const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('SAO', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            ),
            destinations: _items
                .map((item) => NavigationRailDestination(icon: Icon(item.icon), label: Text(item.label)))
                .toList(),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: Column(
              children: [
                Container(
                  height: 64,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    border: Border(bottom: BorderSide(color: AppColors.border)),
                  ),
                  child: Row(
                    children: [
                      Text(_items[_selectedIndex].label, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Actualizar vista',
                        onPressed: () => setState(() => _refreshToken++),
                        icon: const Icon(Icons.refresh),
                      ),
                      _ProjectSelector(
                        selectedProject: _selectedProject,
                        onChanged: (value) => setState(() => _selectedProject = value),
                      ),
                      const SizedBox(width: 16),
                      Text(session.user?.fullName ?? ''),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Cerrar sesión',
                        onPressed: () => ref.read(sessionControllerProvider.notifier).logout(),
                        icon: const Icon(Icons.logout),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: KeyedSubtree(
                    key: ValueKey('admin-page-$_selectedIndex-$_refreshToken'),
                    child: _items[_selectedIndex].page,
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
}

class _ProjectSelector extends ConsumerStatefulWidget {
  const _ProjectSelector({required this.selectedProject, required this.onChanged});

  final String selectedProject;
  final ValueChanged<String> onChanged;

  @override
  ConsumerState<_ProjectSelector> createState() => _ProjectSelectorState();
}

class _ProjectSelectorState extends ConsumerState<_ProjectSelector> {
  List<AdminProject> _projects = const [];

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadProjects);
  }

  Future<void> _loadProjects() async {
    final token = ref.read(sessionControllerProvider).accessToken;
    if (token == null) {
      return;
    }
    try {
      final projects = await ref.read(projectsRepositoryProvider).list(token);
      if (!mounted) {
        return;
      }
      setState(() => _projects = projects);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final values = <String>['ALL', ..._projects.map((e) => e.id)];
    final selected = values.contains(widget.selectedProject) ? widget.selectedProject : 'ALL';

    return SizedBox(
      width: 180,
      child: DropdownButtonFormField<String>(
        initialValue: selected,
        items: values
            .map((value) => DropdownMenuItem(
                  value: value,
                  child: Text(value == 'ALL' ? 'Todos los proyectos' : value),
                ))
            .toList(),
        onChanged: (value) {
          if (value != null) {
            widget.onChanged(value);
          }
        },
        decoration: const InputDecoration(labelText: 'Proyecto', border: OutlineInputBorder()),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  final Widget page;

  const _NavItem({required this.icon, required this.label, required this.page});
}
