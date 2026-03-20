// lib/features/home/home_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../core/catalog/state/catalog_providers.dart';
import '../../core/connectivity/offline_mode_controller.dart';
import '../../core/constants.dart';
import '../../core/network/api_client.dart';
import '../../core/sync/sync_orchestrator.dart';
import '../../data/local/app_db.dart';
import '../../data/local/dao/activity_dao.dart';
import '../auth/application/auth_providers.dart';
import '../agenda/data/assignments_dao.dart';
import '../agenda/data/assignments_repository.dart';
import '../agenda/data/users_dao.dart';
import '../agenda/data/users_repository.dart';
import '../agenda/models/resource.dart';
import '../sync/data/sync_provider.dart';
import '../../core/utils/logger.dart';
import '../../ui/theme/sao_colors.dart';
import '../../core/utils/snackbar.dart';
import 'models/today_activity.dart';

enum FilterMode {
  totales,
  vencidas,
  completadas,
}

class _HomeNotification {
  final TodayActivity activity;
  final String title;
  final String message;
  final IconData icon;
  final Color color;
  final int priority;

  const _HomeNotification({
    required this.activity,
    required this.title,
    required this.message,
    required this.icon,
    required this.color,
    required this.priority,
  });
}

class HomePage extends ConsumerStatefulWidget {
  final String selectedProject;
  final VoidCallback onTapProject;

  const HomePage({
    super.key,
    required this.selectedProject,
    required this.onTapProject,
  });

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  // ====== Estado de datos (MUTABLE) ======
  List<TodayActivity> _items = [];
  bool _loadingActivities = true;

  // ====== UI State ======
  String _query = '';
  final TextEditingController _searchCtrl = TextEditingController();
  final Map<String, bool> _expandedByFrente = {};

  // Filtros interactivos
  FilterMode _filterMode = FilterMode.totales;

  static const _filterModeKey = 'home_filter_mode';

  // ====== Estado de ejecución usando ExecutionState ======
  bool _isAdminViewer = false;
  // Default: filterrar por asignado al usuario (seguro por defecto) hasta que se resuelva el rol.
  bool _isOperativeViewer = true;

  // DAO único — evita instanciar en cada método
  late final ActivityDao _dao;
  late final AgendaUsersRepository _agendaUsersRepository;
  late final AssignmentsRepository _assignmentsRepository;
  final Set<String> _transferringActivityIds = <String>{};

  @override
  void initState() {
    super.initState();
    final db = GetIt.I<AppDb>();
    _dao = ActivityDao(db);
    _agendaUsersRepository = AgendaUsersRepository(
      apiClient: GetIt.I<ApiClient>(),
      usersDao: UsersDao(db),
    );
    _assignmentsRepository = AssignmentsRepository(
      apiClient: GetIt.I<ApiClient>(),
      localStore: AssignmentsDao(db),
      database: db,
    );
    // Persist active project so sync pull can use it from the sync center.
    if (widget.selectedProject.trim().toUpperCase() != kAllProjects) {
      // ignore: unawaited_futures
      ref.read(kvStoreProvider).setString('selected_project', widget.selectedProject);
    }
    // ignore: unawaited_futures
    ref.read(offlineModeProvider.notifier).load();
    // ignore: unawaited_futures
    _loadFilterMode();
    // ignore: unawaited_futures
    _loadHomeActivities();

    // ignore: unawaited_futures
    _resolveViewerRole();
  }

  Future<void> _loadFilterMode() async {
    final stored = await ref.read(kvStoreProvider).getString(_filterModeKey);
    if (!mounted || stored == null) return;
    final mode = FilterMode.values.firstWhere(
      (m) => m.name == stored,
      orElse: () => FilterMode.totales,
    );
    if (mode != _filterMode) setState(() => _filterMode = mode);
  }

  Future<void> _setFilterMode(FilterMode mode) {
    setState(() => _filterMode = mode);
    return ref.read(kvStoreProvider).setString(_filterModeKey, mode.name);
  }

