// lib/features/home/home_page.dart
import 'dart:async';
import 'package:drift/drift.dart' as drift;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../core/catalog/state/catalog_providers.dart';
import '../../core/connectivity/offline_mode_controller.dart';
import '../../core/constants.dart';
import '../../core/network/api_client.dart';
import '../../core/notifications/push_notifications_service.dart';
import '../../core/sync/pending_sync_services.dart';
import '../../core/sync/sync_orchestrator.dart';
import '../../core/flow/activity_flow_projection.dart';
import '../../data/local/app_db.dart';
import '../../data/local/dao/activity_dao.dart';
import '../auth/application/auth_providers.dart';
import '../agenda/data/assignments_dao.dart';
import '../agenda/data/assignments_repository.dart';
import '../agenda/data/users_dao.dart';
import '../agenda/data/users_repository.dart';
import '../agenda/models/agenda_item.dart';
import '../agenda/models/resource.dart';
import '../../core/utils/logger.dart';
import '../../ui/theme/sao_colors.dart';
import '../../core/utils/snackbar.dart';
import 'home_push_refresh_policy.dart';
import 'home_task_sections.dart';
import 'models/today_activity.dart';
import 'widgets/home_task_inbox.dart';

enum FilterMode { totales, vencidas, completadas, pendienteSync }

enum DateRangeFilter { hoy, semana, mes }

