// lib/features/agenda/agenda_equipo_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'models/resource.dart';
import 'models/agenda_item.dart';
import 'widgets/week_strip.dart';
import 'widgets/filter_chips_row.dart';
import 'widgets/timeline_list.dart';
import 'widgets/dispatcher_bottom_sheet.dart';

class AgendaEquipoPage extends StatefulWidget {
  const AgendaEquipoPage({super.key});

  @override
  State<AgendaEquipoPage> createState() => _AgendaEquipoPageState();
}

class _AgendaEquipoPageState extends State<AgendaEquipoPage> {
  DateTime selectedDay = DateTime.now();
  int weekOffset = 0;

  // Dataset local inicial (alineado a catálogos reales)
  final resources = <Resource>[
    const Resource(
      id: 'r1',
      name: 'Juan Pérez García',
      role: ResourceRole.ingeniero,
    ),
    const Resource(
      id: 'r2',
      name: 'María González',
      role: ResourceRole.topografo,
    ),
    const Resource(
      id: 'r3',
      name: 'Luis Hernández',
      role: ResourceRole.tecnico,
    ),
    const Resource(
      id: 'r4',
      name: 'Ana Martínez',
      role: ResourceRole.ingeniero,
    ),
  ];

  String selectedFilterId = 'Todos'; // "Todos" | resourceId | "Frente X"

  List<AgendaItem> items = [];

  @override
  void initState() {
    super.initState();
    _loadSeedData();
  }

  void _loadSeedData() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    items = [
      AgendaItem(
        id: 'ag_cam_001',
        resourceId: 'r1',
        title: 'Caminamiento CAM_DDV - Verificación de DDV',
        projectCode: 'TMQ',
        frente: 'TMQ • Tramo 1: Apaseo Norte',
        municipio: 'Apaseo el Grande',
        estado: 'Guanajuato',
        pk: 142300,
        start: today.add(const Duration(hours: 9)),
        end: today.add(const Duration(hours: 11)),
        risk: RiskLevel.medio,
        syncStatus: SyncStatus.synced,
        activityTypeId: 'CAM',
      ),
      AgendaItem(
        id: 'ag_reu_014',
        resourceId: 'r2',
        title: 'Reunión REU_TEC - Coordinación institucional',
        projectCode: 'TMQ',
        frente: 'TMQ • Tramo 2: Celaya Centro',
        municipio: 'Celaya',
        estado: 'Guanajuato',
        pk: 145100,
        start: today.add(const Duration(hours: 10)),
        end: today.add(const Duration(hours: 12)),
        risk: RiskLevel.bajo,
        syncStatus: SyncStatus.uploading,
        activityTypeId: 'REU',
      ),
      AgendaItem(
        id: 'ag_asp_006',
        resourceId: 'r1',
        title: 'Asamblea ASP_2AP - Firma de COP',
        projectCode: 'TMQ',
        frente: 'TMQ • Tramo 3: Pedro Escobedo',
        municipio: 'Pedro Escobedo',
        estado: 'Querétaro',
        pk: 167000,
        start: today.add(const Duration(hours: 14)),
        end: today.add(const Duration(hours: 16)),
        risk: RiskLevel.alto,
        syncStatus: SyncStatus.pending,
        activityTypeId: 'ASP',
      ),
      AgendaItem(
        id: 'ag_cin_003',
        resourceId: 'r3',
        title: 'Consulta CIN_CON - Construcción de acuerdos',
        projectCode: 'TAP',
        frente: 'TAP • Segmento A: Tizayuca',
        municipio: 'Tizayuca',
        estado: 'Hidalgo',
        pk: 31800,
        start: today.add(const Duration(hours: 12, minutes: 30)),
        end: today.add(const Duration(hours: 13, minutes: 45)),
        risk: RiskLevel.prioritario,
        syncStatus: SyncStatus.error,
        activityTypeId: 'CIN',
      ),
      AgendaItem(
        id: 'ag_soc_011',
        resourceId: 'r4',
        title: 'Socialización SOC_ATN - Atención a inquietudes',
        projectCode: 'TAP',
        frente: 'TAP • Segmento B: Temascalapa',
        municipio: 'Temascalapa',
        estado: 'Estado de México',
        pk: null,
        start: today.add(const Duration(hours: 16, minutes: 30)),
        end: today.add(const Duration(hours: 18)),
        risk: RiskLevel.medio,
        syncStatus: SyncStatus.synced,
        activityTypeId: 'SOC',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final isTutorialGuest = GoRouterState.of(context).uri.queryParameters['tutorial'] == '1';
    final filtered = _filterItems();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
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
        backgroundColor: const Color(0xFF691C32),
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
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.school_outlined, size: 18, color: Color(0xFF1D4ED8)),
                        SizedBox(width: 6),
                        Text(
                          'Modo tutorial · Vista Agenda',
                          style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF1E3A8A)),
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
            selectedDay: selectedDay,
            weekOffset: weekOffset,
            onChangeWeek: (delta) => setState(() => weekOffset += delta),
            onSelectDay: (d) => setState(() => selectedDay = d),
          ),
          FilterChipsRow(
            resources: resources,
            selectedFilterId: selectedFilterId,
            onFilterChange: (id) => setState(() => selectedFilterId = id),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: TimelineList(
              resources: resources,
              items: filtered,
            ),
          ),
        ],
      ),
    );
  }

  List<AgendaItem> _filterItems() {
    final dayStart = DateTime(selectedDay.year, selectedDay.month, selectedDay.day);
    final dayEnd = dayStart.add(const Duration(days: 1));

    // Filtro por día
    final byDay = items
        .where((it) => it.start.isBefore(dayEnd) && it.end.isAfter(dayStart))
        .toList();

    // Filtro por chip seleccionado
    if (selectedFilterId == 'Todos') return byDay;

    final isResource = resources.any((r) => r.id == selectedFilterId);
    if (isResource) {
      return byDay.where((it) => it.resourceId == selectedFilterId).toList();
    }

    // Aquí agregar filtros por frente/proyecto si es necesario
    return byDay;
  }

  void _openDispatcher(BuildContext context) {
    HapticFeedback.mediumImpact();
    
    showModalBottomSheet<AgendaItem>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => DispatcherBottomSheet(
        selectedDay: selectedDay,
        resources: resources,
        existingItems: items,
        onCreate: (newItem) {
          setState(() {
            items.add(newItem);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Actividad asignada a ${_getResourceName(newItem.resourceId)}'),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
        },
      ),
    );
  }

  String _getResourceName(String resourceId) {
    try {
      return resources.firstWhere((r) => r.id == resourceId).name;
    } catch (_) {
      return 'Recurso desconocido';
    }
  }
}
