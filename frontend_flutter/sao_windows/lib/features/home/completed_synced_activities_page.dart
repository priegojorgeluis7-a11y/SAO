import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../core/flow/activity_flow_projection.dart';
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

class _HistoryFilterValues {
  final String project;
  final String front;
  final String state;
  final DateTime? date;
  final bool clearAll;

  const _HistoryFilterValues({
    required this.project,
    required this.front,
    required this.state,
    required this.date,
    this.clearAll = false,
  });
}

class _CompletedSyncedActivitiesPageState
    extends ConsumerState<CompletedSyncedActivitiesPage> {
  late final ActivityDao _dao;
  late final AppDb _db;
  final TextEditingController _searchCtrl = TextEditingController();
  bool _loading = true;
  List<HomeActivityRecord> _allItems = [];

  String _projectFilter = kAllProjects;
  String _frontFilter = 'TODOS';
  String _stateFilter = 'TODOS';
  String _query = '';
  DateTime? _dateFilter;

  String get _defaultProjectFilter {
    final value = widget.selectedProject.trim().toUpperCase();
    return value.isEmpty ? kAllProjects : value;
  }

  bool get _hasFilterSelection {
    return _projectFilter != _defaultProjectFilter ||
        _frontFilter != 'TODOS' ||
        _stateFilter != 'TODOS' ||
        _dateFilter != null;
  }

  bool get _hasAnyFilterApplied =>
      _hasFilterSelection || _query.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _db = GetIt.I<AppDb>();
    _dao = ActivityDao(_db);
    _projectFilter = _defaultProjectFilter;
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final currentUserId = ref
          .read(currentUserProvider)
          ?.id
          .trim()
          .toLowerCase();
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
            assigned != null &&
            assigned.isNotEmpty &&
            assigned == currentUserId;
        final isCreatedByCurrentUser =
            row.activity.createdByUserId.trim().toLowerCase() == currentUserId;
        final includeAsCorrectionFallback =
            isCreatedByCurrentUser && _isRejectedForCorrection(row);
        return (isAssignedToCurrentUser || includeAsCorrectionFallback) &&
            _isHistoryVisible(row);
      }).toList();

      final activityIds = candidateRows.map((e) => e.activity.id).toList();

      final evidenceRows = activityIds.isEmpty
          ? <Evidence>[]
          : await (_db.select(
              _db.evidences,
            )..where((t) => t.activityId.isIn(activityIds))).get();
      final pendingUploads = activityIds.isEmpty
          ? <PendingUpload>[]
          : await (_db.select(
              _db.pendingUploads,
            )..where((t) => t.activityId.isIn(activityIds))).get();

      final evidenceByActivity = <String, List<Evidence>>{};
      for (final ev in evidenceRows) {
        evidenceByActivity
            .putIfAbsent(ev.activityId, () => <Evidence>[])
            .add(ev);
      }
      final hasPendingUploadByActivity = <String, bool>{
        for (final up in pendingUploads)
          if (up.status != 'DONE') up.activityId: true,
      };

      final historyRows = candidateRows.toList()
        ..sort(
          (a, b) =>
              _historyDateOf(b.activity).compareTo(_historyDateOf(a.activity)),
        );

      final dedupedHistoryRows = _dedupeHistoryRows(historyRows);

      if (!mounted) return;
      setState(() {
        _allItems = dedupedHistoryRows;
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
      if (!_matchesQuery(row)) {
        return false;
      }

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
        final dateRef = _historyDateOf(row.activity);
        final dayA = DateTime(dateRef.year, dateRef.month, dateRef.day);
        final dayB = DateTime(
          _dateFilter!.year,
          _dateFilter!.month,
          _dateFilter!.day,
        );
        if (dayA != dayB) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  List<String> get _projectOptions {
    final set =
        _allItems
            .map((e) => e.activity.projectId.trim().toUpperCase())
            .toSet()
            .toList()
          ..sort();
    return <String>[kAllProjects, ...set];
  }

  List<String> get _frontOptions {
    final set =
        _allItems
            .map(
              (e) => (e.frontName?.trim().isNotEmpty ?? false)
                  ? e.frontName!.trim()
                  : (e.segmentName?.trim().isNotEmpty ?? false)
                  ? e.segmentName!.trim()
                  : 'Sin frente',
            )
            .toSet()
            .toList()
          ..sort();
    return <String>['TODOS', ...set];
  }

  List<String> get _stateOptions {
    final set =
        _allItems
            .map(
              (e) => (e.estado?.trim().isNotEmpty ?? false)
                  ? e.estado!.trim()
                  : 'Sin estado',
            )
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

  bool _matchesQuery(HomeActivityRecord row) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) {
      return true;
    }

    final activity = row.activity;
    final title = _title(activity.title, row.activityTypeName).toLowerCase();
    final front =
        ((row.frontName?.trim().isNotEmpty ?? false)
                ? row.frontName!.trim()
                : (row.segmentName?.trim().isNotEmpty ?? false)
                ? row.segmentName!.trim()
                : 'Sin frente')
            .toLowerCase();
    final municipio = (row.municipio ?? '').trim().toLowerCase();
    final estado = (row.estado ?? '').trim().toLowerCase();
    final project = activity.projectId.trim().toLowerCase();
    final pk = _formatPk(activity.pk).toLowerCase();
    final status = _historyStatusLabel(row).toLowerCase();

    return title.contains(query) ||
        front.contains(query) ||
        municipio.contains(query) ||
        estado.contains(query) ||
        project.contains(query) ||
        pk.contains(query) ||
        status.contains(query);
  }

  IconData _activityIcon(String raw, String? activityTypeName) {
    final title = _title(raw, activityTypeName).toLowerCase();
    if (title.contains('reu') || title.contains('junta'))
      return Icons.groups_rounded;
    if (title.contains('reunion')) return Icons.groups_rounded;
    if (title.contains('ins') || title.contains('inspeccion')) {
      return Icons.photo_camera_rounded;
    }
    if (title.contains('cam') || title.contains('caminamiento')) {
      return Icons.directions_walk_rounded;
    }
    if (title.contains('sup') || title.contains('supervision'))
      return Icons.rule_rounded;
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

  bool _isSyncedCompleted(Activity activity) {
    return activity.status.trim().toUpperCase() == 'SYNCED' &&
        activity.finishedAt != null;
  }

  bool _isHistorySynced(Activity activity) {
    final status = activity.status.trim().toUpperCase();
    return status == 'SYNCED' ||
        status == 'REVISION_PENDIENTE' ||
        status == 'RECHAZADA';
  }

  bool _hasMeaningfulHistorySignal(HomeActivityRecord row) {
    final activity = row.activity;
    final operationalState = row.operationalState?.trim().toUpperCase() ?? '';
    final reviewState = row.reviewState?.trim().toUpperCase() ?? '';
    final nextAction = row.nextAction?.trim().toUpperCase() ?? '';

    if (activity.finishedAt != null || activity.startedAt != null) {
      return true;
    }

    if (operationalState.isNotEmpty && operationalState != 'PENDIENTE') {
      return true;
    }

    if (reviewState == 'PENDING_REVIEW' || reviewState == 'APPROVED') {
      return true;
    }

    return nextAction == 'ESPERAR_DECISION_COORDINACION' ||
        nextAction == 'CERRADA_APROBADA' ||
        nextAction == 'COMPLETAR_WIZARD';
  }

  bool _isHistoryVisible(HomeActivityRecord row) {
    if (_isRejectedForCorrection(row)) {
      return true;
    }

    final status = row.activity.status.trim().toUpperCase();
    if (status == 'REVISION_PENDIENTE' || status == 'RECHAZADA') {
      return true;
    }

    if (status != 'SYNCED') {
      return false;
    }

    return _hasMeaningfulHistorySignal(row);
  }

  void _clearFilters() {
    _searchCtrl.clear();
    setState(() {
      _projectFilter = _defaultProjectFilter;
      _frontFilter = 'TODOS';
      _stateFilter = 'TODOS';
      _dateFilter = null;
      _query = '';
    });
  }

  bool _isRejectedForCorrection(HomeActivityRecord row) {
    return isRejectedForCorrectionFlow(
      localStatus: row.activity.status,
      reviewState: row.reviewState,
      nextAction: row.nextAction,
    );
  }

  List<HomeActivityRecord> _dedupeHistoryRows(List<HomeActivityRecord> rows) {
    final byKey = <String, HomeActivityRecord>{};

    for (final row in rows) {
      final key = _historyLogicalKey(row);
      final existing = byKey[key];
      if (existing == null) {
        byKey[key] = row;
        continue;
      }
      byKey[key] = _preferHistoryRow(existing, row);
    }

    final deduped = byKey.values.toList()
      ..sort(
        (a, b) =>
            _historyDateOf(b.activity).compareTo(_historyDateOf(a.activity)),
      );
    return deduped;
  }

  String _historyLogicalKey(HomeActivityRecord row) {
    final activity = row.activity;
    final date = _historyDateOf(activity);
    final normalizedTitle = _normalizeHistoryText(
      _title(activity.title, row.activityTypeName),
    );
    final pk = activity.pk?.toString() ?? 'NO_PK';
    final project = activity.projectId.trim().toUpperCase();
    return '$project|$pk|$normalizedTitle|${date.year}-${date.month}-${date.day}';
  }

  HomeActivityRecord _preferHistoryRow(
    HomeActivityRecord current,
    HomeActivityRecord candidate,
  ) {
    final currentRejected = _isRejectedForCorrection(current);
    final candidateRejected = _isRejectedForCorrection(candidate);
    if (currentRejected != candidateRejected) {
      return candidateRejected ? candidate : current;
    }

    final currentFinished = current.activity.finishedAt != null;
    final candidateFinished = candidate.activity.finishedAt != null;
    if (currentFinished != candidateFinished) {
      return candidateFinished ? candidate : current;
    }

    final currentRevision = current.activity.serverRevision ?? 0;
    final candidateRevision = candidate.activity.serverRevision ?? 0;
    if (candidateRevision != currentRevision) {
      return candidateRevision > currentRevision ? candidate : current;
    }

    return _historyDateOf(
          candidate.activity,
        ).isAfter(_historyDateOf(current.activity))
        ? candidate
        : current;
  }

  String _normalizeHistoryText(String value) {
    return value
        .trim()
        .toUpperCase()
        .replaceAll('Á', 'A')
        .replaceAll('É', 'E')
        .replaceAll('Í', 'I')
        .replaceAll('Ó', 'O')
        .replaceAll('Ú', 'U')
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  DateTime _historyDateOf(Activity activity) {
    return activity.finishedAt ?? activity.startedAt ?? activity.createdAt;
  }

  ExecutionState _executionStateForHistory(HomeActivityRecord row) {
    final activity = row.activity;
    if (_isRejectedForCorrection(row)) {
      return ExecutionState.revisionPendiente;
    }
    if (activity.finishedAt != null) {
      return ExecutionState.terminada;
    }
    if (activity.startedAt != null) {
      return ExecutionState.enCurso;
    }
    return ExecutionState.pendiente;
  }

  ActivitySyncState _syncStateForHistory(Activity activity) {
    switch (activity.status) {
      case 'SYNCED':
        return ActivitySyncState.synced;
      case 'READY_TO_SYNC':
      case 'DRAFT':
        return ActivitySyncState.pending;
      case 'ERROR':
        return ActivitySyncState.error;
      default:
        return ActivitySyncState.unknown;
    }
  }

  String _historyStatusLabel(HomeActivityRecord row) {
    final activity = row.activity;
    if (_isRejectedForCorrection(row)) {
      return 'Rechazada · Requiere correccion';
    }

    final operationalState = row.operationalState?.trim().toUpperCase() ?? '';
    final reviewState = row.reviewState?.trim().toUpperCase() ?? '';
    final nextAction = row.nextAction?.trim().toUpperCase() ?? '';

    if (reviewState == 'PENDING_REVIEW' ||
        nextAction == 'ESPERAR_DECISION_COORDINACION') {
      return 'Sincronizada · En revision';
    }

    if (reviewState == 'APPROVED' || nextAction == 'CERRADA_APROBADA') {
      return 'Sincronizada · Aprobada';
    }

    if (activity.finishedAt != null) {
      return 'Sincronizada · ${_statusLabel(activity.finishedAt!, activity.startedAt)}';
    }

    if (activity.status.trim().toUpperCase() == 'REVISION_PENDIENTE' ||
        operationalState == 'POR_COMPLETAR') {
      return 'Sincronizada · Por completar';
    }

    if (activity.startedAt != null || operationalState == 'EN_CURSO') {
      return 'Sincronizada · En curso';
    }

    return 'Sincronizada · Pendiente';
  }

  Color _historyStatusColor(HomeActivityRecord row) {
    final activity = row.activity;
    final reviewState = row.reviewState?.trim().toUpperCase() ?? '';
    final nextAction = row.nextAction?.trim().toUpperCase() ?? '';
    if (_isRejectedForCorrection(row)) {
      return SaoColors.riskHigh;
    }
    if (reviewState == 'PENDING_REVIEW' ||
        nextAction == 'ESPERAR_DECISION_COORDINACION' ||
        activity.status.trim().toUpperCase() == 'REVISION_PENDIENTE' ||
        (row.operationalState?.trim().toUpperCase() ?? '') == 'POR_COMPLETAR') {
      return SaoColors.warning;
    }
    if (activity.finishedAt != null ||
        reviewState == 'APPROVED' ||
        nextAction == 'CERRADA_APROBADA') {
      return SaoColors.success;
    }
    return SaoColors.info;
  }

  Color _historyStatusBackground(HomeActivityRecord row) {
    final activity = row.activity;
    final reviewState = row.reviewState?.trim().toUpperCase() ?? '';
    final nextAction = row.nextAction?.trim().toUpperCase() ?? '';
    if (_isRejectedForCorrection(row)) {
      return SaoColors.riskHighBg;
    }
    if (reviewState == 'PENDING_REVIEW' ||
        nextAction == 'ESPERAR_DECISION_COORDINACION' ||
        activity.status.trim().toUpperCase() == 'REVISION_PENDIENTE' ||
        (row.operationalState?.trim().toUpperCase() ?? '') == 'POR_COMPLETAR') {
      return SaoColors.alertBg;
    }
    if (activity.finishedAt != null ||
        reviewState == 'APPROVED' ||
        nextAction == 'CERRADA_APROBADA') {
      return SaoColors.successBg;
    }
    return SaoColors.infoBg;
  }

  Future<void> _showFiltersSheet() async {
    final result = await showModalBottomSheet<_HistoryFilterValues>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        var tempProject = _projectOptions.contains(_projectFilter)
            ? _projectFilter
            : _defaultProjectFilter;
        var tempFront = _frontOptions.contains(_frontFilter)
            ? _frontFilter
            : 'TODOS';
        var tempState = _stateOptions.contains(_stateFilter)
            ? _stateFilter
            : 'TODOS';
        DateTime? tempDate = _dateFilter;

        InputDecoration decoration(String label) {
          return InputDecoration(
            labelText: label,
            isDense: true,
            filled: true,
            fillColor: SaoColors.gray50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: SaoColors.gray200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: SaoColors.gray200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: SaoColors.actionPrimary,
                width: 1.4,
              ),
            ),
          );
        }

        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                ),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: SaoColors.surface,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x140F172A),
                        blurRadius: 28,
                        offset: Offset(0, 14),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 38,
                          height: 4,
                          decoration: BoxDecoration(
                            color: SaoColors.gray300,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Filtrar historial',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: SaoColors.gray900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Ajusta proyecto, frente, estado o fecha sin ocupar espacio de la lista.',
                        style: TextStyle(
                          color: SaoColors.gray600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: tempProject,
                        isExpanded: true,
                        decoration: decoration('Proyecto'),
                        items: _projectOptions
                            .map(
                              (value) => DropdownMenuItem(
                                value: value,
                                child: Text(value),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setModalState(() => tempProject = value);
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: tempFront,
                        isExpanded: true,
                        decoration: decoration('Frente'),
                        items: _frontOptions
                            .map(
                              (value) => DropdownMenuItem(
                                value: value,
                                child: Text(value),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setModalState(() => tempFront = value);
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: tempState,
                        isExpanded: true,
                        decoration: decoration('Estado'),
                        items: _stateOptions
                            .map(
                              (value) => DropdownMenuItem(
                                value: value,
                                child: Text(value),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setModalState(() => tempState = value);
                        },
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () async {
                          final now = DateTime.now();
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: tempDate ?? now,
                            firstDate: DateTime(now.year - 3),
                            lastDate: DateTime(now.year + 1),
                          );
                          if (picked != null) {
                            setModalState(() => tempDate = picked);
                          }
                        },
                        child: Ink(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: SaoColors.gray50,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: SaoColors.gray200),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.calendar_month_rounded,
                                color: SaoColors.gray700,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  tempDate == null
                                      ? 'Sin fecha seleccionada'
                                      : _fmtDate(tempDate!),
                                  style: const TextStyle(
                                    color: SaoColors.gray900,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              if (tempDate != null)
                                IconButton(
                                  onPressed: () =>
                                      setModalState(() => tempDate = null),
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    size: 18,
                                  ),
                                  visualDensity: VisualDensity.compact,
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                Navigator.of(context).pop(
                                  const _HistoryFilterValues(
                                    project: kAllProjects,
                                    front: 'TODOS',
                                    state: 'TODOS',
                                    date: null,
                                    clearAll: true,
                                  ),
                                );
                              },
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(48),
                                side: const BorderSide(
                                  color: SaoColors.gray300,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: const Text('Limpiar'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton(
                              onPressed: () {
                                Navigator.of(context).pop(
                                  _HistoryFilterValues(
                                    project: tempProject,
                                    front: tempFront,
                                    state: tempState,
                                    date: tempDate,
                                  ),
                                );
                              },
                              style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(48),
                                backgroundColor: SaoColors.actionPrimary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: const Text('Aplicar filtros'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (result == null || !mounted) {
      return;
    }
    if (result.clearAll) {
      _clearFilters();
      return;
    }
    setState(() {
      _projectFilter = result.project;
      _frontFilter = result.front;
      _stateFilter = result.state;
      _dateFilter = result.date;
    });
  }

  Widget _filterChip({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: SaoColors.gray100,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: SaoColors.gray200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: SaoColors.gray700),
          const SizedBox(width: 6),
          Text(
            '$label: $value',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: SaoColors.gray700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyIllustration() {
    return SizedBox(
      width: 120,
      height: 92,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 8,
            right: 8,
            top: 20,
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                color: SaoColors.infoBg,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: 28,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: SaoColors.successBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: SaoColors.success.withValues(alpha: 0.24),
                ),
              ),
            ),
          ),
          Positioned(
            right: 0,
            top: 30,
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: SaoColors.riskHighBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: SaoColors.riskHigh.withValues(alpha: 0.26),
                ),
              ),
            ),
          ),
          Positioned(
            left: 30,
            top: 0,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: SaoColors.brandPrimary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.filter_alt_off_rounded,
                size: 28,
                color: SaoColors.brandPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required Color background,
    bool compact = false,
  }) {
    return Container(
      padding: EdgeInsets.all(compact ? 10 : 12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(compact ? 14 : 16),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: compact ? 34 : 38,
            height: compact ? 34 : 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.20),
              borderRadius: BorderRadius.circular(compact ? 11 : 12),
            ),
            child: Icon(icon, size: compact ? 18 : 19, color: color),
          ),
          SizedBox(width: compact ? 8 : 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: compact ? 16 : 18,
                    fontWeight: FontWeight.w900,
                    color: SaoColors.gray900,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: compact ? 11 : 12,
                    fontWeight: FontWeight.w700,
                    color: SaoColors.gray600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibleItems = _items;
    final syncedCount = _allItems
        .where((row) => _isHistorySynced(row.activity))
        .length;
    final rejectedCount = _allItems
        .where((row) => _isRejectedForCorrection(row))
        .length;
    final projectsCount = _allItems
        .map((row) => row.activity.projectId.trim().toUpperCase())
        .where((value) => value.isNotEmpty)
        .toSet()
        .length;
    final showSummary = _allItems.isNotEmpty || _hasAnyFilterApplied;
    final compactSummary = visibleItems.isEmpty || _allItems.isEmpty;

    return Scaffold(
      backgroundColor: SaoColors.gray50,
      appBar: AppBar(
        backgroundColor: SaoColors.surface,
        surfaceTintColor: SaoColors.surface,
        title: const Text('Historial de actividades'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: Column(
                children: [
                  Container(
                    color: SaoColors.surface,
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (showSummary) ...[
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(compactSummary ? 14 : 16),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              gradient: const LinearGradient(
                                colors: [
                                  SaoColors.actionPrimary,
                                  SaoColors.primaryLight,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: EdgeInsets.all(
                                        compactSummary ? 9 : 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: 0.14,
                                        ),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: const Icon(
                                        Icons.history_rounded,
                                        color: Colors.white,
                                        size: 21,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Tu historial reciente',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 18,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                          Text(
                                            compactSummary
                                                ? '${visibleItems.length} resultados visibles'
                                                : '${visibleItems.length} actividades visibles con los filtros actuales',
                                            style: TextStyle(
                                              color: Colors.white.withValues(
                                                alpha: 0.82,
                                              ),
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _summaryCard(
                                        label: 'Sincronizadas',
                                        value: '$syncedCount',
                                        icon: Icons.cloud_done_rounded,
                                        color: SaoColors.success,
                                        background: SaoColors.successBg,
                                        compact: compactSummary,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _summaryCard(
                                        label: 'Por corregir',
                                        value: '$rejectedCount',
                                        icon: Icons.assignment_late_rounded,
                                        color: SaoColors.riskHigh,
                                        background: SaoColors.riskHighBg,
                                        compact: compactSummary,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _summaryCard(
                                        label: 'Proyectos',
                                        value: '$projectsCount',
                                        icon: Icons.apartment_rounded,
                                        color: SaoColors.info,
                                        background: SaoColors.infoBg,
                                        compact: compactSummary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        TextField(
                          controller: _searchCtrl,
                          onChanged: (value) => setState(() => _query = value),
                          decoration: InputDecoration(
                            hintText: 'Buscar actividad o frente...',
                            prefixIcon: const Icon(Icons.search_rounded),
                            suffixIcon: _query.trim().isEmpty
                                ? null
                                : IconButton(
                                    onPressed: () {
                                      _searchCtrl.clear();
                                      setState(() => _query = '');
                                    },
                                    icon: const Icon(Icons.close_rounded),
                                  ),
                            filled: true,
                            fillColor: SaoColors.gray50,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: SaoColors.gray200,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: SaoColors.gray200,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: SaoColors.actionPrimary,
                                width: 1.4,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _showFiltersSheet,
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size.fromHeight(48),
                                  backgroundColor: SaoColors.surface,
                                  side: const BorderSide(
                                    color: SaoColors.gray200,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                icon: Icon(
                                  _hasFilterSelection
                                      ? Icons.tune_rounded
                                      : Icons.filter_list_rounded,
                                ),
                                label: Text(
                                  _hasFilterSelection
                                      ? 'Editar filtros'
                                      : 'Filtrar',
                                ),
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
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size.fromHeight(48),
                                  backgroundColor: SaoColors.surface,
                                  side: const BorderSide(
                                    color: SaoColors.gray200,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                icon: const Icon(Icons.calendar_today_rounded),
                                label: Text(
                                  _dateFilter == null
                                      ? 'Fecha'
                                      : _fmtDate(_dateFilter!),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_hasAnyFilterApplied) ...[
                          const SizedBox(height: 10),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                if (_query.trim().isNotEmpty)
                                  _filterChip(
                                    icon: Icons.search_rounded,
                                    label: 'Busqueda',
                                    value: _query.trim(),
                                  ),
                                if (_query.trim().isNotEmpty)
                                  const SizedBox(width: 8),
                                if (_projectFilter != _defaultProjectFilter)
                                  _filterChip(
                                    icon: Icons.apartment_rounded,
                                    label: 'Proyecto',
                                    value: _projectFilter,
                                  ),
                                if (_projectFilter != _defaultProjectFilter)
                                  const SizedBox(width: 8),
                                if (_frontFilter != 'TODOS')
                                  _filterChip(
                                    icon: Icons.layers_rounded,
                                    label: 'Frente',
                                    value: _frontFilter,
                                  ),
                                if (_frontFilter != 'TODOS')
                                  const SizedBox(width: 8),
                                if (_stateFilter != 'TODOS')
                                  _filterChip(
                                    icon: Icons.flag_rounded,
                                    label: 'Estado',
                                    value: _stateFilter,
                                  ),
                                if (_stateFilter != 'TODOS')
                                  const SizedBox(width: 8),
                                if (_dateFilter != null)
                                  _filterChip(
                                    icon: Icons.calendar_month_rounded,
                                    label: 'Fecha',
                                    value: _fmtDate(_dateFilter!),
                                  ),
                                if (_dateFilter != null)
                                  const SizedBox(width: 8),
                                ActionChip(
                                  avatar: const Icon(
                                    Icons.filter_alt_off_rounded,
                                    size: 16,
                                    color: SaoColors.brandPrimary,
                                  ),
                                  label: const Text('Limpiar todo'),
                                  labelStyle: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: SaoColors.brandPrimary,
                                  ),
                                  backgroundColor: SaoColors.brandPrimary
                                      .withValues(alpha: 0.08),
                                  side: BorderSide.none,
                                  onPressed: _clearFilters,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Expanded(
                    child: visibleItems.isEmpty
                        ? ListView(
                            padding: const EdgeInsets.all(20),
                            children: [
                              const SizedBox(height: 64),
                              Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: SaoColors.surface,
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(color: SaoColors.gray200),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x0A0F172A),
                                      blurRadius: 24,
                                      offset: Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    _emptyIllustration(),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'No hay resultados en el historial',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                        color: SaoColors.gray900,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _query.trim().isEmpty &&
                                              _projectFilter ==
                                                  _defaultProjectFilter &&
                                              _frontFilter == 'TODOS' &&
                                              _stateFilter == 'TODOS' &&
                                              _dateFilter == null
                                          ? 'Todavia no tienes actividades sincronizadas o rechazadas para mostrar.'
                                          : 'Prueba limpiar filtros o cambiar la busqueda para encontrar otras actividades.',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: SaoColors.gray600,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (_hasAnyFilterApplied) ...[
                                      const SizedBox(height: 18),
                                      FilledButton.icon(
                                        onPressed: _clearFilters,
                                        style: FilledButton.styleFrom(
                                          backgroundColor:
                                              SaoColors.actionPrimary,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 18,
                                            vertical: 12,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                          ),
                                        ),
                                        icon: const Icon(
                                          Icons.filter_alt_off_rounded,
                                        ),
                                        label: const Text(
                                          'Limpiar todos los filtros',
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(12),
                            itemCount: visibleItems.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final row = visibleItems[index];
                              final activity = row.activity;
                              final isRejected = _isRejectedForCorrection(row);
                              final dateRef = _historyDateOf(activity);
                              final startedAt = activity.startedAt;
                              final activityTitle = _title(
                                activity.title,
                                row.activityTypeName,
                              );
                              final front =
                                  (row.frontName?.trim().isNotEmpty ?? false)
                                  ? row.frontName!.trim()
                                  : (row.segmentName?.trim().isNotEmpty ??
                                        false)
                                  ? row.segmentName!.trim()
                                  : 'Sin frente';
                              final state =
                                  (row.estado?.trim().isNotEmpty ?? false)
                                  ? row.estado!.trim()
                                  : 'Sin estado';
                              final compactState = _compactState(state);
                              final municipality = row.municipio?.trim() ?? '';
                              final hasMunicipality = municipality.isNotEmpty;
                              final location = [
                                if (hasMunicipality) municipality,
                                if (compactState.isNotEmpty) compactState,
                              ].join(', ');
                              final statusLabel = _historyStatusLabel(row);
                              final statusColor = _historyStatusColor(row);
                              final statusBg = _historyStatusBackground(row);

                              return Container(
                                decoration: BoxDecoration(
                                  color: SaoColors.surface,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(color: SaoColors.gray200),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x0A0F172A),
                                      blurRadius: 18,
                                      offset: Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(18),
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
                                      executionState: _executionStateForHistory(
                                        row,
                                      ),
                                      horaInicio: startedAt,
                                      horaFin: activity.finishedAt,
                                      syncState: _syncStateForHistory(activity),
                                      isRejected: isRejected,
                                      operationalState:
                                          row.operationalState ?? 'PENDIENTE',
                                      reviewState:
                                          row.reviewState ?? 'NOT_APPLICABLE',
                                      nextAction:
                                          row.nextAction ?? 'SIN_ACCION',
                                      assignedToUserId: row.assignedToUserId,
                                      assignedToName: row.assignedToName,
                                    );
                                    context.push(
                                      '/activity/${activity.id}?project=${Uri.encodeQueryComponent(activity.projectId)}',
                                      extra: todayActivity,
                                    );
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      14,
                                      14,
                                      14,
                                      14,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Container(
                                              width: 42,
                                              height: 42,
                                              decoration: BoxDecoration(
                                                color: SaoColors.infoLight,
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                              ),
                                              child: Icon(
                                                _activityIcon(
                                                  activity.title,
                                                  row.activityTypeName,
                                                ),
                                                size: 22,
                                                color: SaoColors.actionPrimary,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    activityTitle,
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w900,
                                                      color: SaoColors.primary,
                                                      fontSize: 15,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    'PK ${_formatPk(activity.pk)} • ${_displayProject(activity.projectId)}',
                                                    style: const TextStyle(
                                                      color: SaoColors.gray600,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 7,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: statusBg,
                                                borderRadius:
                                                    BorderRadius.circular(999),
                                              ),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.end,
                                                children: [
                                                  Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        Icons.circle,
                                                        size: 9,
                                                        color: statusColor,
                                                      ),
                                                      const SizedBox(width: 5),
                                                      Text(
                                                        _fmtDate(dateRef),
                                                        style: TextStyle(
                                                          color: statusColor,
                                                          fontWeight:
                                                              FontWeight.w800,
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  if (activity.finishedAt !=
                                                      null) ...[
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      _fmtTime(
                                                        activity.finishedAt!,
                                                      ),
                                                      style: TextStyle(
                                                        color: statusColor,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        fontSize: 11,
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: SaoColors.gray50,
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            border: Border.all(
                                              color: SaoColors.gray200,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(
                                                Icons.location_on_outlined,
                                                size: 16,
                                                color: SaoColors.gray600,
                                              ),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Text(
                                                  location.isEmpty
                                                      ? 'Sin ubicacion registrada'
                                                      : location,
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    color: SaoColors.gray800,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 6,
                                          children: [
                                            _metaChip(
                                              icon: Icons.apartment_rounded,
                                              label: 'Proyecto',
                                              value: _displayProject(
                                                activity.projectId,
                                              ),
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
                                            Icon(
                                              Icons.circle,
                                              size: 10,
                                              color: statusColor,
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                statusLabel,
                                                style: TextStyle(
                                                  color: statusColor,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                            const Text(
                                              'Ver detalle',
                                              style: TextStyle(
                                                color: SaoColors.gray500,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 12,
                                              ),
                                            ),
                                            const SizedBox(width: 2),
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
