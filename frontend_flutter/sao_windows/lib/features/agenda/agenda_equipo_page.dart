// lib/features/agenda/agenda_equipo_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:drift/drift.dart' as drift;

import '../../core/connectivity/offline_mode_controller.dart';
import '../../core/utils/logger.dart';
import '../../core/utils/snackbar.dart';
import '../../data/local/app_db.dart' show AppDb, ActivitiesCompanion;
import '../../data/local/dao/activity_dao.dart';
import '../auth/application/auth_providers.dart';
import '../auth/data/models/user.dart';
import '../home/models/today_activity.dart';
import 'application/agenda_controller.dart';
import 'models/resource.dart';
import '../../ui/theme/sao_colors.dart';
import 'models/agenda_item.dart';
import 'widgets/week_strip.dart';
import 'widgets/filter_chips_row.dart';
import 'widgets/timeline_list.dart';
import 'widgets/dispatcher_bottom_sheet.dart';

class AgendaEquipoPage extends ConsumerStatefulWidget {
  const AgendaEquipoPage({super.key});

  @override
  ConsumerState<AgendaEquipoPage> createState() => _AgendaEquipoPageState();
}

class _AgendaEquipoPageState extends ConsumerState<AgendaEquipoPage> {
  late final ActivityDao _activityDao;

