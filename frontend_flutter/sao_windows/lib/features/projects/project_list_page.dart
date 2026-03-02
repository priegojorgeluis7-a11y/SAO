import 'package:flutter/material.dart';

class ProjectListPage extends StatelessWidget {
  final String selectedProject;
  final ValueChanged<String> onSelected;

  const ProjectListPage({
    super.key,
    required this.selectedProject,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    const projects = [
      ('TMQ', 'Tren México–Querétaro'),
      ('TAP', 'Tren AIFA–Pachuca'),
      ('QIR', 'Tren Querétaro–Irapuato'),
      ('SNL', 'Tren Saltillo–Nuevo Laredo'),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Proyectos')),
      body: ListView.separated(
        itemCount: projects.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final code = projects[i].$1;
          final name = projects[i].$2;
          final isSelected = code == selectedProject;

          return ListTile(
            title: Text('$code — $name'),
            trailing: isSelected ? const Icon(Icons.check) : const Icon(Icons.chevron_right),
            onTap: () => onSelected(code),
          );
        },
      ),
    );
  }
}
