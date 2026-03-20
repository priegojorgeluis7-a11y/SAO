import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../data/local/app_db.dart';
import '../../data/local/dao/activity_dao.dart';
import '../home/models/today_activity.dart';
import '../auth/application/auth_providers.dart';
import '../../ui/theme/sao_colors.dart';

class CompletedSyncedActivitiesPage extends ConsumerStatefulWidget {
  final String selectedProject;

  const CompletedSyncedActivitiesPage({
    super.key,
    required this.selectedProject,
  });

  @override
  ConsumerState<CompletedSyncedActivitiesPage> createState() =>
      _CompletedSyncedActivitiesPageState();
}

class _CompletedSyncedActivitiesPageState
    extends ConsumerState<CompletedSyncedActivitiesPage> {
  late final ActivityDao _dao;
  late final AppDb _db;
  bool _loading = true;
  List<HomeActivityRecord> _allItems = [];

  String _projectFilter = kAllProjects;
  String _frontFilter = 'TODOS';
  String _stateFilter = 'TODOS';
  DateTime? _dateFilter;

  @override
  void initState() {
    super.initState();
    _db = GetIt.I<AppDb>();
    _dao = ActivityDao(_db);
    _projectFilter = widget.selectedProject.trim().isEmpty
        ? kAllProjects
        : widget.selectedProject.trim().toUpperCase();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final currentUserId = ref.read(currentUserProvider)?.id.trim().toLowerCase();
      if (currentUserId == null || currentUserId.isEmpty) {
        if (!mounted) return;
        setState(() {
          _allItems = const [];
          _loading = false;
        });
        return;
      }

      final rows = await _dao.listHomeActivitiesByProject(kAllProjects);
      final candidateRows = rows.where((row) {
        final assigned = row.assignedToUserId?.trim().toLowerCase();
        final isAssignedToCurrentUser =
            assigned != null && assigned.isNotEmpty && assigned == currentUserId;
        // También incluir actividades creadas por el usuario (actividades no planeadas / propias)
        final isCreatedByCurrentUser =
            row.activity.createdByUserId.trim().toLowerCase() == currentUserId;
        final isSynced = row.activity.status == 'SYNCED';
        final isCompleted = row.activity.finishedAt != null;
        return (isAssignedToCurrentUser || isCreatedByCurrentUser) && isSynced && isCompleted;
      }).toList();

      final activityIds = candidateRows.map((e) => e.activity.id).toList();

      final evidenceRows = activityIds.isEmpty
          ? <Evidence>[]
          : await (_db.select(_db.evidences)
                ..where((t) => t.activityId.isIn(activityIds)))
              .get();
      final pendingUploads = activityIds.isEmpty
          ? <PendingUpload>[]
          : await (_db.select(_db.pendingUploads)
                ..where((t) => t.activityId.isIn(activityIds)))
              .get();

      final evidenceByActivity = <String, List<Evidence>>{};
      for (final ev in evidenceRows) {
        evidenceByActivity.putIfAbsent(ev.activityId, () => <Evidence>[]).add(ev);
      }
      final hasPendingUploadByActivity = <String, bool>{
        for (final up in pendingUploads)
          if (up.status != 'DONE') up.activityId: true,
      };

      final syncedCompleted = candidateRows.where((row) {
        // Solo excluir actividades con uploads activos (en progreso).
        // No exigir que todas las evidencias estén UPLOADED: puede que el servidor
        // ya las aceptó pero el estado local no se actualizó aún.
        final hasPendingUpload = hasPendingUploadByActivity[row.activity.id] ?? false;
        return !hasPendingUpload;
      }).toList()
        ..sort((a, b) => b.activity.finishedAt!.compareTo(a.activity.finishedAt!));

      if (!mounted) return;
      setState(() {
        _allItems = syncedCompleted;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _allItems = const [];
        _loading = false;
      });
    }
  }

  List<HomeActivityRecord> get _items {
    return _allItems.where((row) {
      final projectCode = row.activity.projectId.trim().toUpperCase();
      if (_projectFilter != kAllProjects && projectCode != _projectFilter) {
        return false;
      }

      final front = (row.frontName?.trim().isNotEmpty ?? false)
          ? row.frontName!.trim()
          : (row.segmentName?.trim().isNotEmpty ?? false)
              ? row.segmentName!.trim()
              : 'Sin frente';
      if (_frontFilter != 'TODOS' && front != _frontFilter) {
        return false;
      }

      final state = (row.estado?.trim().isNotEmpty ?? false)
          ? row.estado!.trim()
          : 'Sin estado';
      if (_stateFilter != 'TODOS' && state != _stateFilter) {
        return false;
      }

      if (_dateFilter != null) {
        final finished = row.activity.finishedAt!;
        final dayA = DateTime(finished.year, finished.month, finished.day);
        final dayB = DateTime(_dateFilter!.year, _dateFilter!.month, _dateFilter!.day);
        if (dayA != dayB) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  List<String> get _projectOptions {
    final set = _allItems.map((e) => e.activity.projectId.trim().toUpperCase()).toSet().toList()
      ..sort();
    return <String>[kAllProjects, ...set];
  }

  List<String> get _frontOptions {
    final set = _allItems
        .map((e) => (e.frontName?.trim().isNotEmpty ?? false)
            ? e.frontName!.trim()
            : (e.segmentName?.trim().isNotEmpty ?? false)
                ? e.segmentName!.trim()
                : 'Sin frente')
        .toSet()
        .toList()
      ..sort();
    return <String>['TODOS', ...set];
  }

  List<String> get _stateOptions {
    final set = _allItems
        .map((e) => (e.estado?.trim().isNotEmpty ?? false) ? e.estado!.trim() : 'Sin estado')
        .toSet()
        .toList()
      ..sort();
    return <String>['TODOS', ...set];
  }

  String _fmtDate(DateTime dt) {
    final dd = dt.day.toString().padLeft(2, '0');
    final mm = dt.month.toString().padLeft(2, '0');
    final yy = dt.year.toString();
    return '$dd/$mm/$yy';
  }

  String _formatPk(int? pk) {
    if (pk == null) return 'S/PK';
    final km = pk ~/ 1000;
    final m = pk % 1000;
    return '$km+${m.toString().padLeft(3, '0')}';
  }

  String _title(String raw, String? activityTypeName) {
    final base = (activityTypeName?.trim().isNotEmpty ?? false)
        ? activityTypeName!.trim()
        : raw.trim();
    final upper = base.toUpperCase();
    switch (upper) {
      case 'CAM':
        return 'Caminamiento';
      case 'REU':
        return 'Reunion';
      case 'INS':
        return 'Inspeccion';
      case 'SUP':
        return 'Supervision';
      default:
        return base.isEmpty ? 'Actividad' : base;
    }
  }

  String _fmtTime(DateTime dt) {
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  IconData _activityIcon(String raw, String? activityTypeName) {
    final title = _title(raw, activityTypeName).toLowerCase();
    if (title.contains('reu') || title.contains('junta')) return Icons.groups_rounded;
    if (title.contains('reunion')) return Icons.groups_rounded;
    if (title.contains('ins') || title.contains('inspeccion')) {
      return Icons.photo_camera_rounded;
    }
    if (title.contains('cam') || title.contains('caminamiento')) {
      return Icons.directions_walk_rounded;
    }
    if (title.contains('sup') || title.contains('supervision')) return Icons.rule_rounded;
    if (title.contains('liberacion')) return Icons.alt_route_rounded;
    if (title.contains('levantamiento')) return Icons.map_rounded;
    if (title.contains('verificacion')) return Icons.fact_check_rounded;
    return Icons.assignment_turned_in_rounded;
  }

  String _compactState(String state) {
    final trimmed = state.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.toLowerCase().startsWith('estado de ')) {
      return 'Edo. ${trimmed.substring('estado de '.length)}';
    }
    return trimmed;
  }

  Widget _metaChip({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: SaoColors.gray100,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: SaoColors.gray200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: SaoColors.gray600),
          const SizedBox(width: 4),
          Text(
            '$label: $value',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: SaoColors.gray700,
            ),
          ),
        ],
      ),
    );
  }

  String _displayFront(String front) {
    final value = front.trim();
    if (value.isEmpty) return 'Sin frente';
    return value;
  }

  String _displayProject(String projectId) {
    final value = projectId.trim().toUpperCase();
    if (value.isEmpty) return 'N/D';
    return value;
  }

  String _statusLabel(DateTime finishedAt, DateTime? startedAt) {
    if (startedAt != null) {
      return 'Terminada (${_fmtTime(startedAt)}-${_fmtTime(finishedAt)})';
    }
    return 'Terminada (${_fmtTime(finishedAt)})';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SaoColors.gray50,
      appBar: AppBar(
        backgroundColor: SaoColors.surface,
        surfaceTintColor: SaoColors.surface,
        title: const Text('Historial completadas'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: Column(
                children: [
                  Container(
                    color: SaoColors.surface,
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _projectOptions.contains(_projectFilter)
                                    ? _projectFilter
                                    : kAllProjects,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Proyecto',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                items: _projectOptions
                                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                                    .toList(),
                                onChanged: (value) {
                                  if (value == null) return;
                                  setState(() => _projectFilter = value);
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _frontOptions.contains(_frontFilter) ? _frontFilter : 'TODOS',
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Frente',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                items: _frontOptions
                                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                                    .toList(),
                                onChanged: (value) {
                                  if (value == null) return;
                                  setState(() => _frontFilter = value);
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _stateOptions.contains(_stateFilter) ? _stateFilter : 'TODOS',
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Estado',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                items: _stateOptions
                                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                                    .toList(),
                                onChanged: (value) {
                                  if (value == null) return;
                                  setState(() => _stateFilter = value);
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  final now = DateTime.now();
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: _dateFilter ?? now,
                                    firstDate: DateTime(now.year - 3),
                                    lastDate: DateTime(now.year + 1),
                                  );
                                  if (picked != null) {
                                    setState(() => _dateFilter = picked);
                                  }
                                },
                                icon: const Icon(Icons.date_range_rounded),
                                label: Text(
                                  _dateFilter == null ? 'Fecha' : _fmtDate(_dateFilter!),
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Limpiar filtros',
                              onPressed: () {
                                setState(() {
                                  _projectFilter = widget.selectedProject.trim().isEmpty
                                      ? kAllProjects
                                      : widget.selectedProject.trim().toUpperCase();
                                  _frontFilter = 'TODOS';
                                  _stateFilter = 'TODOS';
                                  _dateFilter = null;
                                });
                              },
                              icon: const Icon(Icons.filter_alt_off_rounded),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _items.isEmpty
                        ? ListView(
                            children: const [
                        SizedBox(height: 120),
                        Center(
                          child: Text(
                            'No tienes actividades completadas y sincronizadas.',
                            style: TextStyle(
                              color: SaoColors.gray500,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                            ],
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(12),
                            itemCount: _items.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final row = _items[index];
                              final activity = row.activity;
                              final finishedAt = activity.finishedAt!;
                              final startedAt = activity.startedAt;
                              final activityTitle = _title(activity.title, row.activityTypeName);
                              final front = (row.frontName?.trim().isNotEmpty ?? false)
                                  ? row.frontName!.trim()
                                  : (row.segmentName?.trim().isNotEmpty ?? false)
                                      ? row.segmentName!.trim()
                                      : 'Sin frente';
                              final state = (row.estado?.trim().isNotEmpty ?? false)
                                  ? row.estado!.trim()
                                  : 'Sin estado';
                              final compactState = _compactState(state);
                              final municipality = row.municipio?.trim() ?? '';
                              final hasMunicipality = municipality.isNotEmpty;
                              final location = [
                                if (hasMunicipality) municipality,
                                if (compactState.isNotEmpty) compactState,
                              ].join(', ');
                                final statusLabel = _statusLabel(finishedAt, startedAt);

                              return Container(
                                decoration: BoxDecoration(
                                  color: SaoColors.surface,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: SaoColors.gray200),
                                ),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: () {
                                    final todayActivity = TodayActivity(
                                      id: activity.id,
                                      title: activityTitle,
                                      frente: front,
                                      municipio: row.municipio ?? '',
                                      estado: state,
                                      pk: activity.pk,
                                      status: ActivityStatus.programada,
                                      createdAt: activity.createdAt,
                                      executionState: ExecutionState.terminada,
                                      horaInicio: startedAt,
                                      horaFin: finishedAt,
                                      syncState: ActivitySyncState.synced,
                                      assignedToUserId: row.assignedToUserId,
                                      assignedToName: row.assignedToName,
                                    );
                                    context.push(
                                      '/activity/${activity.id}?project=${Uri.encodeQueryComponent(activity.projectId)}',
                                      extra: todayActivity,
                                    );
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              _activityIcon(activity.title, row.activityTypeName),
                                              size: 22,
                                              color: SaoColors.primary,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                activityTitle,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                  color: SaoColors.primary,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(
                                                  Icons.event_rounded,
                                                  size: 16,
                                                  color: SaoColors.gray500,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  _fmtDate(finishedAt),
                                                  style: const TextStyle(
                                                    color: SaoColors.gray600,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.location_on_outlined,
                                              size: 16,
                                              color: SaoColors.gray600,
                                            ),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                '${location.isEmpty ? 'Sin ubicacion' : location} • PK ${_formatPk(activity.pk)}',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(color: SaoColors.gray700),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 6,
                                          children: [
                                            _metaChip(
                                              icon: Icons.apartment_rounded,
                                              label: 'Proyecto',
                                              value: _displayProject(activity.projectId),
                                            ),
                                            _metaChip(
                                              icon: Icons.layers_rounded,
                                              label: 'Frente',
                                              value: _displayFront(front),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.circle,
                                              size: 10,
                                              color: SaoColors.success,
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                statusLabel,
                                                style: const TextStyle(
                                                  color: SaoColors.success,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                            const Icon(
                                              Icons.chevron_right_rounded,
                                              color: SaoColors.gray400,
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}