  Future<void> _resolveViewerRole() async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      if (!mounted) return;
      setState(() {
        _isAdminViewer = false;
        _isOperativeViewer = false;
      });
      // initState already triggers _loadHomeActivities — no need to repeat here.
      return;
    }

    final db = GetIt.I<AppDb>();
    final localUser = await (db.select(db.users)..where((t) => t.id.equals(user.id))).getSingleOrNull();
    final role = localUser == null
        ? null
        : await (db.select(db.roles)..where((t) => t.id.equals(localUser.roleId))).getSingleOrNull();
    final isAdminByRole = localUser?.roleId == 1;
    final hasKnownRole = localUser != null;
    final isOperativeByRole = localUser?.roleId == 4 ||
      role?.name.trim().toUpperCase() == 'OPERATIVO';
    final email = user.email.trim().toLowerCase();
    final isAdminByEmail = email == 'admin@sao.mx' || email.startsWith('admin.');

    if (!mounted) return;
    final nextIsAdmin = isAdminByRole || isAdminByEmail;
    // Least-privilege fallback: if role cannot be resolved locally and user is not admin,
    // keep strict assignee filtering to avoid exposing activities from other operatives.
    final nextIsOperative = hasKnownRole ? isOperativeByRole : !nextIsAdmin;
    final changed =
        nextIsAdmin != _isAdminViewer || nextIsOperative != _isOperativeViewer;
    setState(() {
      _isAdminViewer = nextIsAdmin;
      _isOperativeViewer = nextIsOperative;
    });

    if (changed) {
      await _loadHomeActivities();
    }
  }

  /// Devuelve el estado actual de una actividad desde _items (puede ser optimista).
  TodayActivity? _findById(String id) {
    for (final item in _items) {
      if (item.id == id) return item;
    }
    return null;
  }

  /// Actualiza una actividad en _items in-place (actualización optimista).
  void _updateItem(String id, TodayActivity updated) {
    final idx = _items.indexWhere((i) => i.id == id);
    if (idx != -1) _items[idx] = updated;
  }

  /// Número de actividades vencidas — derivado de _items, siempre consistente.
  int get _urgentCount => _items.where((a) => a.status == ActivityStatus.vencida).length;

  List<_HomeNotification> _buildNotifications() {
    final notifications = <_HomeNotification>[];

    for (final activity in _items) {
      if (activity.isRejected) {
        notifications.add(
          _HomeNotification(
            activity: activity,
            title: 'Actividad rechazada',
            message: '${activity.title} • Requiere correccion',
            icon: Icons.cancel_rounded,
            color: SaoColors.riskHigh,
            priority: 1,
          ),
        );
      }

      if (activity.status == ActivityStatus.vencida) {
        notifications.add(
          _HomeNotification(
            activity: activity,
            title: 'Actividad vencida',
            message: '${activity.title} • ${activity.frente}',
            icon: Icons.warning_amber_rounded,
            color: SaoColors.error,
            priority: 0,
          ),
        );
      }

      if (!activity.isRejected &&
          activity.executionState == ExecutionState.revisionPendiente) {
        notifications.add(
          _HomeNotification(
            activity: activity,
            title: 'Captura incompleta',
            message: '${activity.title} • Requiere completar formulario',
            icon: Icons.edit_note_rounded,
            color: SaoColors.warning,
            priority: 1,
          ),
        );
      }

      if (activity.syncState == ActivitySyncState.error) {
        notifications.add(
          _HomeNotification(
            activity: activity,
            title: 'Error de sincronizacion',
            message: '${activity.title} • Reintentar sync',
            icon: Icons.cloud_off_rounded,
            color: SaoColors.riskHigh,
            priority: 2,
          ),
        );
      }
    }

    notifications.sort((a, b) {
      final priorityCompare = a.priority.compareTo(b.priority);
      if (priorityCompare != 0) return priorityCompare;
      return b.activity.createdAt.compareTo(a.activity.createdAt);
    });

    return notifications;
  }

  int get _notificationCount => _buildNotifications().length;

  Future<void> _openNotificationsCenter() async {
    final notifications = _buildNotifications();

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.notifications_active_rounded, color: SaoColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Notificaciones (${notifications.length})',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (notifications.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Text('Sin alertas por ahora. Todo en orden.'),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: notifications.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = notifications[index];
                        return ListTile(
                          dense: true,
                          leading: Icon(item.icon, color: item.color),
                          title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text(item.message),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () async {
                            Navigator.pop(ctx);
                            if (!mounted) return;

                            if (_isAdminViewer) {
                              await context.push(
                                '/activity/${item.activity.id}?project=${widget.selectedProject}',
                                extra: item.activity,
                              );
                            } else {
                              await _openRegisterWizard(item.activity);
                            }
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _loadHomeActivities() async {
    setState(() {
      _loadingActivities = true;
    });

    try {
      final effectiveProject = _isAdminViewer ? kAllProjects : widget.selectedProject;
      final rows = await _dao.listHomeActivitiesByProject(effectiveProject);
      final currentUserId = ref.read(currentUserProvider)?.id.trim().toLowerCase();
        final filteredRows = _isOperativeViewer
          ? ((currentUserId?.isNotEmpty ?? false)
            ? rows.where((row) {
              final assignedTo = row.assignedToUserId?.trim().toLowerCase();
              return assignedTo != null &&
                assignedTo.isNotEmpty &&
                assignedTo == currentUserId;
            }).toList()
            : <HomeActivityRecord>[])
          : rows;
      final items = filteredRows.map(_toTodayActivity).toList();

      if (!mounted) return;
      setState(() {
        _items = items;
        _loadingActivities = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingActivities = false;
      });
    }
  }

  bool _canTransferResponsibility(TodayActivity activity) {
    if (!_isOperativeViewer || _isAdminViewer) {
      return false;
    }
    if (ref.read(offlineModeProvider)) {
      return false;
    }
    if (activity.executionState == ExecutionState.terminada) {
      return false;
    }

    final currentUserId = ref.read(currentUserProvider)?.id.trim().toLowerCase();
    final assignedTo = activity.assignedToUserId?.trim().toLowerCase();
    if (currentUserId == null || currentUserId.isEmpty || assignedTo == null || assignedTo.isEmpty) {
      return false;
    }
    return currentUserId == assignedTo;
  }

  Future<void> _openTransferResponsibilitySheet(TodayActivity activity) async {
    if (!_canTransferResponsibility(activity)) {
      return;
    }

    final projectId = widget.selectedProject.trim();
    if (projectId.isEmpty || projectId.toUpperCase() == kAllProjects) {
      if (!mounted) return;
      showTransientSnackBar(
        context,
        appSnackBar(message: 'Selecciona un proyecto para transferir la responsabilidad.'),
      );
      return;
    }

    List<Resource> resources;
    try {
      resources = await _agendaUsersRepository.getOperationalUsers(
        projectId: projectId,
        isOffline: false,
      );
    } catch (_) {
      if (!mounted) return;
      showTransientSnackBar(
        context,
        appSnackBar(message: 'No se pudo cargar el equipo operativo para transferir.'),
      );
      return;
    }

    final candidates = resources
        .where((resource) => resource.isActive && resource.id != activity.assignedToUserId)
        .toList()
      ..sort((left, right) => left.name.toLowerCase().compareTo(right.name.toLowerCase()));

    if (candidates.isEmpty) {
      if (!mounted) return;
      showTransientSnackBar(
        context,
        appSnackBar(message: 'No hay otro operativo disponible para recibir la actividad.'),
      );
      return;
    }

    final selection = await showModalBottomSheet<_TransferSelection>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _TransferResponsibilitySheet(
        activity: activity,
        candidates: candidates,
      ),
    );

    if (selection == null) {
      return;
    }

    await _transferResponsibility(activity, selection.resource, selection.reason);
  }

  Future<void> _transferResponsibility(
    TodayActivity activity,
    Resource target,
    String? reason,
  ) async {
    setState(() {
      _transferringActivityIds.add(activity.id);
    });

    try {
      await _assignmentsRepository.transferAssignment(
        assignmentId: activity.id,
        projectId: widget.selectedProject.trim(),
        assigneeUserId: target.id,
        assigneeName: target.name,
        reason: reason,
      );
      await _loadHomeActivities();

      if (!mounted) return;
      showTransientSnackBar(
        context,
        appSnackBar(
          message: 'Responsabilidad transferida a ${target.name}',
          backgroundColor: SaoColors.success,
        ),
      );
    } catch (e, st) {
      appLogger.w('No se pudo transferir la actividad ${activity.id}: $e\n$st');
      if (!mounted) return;
      showTransientSnackBar(
        context,
        appSnackBar(
          message: 'No se pudo transferir la actividad. Intenta de nuevo.',
          backgroundColor: SaoColors.error,
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _transferringActivityIds.remove(activity.id);
      });
    }
  }

  TodayActivity _toTodayActivity(HomeActivityRecord row) {
    final activity = row.activity;
    final executionState = _executionStateFromRow(activity);
    final hasAssignee = (row.assignedToUserId?.trim().isNotEmpty ?? false);
    final activityName = row.activityTypeName?.trim();
    final legacyTitle = _stripLegacyTitlePrefixes(activity.title);
    final preferredTitle = (activityName?.isNotEmpty ?? false)
      ? activityName!
      : legacyTitle;
    final title = _isLikelyActivityCode(preferredTitle)
      ? _humanizeActivityCode(preferredTitle)
      : preferredTitle;

    final normalizedSegment = _normalizeDisplayValue(row.segmentName);
    final normalizedFront = _normalizeDisplayValue(row.frontName);
    final legacyMunicipio = _normalizeDisplayValue(
      _extractLegacyTaggedValue(activity.title, 'Municipio'),
    );
    final legacyEstado = _normalizeDisplayValue(
      _extractLegacyTaggedValue(activity.title, 'Estado'),
    );
    final normalizedMunicipio =
      _normalizeDisplayValue(row.municipio) ?? legacyMunicipio;
    final normalizedEstado =
      _normalizeDisplayValue(row.estado) ?? legacyEstado;

    return TodayActivity(
      id: activity.id,
      title: title,
      frente: normalizedSegment ?? normalizedFront ?? 'Sin frente',
      municipio: normalizedMunicipio ?? '',
      estado: normalizedEstado ?? '',
      pk: activity.pk,
      status: _statusFromRow(
        activity,
        executionState,
        isAssigned: hasAssignee,
      ),
      createdAt: activity.createdAt,
      executionState: executionState,
      horaInicio: activity.startedAt,
      horaFin: activity.finishedAt,
      isUnplanned: row.isUnplanned,
      isRejected: activity.status == 'RECHAZADA',
      syncState: _syncStateFromRow(activity),
      assignedToUserId: row.assignedToUserId,
      assignedToName: row.assignedToName,
    );
  }

  String _stripLegacyTitlePrefixes(String rawTitle) {
    final trimmed = rawTitle.trim();
    if (trimmed.isEmpty) return 'Actividad';

    final lowered = trimmed.toLowerCase();
    if (lowered.startsWith('frente:') ||
        lowered.startsWith('estado:') ||
        lowered.startsWith('municipio:')) {
      return 'Actividad';
    }
    return trimmed;
  }

  String? _normalizeDisplayValue(String? rawValue) {
    final value = rawValue?.trim() ?? '';
    if (value.isEmpty) return null;
    final normalized = value.toLowerCase();
    if (normalized == 'sin frente' ||
        normalized == 'sin ubicación' ||
        normalized == 'sin ubicacion' ||
        normalized == 'sin municipio' ||
        normalized == 'sin estado') {
      return null;
    }
    return value;
  }

  bool _isLikelyActivityCode(String value) {
    final compact = value.trim();
    if (compact.isEmpty) return false;
    return RegExp(r'^[A-Z]{2,6}$').hasMatch(compact);
  }

  String _humanizeActivityCode(String rawCode) {
    final code = rawCode.trim().toUpperCase();
    const known = <String, String>{
      'REU': 'Reunion',
      'CAM': 'Caminamiento',
      'INS': 'Inspeccion',
      'SUP': 'Supervision',
    };
    return known[code] ?? 'Actividad';
  }

  String? _extractLegacyTaggedValue(String rawTitle, String key) {
    final source = rawTitle.replaceAll('•', ' ').trim();
    final lower = source.toLowerCase();
    final keyPrefix = '${key.toLowerCase()}:';
    final start = lower.indexOf(keyPrefix);
    if (start == -1) return null;

    final contentStart = start + keyPrefix.length;
    var end = source.length;
    const markers = <String>['frente:', 'estado:', 'municipio:'];
    for (final marker in markers) {
      if (marker == keyPrefix) continue;
      final idx = lower.indexOf(marker, contentStart);
      if (idx != -1 && idx < end) {
        end = idx;
      }
    }

    final value = source.substring(contentStart, end).trim();
    return value.isEmpty ? null : value;
  }

  ActivitySyncState _syncStateFromRow(Activity activity) {
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

  ExecutionState _executionStateFromRow(Activity activity) {
    // Si está cancelada, no mostrar (puedes filtrar en el DAO si lo prefieres)
    if (activity.status == 'CANCELED') {
      return ExecutionState.pendiente; // O filtrar en el DAO
    }
    if (activity.status == 'REVISION_PENDIENTE') {
      return ExecutionState.revisionPendiente;
    }
    if (activity.status == 'RECHAZADA') {
      return ExecutionState.revisionPendiente;
    }
    if (activity.finishedAt != null) {
      return ExecutionState.terminada;
    }
    if (activity.startedAt != null) {
      return ExecutionState.enCurso;
    }

    if (activity.status == 'DRAFT') {
      return ExecutionState.pendiente;
    }

    return ExecutionState.pendiente;
  }

  ActivityStatus _statusFromRow(
    Activity activity,
    ExecutionState executionState, {
    required bool isAssigned,
  }) {
    if (isAssigned && executionState == ExecutionState.pendiente) {
      // Admin view should start as "Asignada" until operativo advances it.
      return ActivityStatus.programada;
    }
    // Una actividad terminada NO debe mostrarse como vencida aunque su createdAt
    // sea anterior a hoy — ya está completada.
    if (executionState == ExecutionState.terminada) {
      return ActivityStatus.programada;
    }
    if (activity.status == 'RECHAZADA') {
      return ActivityStatus.vencida;
    }
    if (executionState == ExecutionState.revisionPendiente) {
      return ActivityStatus.vencida;
    }
    final created = activity.createdAt;
    final today = DateTime.now();
    final createdDay = DateTime(created.year, created.month, created.day);
    final todayDay = DateTime(today.year, today.month, today.day);
    if (createdDay.isBefore(todayDay)) {
      return ActivityStatus.vencida;
    }
    if (createdDay.isAtSameMomentAs(todayDay)) {
      return ActivityStatus.hoy;
    }
    return ActivityStatus.programada;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ====== Helpers visuales ======
  Color _statusColor(ActivityStatus s) {
    switch (s) {
      case ActivityStatus.vencida:
        return SaoColors.error;
      case ActivityStatus.hoy:
        return SaoColors.warning;
      case ActivityStatus.programada:
        return SaoColors.gray400;
    }
  }

  IconData _statusIcon(ActivityStatus s) {
    switch (s) {
      case ActivityStatus.vencida:
        return Icons.warning_amber_rounded;
      case ActivityStatus.hoy:
        return Icons.schedule_rounded;
      case ActivityStatus.programada:
        return Icons.event_available_rounded;
    }
  }

  String _statusText(ActivityStatus s) {
    switch (s) {
      case ActivityStatus.vencida:
        return 'Venció ayer';
      case ActivityStatus.hoy:
        return 'Vence hoy';
      case ActivityStatus.programada:
        return 'Asignada';
    }
  }

  String _effectiveFooterText(String activityId, ActivityStatus originalStatus) {
    final activity = _findById(activityId);
    if (activity == null) return _statusText(originalStatus);
    switch (activity.executionState) {
      case ExecutionState.pendiente:
        return _statusText(originalStatus);
      case ExecutionState.enCurso:
        if (activity.horaInicio != null) {
          final t = _fmtTime(activity.horaInicio!);
          return 'En curso • Iniciada $t';
        }
        return 'En curso';
      case ExecutionState.revisionPendiente:
        if (activity.isRejected) {
          return 'Rechazada • Requiere correccion';
        }
        if (activity.horaInicio != null && activity.horaFin != null) {
          final start = _fmtTime(activity.horaInicio!);
          final end = _fmtTime(activity.horaFin!);
          return '⚠️ Captura Incompleta • $start–$end';
        }
        return '⚠️ Captura Incompleta';
      case ExecutionState.terminada:
        final syncLabel = switch (activity.syncState) {
          ActivitySyncState.synced => 'Sincronizada',
          ActivitySyncState.pending => 'Pendiente de sincronizar',
          ActivitySyncState.error => 'Error de sincronizacion',
          ActivitySyncState.unknown => 'Sin estado de sync',
        };
        if (activity.horaInicio != null && activity.horaFin != null) {
          final start = _fmtTime(activity.horaInicio!);
          final end = _fmtTime(activity.horaFin!);
          return 'Terminada • $start-$end • $syncLabel';
        }
        return 'Terminada • $syncLabel';
    }
  }

  String _formatPk(int? pk) {
    if (pk == null) return '';
    final km = pk ~/ 1000;
    final m = pk % 1000;
    return "$km+${m.toString().padLeft(3, '0')}";
  }

  bool _matchesQuery(TodayActivity a, String q) {
    final s = q.trim().toLowerCase();
    if (s.isEmpty) return true;

    final pkText = a.pk == null ? '' : _formatPk(a.pk).toLowerCase();
    final pkDigits = a.pk?.toString() ?? '';

    return a.title.toLowerCase().contains(s) ||
        a.frente.toLowerCase().contains(s) ||
        a.municipio.toLowerCase().contains(s) ||
        a.estado.toLowerCase().contains(s) ||
        pkText.contains(s) ||
        pkDigits.contains(s);
  }

  // ====== Wizard: abre el FORMULARIO real (data-driven) ======
  Future<bool?> _openRegisterWizard(TodayActivity a) async {
    final isTutorialGuest = GoRouterState.of(context).uri.queryParameters['tutorial'] == '1';
    if (isTutorialGuest) {
      showTransientSnackBar(
        context,
        appSnackBar(
          message: 'Modo tutorial: en operación real aqui se abre el wizard para capturar y guardar.',
          backgroundColor: SaoColors.info,
        ),
      );
      return false;
    }

    // Pasar la actividad con las horas ya registradas
    final currentActivity = _findById(a.id) ?? a;
    final result = await context.push(
      '/activity/${a.id}/wizard?project=${widget.selectedProject}',
      extra: currentActivity,
    );
    // result puede ser el ID de la actividad guardada o null si canceló
    final saved = result != null;
    if (saved) {
      await _loadHomeActivities();
    }
    return saved; // true si guardó, false/null si canceló
  }

  // ====== Flujo swipe derecha ======
  // 1) PENDIENTE: marcar iniciada
  // 2) EN_CURSO: abrir wizard
  // 3) REVISION_PENDIENTE: reabrir wizard para completar captura
  void _onSwipeRight(TodayActivity a) async {
    final currentActivity = _findById(a.id) ?? a;
    
    HapticFeedback.mediumImpact();
    
    if (currentActivity.executionState == ExecutionState.pendiente) {
      // Primer swipe: solo iniciar.
      await _iniciarActividad(a);
    } else if (currentActivity.executionState == ExecutionState.enCurso) {
      // Segundo swipe: abrir wizard.
      await _abrirWizardDesdeEnCurso(a);
    } else if (currentActivity.executionState == ExecutionState.revisionPendiente) {
      if (currentActivity.isRejected) {
        showTransientSnackBar(
          context,
          appSnackBar(
            message: 'Esta actividad fue rechazada. Revisa observaciones y corrige antes de reenviar.',
            backgroundColor: SaoColors.riskHigh,
          ),
        );
        return;
      }
      // Tercer swipe (si quedo pendiente): reintentar captura.
      await _reintentarCaptura(a);
    }
  }

  Future<void> _iniciarActividad(TodayActivity a) async {
    final now = DateTime.now();
    final gps = a.gpsLocation;
    
    final updated = a.copyWith(
      executionState: ExecutionState.enCurso,
      horaInicio: now,
      gpsLocation: gps,
    );
    
    setState(() {
      _updateItem(a.id, updated);
    });

    try {
      await _dao.markActivityStarted(activityId: a.id, startedAt: now);
    } catch (_) {
      // Keep UI responsive even if local persistence fails.
    }

    if (!mounted) return;

    final t = _fmtTime(now);
    showTransientSnackBar(
      context,
      appSnackBar(
        message: 'Actividad iniciada a las $t: ${a.title}',
        backgroundColor: SaoColors.success,
      ),
    );
  }

  Future<void> _abrirWizardDesdeEnCurso(TodayActivity a) async {
    final currentActivity = _findById(a.id) ?? a;

    showTransientSnackBar(
      context,
      appSnackBar(
        message: 'Abriendo formulario de captura...',
        backgroundColor: SaoColors.info,
      ),
    );

    final guardadoExitoso = await _openRegisterWizard(currentActivity);
    if (!mounted) return;

    if (guardadoExitoso == true) {
      DateTime finishedAt = DateTime.now();
      try {
        final existing = await _dao.getActivityById(a.id);
        if (existing?.finishedAt != null) {
          finishedAt = existing!.finishedAt!;
        } else {
          await _dao.markActivityFinished(activityId: a.id, finishedAt: finishedAt);
        }
      } catch (_) {
        // Fallback to in-memory finished timestamp.
      }

      final completedActivity = currentActivity.copyWith(
        executionState: ExecutionState.terminada,
        horaFin: finishedAt,
      );
      setState(() {
        _updateItem(a.id, completedActivity);
      });

      await _loadHomeActivities();
      return;
    }

    // Si no completa wizard, pasa a pendiente de completar para el siguiente swipe.
    final now = DateTime.now();
    final pendingCapture = currentActivity.copyWith(
      executionState: ExecutionState.revisionPendiente,
      horaFin: now,
    );
    setState(() {
      _updateItem(a.id, pendingCapture);
    });

    // Persistir estado en DB para que sobreviva recargas
    try {
      await _dao.markActivityRevisionPendiente(activityId: a.id, finishedAt: now);
    } catch (e, st) {
      appLogger.w(
        'No se pudo persistir REVISION_PENDIENTE para activity=${a.id}: $e\n$st',
      );
    }

    final startTxt = pendingCapture.horaInicio != null ? _fmtTime(pendingCapture.horaInicio!) : '?';
    final endTxt = _fmtTime(now);
    showTransientSnackBar(
      context,
      appSnackBar(
        message: 'Pendiente de completar captura ($startTxt-$endTxt).',
        backgroundColor: SaoColors.warning,
      ),
    );
  }

  Future<void> _reintentarCaptura(TodayActivity a) async {
    showTransientSnackBar(
      context,
      appSnackBar(
        message: 'Re-abriendo formulario para completar captura...',
        backgroundColor: SaoColors.info,
      ),
    );
    
    final guardadoExitoso = await _openRegisterWizard(a);
    if (!mounted) return;
    
    if (guardadoExitoso == true) {
      final currentActivity = _findById(a.id) ?? a;
      final completedActivity = currentActivity.copyWith(
        executionState: ExecutionState.terminada,
      );
      setState(() {
        _updateItem(a.id, completedActivity);
      });
    }
  }

  // ====== Swipe izquierda: Incidencia/Bloqueo ======
  Future<void> _reportIncident(TodayActivity a) async {
    final reason = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text('Reportar incidencia', style: TextStyle(fontWeight: FontWeight.w900)),
              subtitle: Text('Selecciona un motivo rápido (sin llenar todo el formulario)'),
            ),
            const Divider(height: 0),
            ...['Clima', 'Acceso denegado', 'Riesgo', 'Cancelada'].map((r) {
              final icon = switch (r) {
                'Clima' => Icons.cloud_rounded,
                'Acceso denegado' => Icons.lock_rounded,
                'Riesgo' => Icons.warning_rounded,
                _ => Icons.cancel_rounded,
              };
              return ListTile(
                leading: Icon(icon),
                title: Text(r),
                onTap: () => Navigator.pop(ctx, r),
              );
            }),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );

    if (reason == null) return;
    if (!mounted) return;

    // ✅ Obtener la actividad actualizada del estado (con horaInicio/horaFin preservados)
    final currentActivity = _findById(a.id) ?? a;
    
    // Marcar como incidencia - resetea el estado a pendiente pero conserva tiempos
    final updated = currentActivity.copyWith(
      executionState: ExecutionState.pendiente,
    );
    
    setState(() {
      _updateItem(a.id, updated);
    });

    showTransientSnackBar(
      context,
      appSnackBar(
        message: 'Incidencia registrada: $reason',
        backgroundColor: SaoColors.riskHigh,
      ),
    );
  }

  // ====== Colores / iconos / textos efectivos basados en ExecutionState ======
  Color _effectiveBarColor(String activityId, ActivityStatus originalStatus) {
    final activity = _findById(activityId);
    if (activity == null) return _statusColor(originalStatus);
    
    switch (activity.executionState) {
      case ExecutionState.pendiente:
        return _statusColor(originalStatus); // Color según vencida/hoy/programada
      case ExecutionState.enCurso:
        return SaoColors.success; // Verde - En curso
      case ExecutionState.revisionPendiente:
        if (activity.isRejected) return SaoColors.riskHigh;
        return SaoColors.warning; // Ámbar - Necesita captura
      case ExecutionState.terminada:
        return SaoColors.success; // Verde oscuro - Completada
    }
  }

  IconData _effectiveIcon(String activityId, ActivityStatus originalStatus) {
    final activity = _findById(activityId);
    if (activity == null) return _statusIcon(originalStatus);
    
    switch (activity.executionState) {
      case ExecutionState.pendiente:
        return _statusIcon(originalStatus);
      case ExecutionState.enCurso:
        return Icons.play_circle_fill_rounded;
      case ExecutionState.revisionPendiente:
        if (activity.isRejected) return Icons.cancel_rounded;
        return Icons.edit_note_rounded;
      case ExecutionState.terminada:
        return Icons.verified_rounded;
    }
  }

  Future<void> _syncCompletedActivity(TodayActivity activity) async {
    final isOffline = ref.read(offlineModeProvider);
    final syncState = ref.read(syncOrchestratorProvider);

    await _handleCloudAction(isOffline: isOffline, isSyncing: syncState.isSyncing);
    await _loadHomeActivities();

    if (!mounted) return;
    showTransientSnackBar(
      context,
      appSnackBar(message: 'Sincronizacion ejecutada para ${activity.title}'),
    );
  }

  // ====== Utils ======
  String _fmtTime(DateTime dt) =>
      "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";

  String _fmtDateTime(DateTime dt) =>
      "${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${_fmtTime(dt)}";

  void _clearSearch() {
    setState(() {
      _query = '';
      _searchCtrl.clear();
    });
  }

  Future<void> _handleCloudAction({
    required bool isOffline,
    required bool isSyncing,
  }) async {
    if (widget.selectedProject.trim().toUpperCase() == kAllProjects) {
      if (!mounted) return;
      showTransientSnackBar(
        context,
        appSnackBar(message: 'Selecciona un proyecto especifico para sincronizar.'),
      );
      return;
    }

    if (isSyncing) {
      if (!mounted) return;
      showTransientSnackBar(
        context,
        appSnackBar(message: 'Sincronizacion en progreso...'),
      );
      return;
    }

    if (isOffline) {
      await ref.read(offlineModeProvider.notifier).setOffline(false);
    }

    try {
      await ref.read(syncOrchestratorProvider.notifier).syncAll(
            projectId: widget.selectedProject,
          );
      await _loadHomeActivities();
    } catch (_) {
      if (!mounted) return;
      showTransientSnackBar(
        context,
        appSnackBar(message: 'Error al sincronizar con backend'),
      );
    }
  }

  void _openPendingEvidenceCenter() {
    final project = widget.selectedProject.trim().toUpperCase();
    if (project == kAllProjects) {
      context.push('/sync');
      return;
    }
    final encodedProject = Uri.encodeQueryComponent(project);
    context.push(
      '/sync?project=$encodedProject&pending_project=$encodedProject',
    );
  }

  void _showSyncStatusSheet(SyncOrchestratorState state) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final statusLabel = switch (state.status) {
          SyncOrchestratorStatus.success => 'Éxito',
          SyncOrchestratorStatus.error => 'Error',
          SyncOrchestratorStatus.syncing => 'Sincronizando',
          SyncOrchestratorStatus.idle => 'Idle',
        };
        final timestamp = state.updatedAt == null ? 'N/A' : _fmtDateTime(state.updatedAt!);

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Estado de sincronización',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 12),
                Text('Último estado: $statusLabel'),
                const SizedBox(height: 6),
                Text('Timestamp: $timestamp'),
                const SizedBox(height: 6),
                const Text('Pendientes: N/A'),
                if (state.errorMessage != null && state.errorMessage!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    state.errorMessage!,
                    style: const TextStyle(color: SaoColors.error),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isOffline = ref.watch(offlineModeProvider);
    final syncState = ref.watch(syncOrchestratorProvider);
    final pendingEvidenceAsync = ref.watch(pendingEvidenceActivitiesProvider);
    final pendingEvidenceCount = pendingEvidenceAsync.valueOrNull?.length ?? 0;
    final isSyncing = syncState.status == SyncOrchestratorStatus.syncing;
    final hasSyncError = syncState.status == SyncOrchestratorStatus.error;

    ref.listen<SyncOrchestratorState>(syncOrchestratorProvider, (previous, next) {
      if (!mounted) return;
      final wasSyncing = previous?.status == SyncOrchestratorStatus.syncing;
      if (wasSyncing && next.status == SyncOrchestratorStatus.success) {
        showTransientSnackBar(
          context,
          appSnackBar(
            message: 'Sincronizacion completada',
            duration: const Duration(seconds: 3),
          ),
        );
      }
      if (wasSyncing && next.status == SyncOrchestratorStatus.error) {
        showTransientSnackBar(
          context,
          appSnackBar(
            message: 'Error al sincronizar',
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Detalles',
              onPressed: () => _showSyncStatusSheet(next),
            ),
          ),
        );
      }
    });

    final cloudIcon = isSyncing
        ? Icons.cloud_upload_rounded
        : (hasSyncError || isOffline)
            ? Icons.cloud_off_rounded
            : Icons.cloud_done_rounded;
    final cloudTooltip = isSyncing
        ? 'Sincronizando…'
        : hasSyncError
            ? 'Error de sync'
            : isOffline
                ? 'Offline'
                : 'Online';
    final cloudColor = isSyncing
        ? SaoColors.info
        : hasSyncError
            ? SaoColors.error
            : isOffline
                ? SaoColors.gray400
                : SaoColors.success;
    final isTutorialGuest = GoRouterState.of(context).uri.queryParameters['tutorial'] == '1';
    final currentUser = ref.watch(currentUserProvider);
    final userInitial = currentUser?.fullName.trim().isNotEmpty == true
        ? currentUser!.fullName.trim()[0].toUpperCase()
        : '?';

    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final sevenDaysAgo = todayDate.subtract(const Duration(days: 7));
    final baseItems = _isAdminViewer
        ? _items.where((a) {
            final assigned =
                a.assignedToUserId != null && a.assignedToUserId!.trim().isNotEmpty;
            if (!assigned) return false;
            final created = DateTime(a.createdAt.year, a.createdAt.month, a.createdAt.day);
            // Show today's activities + terminated activities from last 7 days
            if (created == todayDate) return true;
            if (a.executionState == ExecutionState.terminada &&
                !created.isBefore(sevenDaysAgo)) return true;
            return false;
          }).toList()
        : _items;

    // ====== Filtrado por búsqueda ======
    var filtered = baseItems.where((a) => _matchesQuery(a, _query)).toList();
    
    // ====== Filtrado por modo (Totales / Vencidas) ======
    if (_filterMode == FilterMode.vencidas) {
      filtered = filtered.where((a) => a.status == ActivityStatus.vencida).toList();
    } else if (_filterMode == FilterMode.completadas) {
      filtered = filtered.where((a) => a.executionState == ExecutionState.terminada).toList();
    }

    // ====== Agrupado ======
    final grouped = <String, List<TodayActivity>>{};
    for (final a in filtered) {
      grouped.putIfAbsent(a.frente, () => []).add(a);
    }
    for (final k in grouped.keys) {
      _expandedByFrente.putIfAbsent(k, () => true);
    }

    // Regla anti doble cabecera:
    final showFrenteInsideCard = _query.trim().isNotEmpty;

    final totalCount = baseItems.where((a) => _matchesQuery(a, _query)).length;
    final vencidasCount = baseItems
      .where((a) => _matchesQuery(a, _query) && a.status == ActivityStatus.vencida)
      .length;
    final completadasCount = baseItems
      .where((a) => _matchesQuery(a, _query) && a.executionState == ExecutionState.terminada)
      .length;

    return Scaffold(
      backgroundColor: SaoColors.gray50,
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: 'fab_report_event',
            tooltip: 'Actividad no planeada',
            backgroundColor: SaoColors.riskHigh,
            foregroundColor: Colors.white,
            onPressed: () async {
              final result = await context.push(
                '/wizard/register?project=${widget.selectedProject}&mode=unplanned',
              );
              if (result != null) {
                await _loadHomeActivities();
              }
            },
            child: const Icon(Icons.warning_rounded),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: SaoColors.surface,
            surfaceTintColor: SaoColors.surface,
            elevation: 0,
            scrolledUnderElevation: 0,
            pinned: true,
            floating: true,
            snap: true,
            titleSpacing: 12,
            title: Row(
              children: [
                GestureDetector(
                  onTap: () => context.push('/profile'),
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: SaoColors.gray100,
                    child: Text(
                      userInitial,
                      style: const TextStyle(fontWeight: FontWeight.w900, color: SaoColors.primary),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: widget.onTapProject,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Proyecto: ${widget.selectedProject}',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: SaoColors.primary,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.chevron_right_rounded, color: SaoColors.gray500),
                        ],
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: cloudTooltip,
                  onPressed: () async => _handleCloudAction(
                    isOffline: isOffline,
                    isSyncing: isSyncing,
                  ),
                  icon: Icon(
                    cloudIcon,
                    color: cloudColor,
                  ),
                ),
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      tooltip: 'Pendientes por completar',
                      onPressed: _openPendingEvidenceCenter,
                      icon: const Icon(
                        Icons.assignment_late_outlined,
                        color: SaoColors.warning,
                      ),
                    ),
                    if (pendingEvidenceCount > 0)
                      Positioned(
                        right: 6,
                        top: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: SaoColors.error,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: SaoColors.surface, width: 1.5),
                          ),
                          constraints: const BoxConstraints(minWidth: 18),
                          child: Text(
                            pendingEvidenceCount > 99
                                ? '99+'
                                : '$pendingEvidenceCount',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      tooltip: 'Notificaciones',
                      onPressed: _openNotificationsCenter,
                      icon: const Icon(Icons.notifications_none_rounded, color: SaoColors.primary),
                    ),
                    if (_notificationCount > 0)
                      Positioned(
                        right: 10,
                        top: 10,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: SaoColors.error,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: SaoColors.surface, width: 2),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(108),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Column(
                  children: [
                    // Buscador
                    Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: SaoColors.gray100,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: SaoColors.gray200),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 12),
                          const Icon(Icons.search_rounded, color: SaoColors.gray600),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _searchCtrl,
                              onChanged: (v) => setState(() => _query = v),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                hintText: 'Buscar PK, Frente, Municipio…',
                                hintStyle: TextStyle(color: SaoColors.gray400),
                              ),
                            ),
                          ),
                          if (_query.isNotEmpty)
                            IconButton(
                              tooltip: 'Limpiar',
                              onPressed: _clearSearch,
                              icon: const Icon(Icons.close_rounded, color: SaoColors.gray600),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Métricas con selección
                    Row(
                      children: [
                        _MetricBadge(
                          label: 'Totales',
                          count: totalCount,
                          color: SaoColors.gray500,
                          isSelected: _filterMode == FilterMode.totales,
                          onTap: () => _setFilterMode(FilterMode.totales),
                        ),
                        const SizedBox(width: 10),
                        _MetricBadge(
                          label: 'Vencidas',
                          count: vencidasCount,
                          color: SaoColors.error,
                          isSelected: _filterMode == FilterMode.vencidas,
                          onTap: () => _setFilterMode(FilterMode.vencidas),
                        ),
                        const SizedBox(width: 10),
                        _MetricBadge(
                          label: 'Completadas',
                          count: completadasCount,
                          color: SaoColors.success,
                          isSelected: _filterMode == FilterMode.completadas,
                          onTap: () => _setFilterMode(FilterMode.completadas),
                        ),
                        const Spacer(),
                        IconButton(
                          tooltip: 'Ver completadas sincronizadas',
                          onPressed: () {
                            context.push(
                              '/home/completed?project=${Uri.encodeQueryComponent(widget.selectedProject)}',
                            );
                          },
                          icon: const Icon(
                            Icons.fact_check_rounded,
                            color: SaoColors.success,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          if (isTutorialGuest)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: SaoColors.infoBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: SaoColors.infoBorder),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.school_outlined, size: 18, color: SaoColors.infoIcon),
                          SizedBox(width: 6),
                          Text(
                            'Modo tutorial · Vista Inicio',
                            style: TextStyle(fontWeight: FontWeight.w700, color: SaoColors.infoText),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text('1) Asigna actividades desde Agenda (botón Asignar).'),
                      Text('2) Aquí inicia con swipe derecho cuando esté Pendiente.'),
                      Text('3) Termina con swipe derecho en En curso para abrir captura.'),
                      Text('4) Si queda en Revisión pendiente, vuelve a abrir y completa.'),
                    ],
                  ),
                ),
              ),
            ),

          if (_isAdminViewer)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => context.push('/admin/history'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: SaoColors.primary,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.history_rounded, color: SaoColors.onPrimary, size: 20),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Historial',
                                  style: TextStyle(
                                    color: SaoColors.onPrimary,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              Icon(Icons.chevron_right_rounded, color: SaoColors.onPrimary, size: 18),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => context.push('/admin/stats'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: SaoColors.actionPrimary,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.bar_chart_rounded, color: SaoColors.onPrimary, size: 20),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Estadísticas',
                                  style: TextStyle(
                                    color: SaoColors.onPrimary,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              Icon(Icons.chevron_right_rounded, color: SaoColors.onPrimary, size: 18),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Lista / Empty State
          if (_loadingActivities)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (grouped.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _EmptyState(
                title: _query.trim().isEmpty ? 'Sin actividades' : 'Sin resultados',
                subtitle: _query.trim().isEmpty
                    ? 'Todavía no hay registros para mostrar.\nCrea una nueva actividad con el botón +.'
                    : 'Prueba con otro PK, municipio o frente.',
                onClear: _query.trim().isEmpty ? null : _clearSearch,
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 120), // anti-FAB
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final frente = grouped.keys.elementAt(index);
                    final items = grouped[frente]!;
                    final expanded = _expandedByFrente[frente] ?? true;

                    return _FrenteSection(
                      frente: frente,
                      count: items.length,
                      expanded: expanded,
                      onToggle: () => setState(() => _expandedByFrente[frente] = !expanded),
                      children: expanded
                          ? items.map((a) {
                              final currentActivity = _findById(a.id) ?? a;
                              final barColor = _effectiveBarColor(a.id, a.status);
                              final icon = _effectiveIcon(a.id, a.status);
                              final footer = _effectiveFooterText(a.id, a.status);

                              return _SwipeActivityTile(
                                key: ValueKey(a.id),
                                a: a,
                                isRejected: currentActivity.isRejected,
                                executionState: currentActivity.executionState,
                                syncState: currentActivity.syncState,
                                barColor: barColor,
                                footerIcon: icon,
                                footerText: footer,
                                pkText: _formatPk(a.pk),
                                showFrenteInsideCard: showFrenteInsideCard,
                                onTapOpenWizard: _isAdminViewer
                                    ? () => context.push(
                                          '/activity/${a.id}?project=${widget.selectedProject}',
                                          extra: currentActivity,
                                        )
                                    : () => _openRegisterWizard(a),
                                onSwipeRight: () => _onSwipeRight(a),
                                onSwipeLeftIncident: () => _reportIncident(a),
                                assigneeLabel: _assigneeLabelFor(currentActivity),
                                onTransferResponsibility: _canTransferResponsibility(currentActivity)
                                    ? () => _openTransferResponsibilitySheet(currentActivity)
                                    : null,
                                transferInProgress: _transferringActivityIds.contains(a.id),
                                // Solo mostrar botón de sync si: está terminada Y aún no fue sincronizada.
                                onSyncCompleted: (currentActivity.executionState == ExecutionState.terminada &&
                                    currentActivity.syncState != ActivitySyncState.synced)
                                    ? () => _syncCompletedActivity(currentActivity)
                                    : null,
                              );
                            }).toList()
                          : const [],
                    );
                  },
                  childCount: grouped.keys.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String? _assigneeLabelFor(TodayActivity activity) {
    final name = activity.assignedToName?.trim();
    if (name != null && name.isNotEmpty && !name.startsWith('Usuario ')) {
      return name;
    }
    final currentUserId = ref.read(currentUserProvider)?.id.trim().toLowerCase();
    final assignedTo = activity.assignedToUserId?.trim().toLowerCase();
    if (currentUserId != null && currentUserId.isNotEmpty && assignedTo == currentUserId) {
      return 'Tú';
    }
    return name?.isNotEmpty == true ? name : null;
  }
}

class _TransferSelection {
  final Resource resource;
  final String? reason;

  const _TransferSelection({
    required this.resource,
    this.reason,
  });
}

class _TransferResponsibilitySheet extends StatefulWidget {
  final TodayActivity activity;
  final List<Resource> candidates;

  const _TransferResponsibilitySheet({
    required this.activity,
    required this.candidates,
  });

  @override
  State<_TransferResponsibilitySheet> createState() => _TransferResponsibilitySheetState();
}

class _TransferResponsibilitySheetState extends State<_TransferResponsibilitySheet> {
  late String _selectedResourceId;
  final TextEditingController _reasonController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedResourceId = widget.candidates.first.id;
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Transferir responsabilidad',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            widget.activity.title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: SaoColors.gray700,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Selecciona a quién transferir esta actividad.',
            style: TextStyle(fontSize: 13, color: SaoColors.gray600),
          ),
          const SizedBox(height: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: widget.candidates.length,
              itemBuilder: (context, index) {
                final candidate = widget.candidates[index];
                return RadioListTile<String>(
                  contentPadding: EdgeInsets.zero,
                  value: candidate.id,
                  groupValue: _selectedResourceId,
                  activeColor: SaoColors.primary,
                  title: Text(
                    candidate.name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(candidate.roleLabel),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _selectedResourceId = value;
                    });
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _reasonController,
            minLines: 2,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Motivo de transferencia (opcional)',
              hintText: 'Ej. cobertura de turno, apoyo en frente, cambio de ruta',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    final target = widget.candidates.firstWhere(
                      (candidate) => candidate.id == _selectedResourceId,
                    );
                    Navigator.of(context).pop(
                      _TransferSelection(
                        resource: target,
                        reason: _reasonController.text.trim().isEmpty
                            ? null
                            : _reasonController.text.trim(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.swap_horiz_rounded),
                  label: const Text('Transferir'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/* =========================
   COMPONENTES
========================= */

class _MetricBadge extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _MetricBadge({
    required this.label,
    required this.count,
    required this.color,
    this.isSelected = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isSelected ? 0.18 : 0.10),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: color.withValues(alpha: isSelected ? 0.4 : 0.18),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: color.withValues(alpha: 0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ] : null,
        ),
        child: Row(
          children: [
            Text(
              count.toString(),
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FrenteSection extends StatelessWidget {
  final String frente;
  final int count;
  final bool expanded;
  final VoidCallback onToggle;
  final List<Widget> children;

  const _FrenteSection({
    required this.frente,
    required this.count,
    required this.expanded,
    required this.onToggle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Frente: $frente',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: SaoColors.gray900),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: SaoColors.gray100,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: SaoColors.gray200),
                    ),
                    child: Text('$count', style: const TextStyle(fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(width: 8),
                  Icon(expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: SaoColors.gray600),
                ],
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

class _SwipeActivityTile extends StatelessWidget {
  final TodayActivity a;
  final bool isRejected;
  final ExecutionState executionState;
  final Color barColor;
  final ActivitySyncState syncState;
  final IconData footerIcon;
  final String footerText;
  final String pkText;
  final bool showFrenteInsideCard;
  final String? assigneeLabel;
  final VoidCallback? onTransferResponsibility;
  final bool transferInProgress;

  final VoidCallback onTapOpenWizard;
  final VoidCallback onSwipeRight;
  final VoidCallback onSwipeLeftIncident;
  final VoidCallback? onSyncCompleted;

  const _SwipeActivityTile({
    super.key,
    required this.a,
    this.isRejected = false,
    required this.executionState,
    required this.syncState,
    required this.barColor,
    required this.footerIcon,
    required this.footerText,
    required this.pkText,
    required this.showFrenteInsideCard,
    this.assigneeLabel,
    this.onTransferResponsibility,
    this.transferInProgress = false,
    required this.onTapOpenWizard,
    required this.onSwipeRight,
    required this.onSwipeLeftIncident,
    this.onSyncCompleted,
  });

  // Colores dinámicos según el estado
  Color _getSwipeColor() {
    if (isRejected) {
      return SaoColors.riskHigh;
    }
    switch (executionState) {
      case ExecutionState.pendiente:
        return SaoColors.success; // Verde - Iniciar
      case ExecutionState.enCurso:
        return SaoColors.error; // Rojo - Terminar
      case ExecutionState.revisionPendiente:
        return SaoColors.info; // Azul - Capturar
      case ExecutionState.terminada:
        return SaoColors.success; // Verde oscuro - Completada (no debería swipear)
    }
  }

  IconData _getSwipeIcon() {
    if (isRejected) {
      return Icons.cancel_rounded;
    }
    switch (executionState) {
      case ExecutionState.pendiente:
        return Icons.play_circle_fill_rounded;
      case ExecutionState.enCurso:
        return Icons.stop_circle_rounded;
      case ExecutionState.revisionPendiente:
        return Icons.edit_note_rounded;
      case ExecutionState.terminada:
        return Icons.verified_rounded;
    }
  }

  String _getSwipeLabel() {
    if (isRejected) {
      return 'Rechazada';
    }
    switch (executionState) {
      case ExecutionState.pendiente:
        return 'Iniciar';
      case ExecutionState.enCurso:
        return 'Terminar';
      case ExecutionState.revisionPendiente:
        return 'Capturar';
      case ExecutionState.terminada:
        return 'Completada';
    }
  }

  @override
  Widget build(BuildContext context) {
    final swipeColor = _getSwipeColor();
    final swipeIcon = _getSwipeIcon();
    final swipeLabel = _getSwipeLabel();

    return Dismissible(
      key: key!,
      direction: isRejected ? DismissDirection.none : DismissDirection.horizontal,

      // ✅ NO desaparece el item: usamos confirmDismiss y devolvemos false
      confirmDismiss: (dir) async {
        if (isRejected) {
          return false;
        }
        if (dir == DismissDirection.startToEnd) {
          onSwipeRight();
          return false;
        }
        if (dir == DismissDirection.endToStart) {
          onSwipeLeftIncident();
          return false;
        }
        return false;
      },

      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: swipeColor.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(
              swipeIcon,
              color: swipeColor,
            ),
            const SizedBox(width: 8),
            Text(
              swipeLabel,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: swipeColor.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),

      secondaryBackground: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: SaoColors.riskHigh.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text('Incidencia', style: TextStyle(fontWeight: FontWeight.w900, color: SaoColors.riskHigh)),
            SizedBox(width: 8),
            Icon(Icons.report_problem_rounded, color: SaoColors.riskHigh),
          ],
        ),
      ),

      child: _ActivityTile(
        a: a,
        isRejected: isRejected,
        barColor: barColor,
        footerIcon: footerIcon,
        footerText: footerText,
        pkText: pkText,
        showFrenteInsideCard: showFrenteInsideCard,
        executionState: executionState,
        syncState: syncState,
        assigneeLabel: assigneeLabel,
        onTransferResponsibility: onTransferResponsibility,
        transferInProgress: transferInProgress,
        onTap: onTapOpenWizard,
        onSyncCompleted: onSyncCompleted,
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  final TodayActivity a;
  final bool isRejected;
  final Color barColor;
  final IconData footerIcon;
  final String footerText;
  final String pkText;
  final bool showFrenteInsideCard;
  final String? assigneeLabel;
  final VoidCallback? onTransferResponsibility;
  final bool transferInProgress;
  final ExecutionState executionState;
  final ActivitySyncState syncState;
  final VoidCallback onTap;
  final VoidCallback? onSyncCompleted;

  const _ActivityTile({
    required this.a,
    this.isRejected = false,
    required this.barColor,
    required this.footerIcon,
    required this.footerText,
    required this.pkText,
    required this.showFrenteInsideCard,
    this.assigneeLabel,
    this.onTransferResponsibility,
    this.transferInProgress = false,
    required this.executionState,
    required this.syncState,
    required this.onTap,
    this.onSyncCompleted,
  });

  (String, Color, IconData) _syncBadgeMeta() {
    switch (syncState) {
      case ActivitySyncState.synced:
        return ('Sincronizada', SaoColors.success, Icons.cloud_done_rounded);
      case ActivitySyncState.pending:
        return ('Pendiente', SaoColors.warning, Icons.cloud_upload_rounded);
      case ActivitySyncState.error:
        return ('Error', SaoColors.error, Icons.cloud_off_rounded);
      case ActivitySyncState.unknown:
        return ('Sin estado', SaoColors.gray500, Icons.cloud_queue_rounded);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasPk = a.pk != null;
    final needsAttention = executionState == ExecutionState.revisionPendiente && !isRejected;
    final isActive = executionState == ExecutionState.enCurso;
    final isCompleted = executionState == ExecutionState.terminada;
    final hasAssignee = assigneeLabel != null && assigneeLabel!.trim().isNotEmpty;
    final syncMeta = _syncBadgeMeta();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isRejected
                    ? SaoColors.riskHigh
                    : needsAttention
                        ? SaoColors.riskMedium
                        : SaoColors.gray200,
                width: needsAttention ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                  color: isRejected
                      ? SaoColors.riskHigh.withValues(alpha: 0.1)
                      : needsAttention
                          ? SaoColors.riskMedium.withValues(alpha: 0.1)
                          : SaoColors.gray900.withValues(alpha: 0.04),
                ),
              ],
            ),
            child: Row(
              children: [
                _PulsingBar(
                  color: barColor,
                  height: 96,
                  isActive: isActive || needsAttention,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                a.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  color: SaoColors.gray900,
                                ),
                              ),
                            ),
                            if (a.isUnplanned)
                              Container(
                                margin: const EdgeInsets.only(right: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: SaoColors.warning.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: SaoColors.warning),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.warning_rounded, size: 12, color: SaoColors.warning),
                                    SizedBox(width: 2),
                                    Text(
                                      'No planeada',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                        color: SaoColors.warning,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (needsAttention || isRejected)
                              Container(
                                margin: const EdgeInsets.only(right: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isRejected
                                      ? SaoColors.riskHigh.withValues(alpha: 0.12)
                                      : SaoColors.riskMedium.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isRejected ? SaoColors.riskHigh : SaoColors.riskMedium,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isRejected
                                          ? Icons.cancel_rounded
                                          : Icons.edit_note_rounded,
                                      size: 12,
                                      color: SaoColors.riskHigh,
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      isRejected ? 'Rechazada' : 'Pendiente',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                        color: SaoColors.riskHigh,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (hasPk)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: SaoColors.gray100,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: SaoColors.gray200),
                                ),
                                child: Text(
                                  pkText,
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                    color: SaoColors.gray900,
                                  ),
                                ),
                              ),
                            if (transferInProgress)
                              const Padding(
                                padding: EdgeInsets.only(left: 6, top: 4),
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              )
                            else if (onTransferResponsibility != null)
                              IconButton(
                                tooltip: 'Transferir responsabilidad',
                                splashRadius: 18,
                                onPressed: onTransferResponsibility,
                                icon: const Icon(
                                  Icons.swap_horiz_rounded,
                                  size: 18,
                                  color: SaoColors.gray600,
                                ),
                              ),
                          ],
                        ),
                        if (isCompleted) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: syncMeta.$2.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                    border:
                                      Border.all(color: syncMeta.$2.withValues(alpha: 0.35)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(syncMeta.$3, size: 12, color: syncMeta.$2),
                                    const SizedBox(width: 4),
                                    Text(
                                      syncMeta.$1,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: syncMeta.$2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Spacer(),
                              TextButton.icon(
                                onPressed: onSyncCompleted,
                                icon: const Icon(Icons.sync_rounded, size: 16),
                                label: const Text('Sincronizar'),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 6),
                        if (showFrenteInsideCard) ...[
                          Text(
                            a.frente,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: SaoColors.gray700,
                            ),
                          ),
                          const SizedBox(height: 2),
                        ],
                        if (hasAssignee) ...[
                          Row(
                            children: [
                              const Icon(
                                Icons.person_pin_circle_rounded,
                                size: 14,
                                color: SaoColors.info,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'Asignada a: ${assigneeLabel!}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: SaoColors.info,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                        ],
                        if (a.municipio.isNotEmpty || a.estado.isNotEmpty)
                          Text(
                            [a.municipio, a.estado].where((s) => s.isNotEmpty).join(', '),
                            style: const TextStyle(fontSize: 13, color: SaoColors.gray600),
                          ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Icon(footerIcon, size: 16, color: barColor),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                footerText,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: barColor),
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded, color: SaoColors.gray400),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PulsingBar extends StatefulWidget {
  final Color color;
  final double height;
  final bool isActive;

  const _PulsingBar({
    required this.color,
    required this.height,
    required this.isActive,
  });

  @override
  State<_PulsingBar> createState() => _PulsingBarState();
}

class _PulsingBarState extends State<_PulsingBar> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _a;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _a = Tween<double>(begin: 0.35, end: 1.0).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));

    if (widget.isActive) _c.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _PulsingBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !_c.isAnimating) {
      _c.repeat(reverse: true);
    } else if (!widget.isActive && _c.isAnimating) {
      _c.stop();
      _c.value = 1.0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _a,
      builder: (_, _) {
        final opacity = widget.isActive ? _a.value : 1.0;
        return Opacity(
          opacity: opacity,
          child: Container(
            width: 8,
            height: widget.height,
            decoration: BoxDecoration(
              color: widget.color,
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(14)),
            ),
          ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback? onClear;

  const _EmptyState({
    required this.title,
    required this.subtitle,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                color: SaoColors.gray50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: SaoColors.gray200),
              ),
              child: const Icon(Icons.inbox_rounded, size: 34, color: SaoColors.gray500),
            ),
            const SizedBox(height: 14),
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: SaoColors.gray900)),
            const SizedBox(height: 6),
            Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: SaoColors.gray600)),
            if (onClear != null) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onClear,
                icon: const Icon(Icons.close_rounded),
                label: const Text('Limpiar búsqueda'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
