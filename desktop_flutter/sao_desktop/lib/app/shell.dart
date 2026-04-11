import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/dashboard/dashboard_page.dart';
import '../features/digital_records/digital_records_page.dart';
import '../features/operations/operations_hub_page.dart';
import '../features/planning/planning_page.dart';
import '../features/profile/profile_settings_page.dart';
import '../features/structure/structure_page.dart';
import '../features/ui_catalog/ui_catalog_page.dart';
import '../core/providers/app_refresh_provider.dart';
import '../core/theme/app_colors.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _selectedIndex = 2; // Start on Operations
  int _refreshToken = 0;

  List<_NavItem> get _navItems {
    final items = [
      _NavItem(
        icon: Icons.grid_view_rounded,
        label: 'Dashboard',
        page: const DashboardPage(),
      ),
      _NavItem(
        icon: Icons.calendar_month_rounded,
        label: 'Planeación',
        page: const PlanningPage(),
      ),
      _NavItem(
        icon: Icons.rule_folder_rounded,
        label: 'Operaciones',
        page: const OperationsHubPage(),
      ),
      _NavItem(
        icon: Icons.account_tree_rounded,
        label: 'Estructura',
        page: const StructurePage(),
      ),
      _NavItem(
        icon: Icons.folder_copy_rounded,
        label: 'Expediente digital',
        page: const DigitalRecordsPage(),
      ),
      if (kDebugMode)
        _NavItem(
          icon: Icons.palette_rounded,
          label: 'UI Catalog',
          page: const UiCatalogPage(),
        ),
      _NavItem(
        icon: Icons.person_rounded,
        label: 'Configuración',
        page: const ProfileSettingsPage(),
      ),
    ];
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final appRefreshToken = ref.watch(appRefreshTokenProvider);
    final navItems = _navItems;
    final safeIndex = _selectedIndex.clamp(0, navItems.length - 1);

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.f5): () {
          if (!mounted) return;
          setState(() => _refreshToken++);
        },
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          body: Row(
            children: [
              // ── Sidebar custom ─────────────────────────────────────────
              _SideNav(
                selectedIndex: safeIndex,
                items: navItems,
                onSelect: (i) => setState(() => _selectedIndex = i),
              ),

              const VerticalDivider(thickness: 1, width: 1),

              // ── Contenido principal ────────────────────────────────────
              Expanded(
                child: KeyedSubtree(
                  key: ValueKey(
                      'page-$safeIndex-$_refreshToken-$appRefreshToken'),
                  child: navItems[safeIndex].page,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Color de acento de la barra activa (teal del logo) ─────────────────────
const _kNavAccent = Color(0xFF104848); // teal oscuro del logo
const _kNavAccentDark = Color(0xFF5EEAD4); // teal claro para dark mode

// ── Sidebar ────────────────────────────────────────────────────────────────

class _SideNav extends StatelessWidget {
  final int selectedIndex;
  final List<_NavItem> items;
  final ValueChanged<int> onSelect;

  const _SideNav({
    required this.selectedIndex,
    required this.items,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: 86,
      color: cs.surface,
      child: Column(
        children: [
          // ── Logo (sin texto "SAO" — el icono habla por sí solo) ───────
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 24, 0, 20),
            child: Image.asset(
              'assets/images/logo_tren.png',
              width: 50,
              height: 50,
              fit: BoxFit.contain,
              color: isDark ? Colors.white : null,
              colorBlendMode: isDark ? BlendMode.srcIn : null,
            ),
          ),
          Divider(
              height: 1, thickness: 1, color: Theme.of(context).dividerColor),
          const SizedBox(height: 4),
          // ── Items ─────────────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: items.asMap().entries.map((e) {
                  return _NavTile(
                    icon: e.value.icon,
                    label: e.value.label,
                    selected: e.key == selectedIndex,
                    onTap: () => onSelect(e.key),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

class _NavTile extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_NavTile> createState() => _NavTileState();
}

class _NavTileState extends State<_NavTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? _kNavAccentDark : _kNavAccent;

    final Color iconColor;
    final Color labelColor;
    final Color bgColor;
    final Color barColor;

    if (widget.selected) {
      iconColor = accent;
      labelColor = accent;
      bgColor = accent.withValues(alpha: isDark ? 0.14 : 0.09);
      barColor = accent;
    } else if (_hovered) {
      iconColor = isDark ? const Color(0xFFCBD5E1) : AppColors.gray700;
      labelColor = isDark ? const Color(0xFFCBD5E1) : AppColors.gray700;
      bgColor =
          isDark ? Colors.white.withValues(alpha: 0.05) : AppColors.gray100;
      barColor = Colors.transparent;
    } else {
      iconColor = isDark ? const Color(0xFF64748B) : AppColors.gray400;
      labelColor = isDark ? const Color(0xFF64748B) : AppColors.gray500;
      bgColor = Colors.transparent;
      barColor = Colors.transparent;
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        // ── Row: barra izquierda (3px fija) + contenido con bg redondeado
        child: Row(
          children: [
            // Barra indicadora — siempre 3px, solo colorea cuando activo
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 3,
              height: 58, // cubre el área del tile
              decoration: BoxDecoration(
                color: barColor,
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(3),
                  bottomRight: Radius.circular(3),
                ),
              ),
            ),
            // Contenido con fondo de esquinas derechas redondeadas
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeOut,
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(8),
                      bottomRight: Radius.circular(8),
                      topLeft: Radius.circular(6),
                      bottomLeft: Radius.circular(6),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(widget.icon, size: 22, color: iconColor),
                      const SizedBox(height: 4),
                      Text(
                        widget.label,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: widget.selected
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: labelColor,
                          height: 1.2,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Model ──────────────────────────────────────────────────────────────────

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
