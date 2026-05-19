import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/projects_repository.dart';
import '../../ui/theme/sao_colors.dart';

class ProjectItem {
  final String code;     // TMQ
  final String name;     // Tren México–Querétaro
  final bool isActive;

  const ProjectItem({
    required this.code,
    required this.name,
    required this.isActive,
  });
}

class ProjectsPage extends ConsumerStatefulWidget {
  const ProjectsPage({
    super.key,
    required this.selectedCode,
  });

  final String selectedCode;

  @override
  ConsumerState<ProjectsPage> createState() => _ProjectsPageState();
}

class _ProjectsPageState extends ConsumerState<ProjectsPage> {
  static const _hiddenTemplateProjectCodes = {'PROJECT_0', 'P0'};

  List<ProjectItem> _projects = const [];
  bool _loading = true;
  String? _loadError;
  String _query = '';

  @override
  void initState() {
    super.initState();
    final initialCode = widget.selectedCode.trim().toUpperCase();
    if (initialCode.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(projectSelectionControllerProvider).setActiveProject(initialCode);
      });
    } else {
      // If no project is specified, resolve to the first available project after loading
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _selectFirstProjectIfAvailable();
      });
    }
    _loadProjects();
  }

  Future<void> _selectFirstProjectIfAvailable() async {
    if (!mounted || widget.selectedCode.trim().isNotEmpty) return;
    try {
      final projects = await ref.read(allProjectsProvider.future);
      if (!mounted || projects.isEmpty) return;
      
      final firstProject = projects[0].code.trim().toUpperCase();
      if (firstProject.isNotEmpty) {
        ref.read(projectSelectionControllerProvider).setActiveProject(firstProject);
      }
    } catch (e) {
      // Silently fail; user can select a project manually
    }
  }

  Future<void> _loadProjects() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });

    try {
      final scopedProjects = await ref.read(allProjectsProvider.future);
      if (!mounted) return;
      setState(() {
        _projects = scopedProjects
            .where((item) => !_isHiddenTemplateProject(item.code))
            .map(
              (item) => ProjectItem(
                code: item.code.trim().toUpperCase(),
                name: item.name.trim().isEmpty ? item.code : item.name.trim(),
                isActive: item.isActive,
              ),
            )
            .toList()
          ..sort((a, b) => a.code.compareTo(b.code));
        if (_projects.isEmpty) {
          _loadError = 'No tienes proyectos asignados. Contacta a tu administrador.';
        }
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = 'No se pudo cargar la lista de proyectos. Verifica tu conexión.';
      });
    }
  }

  bool _isHiddenTemplateProject(String? projectId) {
    final normalized = (projectId ?? '').trim().toUpperCase();
    return _hiddenTemplateProjectCodes.contains(normalized);
  }

  List<ProjectItem> get _filtered {
    final q = _query.trim().toLowerCase();
    final base = <ProjectItem>[..._projects];
    if (q.isEmpty) return base;
    return base.where((p) {
      return p.code.toLowerCase().contains(q) || p.name.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final items = _filtered;

    return Scaffold(
      backgroundColor: SaoColors.gray50,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text(
          'Proyectos',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: Column(
        children: [
          if (_loadError != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: SaoColors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: SaoColors.warning.withValues(alpha: 0.28)),
                ),
                child: Text(
                  _loadError!,
                  style: const TextStyle(
                    color: SaoColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          // buscador
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: SaoColors.gray100,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: SaoColors.gray200),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  const Icon(Icons.search_rounded, color: SaoColors.statusBorrador),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      onChanged: (v) => setState(() => _query = v),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Buscar TMQ, TAP… o nombre',
                        hintStyle: TextStyle(color: SaoColors.gray400),
                      ),
                    ),
                  ),
                  if (_query.isNotEmpty)
                    IconButton(
                      tooltip: 'Limpiar',
                      onPressed: () => setState(() => _query = ''),
                      icon: const Icon(Icons.close_rounded, color: SaoColors.statusBorrador),
                    ),
                ],
              ),
            ),
          ),

          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : items.isEmpty
                ? const Center(
                    child: Text(
                      'Sin resultados',
                      style: TextStyle(color: SaoColors.statusBorrador),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
                    itemCount: items.length,
                    itemBuilder: (context, i) {
                      final p = items[i];
                      final selected = p.code == widget.selectedCode;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Material(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () {
                              ref.read(projectSelectionControllerProvider).setActiveProject(p.code);
                              Navigator.pop(context, p.code);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: SaoColors.gray200),
                                boxShadow: const [
                                  BoxShadow(
                                    blurRadius: 10,
                                    offset: Offset(0, 4),
                                    color: Color(0x0A000000),
                                  )
                                ],
                              ),
                              child: Row(
                                children: [
                                  // badge code
                                  Container(
                                    width: 54,
                                    height: 44,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: SaoColors.gray100,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: SaoColors.gray200),
                                    ),
                                    child: Text(
                                      p.code,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        color: SaoColors.primary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),

                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          p.name,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w900,
                                            color: SaoColors.primary,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            _Chip(
                                              text: p.isActive ? 'Activo' : 'Inactivo',
                                              color: p.isActive
                                                  ? SaoColors.success
                                                  : SaoColors.gray400,
                                            ),
                                            const SizedBox(width: 8),
                                            if (selected)
                                              const _Chip(
                                                text: 'Seleccionado',
                                                color: SaoColors.gray900,
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),

                                  const Icon(Icons.chevron_right_rounded, color: SaoColors.gray400),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;
  final Color color;

  const _Chip({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}