  @override
  void initState() {
    super.initState();
    _activityDao = ActivityDao(GetIt.I<AppDb>());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uri = GoRouterState.of(context).uri;
      final projectId = uri.queryParameters['project'];
      final isOffline = ref.read(offlineModeProvider);
      final authUser = ref.read(currentUserProvider);
      final selfResource = _toSelfResource(authUser);
      ref.read(agendaControllerProvider.notifier).initialize(
            projectId: projectId,
            isOffline: isOffline,
            selfResource: selfResource,
          );
    });
  }

  Resource? _toSelfResource(User? authUser) {
    if (authUser == null) return null;
    return Resource(
      id: authUser.id,
      name: authUser.fullName,
      email: authUser.email,
      role: ResourceRole.tecnico,
      // Must be selectable for self-assignment even if backend status varies.
      isActive: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<User?>(currentUserProvider, (previous, next) {
      final selfResource = _toSelfResource(next);
      ref.read(agendaControllerProvider.notifier).ensureSelfResource(selfResource);
    });

    final authUser = ref.watch(currentUserProvider);
    final state = ref.watch(agendaControllerProvider);
    final controller = ref.read(agendaControllerProvider.notifier);
    final isOffline = ref.watch(offlineModeProvider);
    // Estado del ícono cloud derivado únicamente del controller (sin setState local)
    final cloudIcon = state.isSyncing
        ? Icons.cloud_upload_rounded
        : (state.hasSyncError || isOffline)
            ? Icons.cloud_off_rounded
            : Icons.cloud_done_rounded;
    final cloudTooltip = state.isSyncing
        ? 'Sincronizando...'
        : state.hasSyncError
            ? 'Error de sync'
            : isOffline
                ? 'Offline'
                : 'Online';
    final cloudColor = state.isSyncing
        ? SaoColors.info
        : state.hasSyncError
            ? SaoColors.error
            : isOffline
                ? SaoColors.gray400
                : SaoColors.success;
    final isTutorialGuest =
        GoRouterState.of(context).uri.queryParameters['tutorial'] == '1';
    final filtered = _filterItems(state);

    return Scaffold(
      backgroundColor: SaoColors.gray50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Agenda de Equipo',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            onPressed: state.isSyncing
                ? null
                : () async {
                    final currentlyOffline = ref.read(offlineModeProvider);
                    if (currentlyOffline) {
                      await ref.read(offlineModeProvider.notifier).setOffline(false);
                    }
                    try {
                      await controller.syncNow();
                      if (context.mounted) {
                        showTransientSnackBar(
                          context,
                          appSnackBar(message: 'Agenda sincronizada'),
                        );
                      }
                    } catch (_) {
                      if (context.mounted) {
                        showTransientSnackBar(
                          context,
                          appSnackBar(message: 'Error al sincronizar agenda con backend'),
                        );
                      }
                    }
                  },
            icon: Icon(cloudIcon, color: cloudColor),
            tooltip: cloudTooltip,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async => _openDispatcher(context),
        backgroundColor: SaoColors.brandPrimary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Asignar'),
      ),
      body: Column(
        children: [
          if (isTutorialGuest)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: Container(
                width: double.infinity,
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
                          'Modo tutorial · Vista Agenda',
                          style: TextStyle(fontWeight: FontWeight.w700, color: SaoColors.infoText),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text('Pasos para asignar actividades:'),
                    Text('1) Pulsa Asignar para abrir el despachador.'),
                    Text('2) Elige recurso, día/hora y tipo de actividad.'),
                    Text('3) Guarda y valida que aparezca en la línea de tiempo.'),
                  ],
                ),
              ),
            ),
          WeekStrip(
            selectedDay: state.selectedDay,
            weekOffset: state.weekOffset,
            onChangeWeek: controller.changeWeek,
            onSelectDay: controller.selectDay,
            onGoToToday: controller.goToToday,
          ),
          FilterChipsRow(
            resources: state.resources,
            selectedFilterId: state.selectedFilterId,
            loading: state.loadingUsers,
            onFilterChange: controller.changeFilter,
          ),
          if (state.usersError != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: SaoColors.errorBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: SaoColors.errorBorder),
                ),
                child: Text(
                  state.usersError!,
                  style: const TextStyle(
                      color: SaoColors.errorText,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ),
          const SizedBox(height: 8),
          // Barra de progreso fina mientras se cargan las asignaciones
          if (state.loadingAssignments)
            const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: TimelineList(
              resources: state.resources,
              items: filtered,
              onAdvanceState: _advanceActivityStateFromAgenda,
              onCancelItem: (item) async {
                await controller.cancelAssignment(item);
                if (context.mounted) {
                  showTransientSnackBar(
                    context,
                    appSnackBar(
                      message: 'Asignación cancelada',
                      backgroundColor: SaoColors.success,
                    ),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _advanceActivityStateFromAgenda(AgendaItem item) async {
    final controller = ref.read(agendaControllerProvider.notifier);
    final activityId = (item.activityId?.trim().isNotEmpty ?? false)
        ? item.activityId!.trim()
        : item.id.trim();
    final now = DateTime.now();

    try {
      final existing = await _activityDao.getActivityById(activityId);
      final typeSeed = (item.activityTypeId?.trim().isNotEmpty ?? false)
          ? item.activityTypeId!.trim()
          : item.title;
      final activityTypeId = await _activityDao.resolveActivityTypeId(typeSeed);
      final createdBy = ref.read(currentUserProvider)?.id ?? item.resourceId;

      if (existing == null) {
        await _activityDao.upsertActivityRow(
          ActivitiesCompanion.insert(
            id: activityId,
            projectId: item.projectCode,
            activityTypeId: activityTypeId,
            title: item.title,
            createdAt: item.start,
            createdByUserId: createdBy,
            assignedToUserId: drift.Value(item.resourceId.trim().isNotEmpty ? item.resourceId.trim() : null),
            status: const drift.Value('SYNCED'),
            pk: drift.Value(item.pk),
          ),
        );
      }

      final nextAction = item.nextAction.trim().toUpperCase();
      if (nextAction == 'INICIAR_ACTIVIDAD') {
        await _activityDao.markActivityStarted(activityId: activityId, startedAt: now);
        if (!mounted) return;
        showTransientSnackBar(
          context,
          appSnackBar(
            message: 'Actividad iniciada desde Agenda.',
            backgroundColor: SaoColors.success,
          ),
        );
      } else {
        final startedAt = existing?.startedAt ?? item.start;
        await _activityDao.markActivityStarted(activityId: activityId, startedAt: startedAt);
        await _activityDao.markActivityRevisionPendiente(
          activityId: activityId,
          finishedAt: now,
        );
        if (!mounted) return;
        await context.push(
          '/activity/$activityId/wizard?project=${item.projectCode}',
          extra: TodayActivity(
            id: activityId,
            title: item.title,
            frente: item.frente,
            municipio: item.municipio,
            estado: item.estado,
            pk: item.pk,
            status: ActivityStatus.hoy,
            createdAt: item.start,
            executionState: ExecutionState.revisionPendiente,
            horaInicio: startedAt,
            horaFin: now,
            assignedToUserId: item.resourceId,
          ),
        );
      }

      await controller.refresh();
    } catch (e, st) {
      appLogger.w('Agenda advance state failed activity=$activityId: $e\n$st');
      if (!mounted) return;
      showTransientSnackBar(
        context,
        appSnackBar(
          message: 'No se pudo actualizar el estado de la actividad en Agenda.',
          backgroundColor: SaoColors.error,
        ),
      );
    }
  }

  List<AgendaItem> _filterItems(AgendaState state) {
    final dayStart = DateTime(state.selectedDay.year, state.selectedDay.month, state.selectedDay.day);
    final dayEnd = dayStart.add(const Duration(days: 1));

    // Filtro por día
    final byDay = state.items
        .where((it) => it.start.isBefore(dayEnd) && it.end.isAfter(dayStart))
        .toList();

    // Filtro por chip seleccionado
    if (state.selectedFilterId == 'Todos') return byDay;

    final isResource = state.resources.any((r) => r.id == state.selectedFilterId);
    if (isResource) {
      return byDay.where((it) => it.resourceId == state.selectedFilterId).toList();
    }

    // Aquí agregar filtros por frente/proyecto si es necesario
    return byDay;
  }

  Future<void> _openDispatcher(BuildContext context) async {
    HapticFeedback.mediumImpact();
    final controller = ref.read(agendaControllerProvider.notifier);
    final projectId = GoRouterState.of(context).uri.queryParameters['project'];
    final authUser = ref.read(currentUserProvider);

    await controller.ensureResourcesReady(projectId: projectId);
    if (!context.mounted) return;

    final state = ref.read(agendaControllerProvider);
    appLogger.i(
      'Agenda dispatcher open resources=${state.resources.length} '
      'loadingUsers=${state.loadingUsers} usersError=${state.usersError}',
    );

    if (state.resources.isEmpty) {
      if (!context.mounted) return;
      showTransientSnackBar(
        context,
        appSnackBar(
          message: state.usersError?.isNotEmpty == true
              ? state.usersError!
              : 'No hay recursos operativos disponibles para asignación.',
        ),
      );
      return;
    }

    showModalBottomSheet<AgendaItem>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => DispatcherBottomSheet(
        selectedDay: state.selectedDay,
        projectId: projectId,
        currentUserId: authUser?.id,
        resources: state.resources,
        existingItems: state.items,
        onCreate: (newItem) {
          controller.createAssignmentFromDispatcher(newItem);
          showTransientSnackBar(
            context,
            appSnackBar(
              message:
                  'Actividad asignada a ${_getResourceName(newItem.resourceId, state.resources)}',
              backgroundColor: SaoColors.success,
            ),
          );
        },
      ),
    );
  }

  String _getResourceName(String resourceId, List<Resource> resources) {
    try {
      return resources.firstWhere((r) => r.id == resourceId).name;
    } catch (_) {
      return 'Recurso desconocido';
    }
  }
}
