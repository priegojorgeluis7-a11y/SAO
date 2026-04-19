// lib/core/navigation/shell.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/di/service_locator.dart';
import '../../data/local/app_db.dart';
import '../../features/home/home_page.dart';
import '../../features/settings/settings_page.dart';
import '../../ui/theme/sao_colors.dart';
import '../../features/sync/sync_center_page.dart';

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _index = 0;
  String _selectedProject = 'TMQ';
  late final AppDb _db;

  @override
  void initState() {
    super.initState();
    _db = getIt<AppDb>();
    _loadSelectedProject();
  }

  Future<void> _loadSelectedProject() async {
    if (!getIt.isRegistered<SharedPreferences>()) return;
    final prefs = getIt<SharedPreferences>();
    final stored = (prefs.getString('selected_project') ?? '').trim().toUpperCase();
    if (stored.isNotEmpty && mounted) {
      setState(() => _selectedProject = stored);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomePage(
        selectedProject: _selectedProject,
        onTapProject: _loadSelectedProject,
      ),
      const SyncCenterPage(),
      const SettingsPage(),
    ];

    return StreamBuilder<List<SyncQueueData>>(
      stream: (_db.select(_db.syncQueue)
            ..where((s) => s.status.isIn(const ['PENDING', 'IN_PROGRESS', 'ERROR'])))
          .watch(),
      builder: (context, snapshot) {
        final urgentCount = snapshot.data?.length ?? 0;

        return Scaffold(
          body: IndexedStack(
            index: _index,
            children: pages,
          ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _index,
            onTap: (i) => setState(() => _index = i),
            type: BottomNavigationBarType.fixed,
            showUnselectedLabels: true,
            items: [
              BottomNavigationBarItem(
                label: 'Inicio',
                icon: _Badge(
                  show: urgentCount > 0,
                  child: const Icon(Icons.home_outlined),
                ),
                activeIcon: _Badge(
                  show: urgentCount > 0,
                  child: const Icon(Icons.home),
                ),
              ),
              const BottomNavigationBarItem(
                label: 'Sincronizar',
                icon: Icon(Icons.sync_outlined),
                activeIcon: Icon(Icons.sync),
              ),
              const BottomNavigationBarItem(
                label: 'Ajustes',
                icon: Icon(Icons.settings_outlined),
                activeIcon: Icon(Icons.settings),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Badge extends StatelessWidget {
  final Widget child;
  final bool show;

  const _Badge({required this.child, required this.show});

  @override
  Widget build(BuildContext context) {
    if (!show) return child;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          right: -2,
          top: -2,
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: SaoColors.riskPriority,
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

