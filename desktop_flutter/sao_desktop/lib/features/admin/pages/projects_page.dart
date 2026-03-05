import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/session_controller.dart';
import '../data/admin_repositories.dart';

class AdminProjectsPage extends ConsumerStatefulWidget {
  const AdminProjectsPage({super.key});

  @override
  ConsumerState<AdminProjectsPage> createState() => _AdminProjectsPageState();
}

class _AdminProjectsPageState extends ConsumerState<AdminProjectsPage> {
  List<AdminProject> _projects = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadProjects);
  }

  Future<void> _loadProjects() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final token = ref.read(sessionControllerProvider).accessToken;
    if (token == null) {
      setState(() {
        _loading = false;
        _error = 'Sesión no disponible';
      });
      return;
    }

    try {
      final data = await ref.read(projectsRepositoryProvider).list(token);
      if (!mounted) {
        return;
      }
      setState(() {
        _projects = data;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = '$error';
      });
    }
  }

  Future<void> _openCreateDialog() async {
    final idController = TextEditingController();
    final nameController = TextEditingController();
    final startDateController = TextEditingController(text: DateTime.now().toIso8601String().split('T').first);
    final frontsController = TextEditingController(
      text: List.generate(12, (index) => 'Frente ${index + 1}').join('\n'),
    );
    final locationScopeController = TextEditingController(
      text: 'Ciudad de México: Cuauhtémoc\nEstado de México: Tultitlán\nQuerétaro: Querétaro',
    );

    final created = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Nuevo proyecto'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: idController, decoration: const InputDecoration(labelText: 'Código', hintText: 'PRJ001')),
                const SizedBox(height: 8),
                TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Nombre')),
                const SizedBox(height: 8),
                TextField(controller: startDateController, decoration: const InputDecoration(labelText: 'Inicio (YYYY-MM-DD)')),
                const SizedBox(height: 8),
                TextField(
                  controller: frontsController,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'Frentes (uno por línea)',
                    hintText: 'Frente 1\\nFrente 2\\nFrente 3',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: locationScopeController,
                  minLines: 3,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    labelText: 'Cobertura (Estado: municipio1, municipio2)',
                    hintText: 'Querétaro: Querétaro, San Juan del Río',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Crear')),
          ],
        );
      },
    );

    if (created != true) {
      return;
    }

    final token = ref.read(sessionControllerProvider).accessToken;
    if (token == null) {
      return;
    }

    try {
      final fronts = _parseFronts(frontsController.text);
      final locationScope = _parseLocationScope(locationScopeController.text);
      await ref.read(projectsRepositoryProvider).create(
            token,
            id: idController.text.trim(),
            name: nameController.text.trim(),
            startDate: startDateController.text.trim(),
        fronts: fronts,
        locationScope: locationScope,
          );
      await _loadProjects();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $error')));
    }
  }

  List<Map<String, dynamic>> _parseFronts(String raw) {
    final lines = raw
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    return [
      for (var i = 0; i < lines.length; i++)
        {
          'code': 'F${i + 1}',
          'name': lines[i],
        },
    ];
  }

  List<Map<String, dynamic>> _parseLocationScope(String raw) {
    final entries = <Map<String, dynamic>>[];
    final lines = raw
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    for (final line in lines) {
      final separator = line.indexOf(':');
      if (separator <= 0) continue;
      final estado = line.substring(0, separator).trim();
      final municipiosRaw = line.substring(separator + 1).trim();
      if (estado.isEmpty || municipiosRaw.isEmpty) continue;

      final municipios = municipiosRaw
          .split(',')
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty);

      for (final municipio in municipios) {
        entries.add({'estado': estado, 'municipio': municipio});
      }
    }
    return entries;
  }

  Future<void> _openEditDialog(AdminProject project) async {
    final nameController = TextEditingController(text: project.name);
    final startDateController = TextEditingController(text: project.startDate);
    final endDateController = TextEditingController(text: project.endDate ?? '');
    String status = project.status;

    final updated = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Editar ${project.id}'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Nombre')),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: status,
                      items: const [
                        DropdownMenuItem(value: 'active', child: Text('Activo')),
                        DropdownMenuItem(value: 'archived', child: Text('Archivado')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() {
                            status = value;
                          });
                        }
                      },
                      decoration: const InputDecoration(labelText: 'Estado'),
                    ),
                    const SizedBox(height: 8),
                    TextField(controller: startDateController, decoration: const InputDecoration(labelText: 'Inicio (YYYY-MM-DD)')),
                    const SizedBox(height: 8),
                    TextField(controller: endDateController, decoration: const InputDecoration(labelText: 'Fin (opcional)')),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
                FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Guardar')),
              ],
            );
          },
        );
      },
    );

    if (updated != true) {
      return;
    }

    final token = ref.read(sessionControllerProvider).accessToken;
    if (token == null) {
      return;
    }

    try {
      await ref.read(projectsRepositoryProvider).update(
            token,
            project.id,
            name: nameController.text.trim(),
            status: status,
            startDate: startDateController.text.trim(),
            endDate: endDateController.text.trim().isEmpty ? null : endDateController.text.trim(),
          );
      await _loadProjects();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text('No se pudo cargar proyectos: $_error'));
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              const Text('Proyectos', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const Spacer(),
              FilledButton.icon(
                onPressed: _openCreateDialog,
                icon: const Icon(Icons.add),
                label: const Text('Nuevo proyecto'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Card(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Código')),
                    DataColumn(label: Text('Nombre')),
                    DataColumn(label: Text('Estado')),
                    DataColumn(label: Text('Inicio')),
                    DataColumn(label: Text('Fin')),
                    DataColumn(label: Text('Acciones')),
                  ],
                  rows: _projects
                      .map(
                        (project) => DataRow(
                          cells: [
                            DataCell(Text(project.id)),
                            DataCell(Text(project.name)),
                            DataCell(Text(project.status)),
                            DataCell(Text(project.startDate)),
                            DataCell(Text(project.endDate ?? '-')),
                            DataCell(
                              IconButton(
                                icon: const Icon(Icons.edit),
                                onPressed: () => _openEditDialog(project),
                              ),
                            ),
                          ],
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
