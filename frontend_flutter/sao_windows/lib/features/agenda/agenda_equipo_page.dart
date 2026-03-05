// lib/features/agenda/agenda_equipo_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/connectivity/offline_mode_controller.dart';
import '../../ui/theme/sao_colors.dart';
import 'application/agenda_controller.dart';
import 'models/resource.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uri = GoRouterState.of(context).uri;
      final projectId = uri.queryParameters['project'];
      final isOffline = ref.read(offlineModeProvider);
      ref.read(agendaControllerProvider.notifier).initialize(
            projectId: projectId,
            isOffline: isOffline,
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(agendaControllerProvider);
    final controller = ref.read(agendaControllerProvider.notifier);
    final isTutorialGuest = GoRouterState.of(context).uri.queryParameters['tutorial'] == '1';
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
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Sincronizando agenda...')),
              );
            },
            icon: const Icon(Icons.cloud_sync_rounded),
            tooltip: 'Sincronizar',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openDispatcher(context),
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
                  style: const TextStyle(color: SaoColors.errorText, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          const SizedBox(height: 8),
          Expanded(
            child: TimelineList(
              resources: state.resources,
              items: filtered,
            ),
          ),
        ],
      ),
    );
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

  void _openDispatcher(BuildContext context) {
    HapticFeedback.mediumImpact();
    final state = ref.read(agendaControllerProvider);
    final controller = ref.read(agendaControllerProvider.notifier);
    final projectId = GoRouterState.of(context).uri.queryParameters['project'];

    showModalBottomSheet<AgendaItem>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => DispatcherBottomSheet(
        selectedDay: state.selectedDay,
        projectId: projectId,
        resources: state.resources,
        existingItems: state.items,
        onCreate: (newItem) {
          controller.createAssignmentFromDispatcher(newItem);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Actividad asignada a ${_getResourceName(newItem.resourceId, state.resources)}'),
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