bool canTransferResponsibilityForViewer({
  required bool isPrivilegedAssignmentManager,
  required bool isOperativeViewer,
  required bool isAssignedToCurrentUser,
  required bool isOfflineMode,
  required ExecutionState executionState,
}) {
  if (isOfflineMode || executionState == ExecutionState.terminada) {
    return false;
  }
  if (isPrivilegedAssignmentManager) {
    return true;
  }
  if (!isOperativeViewer) {
    return false;
  }
  return isAssignedToCurrentUser;
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

class _HomePageState extends ConsumerState<HomePage>
    with WidgetsBindingObserver {
  // ====== Estado de datos (MUTABLE) ======
  List<TodayActivity> _items = [];
  bool _loadingActivities = true;

  // ====== UI State ======
  String _query = '';
  final TextEditingController _searchCtrl = TextEditingController();
  final Map<String, bool> _expandedByFrente = {};

  // Filtros interactivos
  FilterMode _filterMode = FilterMode.totales;
  DateRangeFilter _dateRangeFilter = DateRangeFilter.hoy;

  static const _filterModeKey = 'home_filter_mode';
  static const _dateRangeFilterKey = 'home_date_range_filter';
  static const Duration _catalogAutoCheckInterval = Duration(minutes: 5);
  static const Duration _remoteHomeRefreshInterval = Duration(seconds: 20);

  // ====== Estado de ejecución usando ExecutionState ======
  bool _isAdminViewer = false;
  bool _hasPrivilegedAssignmentTransferAccess = false;
  // Default: filterrar por asignado al usuario (seguro por defecto) hasta que se resuelva el rol.
  bool _isOperativeViewer = true;

  // DAO único — evita instanciar en cada método
  late final ActivityDao _dao;
  late final AgendaUsersRepository _agendaUsersRepository;
  late final AssignmentsRepository _assignmentsRepository;
  final Set<String> _transferringActivityIds = <String>{};
  DateTime? _lastCatalogAutoCheckAt;
  bool _catalogAutoSyncRunning = false;
  DateTime? _lastRemoteHomeRefreshAt;
  bool _remoteHomeRefreshRunning = false;
  String? _lastCatalogNotifiedVersion;
  StreamSubscription<RemoteMessage>? _pushMessageSubscription;
  Timer? _remoteHomeRefreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
      ref
          .read(kvStoreProvider)
          .setString('selected_project', widget.selectedProject);
    }
    // ignore: unawaited_futures
    ref.read(offlineModeProvider.notifier).load();
    // ignore: unawaited_futures
    _loadFilterMode();
    // ignore: unawaited_futures
    _loadDateRangeFilter();
    // ignore: unawaited_futures
    _loadHomeActivities();

    // ignore: unawaited_futures
    _resolveViewerRole();
    // ignore: unawaited_futures
    _autoSyncCatalogIfNeeded(force: true);
    // ignore: unawaited_futures
    _setupPushNotificationsBridge();
    _startRemoteRefreshTimer();
    // ignore: unawaited_futures
    _refreshRemoteHomeStateIfNeeded(force: true);
  }

  @override
  void didUpdateWidget(covariant HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final prev = oldWidget.selectedProject.trim().toUpperCase();
    final next = widget.selectedProject.trim().toUpperCase();
    if (prev == next) return;

    if (next != kAllProjects) {
      // ignore: unawaited_futures
      ref.read(kvStoreProvider).setString('selected_project', next);
      // ignore: unawaited_futures
      _registerPushToken(next);
    }

    _startRemoteRefreshTimer();
    // ignore: unawaited_futures
    _refreshRemoteHomeStateIfNeeded(
      force: true,
      projectId: next == kAllProjects ? null : next,
    );
    // ignore: unawaited_futures
    _autoSyncCatalogIfNeeded(force: true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startRemoteRefreshTimer();
      // Recargar actividades al volver de fondo y refrescar cambios remotos.
      // ignore: unawaited_futures
      _loadHomeActivities();
      // ignore: unawaited_futures
      _refreshRemoteHomeStateIfNeeded(force: true);
      // ignore: unawaited_futures
      _autoSyncCatalogIfNeeded(force: false);
      return;
    }

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.inactive) {
      _remoteHomeRefreshTimer?.cancel();
    }
  }

  void _startRemoteRefreshTimer() {
    _remoteHomeRefreshTimer?.cancel();

    final selectedProject = widget.selectedProject.trim().toUpperCase();
    if (selectedProject.isEmpty) {
      return;
    }

    _remoteHomeRefreshTimer = Timer.periodic(_remoteHomeRefreshInterval, (_) {
      // ignore: unawaited_futures
      _refreshRemoteHomeStateIfNeeded(force: false);
    });
  }

  Future<void> _refreshRemoteHomeStateIfNeeded({
    required bool force,
    String? projectId,
  }) async {
    if (_remoteHomeRefreshRunning) return;
    if (ref.read(offlineModeProvider)) return;

    final selectedProject = widget.selectedProject.trim().toUpperCase();
    final requestedProject = (projectId ?? '').trim().toUpperCase();
    final targetProjects = <String>{};

    if (requestedProject.isNotEmpty && requestedProject != kAllProjects) {
      targetProjects.add(requestedProject);
    } else if (selectedProject.isNotEmpty && selectedProject != kAllProjects) {
      targetProjects.add(selectedProject);
    } else {
      final accessibleProjects = await _loadAccessibleProjectIdsForPush();
      targetProjects.addAll(
        accessibleProjects
            .map((item) => item.trim().toUpperCase())
            .where((item) => item.isNotEmpty && item != kAllProjects),
      );
    }

    if (targetProjects.isEmpty) return;

    final now = DateTime.now();
    if (!force && _lastRemoteHomeRefreshAt != null) {
      final elapsed = now.difference(_lastRemoteHomeRefreshAt!);
      if (elapsed < _remoteHomeRefreshInterval) return;
    }

    _remoteHomeRefreshRunning = true;
    _lastRemoteHomeRefreshAt = now;

    try {
      final service = ref.read(activitySyncServiceProvider);
      for (final targetProject in targetProjects) {
        await service.syncProject(targetProject);
      }
    } catch (_) {
      // Silent background refresh; user can still sync manually if needed.
    } finally {
      _remoteHomeRefreshRunning = false;
      if (mounted) {
        await _loadHomeActivities();
      }
    }
  }

  Future<void> _autoSyncCatalogIfNeeded({required bool force}) async {
    final projectId = widget.selectedProject.trim().toUpperCase();
    if (projectId.isEmpty || projectId == kAllProjects) return;
    if (_catalogAutoSyncRunning) return;

    final now = DateTime.now();
    if (!force && _lastCatalogAutoCheckAt != null) {
      final elapsed = now.difference(_lastCatalogAutoCheckAt!);
      if (elapsed < _catalogAutoCheckInterval) return;
    }

    final isOffline = ref.read(offlineModeProvider);
    if (isOffline) return;

    _catalogAutoSyncRunning = true;
    _lastCatalogAutoCheckAt = now;

    try {
      final kv = ref.read(kvStoreProvider);
      final versionKey = 'catalog_version:$projectId';
      final beforeVersion = await kv.getString(versionKey);

      final syncService = ref.read(catalogSyncServiceProvider);
      await syncService.ensureCatalogUpToDate(projectId);

      final afterVersion = await kv.getString(versionKey);
      if (!mounted) return;

      final didUpdate =
          afterVersion != null &&
          afterVersion.trim().isNotEmpty &&
          afterVersion != beforeVersion;
      if (!didUpdate) return;
      if (_lastCatalogNotifiedVersion == afterVersion) return;

      _lastCatalogNotifiedVersion = afterVersion;
      showTransientSnackBar(
        context,
        appSnackBar(
          message:
              'Catalogo $projectId actualizado ($afterVersion). Ya disponible para uso offline.',
          backgroundColor: SaoColors.success,
        ),
      );
    } catch (_) {
      // Evita interrumpir la experiencia cuando no hay red o backend temporalmente no responde.
    } finally {
      _catalogAutoSyncRunning = false;
    }
  }

  Future<void> _setupPushNotificationsBridge() async {
    final projectIds = await _loadAccessibleProjectIdsForPush();
    if (projectIds.isNotEmpty) {
      await _registerPushTokensForProjects(projectIds);
    } else {
      final project = widget.selectedProject.trim().toUpperCase();
      if (project != kAllProjects) {
        await _registerPushToken(project);
      }
    }

    final pushService = GetIt.I<PushNotificationsService>();
    _pushMessageSubscription ??= pushService.messages.listen((
      RemoteMessage message,
    ) {
      final data = message.data;
      final type = (data['type'] ?? '').toString().trim().toLowerCase();
      final pushProject = (data['project_id'] ?? '')
          .toString()
          .trim()
          .toUpperCase();

      if (type == 'catalog_update') {
        if (pushProject.isEmpty) return;

        // ignore: unawaited_futures
        _syncCatalogForProjectFromPush(pushProject);

        if (!mounted) return;
        showTransientSnackBar(
          context,
          appSnackBar(
            message:
                'Se detecto actualizacion de catalogo en $pushProject. Descargando para uso offline...',
            backgroundColor: SaoColors.info,
          ),
        );
        return;
      }

      if (!shouldRefreshHomeFromPushType(type)) {
        return;
      }

      // ignore: unawaited_futures
      _refreshRemoteHomeStateIfNeeded(
        force: true,
        projectId: pushProject.isEmpty ? null : pushProject,
      );

      if (!mounted) return;
      showTransientSnackBar(
        context,
        appSnackBar(
          message: homeRefreshMessageForPushType(type),
          backgroundColor: type == 'review_changes_required'
              ? SaoColors.warning
              : SaoColors.info,
        ),
      );
    });
  }

  Future<List<String>> _loadAccessibleProjectIdsForPush() async {
    try {
      final response = await GetIt.I<ApiClient>().get<dynamic>('/me/projects');
      final rows = (response.data as List<dynamic>)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();

      return rows
          .map(
            (row) => (row['project_id'] ?? '').toString().trim().toUpperCase(),
          )
          .where(
            (projectId) => projectId.isNotEmpty && projectId != kAllProjects,
          )
          .toSet()
          .toList()
        ..sort();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _registerPushTokensForProjects(List<String> projectIds) async {
    try {
      await GetIt.I<PushNotificationsService>()
          .registerCurrentDeviceForProjects(projectIds: projectIds);
    } catch (_) {
      // Non-blocking: push registration must not break Home UX.
    }
  }

  Future<void> _syncCatalogForProjectFromPush(String projectId) async {
    final normalized = projectId.trim().toUpperCase();
    if (normalized.isEmpty || normalized == kAllProjects) return;
    try {
      await ref
          .read(catalogSyncServiceProvider)
          .ensureCatalogUpToDate(normalized);
    } catch (_) {
      // Ignore transient errors; next app sync will retry.
    }
  }

  Future<void> _registerPushToken(String projectId) async {
    try {
      await GetIt.I<PushNotificationsService>().registerCurrentDevice(
        projectId: projectId,
      );
    } catch (_) {
      // Non-blocking: push registration must not break Home UX.
    }
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

  Future<void> _loadDateRangeFilter() async {
    final stored = await ref
        .read(kvStoreProvider)
        .getString(_dateRangeFilterKey);
    if (!mounted || stored == null) return;
    final filter = DateRangeFilter.values.firstWhere(
      (f) => f.name == stored,
      orElse: () => DateRangeFilter.hoy,
    );
    if (filter != _dateRangeFilter) setState(() => _dateRangeFilter = filter);
  }

  Future<void> _setDateRangeFilter(DateRangeFilter filter) {
    setState(() => _dateRangeFilter = filter);
    return ref
        .read(kvStoreProvider)
        .setString(_dateRangeFilterKey, filter.name);
  }

  Future<void> _resolveViewerRole() async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      if (!mounted) return;
      setState(() {
        _isAdminViewer = false;
        _hasPrivilegedAssignmentTransferAccess = false;
        _isOperativeViewer = false;
      });
      // initState already triggers _loadHomeActivities — no need to repeat here.
      return;
    }

    final db = GetIt.I<AppDb>();
    final localUser = await (db.select(
      db.users,
    )..where((t) => t.id.equals(user.id))).getSingleOrNull();
    final role = localUser == null
        ? null
        : await (db.select(
            db.roles,
          )..where((t) => t.id.equals(localUser.roleId))).getSingleOrNull();
    final normalizedRoleName = role?.name.trim().toUpperCase();
    final isAdminByRole = localUser?.roleId == 1;
    final hasKnownRole = localUser != null;
    final isOperativeByRole =
        localUser?.roleId == 4 || normalizedRoleName == 'OPERATIVO';
    final isPrivilegedManagerByRole =
        localUser?.roleId == 2 ||
        localUser?.roleId == 3 ||
        normalizedRoleName == 'COORD' ||
        normalizedRoleName == 'COORDINATOR' ||
        normalizedRoleName == 'SUPERVISOR';
    final email = user.email.trim().toLowerCase();
    final isAdminByEmail =
        email == 'admin@sao.mx' || email.startsWith('admin.');

    if (!mounted) return;
    final nextIsAdmin = isAdminByRole || isAdminByEmail;
    final nextHasPrivilegedAssignmentTransferAccess =
        nextIsAdmin || isPrivilegedManagerByRole;
    // Least-privilege fallback: if role cannot be resolved locally and user is not admin,
    // keep strict assignee filtering to avoid exposing activities from other operatives.
    final nextIsOperative = hasKnownRole ? isOperativeByRole : !nextIsAdmin;
    final changed =
        nextIsAdmin != _isAdminViewer ||
        nextIsOperative != _isOperativeViewer ||
        nextHasPrivilegedAssignmentTransferAccess !=
            _hasPrivilegedAssignmentTransferAccess;
    setState(() {
      _isAdminViewer = nextIsAdmin;
      _hasPrivilegedAssignmentTransferAccess =
          nextHasPrivilegedAssignmentTransferAccess;
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

  List<_HomeNotification> _buildNotifications() {
    final notifications = <_HomeNotification>[];

    for (final activity in _items) {
      if (_requiresCorrectionAttention(activity)) {
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

      if (activity.nextAction == 'COMPLETAR_WIZARD') {
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

      if (activity.nextAction == 'REVISAR_ERROR_SYNC') {
        notifications.add(
          _HomeNotification(
            activity: activity,
            title: 'Error de sincronizacion',
            message:
                '${activity.title} • ${nextActionLabel(activity.nextAction)}',
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
                    const Icon(
                      Icons.notifications_active_rounded,
                      color: SaoColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Notificaciones (${notifications.length})',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
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
                      separatorBuilder: (_, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = notifications[index];
                        return ListTile(
                          dense: true,
                          leading: Icon(item.icon, color: item.color),
                          title: Text(
                            item.title,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
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

  bool _requiresCorrectionAttention(TodayActivity activity) {
    return isRejectedForCorrectionFlow(
      localStatus: _localStatusForTodayActivity(activity),
      reviewState: activity.reviewState,
      nextAction: activity.nextAction,
    );
  }

  Future<void> _loadHomeActivities() async {
    final previousCorrectionIds = _items
        .where(_requiresCorrectionAttention)
        .map((item) => item.id)
        .toSet();

    setState(() {
      _loadingActivities = true;
    });

    try {
      final agendaItems = await _syncAssignmentsForHome();
      final effectiveProject = _isAdminViewer
          ? kAllProjects
          : widget.selectedProject;
      final rows = await _dao.listHomeActivitiesByProject(effectiveProject);
      final currentUserId = ref.read(currentUserProvider)?.id.trim();
      final fallbackVisibleIds = _isOperativeViewer
          ? await _loadOperativeVisibleActivityIds(
              effectiveProject,
              currentUserId: currentUserId,
            )
          : const <String>{};
      final filteredRows = _isOperativeViewer
          ? ((ref.read(currentUserProvider) != null)
                ? rows.where((row) {
                    // Always show activities with local execution state (DRAFT,
                    // REVISION_PENDIENTE, or startedAt set). The operative is
                    // actively working on them — they are visible regardless of
                    // assignedToUserId being null or the fallback set not containing
                    // their ID yet (can happen after replaceSyncedInRange refreshes
                    // the agendaAssignments table with fresh server IDs).
                    final s = row.activity.status.trim().toUpperCase();
                    if (row.activity.startedAt != null ||
                        s == 'DRAFT' ||
                        s == 'REVISION_PENDIENTE' ||
                        s == 'RECHAZADA') {
                      return true;
                    }

                    final matchesIdentity = _isAssignedToCurrentUser(
                      assignedToUserId: row.assignedToUserId,
                      assignedToName: row.assignedToName,
                    );
                    if (matchesIdentity) {
                      return true;
                    }

                    // Fallback: if assignment sync already marked this activity visible
                    // for this operativo in Agenda, keep it visible in Home too.
                    return fallbackVisibleIds.contains(row.activity.id);
                  }).toList()
                : <HomeActivityRecord>[])
          : rows;
      final mappedItems = filteredRows.map(_toTodayActivity).toList();
      var items = _isOperativeViewer
          ? mappedItems.where(_matchesOperativeHomeRules).toList()
          : mappedItems;

      if (_isOperativeViewer && agendaItems.isNotEmpty) {
        items = _mergeAgendaFallbackActivities(items, agendaItems);
      }

      // Dedup: when a self-assignment is synced successfully, the local activity
      // (created by saveLocal with the assignment UUID) and the server activity
      // (created by syncProject pull with the backend UUID) can both end up in
      // the DB, producing two entries for the same logical activity. Remove the
      // lower-priority duplicate keeping the one with more local state.
      items = _deduplicateFinalItems(items);

      final newCorrectionCount = items
          .where(
            (item) =>
                _requiresCorrectionAttention(item) &&
                !previousCorrectionIds.contains(item.id),
          )
          .length;

      if (!mounted) return;
      setState(() {
        _items = items;
        _loadingActivities = false;
      });

      if (newCorrectionCount > 0) {
        showTransientSnackBar(
          context,
          appSnackBar(
            message: newCorrectionCount == 1
                ? 'Tienes 1 actividad rechazada que requiere correccion.'
                : 'Tienes $newCorrectionCount actividades rechazadas que requieren correccion.',
            backgroundColor: SaoColors.warning,
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingActivities = false;
      });
    }
  }

  Future<List<AgendaItem>> _syncAssignmentsForHome() async {
    final projectId = widget.selectedProject.trim();
    if (projectId.isEmpty || projectId.toUpperCase() == kAllProjects) {
      return const <AgendaItem>[];
    }

    final now = DateTime.now();
    final from = now.subtract(const Duration(days: 60));
    final to = now.add(const Duration(days: 60));

    return _assignmentsRepository.loadRange(
      projectId: projectId,
      from: from,
      to: to,
      isOffline: ref.read(offlineModeProvider),
    );
  }

  List<TodayActivity> _mergeAgendaFallbackActivities(
    List<TodayActivity> baseItems,
    List<AgendaItem> agendaItems,
  ) {
    final merged = <TodayActivity>[...baseItems];
    final existingIds = <String>{...baseItems.map((item) => item.id)};

    for (final agenda in agendaItems) {
      if (!_isAssignedToCurrentUser(
        assignedToUserId: agenda.resourceId,
        assignedToName: null,
      )) {
        continue;
      }

      final candidate = _toTodayActivityFromAgendaItem(agenda);
      if (!_matchesOperativeHomeRules(candidate)) {
        continue;
      }

      if (existingIds.contains(candidate.id)) {
        continue;
      }

      // Evita duplicados lógicos cuando agenda y activities usan IDs distintos
      // para la misma actividad (p. ej. assignment_id vs activity_id).
      final hasLogicalDuplicate = merged.any(
        (existing) => _sameLogicalActivity(existing, candidate),
      );
      if (hasLogicalDuplicate) {
        continue;
      }

      existingIds.add(candidate.id);
      merged.add(candidate);
    }

    merged.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return merged;
  }

  /// Deduplicates items that represent the same logical activity.
  /// Happens when a self-assignment sync creates a server-side activity UUID
  /// while a local activity row (keyed by the original assignment UUID) still
  /// exists — both survive `listHomeActivitiesByProject`.
  List<TodayActivity> _deduplicateFinalItems(List<TodayActivity> items) {
    final normalize = (String v) => v
        .trim()
        .toUpperCase()
        .replaceAll('Á', 'A')
        .replaceAll('É', 'E')
        .replaceAll('Í', 'I')
        .replaceAll('Ó', 'O')
        .replaceAll('Ú', 'U')
        .replaceAll(RegExp(r'\s+'), ' ');

    // Map fingerprint → index in result (for possible replacement).
    final fingerprintToIdx = <String, int>{};
    final result = <TodayActivity>[];

    for (final item in items) {
      final pk = item.pk;
      // Only deduplicate when both pk is set and positive; otherwise we cannot
      // safely tell two activities apart by title alone.
      if (pk == null || pk <= 0) {
        result.add(item);
        continue;
      }

      final key = '${pk}_${normalize(item.title)}';
      final existingIdx = fingerprintToIdx[key];
      if (existingIdx == null) {
        fingerprintToIdx[key] = result.length;
        result.add(item);
      } else {
        // Keep the item with more meaningful local state.
        if (_hasMoreLocalState(item, result[existingIdx])) {
          result[existingIdx] = item;
        }
      }
    }

    return result;
  }

  int _executionStateScore(ExecutionState state) {
    return switch (state) {
      ExecutionState.terminada => 4,
      ExecutionState.revisionPendiente => 3,
      ExecutionState.enCurso => 2,
      ExecutionState.pendiente => 1,
    };
  }

  bool _hasMoreLocalState(TodayActivity a, TodayActivity b) {
    final aScore = _executionStateScore(a.executionState);
    final bScore = _executionStateScore(b.executionState);
    if (aScore != bScore) return aScore > bScore;
    // Prefer items with local-pending changes over purely-synced ones.
    final aSynced = a.syncState == ActivitySyncState.synced;
    final bSynced = b.syncState == ActivitySyncState.synced;
    if (aSynced != bSynced) return !aSynced;
    return false;
  }

  bool _sameLogicalActivity(TodayActivity left, TodayActivity right) {
    if (left.id == right.id) return true;

    final leftPk = left.pk;
    final rightPk = right.pk;
    if (leftPk == null || rightPk == null || leftPk != rightPk) {
      return false;
    }

    final normalize = (String value) => value
        .trim()
        .toUpperCase()
        .replaceAll('Á', 'A')
        .replaceAll('É', 'E')
        .replaceAll('Í', 'I')
        .replaceAll('Ó', 'O')
        .replaceAll('Ú', 'U')
        .replaceAll(RegExp(r'\s+'), ' ');

    return normalize(left.title) == normalize(right.title);
  }

  Future<String?> _resolveProjectFromAssignment(String activityId) async {
    final db = GetIt.I<AppDb>();
    final assignment =
        await ((db.select(db.agendaAssignments)
              ..where(
                (t) =>
                    t.activityId.equals(activityId) | t.id.equals(activityId),
              )
              ..orderBy([(t) => drift.OrderingTerm.desc(t.updatedAt)])
              ..limit(1))
            .getSingleOrNull());
    final projectId = assignment?.projectId.trim();
    if (projectId == null || projectId.isEmpty) return null;
    return projectId;
  }

  Future<String> _resolveLocalActivityIdForAction(
    TodayActivity activity,
  ) async {
    final sourceId = activity.id.trim();
    if (sourceId.isEmpty) return sourceId;

    if (await _dao.activityExists(sourceId)) {
      return sourceId;
    }

    final db = GetIt.I<AppDb>();
    final assignment =
        await ((db.select(db.agendaAssignments)
              ..where(
                (t) => t.activityId.equals(sourceId) | t.id.equals(sourceId),
              )
              ..orderBy([(t) => drift.OrderingTerm.desc(t.updatedAt)])
              ..limit(1))
            .getSingleOrNull());

    final candidateIds = <String>{
      if (assignment?.activityId?.trim().isNotEmpty ?? false)
        if (_looksLikeUuid(assignment!.activityId!.trim()))
          assignment.activityId!.trim(),
      if (assignment?.id.trim().isNotEmpty ?? false) assignment!.id.trim(),
    };

    for (final candidate in candidateIds) {
      if (await _dao.activityExists(candidate)) {
        return candidate;
      }
    }

    return sourceId;
  }

  Future<bool> _userExistsById(String userId) async {
    final candidate = userId.trim();
    if (candidate.isEmpty) return false;
    final db = GetIt.I<AppDb>();
    final row = await (db.select(
      db.users,
    )..where((t) => t.id.equals(candidate))).getSingleOrNull();
    return row != null;
  }

  Future<bool> _projectExistsById(String projectId) async {
    final candidate = projectId.trim();
    if (candidate.isEmpty) return false;
    final db = GetIt.I<AppDb>();
    final row = await (db.select(
      db.projects,
    )..where((t) => t.id.equals(candidate))).getSingleOrNull();
    return row != null;
  }

  Future<bool> _activityTypeExistsById(String activityTypeId) async {
    final candidate = activityTypeId.trim();
    if (candidate.isEmpty) return false;
    final db = GetIt.I<AppDb>();
    final row = await (db.select(
      db.catalogActivityTypes,
    )..where((t) => t.id.equals(candidate))).getSingleOrNull();
    return row != null;
  }

  Future<String?> _resolvePersistableCreatorUserId(
    TodayActivity activity,
  ) async {
    final db = GetIt.I<AppDb>();
    final candidates = <String>{
      if ((ref.read(currentUserProvider)?.id.trim().isNotEmpty ?? false))
        ref.read(currentUserProvider)!.id.trim(),
      if (activity.assignedToUserId?.trim().isNotEmpty ?? false)
        activity.assignedToUserId!.trim(),
    };

    for (final candidate in candidates) {
      if (await _userExistsById(candidate)) {
        return candidate;
      }
    }

    final firstUser = await (db.select(db.users)..limit(1)).getSingleOrNull();
    return firstUser?.id;
  }

  Future<String?> _resolvePersistableAssigneeUserId(
    String? assigneeUserId,
  ) async {
    final candidate = assigneeUserId?.trim();
    if (candidate != null &&
        candidate.isNotEmpty &&
        await _userExistsById(candidate)) {
      return candidate;
    }

    final currentUserId = ref.read(currentUserProvider)?.id.trim();
    if (currentUserId != null &&
        currentUserId.isNotEmpty &&
        await _userExistsById(currentUserId)) {
      return currentUserId;
    }

    return null;
  }

  Future<String?> _resolvePersistableProjectId(
    String projectSeed,
    String resolvedActivityId,
  ) async {
    final db = GetIt.I<AppDb>();

    final resolvedProjectId = await _dao.resolveProjectId(projectSeed);
    if (await _projectExistsById(resolvedProjectId)) {
      return resolvedProjectId;
    }

    final assignmentProject = await _resolveProjectFromAssignment(
      resolvedActivityId,
    );
    if (assignmentProject != null) {
      final normalizedAssignmentProject = await _dao.resolveProjectId(
        assignmentProject,
      );
      if (await _projectExistsById(normalizedAssignmentProject)) {
        return normalizedAssignmentProject;
      }
    }

    final firstProject = await (db.select(
      db.projects,
    )..limit(1)).getSingleOrNull();
    return firstProject?.id;
  }

  Future<String?> _resolvePersistableActivityTypeId(
    String inferredTypeCode,
  ) async {
    final db = GetIt.I<AppDb>();

    final resolvedTypeId = await _dao.resolveActivityTypeId(inferredTypeCode);
    if (await _activityTypeExistsById(resolvedTypeId)) {
      return resolvedTypeId;
    }

    final firstType = await (db.select(
      db.catalogActivityTypes,
    )..limit(1)).getSingleOrNull();
    return firstType?.id;
  }

  TodayActivity _toTodayActivityFromAgendaItem(AgendaItem item) {
    final normalizedId =
        (item.activityId?.trim().isNotEmpty ?? false) &&
            _looksLikeUuid(item.activityId!.trim())
        ? item.activityId!.trim()
        : item.id.trim();

    final executionState = switch (item.nextAction) {
      'TERMINAR_ACTIVIDAD' => ExecutionState.enCurso,
      'COMPLETAR_WIZARD' => ExecutionState.revisionPendiente,
      'CORREGIR_Y_REENVIAR' => ExecutionState.revisionPendiente,
      'CERRADA_RECHAZADA' => ExecutionState.revisionPendiente,
      'ESPERAR_DECISION_COORDINACION' => ExecutionState.terminada,
      'CERRADA_APROBADA' => ExecutionState.terminada,
      'CERRADA_CANCELADA' => ExecutionState.terminada,
      _ => ExecutionState.pendiente,
    };

    final syncState = switch (item.syncStatus) {
      SyncStatus.synced => ActivitySyncState.synced,
      SyncStatus.error => ActivitySyncState.error,
      SyncStatus.pending => ActivitySyncState.pending,
      SyncStatus.uploading => ActivitySyncState.pending,
    };

    final today = DateTime.now();
    final created = item.start;
    final createdDay = DateTime(created.year, created.month, created.day);
    final todayDay = DateTime(today.year, today.month, today.day);

    final status = executionState == ExecutionState.terminada
        ? ActivityStatus.programada
        : createdDay.isBefore(todayDay)
        ? ActivityStatus.vencida
        : createdDay.isAtSameMomentAs(todayDay)
        ? ActivityStatus.hoy
        : ActivityStatus.programada;

    final normalizedReviewState = item.reviewState.trim().toUpperCase();
    final normalizedNextAction = item.nextAction.trim().toUpperCase();

    return TodayActivity(
      id: normalizedId,
      title: item.title.trim().isNotEmpty ? item.title.trim() : 'Actividad',
      frente: _canonicalFrente(
        item.frente.trim().isNotEmpty ? item.frente.trim() : 'Sin frente',
      ),
      municipio: item.municipio,
      estado: item.estado,
      pk: item.pk,
      status: status,
      createdAt: created,
      executionState: executionState,
      horaInicio: executionState == ExecutionState.enCurso ? item.start : null,
      horaFin: executionState == ExecutionState.terminada ? item.end : null,
      isRejected:
          normalizedReviewState == 'REJECTED' ||
          normalizedReviewState == 'CHANGES_REQUIRED' ||
          normalizedNextAction == 'CORREGIR_Y_REENVIAR' ||
          normalizedNextAction == 'CERRADA_RECHAZADA',
      syncState: syncState,
      operationalState: item.operationalState,
      reviewState: item.reviewState,
      nextAction: item.nextAction,
      assignedToUserId: item.resourceId,
      assignedToName: null,
    );
  }

  Future<Set<String>> _loadOperativeVisibleActivityIds(
    String projectId, {
    required String? currentUserId,
  }) async {
    final normalizedProject = projectId.trim();
    final normalizedUserId = currentUserId?.trim();
    if (normalizedProject.isEmpty ||
        normalizedProject.toUpperCase() == kAllProjects ||
        normalizedUserId == null ||
        normalizedUserId.isEmpty) {
      return const <String>{};
    }

    final db = GetIt.I<AppDb>();
    final assignments =
        await (db.select(db.agendaAssignments)..where(
              (t) =>
                  t.projectId.equals(normalizedProject) &
                  t.resourceId.equals(normalizedUserId),
            ))
            .get();

    final visibleIds = <String>{};
    for (final assignment in assignments) {
      final activityId = assignment.activityId?.trim();
      if (activityId != null && _looksLikeUuid(activityId)) {
        visibleIds.add(activityId);
      }
      final assignmentId = assignment.id.trim();
      if (assignmentId.isNotEmpty) {
        visibleIds.add(assignmentId);
      }
    }
    return visibleIds;
  }

  bool _canTransferResponsibility(TodayActivity activity) {
    return canTransferResponsibilityForViewer(
      isPrivilegedAssignmentManager:
          _hasPrivilegedAssignmentTransferAccess,
      isOperativeViewer: _isOperativeViewer,
      isAssignedToCurrentUser: _isAssignedToCurrentUser(
        assignedToUserId: activity.assignedToUserId,
        assignedToName: activity.assignedToName,
      ),
      isOfflineMode: ref.read(offlineModeProvider),
      executionState: activity.executionState,
    );
  }

  /// Returns true if the current user is allowed to delete [activity].
  /// - ADMIN: can delete any activity.
  /// - OPERATIVO: can only delete activities assigned to themselves that have
  ///   not yet been synced to the server (pending / error).
  bool _canDeleteActivity(TodayActivity activity) {
    if (_isAdminViewer) return true;
    if (!_isOperativeViewer) return false;
    // OPERATIVO: must own the activity.
    final isOwn = _isAssignedToCurrentUser(
      assignedToUserId: activity.assignedToUserId,
      assignedToName: activity.assignedToName,
    );
    if (!isOwn) return false;
    // Only allow deleting local-only activities (not yet confirmed by backend).
    return activity.syncState == ActivitySyncState.pending ||
        activity.syncState == ActivitySyncState.error;
  }

  Future<void> _confirmDeleteActivity(TodayActivity activity) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar actividad'),
        content: Text(
          '¿Seguro que quieres eliminar "${activity.title}"? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: SaoColors.riskHigh),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _deleteActivity(activity);
  }

  Future<void> _deleteActivity(TodayActivity activity) async {
    final resolvedId = await _resolveLocalActivityIdForAction(activity);
    try {
      await _dao.deleteActivity(resolvedId);
      if (!mounted) return;
      setState(() {
        _items.removeWhere((i) => i.id == activity.id || i.id == resolvedId);
      });
      showTransientSnackBar(
        context,
        appSnackBar(
          message: 'Actividad eliminada.',
          backgroundColor: SaoColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      showTransientSnackBar(
        context,
        appSnackBar(
          message: 'No se pudo eliminar la actividad. Intenta de nuevo.',
          backgroundColor: SaoColors.error,
        ),
      );
    }
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
        appSnackBar(
          message: 'Selecciona un proyecto para transferir la responsabilidad.',
        ),
      );
      return;
    }

    List<Resource> resources;
    try {
      resources = await _agendaUsersRepository.getTransferCandidates(
        projectId: projectId,
        isOffline: false,
      );
    } catch (_) {
      if (!mounted) return;
      showTransientSnackBar(
        context,
        appSnackBar(
          message: 'No se pudo cargar el equipo del proyecto para transferir.',
        ),
      );
      return;
    }

    final candidates =
        resources
            .where(
              (resource) =>
                  resource.isActive && resource.id != activity.assignedToUserId,
            )
            .toList()
          ..sort(
            (left, right) =>
                left.name.toLowerCase().compareTo(right.name.toLowerCase()),
          );

    if (candidates.isEmpty) {
      if (!mounted) return;
      showTransientSnackBar(
        context,
        appSnackBar(
          message:
              'No hay otra persona disponible en el proyecto para recibir la actividad.',
        ),
      );
      return;
    }

    if (!mounted) return;
    final selection = await showModalBottomSheet<_TransferSelection>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _TransferResponsibilitySheet(
        activity: activity,
        candidates: candidates,
      ),
    );

    if (!mounted) return;
    if (selection == null) {
      return;
    }

    await _transferResponsibility(
      activity,
      selection.resource,
      selection.reason,
    );
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
      if (mounted) {
        setState(() {
          _transferringActivityIds.remove(activity.id);
        });
      }
    }
  }

  TodayActivity _toTodayActivity(HomeActivityRecord row) {
    final activity = row.activity;
    final executionState = _executionStateFromRow(activity);
    final syncState = _syncStateFromRow(activity);
    final flow = deriveLocalActivityFlowProjection(
      localStatus: activity.status,
      startedAt: activity.startedAt,
      finishedAt: activity.finishedAt,
      syncLifecycle: syncLifecycleFromLocalStatus(activity.status),
    );
    final preferLocalFlow =
        activity.status.trim().toUpperCase() != 'SYNCED' &&
        !hasAuthoritativeCanonicalReviewFlow(
          reviewState: row.reviewState,
          nextAction: row.nextAction,
        );
    final operationalState = _validatedOperationalState(
      preferLocalFlow
          ? flow.operationalState
          : _preferCanonicalFlowValue(
              row.operationalState,
              flow.operationalState,
            ),
    );
    final reviewState = _validatedReviewState(
      preferLocalFlow
          ? flow.reviewState
          : _preferCanonicalFlowValue(row.reviewState, flow.reviewState),
    );
    final nextAction = _validatedNextAction(
      preferLocalFlow
          ? flow.nextAction
          : _preferCanonicalFlowValue(row.nextAction, flow.nextAction),
    );
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
    final normalizedEstado = _normalizeDisplayValue(row.estado) ?? legacyEstado;

    final isRejected = isRejectedForCorrectionFlow(
      localStatus: activity.status,
      reviewState: reviewState,
      nextAction: nextAction,
    );

    return TodayActivity(
      id: activity.id,
      title: title,
      frente: _canonicalFrente(normalizedSegment ?? normalizedFront ?? 'Sin frente'),
      municipio: normalizedMunicipio ?? '',
      estado: normalizedEstado ?? '',
      pk: activity.pk,
      status: _statusFromRow(activity, executionState, isAssigned: hasAssignee),
      createdAt: activity.createdAt,
      executionState: executionState,
      horaInicio: activity.startedAt,
      horaFin: activity.finishedAt,
      isUnplanned: row.isUnplanned,
      isRejected: isRejected,
      syncState: syncState,
      operationalState: operationalState,
      reviewState: reviewState,
      nextAction: nextAction,
      assignedToUserId: row.assignedToUserId,
      assignedToName: row.assignedToName,
    );
  }

  String _preferCanonicalFlowValue(String? candidate, String fallback) {
    final value = candidate?.trim().toUpperCase();
    if (value == null || value.isEmpty) {
      return fallback.trim().toUpperCase();
    }
    return value;
  }

  String _validatedOperationalState(String state) {
    const valid = <String>{
      'PENDIENTE',
      'EN_CURSO',
      'POR_COMPLETAR',
      'BLOQUEADA',
      'CANCELADA',
    };
    return valid.contains(state) ? state : 'PENDIENTE';
  }

  String _validatedReviewState(String state) {
    const valid = <String>{
      'NOT_APPLICABLE',
      'PENDING_REVIEW',
      'CHANGES_REQUIRED',
      'APPROVED',
      'REJECTED',
    };
    return valid.contains(state) ? state : 'NOT_APPLICABLE';
  }

  String _validatedNextAction(String action) {
    const valid = <String>{
      'INICIAR_ACTIVIDAD',
      'TERMINAR_ACTIVIDAD',
      'COMPLETAR_WIZARD',
      'CORREGIR_Y_REENVIAR',
      'ESPERAR_DECISION_COORDINACION',
      'REVISAR_ERROR_SYNC',
      'SINCRONIZAR_PENDIENTE',
      'CERRADA_CANCELADA',
      'CERRADA_RECHAZADA',
      'CERRADA_APROBADA',
      'SIN_ACCION',
    };
    return valid.contains(action) ? action : 'SIN_ACCION';
  }

  TodayActivity _rehydrateFlow(TodayActivity activity) {
    final localStatus = _localStatusForTodayActivity(activity);
    final syncLifecycle = switch (activity.syncState) {
      ActivitySyncState.pending => 'READY_TO_SYNC',
      ActivitySyncState.error => 'SYNC_ERROR',
      ActivitySyncState.synced => 'SYNCED',
      ActivitySyncState.unknown => syncLifecycleFromLocalStatus(localStatus),
    };
    final flow = deriveLocalActivityFlowProjection(
      localStatus: localStatus,
      startedAt: activity.horaInicio,
      finishedAt: activity.horaFin,
      syncLifecycle: syncLifecycle,
    );
    return activity.copyWith(
      operationalState: flow.operationalState,
      reviewState: flow.reviewState,
      nextAction: flow.nextAction,
    );
  }

  String _localStatusForTodayActivity(TodayActivity activity) {
    if (activity.isRejected) {
      return 'RECHAZADA';
    }
    if (activity.executionState == ExecutionState.revisionPendiente) {
      return 'REVISION_PENDIENTE';
    }
    if (activity.syncState == ActivitySyncState.error) {
      return 'ERROR';
    }
    if (activity.syncState == ActivitySyncState.pending) {
      return 'READY_TO_SYNC';
    }
    return 'SYNCED';
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

  /// Normalizes front/frente abbreviations so that grouping treats them as
  /// the same unit. For example: "F1" and "Frente 1" both become "Frente 1".
  String _canonicalFrente(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return 'Sin frente';
    // Match patterns like "F1", "F2", "F10", "F 1", case-insensitive.
    final abbrev = RegExp(r'^[Ff]\s*(\d+)$').firstMatch(value);
    if (abbrev != null) {
      return 'Frente ${abbrev.group(1)}';
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
    WidgetsBinding.instance.removeObserver(this);
    _remoteHomeRefreshTimer?.cancel();
    _pushMessageSubscription?.cancel();
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

  String _effectiveFooterText(
    String activityId,
    ActivityStatus originalStatus,
  ) {
    final activity = _findById(activityId);
    if (activity == null) return _statusText(originalStatus);
    if (_requiresCorrectionAttention(activity)) {
      return 'Rechazada • Requiere correccion';
    }
    if (activity.nextAction == 'REVISAR_ERROR_SYNC') {
      return 'Error de sync • ${nextActionLabel(activity.nextAction)}';
    }
    if (activity.nextAction == 'SINCRONIZAR_PENDIENTE' &&
        activity.executionState == ExecutionState.terminada) {
      return 'Terminada • ${nextActionLabel(activity.nextAction)}';
    }
    if (activity.nextAction == 'ESPERAR_DECISION_COORDINACION') {
      return 'Terminada • ${nextActionLabel(activity.nextAction)}';
    }
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

  bool _matchesOperativeHomeRules(TodayActivity activity) {
    switch (activity.nextAction) {
      case 'INICIAR_ACTIVIDAD':
      case 'TERMINAR_ACTIVIDAD':
      case 'COMPLETAR_WIZARD':
      case 'CORREGIR_Y_REENVIAR':
      case 'CERRADA_RECHAZADA':
      case 'REVISAR_ERROR_SYNC':
      case 'SINCRONIZAR_PENDIENTE':
      case 'ESPERAR_DECISION_COORDINACION':
        return true;
      default:
        return false;
    }
  }

  bool _isAssignedToCurrentUser({
    required String? assignedToUserId,
    required String? assignedToName,
  }) {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      return false;
    }

    final currentUserId = user.id.trim().toLowerCase();
    final currentUserEmail = user.email.trim().toLowerCase();
    final currentUserName = user.fullName.trim().toLowerCase();

    final assignedTo = assignedToUserId?.trim().toLowerCase();
    if (assignedTo != null && assignedTo.isNotEmpty) {
      if (assignedTo == currentUserId || assignedTo == currentUserEmail) {
        return true;
      }
    }

    final assignedName = assignedToName?.trim().toLowerCase();
    if (assignedName != null &&
        assignedName.isNotEmpty &&
        currentUserName.isNotEmpty) {
      if (assignedName == currentUserName) {
        return true;
      }
    }

    return false;
  }

  bool _looksLikeUuid(String value) {
    final normalized = value.trim();
    return RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
    ).hasMatch(normalized);
  }

  // ====== Wizard: abre el FORMULARIO real (data-driven) ======
  Future<bool?> _openRegisterWizard(TodayActivity a) async {
    final isTutorialGuest =
        GoRouterState.of(context).uri.queryParameters['tutorial'] == '1';
    if (isTutorialGuest) {
      showTransientSnackBar(
        context,
        appSnackBar(
          message:
              'Modo tutorial: en operación real aqui se abre el wizard para capturar y guardar.',
          backgroundColor: SaoColors.info,
        ),
      );
      return false;
    }

    final resolvedId = await _resolveLocalActivityIdForAction(a);
    // Pasar la actividad con las horas ya registradas
    final currentActivity = (_findById(a.id) ?? a).copyWith();
    final result = await context.push(
      '/activity/$resolvedId/wizard?project=${widget.selectedProject}',
      extra: currentActivity,
    );
    // Recargar siempre al volver del wizard para reflejar cambios de estado
    // (iniciada, pendiente de formulario) aunque no se haya guardado completamente.
    await _loadHomeActivities();
    return result != null;
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
    } else if (currentActivity.executionState ==
        ExecutionState.revisionPendiente) {
      if (currentActivity.isRejected) {
        showTransientSnackBar(
          context,
          appSnackBar(
            message:
                'Esta actividad fue rechazada. Revisa observaciones y corrige antes de reenviar.',
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
    final resolvedId = await _resolveLocalActivityIdForAction(a);
    final baseActivity = (resolvedId == a.id)
        ? a
        : TodayActivity(
            id: resolvedId,
            title: a.title,
            frente: a.frente,
            municipio: a.municipio,
            estado: a.estado,
            pk: a.pk,
            status: a.status,
            createdAt: a.createdAt,
            executionState: a.executionState,
            horaInicio: a.horaInicio,
            horaFin: a.horaFin,
            gpsLocation: a.gpsLocation,
            isUnplanned: a.isUnplanned,
            isRejected: a.isRejected,
            syncState: a.syncState,
            operationalState: a.operationalState,
            reviewState: a.reviewState,
            nextAction: a.nextAction,
            assignedToUserId: a.assignedToUserId,
            assignedToName: a.assignedToName,
          );

    final now = DateTime.now();
    final gps = baseActivity.gpsLocation;

    final updated = baseActivity.copyWith(
      executionState: ExecutionState.enCurso,
      horaInicio: now,
      gpsLocation: gps,
    );

    setState(() {
      _updateItem(a.id, _rehydrateFlow(updated));
    });

    try {
      if (!await _dao.activityExists(resolvedId)) {
        final selectedProject = widget.selectedProject.trim();
        final assignmentProject = await _resolveProjectFromAssignment(
          resolvedId,
        );
        final projectSeed =
            selectedProject.toUpperCase() == kAllProjects &&
                assignmentProject != null
            ? assignmentProject
            : selectedProject;
        final projectId = await _resolvePersistableProjectId(
          projectSeed,
          resolvedId,
        );
        final activityTypeId = await _resolvePersistableActivityTypeId(
          _inferActivityTypeCodeFromTitle(baseActivity.title),
        );
        final createdByUserId = await _resolvePersistableCreatorUserId(
          baseActivity,
        );
        final assignedToUserId = await _resolvePersistableAssigneeUserId(
          baseActivity.assignedToUserId,
        );

        if (projectId == null ||
            activityTypeId == null ||
            createdByUserId == null) {
          throw StateError(
            'No se pudo resolver FK local para persistir inicio: '
            'projectId=$projectId activityTypeId=$activityTypeId createdByUserId=$createdByUserId',
          );
        }

        await _dao.upsertActivityRow(
          ActivitiesCompanion.insert(
            id: resolvedId,
            projectId: projectId,
            activityTypeId: activityTypeId,
            title: baseActivity.title,
            createdAt: baseActivity.createdAt,
            createdByUserId: createdByUserId,
            assignedToUserId: drift.Value(assignedToUserId),
            status: const drift.Value('DRAFT'),
            startedAt: drift.Value(now),
            finishedAt: const drift.Value(null),
            pk: drift.Value(baseActivity.pk),
          ),
        );
      }

      await _dao.markActivityStarted(activityId: resolvedId, startedAt: now);
    } catch (e, st) {
      appLogger.w(
        'No se pudo persistir inicio activity=${a.id} resolved=$resolvedId: $e\n$st',
      );
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

  String _inferActivityTypeCodeFromTitle(String title) {
    final t = title.toUpperCase();
    if (t.contains('CAMIN')) return 'CAM';
    if (t.contains('REUN')) return 'REU';
    if (t.contains('ASAM')) return 'ASP';
    if (t.contains('CONSULTA')) return 'CIN';
    if (t.contains('SOCIAL')) return 'SOC';
    if (t.contains('ACOMPA')) return 'AIN';
    return 'CAM';
  }

  Future<void> _abrirWizardDesdeEnCurso(TodayActivity a) async {
    final resolvedId = await _resolveLocalActivityIdForAction(a);
    final currentActivity = (_findById(a.id) ?? a);
    final swipeFinishedAt = DateTime.now();
    final pendingCapture = currentActivity.copyWith(
      executionState: ExecutionState.revisionPendiente,
      horaFin: swipeFinishedAt,
    );

    // Persistir hora de término al momento del swipe, antes de abrir wizard.
    setState(() {
      _updateItem(a.id, _rehydrateFlow(pendingCapture));
    });

    try {
      if (!await _dao.activityExists(resolvedId)) {
        final selectedProject = widget.selectedProject.trim();
        final assignmentProject = await _resolveProjectFromAssignment(
          resolvedId,
        );
        final projectSeed =
            selectedProject.toUpperCase() == kAllProjects &&
                assignmentProject != null
            ? assignmentProject
            : selectedProject;
        final projectId = await _resolvePersistableProjectId(
          projectSeed,
          resolvedId,
        );
        final activityTypeId = await _resolvePersistableActivityTypeId(
          _inferActivityTypeCodeFromTitle(a.title),
        );
        final createdByUserId = await _resolvePersistableCreatorUserId(
          currentActivity,
        );
        final assignedToUserId = await _resolvePersistableAssigneeUserId(
          currentActivity.assignedToUserId,
        );
        final startedAt = currentActivity.horaInicio ?? swipeFinishedAt;

        if (projectId == null ||
            activityTypeId == null ||
            createdByUserId == null) {
          throw StateError(
            'No se pudo resolver FK local para persistir termino: '
            'projectId=$projectId activityTypeId=$activityTypeId createdByUserId=$createdByUserId',
          );
        }

        await _dao.upsertActivityRow(
          ActivitiesCompanion.insert(
            id: resolvedId,
            projectId: projectId,
            activityTypeId: activityTypeId,
            title: a.title,
            createdAt: a.createdAt,
            createdByUserId: createdByUserId,
            assignedToUserId: drift.Value(assignedToUserId),
            status: const drift.Value('REVISION_PENDIENTE'),
            startedAt: drift.Value(startedAt),
            finishedAt: drift.Value(swipeFinishedAt),
            pk: drift.Value(a.pk),
          ),
        );
      }

      await _dao.markActivityRevisionPendiente(
        activityId: resolvedId,
        finishedAt: swipeFinishedAt,
      );
    } catch (e, st) {
      appLogger.w(
        'No se pudo persistir horaFin por swipe terminar activity=${a.id}: $e\n$st',
      );
    }

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
      DateTime finishedAt = swipeFinishedAt;
      try {
        final existing = await _dao.getActivityById(resolvedId);
        if (existing?.finishedAt != null) {
          finishedAt = existing!.finishedAt!;
        }
      } catch (_) {
        // Fallback to in-memory finished timestamp.
      }

      final completedActivity = currentActivity.copyWith(
        executionState: ExecutionState.terminada,
        horaFin: finishedAt,
      );
      setState(() {
        _updateItem(a.id, _rehydrateFlow(completedActivity));
      });

      await _loadHomeActivities();
      return;
    }

    if (!mounted) return;
    final startTxt = pendingCapture.horaInicio != null
        ? _fmtTime(pendingCapture.horaInicio!)
        : '?';
    final endTxt = _fmtTime(swipeFinishedAt);
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
        _updateItem(a.id, _rehydrateFlow(completedActivity));
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
              title: Text(
                'Reportar incidencia',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              subtitle: Text(
                'Selecciona un motivo rápido (sin llenar todo el formulario)',
              ),
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
      _updateItem(a.id, _rehydrateFlow(updated));
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
        return _statusColor(
          originalStatus,
        ); // Color según vencida/hoy/programada
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

    await _handleCloudAction(
      isOffline: isOffline,
      isSyncing: syncState.isSyncing,
    );
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

  Color _taskSectionColor(String sectionId) {
    switch (sectionId) {
      case 'por_iniciar':
        return SaoColors.primary;
      case 'en_curso':
        return SaoColors.success;
      case 'por_completar':
        return SaoColors.warning;
      case 'por_corregir':
        return SaoColors.riskHigh;
      case 'error_sync':
        return SaoColors.error;
      case 'pendiente_sync':
        return SaoColors.info;
      case 'en_revision':
        return SaoColors.actionPrimary;
      default:
        return SaoColors.gray500;
    }
  }

  IconData _taskSectionIcon(String sectionId) {
    switch (sectionId) {
      case 'por_iniciar':
        return Icons.play_circle_fill_rounded;
      case 'en_curso':
        return Icons.timelapse_rounded;
      case 'por_completar':
        return Icons.edit_note_rounded;
      case 'por_corregir':
        return Icons.assignment_late_rounded;
      case 'error_sync':
        return Icons.cloud_off_rounded;
      case 'pendiente_sync':
        return Icons.cloud_upload_rounded;
      case 'en_revision':
        return Icons.fact_check_rounded;
      default:
        return Icons.inbox_rounded;
    }
  }

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
        appSnackBar(
          message: 'Selecciona un proyecto especifico para sincronizar.',
        ),
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
      await ref
          .read(syncOrchestratorProvider.notifier)
          .syncAll(projectId: widget.selectedProject);
      await _loadHomeActivities();
    } catch (_) {
      if (!mounted) return;
      showTransientSnackBar(
        context,
        appSnackBar(message: 'Error al sincronizar con backend'),
      );
    }
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
        final timestamp = state.updatedAt == null
            ? 'N/A'
            : _fmtDateTime(state.updatedAt!);

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
                if (state.errorMessage != null &&
                    state.errorMessage!.isNotEmpty) ...[
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
    final isSyncing = syncState.status == SyncOrchestratorStatus.syncing;
    final hasSyncError = syncState.status == SyncOrchestratorStatus.error;

    ref.listen<SyncOrchestratorState>(syncOrchestratorProvider, (
      previous,
      next,
    ) {
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
    final isTutorialGuest =
        GoRouterState.of(context).uri.queryParameters['tutorial'] == '1';
    final currentUser = ref.watch(currentUserProvider);
    final userInitial = currentUser?.fullName.trim().isNotEmpty == true
        ? currentUser!.fullName.trim()[0].toUpperCase()
        : '?';

    final baseItems = _items.where((a) {
      if (_isOperativeViewer) {
        return _matchesOperativeHomeRules(a);
      }
      if (_isAdminViewer) {
        final assigned =
            a.assignedToUserId != null && a.assignedToUserId!.trim().isNotEmpty;
        if (!assigned) return false;
      }
      final today = DateTime.now();
      final todayDate = DateTime(today.year, today.month, today.day);
      final dateFrom = switch (_dateRangeFilter) {
        DateRangeFilter.hoy => todayDate,
        DateRangeFilter.semana => todayDate.subtract(const Duration(days: 6)),
        DateRangeFilter.mes => DateTime(today.year, today.month - 1, today.day),
      };
      final created = DateTime(
        a.createdAt.year,
        a.createdAt.month,
        a.createdAt.day,
      );
      // Always show active (non-terminated) activities regardless of date range
      if (a.executionState != ExecutionState.terminada) return true;
      return !created.isBefore(dateFrom);
    }).toList();

    // ====== Filtrado por búsqueda ======
    var filtered = baseItems.where((a) => _matchesQuery(a, _query)).toList();

    // ====== Filtrado por modo (Totales / Vencidas / Completadas / Pend. Sync) ======
    if (_filterMode == FilterMode.vencidas) {
      filtered = filtered
          .where((a) => a.status == ActivityStatus.vencida)
          .toList();
    } else if (_filterMode == FilterMode.completadas) {
      filtered = filtered
          .where((a) => a.executionState == ExecutionState.terminada)
          .toList();
    } else if (_filterMode == FilterMode.pendienteSync) {
      filtered = filtered
          .where(
            (a) =>
                a.executionState == ExecutionState.terminada &&
                a.syncState == ActivitySyncState.pending,
          )
          .toList();
    }

    // ====== Bandeja por siguiente accion y subagrupado por frente ======
    final taskSections = buildHomeTaskSections(filtered);
    for (final section in taskSections) {
      for (final frente in section.groupedByFrente.keys) {
        final expansionKey = '${section.id}::$frente';
        _expandedByFrente.putIfAbsent(
          expansionKey,
          () => section.shouldAutoExpand,
        );
      }
    }

    // Regla anti doble cabecera:
    final showFrenteInsideCard = _query.trim().isNotEmpty;

    final totalCount = baseItems.where((a) => _matchesQuery(a, _query)).length;
    final vencidasCount = baseItems
        .where(
          (a) => _matchesQuery(a, _query) && a.status == ActivityStatus.vencida,
        )
        .length;
    final completadasCount = baseItems
        .where(
          (a) =>
              _matchesQuery(a, _query) &&
              a.executionState == ExecutionState.terminada,
        )
        .length;
    final pendienteSyncCount = baseItems
        .where(
          (a) =>
              _matchesQuery(a, _query) &&
              a.executionState == ExecutionState.terminada &&
              a.syncState == ActivitySyncState.pending,
        )
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
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: SaoColors.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: widget.onTapProject,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
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
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: SaoColors.gray500,
                          ),
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
                  icon: Icon(cloudIcon, color: cloudColor),
                ),
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      tooltip: 'Notificaciones',
                      onPressed: _openNotificationsCenter,
                      icon: const Icon(
                        Icons.notifications_none_rounded,
                        color: SaoColors.primary,
                      ),
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
                            border: Border.all(
                              color: SaoColors.surface,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(152),
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
                          const Icon(
                            Icons.search_rounded,
                            color: SaoColors.gray600,
                          ),
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
                              icon: const Icon(
                                Icons.close_rounded,
                                color: SaoColors.gray600,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Métricas con selección
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _MetricBadge(
                            label: 'Totales',
                            count: totalCount,
                            color: SaoColors.gray500,
                            isSelected: _filterMode == FilterMode.totales,
                            onTap: () => _setFilterMode(FilterMode.totales),
                          ),
                          const SizedBox(width: 8),
                          _MetricBadge(
                            label: 'Vencidas',
                            count: vencidasCount,
                            color: SaoColors.error,
                            isSelected: _filterMode == FilterMode.vencidas,
                            onTap: () => _setFilterMode(FilterMode.vencidas),
                          ),
                          const SizedBox(width: 8),
                          _MetricBadge(
                            label: 'Completadas',
                            count: completadasCount,
                            color: SaoColors.success,
                            isSelected: _filterMode == FilterMode.completadas,
                            onTap: () => _setFilterMode(FilterMode.completadas),
                          ),
                          const SizedBox(width: 8),
                          _MetricBadge(
                            label: 'Pend. Sync',
                            count: pendienteSyncCount,
                            color: SaoColors.warning,
                            isSelected: _filterMode == FilterMode.pendienteSync,
                            onTap: () =>
                                _setFilterMode(FilterMode.pendienteSync),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Filtro de rango de fechas
                    SegmentedButton<DateRangeFilter>(
                      showSelectedIcon: false,
                      style: SegmentedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        textStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        minimumSize: const Size(0, 30),
                      ),
                      segments: const [
                        ButtonSegment(
                          value: DateRangeFilter.hoy,
                          label: Text('Hoy'),
                        ),
                        ButtonSegment(
                          value: DateRangeFilter.semana,
                          label: Text('7 días'),
                        ),
                        ButtonSegment(
                          value: DateRangeFilter.mes,
                          label: Text('1 mes'),
                        ),
                      ],
                      selected: {_dateRangeFilter},
                      onSelectionChanged: (selection) {
                        if (selection.isNotEmpty)
                          _setDateRangeFilter(selection.first);
                      },
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
                          Icon(
                            Icons.school_outlined,
                            size: 18,
                            color: SaoColors.infoIcon,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Modo tutorial · Vista Inicio',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: SaoColors.infoText,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        '1) Asigna actividades desde Agenda (botón Asignar).',
                      ),
                      Text(
                        '2) Aquí inicia con swipe derecho cuando esté Pendiente.',
                      ),
                      Text(
                        '3) Termina con swipe derecho en En curso para abrir captura.',
                      ),
                      Text(
                        '4) Si queda en Revisión pendiente, vuelve a abrir y completa.',
                      ),
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: SaoColors.primary,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.history_rounded,
                                color: SaoColors.onPrimary,
                                size: 20,
                              ),
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
                              Icon(
                                Icons.chevron_right_rounded,
                                color: SaoColors.onPrimary,
                                size: 18,
                              ),
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: SaoColors.actionPrimary,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.bar_chart_rounded,
                                color: SaoColors.onPrimary,
                                size: 20,
                              ),
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
                              Icon(
                                Icons.chevron_right_rounded,
                                color: SaoColors.onPrimary,
                                size: 18,
                              ),
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
          else if (taskSections.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _EmptyState(
                title: _query.trim().isEmpty
                    ? 'Sin actividades'
                    : 'Sin resultados',
                subtitle: _query.trim().isEmpty
                    ? 'Todavía no hay registros para mostrar.\nCrea una nueva actividad con el botón +.'
                    : 'Prueba con otro PK, municipio o frente.',
                onClear: _query.trim().isEmpty ? null : _clearSearch,
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 120), // anti-FAB
              sliver: SliverToBoxAdapter(
                child: HomeTaskInboxList(
                  sections: taskSections,
                  colorForSection: _taskSectionColor,
                  iconForSection: _taskSectionIcon,
                  childrenBuilder: (context, section) {
                    final groupedByFrente = section.groupedByFrente;
                    return groupedByFrente.entries.map((entry) {
                      final frente = entry.key;
                      final items = entry.value;
                      final expansionKey = '${section.id}::$frente';
                      final expanded = _expandedByFrente[expansionKey] ?? true;

                      return _FrenteSection(
                        frente: frente,
                        count: items.length,
                        expanded: expanded,
                        onToggle: () => setState(
                          () => _expandedByFrente[expansionKey] = !expanded,
                        ),
                        children: expanded
                            ? items.map((a) {
                                final currentActivity = _findById(a.id) ?? a;
                                final barColor = _effectiveBarColor(
                                  a.id,
                                  a.status,
                                );
                                final icon = _effectiveIcon(a.id, a.status);
                                final footer = _effectiveFooterText(
                                  a.id,
                                  a.status,
                                );

                                return _SwipeActivityTile(
                                  key: ValueKey(a.id),
                                  a: a,
                                  isRejected: currentActivity.isRejected,
                                  executionState:
                                      currentActivity.executionState,
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
                                  assigneeLabel: _assigneeLabelFor(
                                    currentActivity,
                                  ),
                                  onTransferResponsibility:
                                      _canTransferResponsibility(
                                        currentActivity,
                                      )
                                      ? () => _openTransferResponsibilitySheet(
                                          currentActivity,
                                        )
                                      : null,
                                  transferInProgress: _transferringActivityIds
                                      .contains(a.id),
                                  onSyncCompleted:
                                      (currentActivity.executionState ==
                                              ExecutionState.terminada &&
                                          currentActivity.syncState !=
                                              ActivitySyncState.synced)
                                      ? () => _syncCompletedActivity(
                                          currentActivity,
                                        )
                                      : null,
                                  onDelete: _canDeleteActivity(currentActivity)
                                      ? () => _confirmDeleteActivity(currentActivity)
                                      : null,
                                );
                              }).toList()
                            : const [],
                      );
                    }).toList();
                  },
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
    if (_isAssignedToCurrentUser(
      assignedToUserId: activity.assignedToUserId,
      assignedToName: activity.assignedToName,
    )) {
      return 'Tú';
    }
    return name?.isNotEmpty == true ? name : null;
  }
}

class _TransferSelection {
  final Resource resource;
  final String? reason;

  const _TransferSelection({required this.resource, this.reason});
}

class _TransferResponsibilitySheet extends StatefulWidget {
  final TodayActivity activity;
  final List<Resource> candidates;

  const _TransferResponsibilitySheet({
    required this.activity,
    required this.candidates,
  });

  @override
  State<_TransferResponsibilitySheet> createState() =>
      _TransferResponsibilitySheetState();
}

class _TransferResponsibilitySheetState
    extends State<_TransferResponsibilitySheet> {
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
                final isSelected = candidate.id == _selectedResourceId;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    isSelected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    color: isSelected ? SaoColors.primary : SaoColors.gray400,
                  ),
                  title: Text(
                    candidate.name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(candidate.roleLabel),
                  trailing: isSelected
                      ? const Icon(
                          Icons.check_rounded,
                          color: SaoColors.primary,
                        )
                      : null,
                  selected: isSelected,
                  selectedTileColor: SaoColors.primary.withValues(alpha: 0.05),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onTap: () {
                    setState(() {
                      _selectedResourceId = candidate.id;
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
              hintText:
                  'Ej. cobertura de turno, apoyo en frente, cambio de ruta',
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
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Text(
              count.toString(),
              style: TextStyle(fontWeight: FontWeight.w900, color: color),
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
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: SaoColors.gray900,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: SaoColors.gray100,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: SaoColors.gray200),
                    ),
                    child: Text(
                      '$count',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: SaoColors.gray600,
                  ),
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
  final VoidCallback? onDelete;

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
    this.onDelete,
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
        return SaoColors
            .success; // Verde oscuro - Completada (no debería swipear)
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
      direction: isRejected
          ? DismissDirection.none
          : DismissDirection.horizontal,

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
            Icon(swipeIcon, color: swipeColor),
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
            Text(
              'Incidencia',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: SaoColors.riskHigh,
              ),
            ),
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
        onDelete: onDelete,
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
  final VoidCallback? onDelete;

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
    this.onDelete,
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
    final needsAttention =
        executionState == ExecutionState.revisionPendiente && !isRejected;
    final isActive = executionState == ExecutionState.enCurso;
    final isCompleted = executionState == ExecutionState.terminada;
    final hasAssignee =
        assigneeLabel != null && assigneeLabel!.trim().isNotEmpty;
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
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: SaoColors.warning.withValues(
                                    alpha: 0.12,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: SaoColors.warning),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.warning_rounded,
                                      size: 12,
                                      color: SaoColors.warning,
                                    ),
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
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: isRejected
                                      ? SaoColors.riskHigh.withValues(
                                          alpha: 0.12,
                                        )
                                      : SaoColors.riskMedium.withValues(
                                          alpha: 0.12,
                                        ),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isRejected
                                        ? SaoColors.riskHigh
                                        : SaoColors.riskMedium,
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
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
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
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
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
                            if (onDelete != null)
                              IconButton(
                                tooltip: 'Eliminar actividad',
                                splashRadius: 18,
                                onPressed: onDelete,
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  size: 18,
                                  color: SaoColors.riskHigh,
                                ),
                              ),
                          ],
                        ),
                        if (isCompleted) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: syncMeta.$2.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: syncMeta.$2.withValues(alpha: 0.35),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      syncMeta.$3,
                                      size: 12,
                                      color: syncMeta.$2,
                                    ),
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
                            [
                              a.municipio,
                              a.estado,
                            ].where((s) => s.isNotEmpty).join(', '),
                            style: const TextStyle(
                              fontSize: 13,
                              color: SaoColors.gray600,
                            ),
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
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  color: barColor,
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

class _PulsingBarState extends State<_PulsingBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _a;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _a = Tween<double>(
      begin: 0.35,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));

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
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(14),
              ),
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
              child: const Icon(
                Icons.inbox_rounded,
                size: 34,
                color: SaoColors.gray500,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: SaoColors.gray900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: SaoColors.gray600),
            ),
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
