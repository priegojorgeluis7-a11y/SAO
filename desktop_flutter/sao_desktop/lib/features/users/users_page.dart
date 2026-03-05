import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../data/repositories/backend_api_client.dart';
import '../../ui/theme/sao_colors.dart';

// ---------------------------------------------------------------------------
// Model + Provider
// ---------------------------------------------------------------------------

class _UserRow {
  final String id;
  final String name;
  final String email;
  final String role;
  final String status;

  const _UserRow({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.status,
  });

  factory _UserRow.fromJson(Map<String, dynamic> json) {
    return _UserRow(
      id: (json['id'] ?? '').toString(),
      name: (json['full_name'] ?? json['name'] ?? 'Sin nombre').toString(),
      email: (json['email'] ?? '').toString(),
      role: (json['role_name'] ?? json['role'] ?? '').toString(),
      status: (json['status'] ?? 'active').toString(),
    );
  }
}

final _usersProvider = FutureProvider.autoDispose<List<_UserRow>>((ref) async {
  try {
    final decoded = await const BackendApiClient().getJson('/api/v1/users');
    if (decoded is! List) return [];
    return decoded
        .whereType<Map<String, dynamic>>()
        .map((e) => _UserRow.fromJson(e))
        .toList();
  } catch (_) {
    return [];
  }
});

// ---------------------------------------------------------------------------
// Page
// ---------------------------------------------------------------------------

class UsersPage extends ConsumerStatefulWidget {
  const UsersPage({super.key});

  @override
  ConsumerState<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends ConsumerState<UsersPage> {
  String _roleFilter = 'Todos';

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(_usersProvider);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              const Text(
                'Gestión de Usuarios',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              SizedBox(
                width: 180,
                child: DropdownButtonFormField<String>(
                  value: _roleFilter,
                  decoration: const InputDecoration(
                    labelText: 'Rol',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Todos', child: Text('Todos')),
                    DropdownMenuItem(value: 'ADMIN', child: Text('Admin')),
                    DropdownMenuItem(value: 'COORD', child: Text('Coordinador')),
                    DropdownMenuItem(value: 'SUPERVISOR', child: Text('Supervisor')),
                    DropdownMenuItem(value: 'OPERATIVO', child: Text('Operativo')),
                    DropdownMenuItem(value: 'LECTOR', child: Text('Lector')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _roleFilter = value);
                  },
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'Refrescar',
                onPressed: () => ref.invalidate(_usersProvider),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: usersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: AppColors.error),
                    const SizedBox(height: 8),
                    Text('Error al cargar usuarios: $e'),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => ref.invalidate(_usersProvider),
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
              data: (users) {
                final filtered = _roleFilter == 'Todos'
                    ? users
                    : users
                        .where((u) =>
                            u.role.toUpperCase() == _roleFilter.toUpperCase())
                        .toList();

                if (filtered.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.people_outline, size: 48, color: Colors.grey),
                        SizedBox(height: 8),
                        Text('No se encontraron usuarios'),
                      ],
                    ),
                  );
                }

                return Card(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(12),
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Nombre')),
                        DataColumn(label: Text('Correo')),
                        DataColumn(label: Text('Rol')),
                        DataColumn(label: Text('Estado')),
                      ],
                      rows: filtered
                          .map(
                            (item) => DataRow(cells: [
                              DataCell(Text(item.name)),
                              DataCell(Text(item.email)),
                              DataCell(Text(item.role)),
                              DataCell(
                                Text(
                                  item.status.toLowerCase() == 'active'
                                      ? 'Activo'
                                      : 'Inactivo',
                                  style: TextStyle(
                                    color:
                                        item.status.toLowerCase() == 'active'
                                            ? SaoColors.success
                                            : SaoColors.gray500,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ]),
                          )
                          .toList(),
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
