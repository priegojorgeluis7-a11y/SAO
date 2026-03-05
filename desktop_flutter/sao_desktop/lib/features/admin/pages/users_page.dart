import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/session_controller.dart';
import '../data/admin_repositories.dart';

class AdminUsersPage extends ConsumerStatefulWidget {
  const AdminUsersPage({super.key});

  @override
  ConsumerState<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends ConsumerState<AdminUsersPage> {
  List<AdminUserItem> _users = const [];
  bool _loading = true;
  String? _error;
  String _roleFilter = '';

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadUsers);
  }

  Future<void> _loadUsers() async {
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
      final data = await ref.read(usersRepositoryProvider).list(
            token,
            role: _roleFilter.isEmpty ? null : _roleFilter,
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _users = data;
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
    final emailController = TextEditingController();
    final nameController = TextEditingController();
    final passwordController = TextEditingController();
    final projectController = TextEditingController();
    String role = 'SUPERVISOR';

    final created = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Nuevo usuario'),
              content: SizedBox(
                width: 460,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(controller: emailController, decoration: const InputDecoration(labelText: 'Correo')),
                    const SizedBox(height: 8),
                    TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Nombre completo')),
                    const SizedBox(height: 8),
                    TextField(controller: passwordController, decoration: const InputDecoration(labelText: 'Contraseña inicial')),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: role,
                      items: const [
                        DropdownMenuItem(value: 'ADMIN', child: Text('ADMIN')),
                        DropdownMenuItem(value: 'SUPERVISOR', child: Text('SUPERVISOR')),
                        DropdownMenuItem(value: 'OPERATIVO', child: Text('OPERATIVO')),
                        DropdownMenuItem(value: 'LECTOR', child: Text('LECTOR')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => role = value);
                        }
                      },
                      decoration: const InputDecoration(labelText: 'Rol'),
                    ),
                    const SizedBox(height: 8),
                    TextField(controller: projectController, decoration: const InputDecoration(labelText: 'Proyecto (opcional)')),
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
      await ref.read(usersRepositoryProvider).create(
            token,
            email: emailController.text.trim(),
            fullName: nameController.text.trim(),
            password: passwordController.text,
            role: role,
            projectId: projectController.text.trim().isEmpty ? null : projectController.text.trim(),
          );
      await _loadUsers();
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
      return Center(child: Text('No se pudo cargar usuarios: $_error'));
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              const Text('Usuarios', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(width: 12),
              SizedBox(
                width: 200,
                child: DropdownButtonFormField<String>(
                  initialValue: _roleFilter.isEmpty ? 'ALL' : _roleFilter,
                  items: const [
                    DropdownMenuItem(value: 'ALL', child: Text('Todos los roles')),
                    DropdownMenuItem(value: 'ADMIN', child: Text('ADMIN')),
                    DropdownMenuItem(value: 'SUPERVISOR', child: Text('SUPERVISOR')),
                    DropdownMenuItem(value: 'OPERATIVO', child: Text('OPERATIVO')),
                    DropdownMenuItem(value: 'LECTOR', child: Text('LECTOR')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _roleFilter = value == null || value == 'ALL' ? '' : value;
                    });
                    _loadUsers();
                  },
                  decoration: const InputDecoration(labelText: 'Filtro rol'),
                ),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _openCreateDialog,
                icon: const Icon(Icons.person_add),
                label: const Text('Nuevo usuario'),
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
                    DataColumn(label: Text('Nombre')),
                    DataColumn(label: Text('Correo')),
                    DataColumn(label: Text('Rol')),
                    DataColumn(label: Text('Proyecto')),
                    DataColumn(label: Text('Estado')),
                  ],
                  rows: _users
                      .map(
                        (user) => DataRow(
                          cells: [
                            DataCell(Text(user.fullName)),
                            DataCell(Text(user.email)),
                            DataCell(Text(user.roleName)),
                            DataCell(Text(user.projectId ?? '-')),
                            DataCell(Text(user.status)),
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
