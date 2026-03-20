import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';

import '../../catalog/roles_catalog.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/snackbar.dart';
import '../../data/local/app_db.dart';
import '../../data/local/dao/activity_dao.dart';
import '../../ui/theme/sao_colors.dart';

class AdminActivityDetailPage extends ConsumerStatefulWidget {
  final String activityId;
  final String projectCode;

  const AdminActivityDetailPage({
    super.key,
    required this.activityId,
    required this.projectCode,
  });

  @override
  ConsumerState<AdminActivityDetailPage> createState() => _AdminActivityDetailPageState();
}

class _AdminActivityDetailPageState extends ConsumerState<AdminActivityDetailPage> {
  late final ActivityDao _dao;
  AdminActivityRecord? _record;

  bool _loading = true;
  bool _canCancelAssignment = false;
  bool _resolvingPermission = true;
  bool _cancelingAssignment = false;

  static final RegExp _uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  );

  @override
  void initState() {
    super.initState();
    _dao = ActivityDao(GetIt.I<AppDb>());
    _loadDetail();
    _resolveCancelPermission();
  }

  Future<void> _loadDetail() async {
    setState(() => _loading = true);
    try {
      final record = await _dao.getAdminActivityById(widget.activityId);
      if (!mounted) return;
      setState(() {
        _record = record;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _resolveCancelPermission() async {
    try {
      final apiClient = GetIt.I<ApiClient>();
      final response = await apiClient.get<dynamic>('/me/projects');
      final data = response.data;
      final scopedRoles = <String>{};
      final targetProject = widget.projectCode.trim().toUpperCase();

      if (data is List) {
        for (final item in data) {
          if (item is! Map) continue;
          final map = Map<String, dynamic>.from(item);
          final projectId = (map['project_id'] ?? '').toString().trim().toUpperCase();
          if (targetProject.isNotEmpty && projectId != targetProject) {
            continue;
          }

          final roleNames = map['role_names'];
          if (roleNames is! List) continue;
          for (final role in roleNames) {
            final roleId = _roleNameToCatalogId(role?.toString() ?? '');
            if (roleId.isNotEmpty) {
              scopedRoles.add(roleId);
            }
          }
        }
      }

      final canCancel = scopedRoles.any(
        (roleId) => RolesCatalog.hasPermission(roleId, RolesCatalog.permDeleteActivity),
      );

      if (!mounted) return;
      setState(() {
        _canCancelAssignment = canCancel;
        _resolvingPermission = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _canCancelAssignment = false;
        _resolvingPermission = false;
      });
    }
  }

  String _roleNameToCatalogId(String rawRoleName) {
    switch (rawRoleName.trim().toUpperCase()) {
      case 'ADMIN':
        return 'admin';
      case 'COORD':
        return 'coordinador';
      case 'SUPERVISOR':
        return 'coordinador';
      case 'OPERATIVO':
        return 'operativo';
      case 'LECTOR':
        return 'consulta';
      default:
        return '';
    }
  }

  Future<String?> _askCancelReason() async {
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Cancelar asignacion'),
          content: TextField(
            controller: ctrl,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Motivo (opcional)',
              hintText: 'Ejemplo: replanificacion por clima',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cerrar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('Confirmar'),
            ),
          ],
        );
      },
    );
    ctrl.dispose();
    return result;
  }

  Future<void> _cancelAssignment() async {
    if (!_uuidPattern.hasMatch(widget.activityId)) {
      showTransientSnackBar(
        context,
        appSnackBar(message: 'Identificador de asignación inválido', backgroundColor: SaoColors.error),
      );
      return;
    }

    final reason = await _askCancelReason();
    if (reason == null) return;

    setState(() => _cancelingAssignment = true);
    try {
      final apiClient = GetIt.I<ApiClient>();
      await apiClient.post<dynamic>(
        '/assignments/${widget.activityId}/cancel',
        data: reason.isEmpty ? null : {'reason': reason},
      );

      if (!mounted) return;
      showTransientSnackBar(
        context,
        appSnackBar(message: 'Asignación cancelada', backgroundColor: SaoColors.success),
      );
      await _loadDetail();
    } on DioException catch (e) {
      if (!mounted) return;
      final message = e.response?.statusCode == 403
          ? 'No tienes permisos para cancelar en este proyecto'
          : 'No se pudo cancelar la asignación';
      showTransientSnackBar(
        context,
        appSnackBar(message: message, backgroundColor: SaoColors.error),
      );
    } catch (_) {
      if (!mounted) return;
      showTransientSnackBar(
        context,
        appSnackBar(message: 'No se pudo cancelar la asignación', backgroundColor: SaoColors.error),
      );
    } finally {
      if (mounted) {
        setState(() => _cancelingAssignment = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final record = _record;
    if (record == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detalle de Actividad')),
        body: const Center(
          child: Text('No se encontro la actividad solicitada.'),
        ),
      );
    }

    final activity = record.activity;
    final status = activity.status;

    return Scaffold(
      appBar: AppBar(title: const Text('Detalle de Actividad')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _InfoRow(label: 'ID', value: activity.id),
            _InfoRow(label: 'Proyecto', value: record.projectCode ?? widget.projectCode),
            _InfoRow(label: 'Tipo', value: record.activityTypeName ?? 'Sin tipo'),
            _InfoRow(label: 'Estado', value: status),
            _InfoRow(label: 'Titulo', value: activity.title),
            _InfoRow(label: 'Usuario asignado', value: record.assignedToName ?? 'Sin asignar'),
            _InfoRow(label: 'Frente', value: record.frente ?? 'Sin frente'),
            _InfoRow(label: 'Municipio', value: record.municipio ?? 'Sin municipio'),
            _InfoRow(label: 'Estado (MX)', value: record.estado ?? 'Sin estado'),
            _InfoRow(label: 'Fecha inicio', value: activity.startedAt?.toIso8601String() ?? '-'),
            _InfoRow(label: 'Fecha fin', value: activity.finishedAt?.toIso8601String() ?? '-'),
            const SizedBox(height: 16),
            Row(
              children: [
                Chip(
                  avatar: const Icon(Icons.photo_library_outlined, size: 16),
                  label: Text('Evidencias: ${record.evidenceCount}'),
                ),
                const SizedBox(width: 8),
                if (_resolvingPermission)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Recargar'),
                  onPressed: _loadDetail,
                ),
                if (!_resolvingPermission && _canCancelAssignment)
                  ElevatedButton.icon(
                    icon: _cancelingAssignment
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.cancel_rounded),
                    label: const Text('Cancelar asignacion'),
                    style: ElevatedButton.styleFrom(backgroundColor: SaoColors.error),
                    onPressed: _cancelingAssignment ? null : _cancelAssignment,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
