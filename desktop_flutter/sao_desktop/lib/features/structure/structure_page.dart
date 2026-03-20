import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/project_providers.dart';
import '../admin/pages/projects_page.dart';
import '../catalogs/catalogs_page.dart';
import '../users/users_page.dart';

class StructurePage extends ConsumerStatefulWidget {
  const StructurePage({super.key});

  @override
  ConsumerState<StructurePage> createState() => _StructurePageState();
}

class _StructurePageState extends ConsumerState<StructurePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _openCatalogForProject(String projectId) {
    final normalizedProjectId = projectId.trim().toUpperCase();
    if (normalizedProjectId.isNotEmpty) {
      ref.read(activeProjectIdProvider.notifier).select(normalizedProjectId);
    }
    _tabController.animateTo(1);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      children: [
        Container(
          color: cs.surface,
          padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: cs.primary,
              unselectedLabelColor: cs.onSurface.withValues(alpha: 0.55),
              indicatorColor: cs.primary,
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(icon: Icon(Icons.domain_rounded, size: 18), text: 'Proyectos'),
                Tab(icon: Icon(Icons.layers_rounded, size: 18), text: 'Catálogos'),
                Tab(icon: Icon(Icons.group_rounded, size: 18), text: 'Usuarios'),
              ],
            ),
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              AdminProjectsPage(onOpenCatalog: _openCatalogForProject),
              const CatalogsPage(),
              const UsersPage(),
            ],
          ),
        ),
      ],
    );
  }
}
