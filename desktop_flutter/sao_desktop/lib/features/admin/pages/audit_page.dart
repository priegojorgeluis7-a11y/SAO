import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/session_controller.dart';
import '../data/admin_repositories.dart';

class AdminAuditPage extends ConsumerStatefulWidget {
  const AdminAuditPage({super.key});

  @override
  ConsumerState<AdminAuditPage> createState() => _AdminAuditPageState();
}

class _AdminAuditPageState extends ConsumerState<AdminAuditPage> {
  List<AuditItem> _rows = const [];
  bool _loading = true;
  String? _error;

  final _actorController = TextEditingController();
  final _entityController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadAudit);
  }

  @override
  void dispose() {
    _actorController.dispose();
    _entityController.dispose();
    super.dispose();
  }

  Future<void> _loadAudit() async {
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
      final data = await ref.read(auditRepositoryProvider).list(
            token,
            actorEmail: _actorController.text.trim().isEmpty ? null : _actorController.text.trim(),
            entity: _entityController.text.trim().isEmpty ? null : _entityController.text.trim(),
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _rows = data;
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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text('No se pudo cargar auditoría: $_error'));
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              const Text('Auditoría', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(width: 12),
              SizedBox(
                width: 220,
                child: TextField(
                  controller: _actorController,
                  decoration: const InputDecoration(labelText: 'Actor email'),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 180,
                child: TextField(
                  controller: _entityController,
                  decoration: const InputDecoration(labelText: 'Entidad'),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _loadAudit,
                child: const Text('Filtrar'),
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
                    DataColumn(label: Text('Fecha')),
                    DataColumn(label: Text('Actor')),
                    DataColumn(label: Text('Acción')),
                    DataColumn(label: Text('Entidad')),
                    DataColumn(label: Text('ID entidad')),
                  ],
                  rows: _rows
                      .map(
                        (row) => DataRow(
                          cells: [
                            DataCell(Text(row.createdAt)),
                            DataCell(Text(row.actorEmail ?? '-')),
                            DataCell(Text(row.action)),
                            DataCell(Text(row.entity)),
                            DataCell(Text(row.entityId)),
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
