// lib/core/navigation/shell.dart
import 'package:flutter/material.dart';

import '../../features/home/home_page.dart';
import '../../features/sync/sync_center_page.dart';

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _index = 0;

  // ✅ Estado global (luego lo conectas a Drift/User prefs)
  final String _selectedProject = 'TMQ';

  // ✅ Mock: luego lo conectamos a Drift (vencidas, urgentes, sync pendientes)
  final int urgentCount = 1;

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomePage(
        selectedProject: _selectedProject,
        onTapProject: () {}, // Sin funcionalidad de proyectos
      ),
      const SyncCenterPage(), // 🔄 Sincronización
      const _SettingsPage(),
    ];

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
              color: const Color(0xFFD32F2F),
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

class _SettingsPage extends StatelessWidget {
  const _SettingsPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Ajustes (placeholder)',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
        ),
      ),
    );
  }
}
