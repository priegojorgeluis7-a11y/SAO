import 'package:flutter/material.dart';

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
  static const _projects = <ProjectItem>[
    ProjectItem(code: 'TMQ', name: 'Tren México–Querétaro', isActive: true),
    ProjectItem(code: 'TAP', name: 'Tren AIFA–Pachuca', isActive: true),
    ProjectItem(code: 'QIR', name: 'Tren Querétaro–Irapuato', isActive: true),
    ProjectItem(code: 'SNL', name: 'Tren Saltillo–Nuevo Laredo', isActive: true),
  ];

  String _query = '';

  List<ProjectItem> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _projects;
    return _projects.where((p) {
      return p.code.toLowerCase().contains(q) || p.name.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final items = _filtered;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
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
          // buscador
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  const Icon(Icons.search_rounded, color: Color(0xFF6B7280)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      onChanged: (v) => setState(() => _query = v),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Buscar TMQ, TAP… o nombre',
                        hintStyle: TextStyle(color: Color(0xFF9CA3AF)),
                      ),
                    ),
                  ),
                  if (_query.isNotEmpty)
                    IconButton(
                      tooltip: 'Limpiar',
                      onPressed: () => setState(() => _query = ''),
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF6B7280)),
                    ),
                ],
              ),
            ),
          ),

          Expanded(
            child: items.isEmpty
                ? const Center(
                    child: Text(
                      'Sin resultados',
                      style: TextStyle(color: Color(0xFF6B7280)),
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
                                border: Border.all(color: const Color(0xFFE5E7EB)),
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
                                      color: const Color(0xFFF3F4F6),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: const Color(0xFFE5E7EB)),
                                    ),
                                    child: Text(
                                      p.code,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFF111827),
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
                                            color: Color(0xFF111827),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            _Chip(
                                              text: p.isActive ? 'Activo' : 'Inactivo',
                                              color: p.isActive
                                                  ? const Color(0xFF10B981)
                                                  : const Color(0xFF94A3B8),
                                            ),
                                            const SizedBox(width: 8),
                                            if (selected)
                                              const _Chip(
                                                text: 'Seleccionado',
                                                color: Color(0xFF0F172A),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),

                                  const Icon(Icons.chevron_right_rounded, color: Color(0xFF9CA3AF)),
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
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.18)),
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
