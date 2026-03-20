import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../core/di/service_locator.dart';
import '../../core/network/api_client.dart';
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

class MyProjectItem {
  final String projectId;
  final String projectName;
  final List<String> roleNames;

  const MyProjectItem({
    required this.projectId,
    required this.projectName,
    required this.roleNames,
  });
}

class ProjectsPage extends StatefulWidget {
  const ProjectsPage({
    super.key,
    required this.selectedCode,
  });

  final String selectedCode;

  @override
  State<ProjectsPage> createState() => _ProjectsPageState();
}

class _ProjectsPageState extends State<ProjectsPage> {
  static const _hiddenTemplateProjectCodes = {'PROJECT_0', 'P0'};

  static const _allProjectsItem = ProjectItem(
    code: kAllProjects,
    name: 'Todos los proyectos',
    isActive: true,
  );

  static const _fallbackProjects = <ProjectItem>[
    ProjectItem(code: 'TMQ', name: 'Tren México–Querétaro', isActive: true),
    ProjectItem(code: 'TAP', name: 'Tren AIFA–Pachuca', isActive: true),
  ];

  final ApiClient _apiClient = getIt<ApiClient>();

  List<ProjectItem> _projects = const [];
  bool _loading = true;
  String? _loadError;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });

    try {
      final scopedProjects = await _fetchMyProjects();
      if (scopedProjects.isEmpty) {
        throw StateError('Lista vacia en /me/projects, intentando /projects');
      }
      if (!mounted) return;
      setState(() {
        _projects = scopedProjects
            .where((item) => !_isHiddenTemplateProject(item.projectId))
            .map(
              (item) => ProjectItem(
                code: item.projectId,
                name: item.projectName,
                isActive: true,
              ),
            )
            .toList()
          ..sort((a, b) => a.code.compareTo(b.code));
        _loading = false;
      });
      return;
    } catch (_) {
      // Fallback to legacy endpoints when /me/projects is unavailable.
    }

    try {
      final response = await _apiClient.get<dynamic>('/projects');
      final data = response.data;
      if (data is! List) {
        throw StateError('Respuesta inválida de /projects');
      }

      final remote = data
          .whereType<Map<String, dynamic>>()
          .map((raw) {
            final map = Map<String, dynamic>.from(raw);
            final code = (map['id'] ?? '').toString().trim().toUpperCase();
            if (code.isEmpty) return null;
            if (_isHiddenTemplateProject(code)) return null;
            final name = (map['name'] ?? code).toString().trim();
            final status = (map['status'] ?? '').toString().toLowerCase();
            return ProjectItem(
              code: code,
              name: name.isEmpty ? code : name,
              isActive: status != 'inactive' && status != 'archived' && status != 'cancelled',
            );
          })
          .whereType<ProjectItem>()
          .toList()
        ..sort((a, b) => a.code.compareTo(b.code));

      if (!mounted) return;
      setState(() {
        _projects = remote.isEmpty ? _fallbackProjects : remote;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _projects = _fallbackProjects;
        _loading = false;
        _loadError = 'No se pudo cargar /me/projects ni /projects. Mostrando lista local.';
      });
    }
  }

  Future<List<MyProjectItem>> _fetchMyProjects() async {
    final response = await _apiClient.get<dynamic>('/me/projects');
    final data = response.data;
    if (data is! List) {
      throw StateError('Respuesta inválida de /me/projects');
    }

    return data
        .whereType<Map<String, dynamic>>()
        .map((raw) {
          final map = Map<String, dynamic>.from(raw);
          final projectId = (map['project_id'] ?? '').toString().trim().toUpperCase();
          if (projectId.isEmpty) return null;
          if (_isHiddenTemplateProject(projectId)) return null;
          final projectName = (map['project_name'] ?? projectId).toString().trim();
          final roleNames = (map['role_names'] is List)
              ? (map['role_names'] as List<dynamic>)
                  .map((role) => role.toString().trim().toUpperCase())
                  .where((role) => role.isNotEmpty)
                  .toList(growable: false)
              : const <String>[];
          return MyProjectItem(
            projectId: projectId,
            projectName: projectName.isEmpty ? projectId : projectName,
            roleNames: roleNames,
          );
        })
        .whereType<MyProjectItem>()
        .toList(growable: false);
  }

  bool _isHiddenTemplateProject(String? projectId) {
    final normalized = (projectId ?? '').trim().toUpperCase();
    return _hiddenTemplateProjectCodes.contains(normalized);
  }

  List<ProjectItem> get _filtered {
    final q = _query.trim().toLowerCase();
    final base = <ProjectItem>[_allProjectsItem, ..._projects];
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
                              // ✅ Regresa el proyecto seleccionado al Shell/Home
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
