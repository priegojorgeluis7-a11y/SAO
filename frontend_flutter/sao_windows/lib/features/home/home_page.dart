// lib/features/home/home_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/application/auth_providers.dart';
import '../../features/events/ui/report_event_sheet.dart';
import '../../ui/theme/sao_colors.dart';
import 'models/today_activity.dart';

enum FilterMode {
  totales,
  vencidas,
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
  static const List<TodayActivity> _seedData = [];

  // ====== Estado de datos (MUTABLE) ======
  late final List<TodayActivity> _items;

  // ====== UI State ======
  bool _isOffline = true;
  int _urgentCount = 0;
  String _query = '';
  final TextEditingController _searchCtrl = TextEditingController();
  final Map<String, bool> _expandedByFrente = {};
  
  // Filtros interactivos
  FilterMode _filterMode = FilterMode.totales;

  // ====== Estado de ejecución usando ExecutionState ======
  final Map<String, TodayActivity> _activityStates = {};

  @override
  void initState() {
    super.initState();
    _items = List<TodayActivity>.from(_seedData);
    _urgentCount = _items.where((a) => a.status == ActivityStatus.vencida).length;
    
    // Inicializar mapa de estados
    for (final item in _items) {
      _activityStates[item.id] = item;
    }

    // ✅ Si tu CatalogRepository necesita cargar JSON / drift, hazlo aquí.
    // ignore: unawaited_futures
    _safeInitCatalogs();
  }

  Future<void> _safeInitCatalogs() async {
    try {
      // Ej: await _catalogRepo.init();
      // Ej: await _catalogRepo.loadFromAssets();
      // Ej: await _catalogRepo.refreshIfOnline();
    } catch (_) {}
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
        return 'Programada hoy';
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Modo tutorial: en operación real aquí se abre el wizard para capturar y guardar.'),
          backgroundColor: SaoColors.info,
        ),
      );
      return false;
    }

    // Pasar la actividad con las horas ya registradas
    final currentActivity = _activityStates[a.id] ?? a;
    final result = await context.push(
      '/activity/${a.id}/wizard?project=${widget.selectedProject}',
      extra: currentActivity,
    );
    // result puede ser el ID de la actividad guardada o null si canceló
    return result != null; // true si guardó, false/null si canceló
  }

  // ====== NUEVO FLUJO: swipe derecha con 3 estados ======
  // PENDIENTE → Verde "Iniciar"
  // EN_CURSO → Rojo "Terminar" (abre wizard)
  // REVISION_PENDIENTE → Azul "Capturar" (re-abre wizard)
  void _onSwipeRight(TodayActivity a) async {
    final currentActivity = _activityStates[a.id] ?? a;
    
    HapticFeedback.mediumImpact();
    
    if (currentActivity.executionState == ExecutionState.pendiente) {
      // PASO 1: INICIAR
      _iniciarActividad(a);
    } else if (currentActivity.executionState == ExecutionState.enCurso) {
      // PASO 2: TERMINAR Y ABRIR FORMULARIO
      await _terminarYAbrirWizard(a);
    } else if (currentActivity.executionState == ExecutionState.revisionPendiente) {
      // PASO 3: RE-INTENTAR CAPTURA
      await _reintentarCaptura(a);
    }
  }

  void _iniciarActividad(TodayActivity a) {
    final now = DateTime.now();
    final gps = _mockGps();
    
    final updated = a.copyWith(
      executionState: ExecutionState.enCurso,
      horaInicio: now,
      gpsLocation: gps,
    );
    
    setState(() {
      _activityStates[a.id] = updated;
    });

    final t = _fmtTime(now);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ Actividad iniciada a las $t: ${a.title}'),
        backgroundColor: SaoColors.success,
      ),
    );
  }

  Future<void> _terminarYAbrirWizard(TodayActivity a) async {
    final now = DateTime.now();
    
    // Cambiar a estado intermedio (limbo)
    final updated = a.copyWith(
      executionState: ExecutionState.revisionPendiente,
      horaFin: now,
    );
    
    setState(() {
      _activityStates[a.id] = updated;
    });

    final currentActivity = _activityStates[a.id]!;
    final startTxt = currentActivity.horaInicio != null ? _fmtTime(currentActivity.horaInicio!) : '?';
    final endTxt = _fmtTime(now);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ Terminada ($startTxt–$endTxt). Abriendo formulario…'),
        backgroundColor: SaoColors.warning,
      ),
    );

    // Abrir wizard y esperar resultado
    final guardadoExitoso = await _openRegisterWizard(a);
    
    if (guardadoExitoso == true) {
      // Formulario guardado exitosamente
      final completedActivity = updated.copyWith(
        executionState: ExecutionState.terminada,
      );
      setState(() {
        _activityStates[a.id] = completedActivity;
      });
    }
    // Si guardadoExitoso es false o null, se queda en REVISION_PENDIENTE
  }

  Future<void> _reintentarCaptura(TodayActivity a) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('📝 Re-abriendo formulario para completar captura...'),
        backgroundColor: SaoColors.info,
      ),
    );
    
    final guardadoExitoso = await _openRegisterWizard(a);
    
    if (guardadoExitoso == true) {
      final currentActivity = _activityStates[a.id]!;
      final completedActivity = currentActivity.copyWith(
        executionState: ExecutionState.terminada,
      );
      setState(() {
        _activityStates[a.id] = completedActivity;
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

    // ✅ Obtener la actividad actualizada del estado (con horaInicio/horaFin preservados)
    final currentActivity = _activityStates[a.id] ?? a;
    
    // Marcar como incidencia - resetea el estado a pendiente pero conserva tiempos
    final updated = currentActivity.copyWith(
      executionState: ExecutionState.pendiente,
    );
    
    setState(() {
      _activityStates[a.id] = updated;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('⚠️ Incidencia registrada: $reason'),
        backgroundColor: SaoColors.riskHigh,
      ),
    );
  }

  // ====== Colores / iconos / textos efectivos basados en ExecutionState ======
  Color _effectiveBarColor(String activityId, ActivityStatus originalStatus) {
    final activity = _activityStates[activityId];
    if (activity == null) return _statusColor(originalStatus);
    
    switch (activity.executionState) {
      case ExecutionState.pendiente:
        return _statusColor(originalStatus); // Color según vencida/hoy/programada
      case ExecutionState.enCurso:
        return SaoColors.success; // Verde - En curso
      case ExecutionState.revisionPendiente:
        return SaoColors.warning; // Ámbar - Necesita captura
      case ExecutionState.terminada:
        return SaoColors.success; // Verde oscuro - Completada
    }
  }

  IconData _effectiveIcon(String activityId, ActivityStatus originalStatus) {
    final activity = _activityStates[activityId];
    if (activity == null) return _statusIcon(originalStatus);
    
    switch (activity.executionState) {
      case ExecutionState.pendiente:
        return _statusIcon(originalStatus);
      case ExecutionState.enCurso:
        return Icons.play_circle_fill_rounded;
      case ExecutionState.revisionPendiente:
        return Icons.edit_note_rounded;
      case ExecutionState.terminada:
        return Icons.verified_rounded;
    }
  }

  String _effectiveFooterText(String activityId, ActivityStatus originalStatus) {
    final activity = _activityStates[activityId];
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
        if (activity.horaInicio != null && activity.horaFin != null) {
          final start = _fmtTime(activity.horaInicio!);
          final end = _fmtTime(activity.horaFin!);
          return '⚠️ Captura Incompleta • $start–$end';
        }
        return '⚠️ Captura Incompleta';
      case ExecutionState.terminada:
        if (activity.horaInicio != null && activity.horaFin != null) {
          final start = _fmtTime(activity.horaInicio!);
          final end = _fmtTime(activity.horaFin!);
          return 'Terminada • $start–$end • Guardada';
        }
        return 'Terminada • Guardada';
    }
  }

  // ====== Utils ======
  String _mockGps() => '20.523,-100.812';

  String _fmtTime(DateTime dt) =>
      "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";

  void _clearSearch() {
    setState(() {
      _query = '';
      _searchCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isTutorialGuest = GoRouterState.of(context).uri.queryParameters['tutorial'] == '1';

    // ====== Filtrado por búsqueda ======
    var filtered = _items.where((a) => _matchesQuery(a, _query)).toList();
    
    // ====== Filtrado por modo (Totales / Vencidas) ======
    if (_filterMode == FilterMode.vencidas) {
      filtered = filtered.where((a) => a.status == ActivityStatus.vencida).toList();
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

    final totalCount = _items.where((a) => _matchesQuery(a, _query)).length;
    final vencidasCount = _items.where((a) => _matchesQuery(a, _query) && a.status == ActivityStatus.vencida).length;

    return Scaffold(
      backgroundColor: SaoColors.gray50,
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: 'fab_report_event',
            tooltip: 'Reportar evento',
            backgroundColor: SaoColors.riskHigh,
            foregroundColor: Colors.white,
            onPressed: () {
              final user = ref.read(currentUserProvider);
              showReportEventSheet(
                context,
                projectId: widget.selectedProject,
                reportedByUserId: user?.id ?? 'unknown',
              );
            },
            child: const Icon(Icons.warning_rounded),
          ),
          const SizedBox(height: 10),
          FloatingActionButton(
            heroTag: 'fab_add_activity',
            tooltip: 'Agregar actividad',
            onPressed: () => context.push(
                '/wizard/register?project=${widget.selectedProject}'),
            child: const Icon(Icons.add_rounded),
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
                const CircleAvatar(
                  radius: 16,
                  backgroundColor: SaoColors.gray100,
                  child: Text(
                    'L',
                    style: TextStyle(fontWeight: FontWeight.w900, color: SaoColors.primary),
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
                  tooltip: _isOffline ? 'Offline' : 'Online',
                  onPressed: () => setState(() => _isOffline = !_isOffline),
                  icon: Icon(
                    _isOffline ? Icons.cloud_off_rounded : Icons.cloud_done_rounded,
                    color: _isOffline ? SaoColors.gray400 : SaoColors.success,
                  ),
                ),
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      tooltip: 'Urgentes',
                      onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Abrir urgentes (pendiente)')),
                      ),
                      icon: const Icon(Icons.notifications_none_rounded, color: SaoColors.primary),
                    ),
                    if (_urgentCount > 0)
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
                          onTap: () => setState(() => _filterMode = FilterMode.totales),
                        ),
                        const SizedBox(width: 10),
                        _MetricBadge(
                          label: 'Vencidas',
                          count: vencidasCount,
                          color: SaoColors.error,
                          isSelected: _filterMode == FilterMode.vencidas,
                          onTap: () => setState(() => _filterMode = FilterMode.vencidas),
                        ),
                        const Spacer(),
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
                            'Modo tutorial · Vista Inicio',
                            style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF1E3A8A)),
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

          // Lista / Empty State
          if (grouped.isEmpty)
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
                              final currentActivity = _activityStates[a.id] ?? a;
                              final barColor = _effectiveBarColor(a.id, a.status);
                              final icon = _effectiveIcon(a.id, a.status);
                              final footer = _effectiveFooterText(a.id, a.status);

                              return _SwipeActivityTile(
                                key: ValueKey(a.id),
                                a: a,
                                executionState: currentActivity.executionState,
                                barColor: barColor,
                                footerIcon: icon,
                                footerText: footer,
                                pkText: _formatPk(a.pk),
                                showFrenteInsideCard: showFrenteInsideCard,
                                onTapOpenWizard: () => _openRegisterWizard(a),
                                onSwipeRight: () => _onSwipeRight(a),
                                onSwipeLeftIncident: () => _reportIncident(a),
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
          color: color.withOpacity(isSelected ? 0.18 : 0.10),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: color.withOpacity(isSelected ? 0.4 : 0.18),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: color.withOpacity(0.2),
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
  final ExecutionState executionState;
  final Color barColor;
  final IconData footerIcon;
  final String footerText;
  final String pkText;
  final bool showFrenteInsideCard;

  final VoidCallback onTapOpenWizard;
  final VoidCallback onSwipeRight;
  final VoidCallback onSwipeLeftIncident;

  const _SwipeActivityTile({
    super.key,
    required this.a,
    required this.executionState,
    required this.barColor,
    required this.footerIcon,
    required this.footerText,
    required this.pkText,
    required this.showFrenteInsideCard,
    required this.onTapOpenWizard,
    required this.onSwipeRight,
    required this.onSwipeLeftIncident,
  });

  // Colores dinámicos según el estado
  Color _getSwipeColor() {
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
      direction: DismissDirection.horizontal,

      // ✅ NO desaparece el item: usamos confirmDismiss y devolvemos false
      confirmDismiss: (dir) async {
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
          color: swipeColor.withOpacity(0.14),
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
                color: swipeColor.withOpacity(0.8),
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
          color: SaoColors.riskHigh.withOpacity(0.18),
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
        barColor: barColor,
        footerIcon: footerIcon,
        footerText: footerText,
        pkText: pkText,
        showFrenteInsideCard: showFrenteInsideCard,
        executionState: executionState,
        onTap: onTapOpenWizard,
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  final TodayActivity a;
  final Color barColor;
  final IconData footerIcon;
  final String footerText;
  final String pkText;
  final bool showFrenteInsideCard;
  final ExecutionState executionState;
  final VoidCallback onTap;

  const _ActivityTile({
    required this.a,
    required this.barColor,
    required this.footerIcon,
    required this.footerText,
    required this.pkText,
    required this.showFrenteInsideCard,
    required this.executionState,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasPk = a.pk != null;
    final needsAttention = executionState == ExecutionState.revisionPendiente;
    final isActive = executionState == ExecutionState.enCurso;

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
                color: needsAttention ? SaoColors.riskMedium : SaoColors.gray200,
                width: needsAttention ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                  color: needsAttention ? SaoColors.riskMedium.withOpacity(0.1) : SaoColors.gray900.withOpacity(0.04),
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
                            if (needsAttention)
                              Container(
                                margin: const EdgeInsets.only(right: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: SaoColors.riskMedium.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: SaoColors.riskMedium),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.edit_note_rounded, size: 12, color: SaoColors.riskHigh),
                                    SizedBox(width: 2),
                                    Text(
                                      'Pendiente',
                                      style: TextStyle(
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
                          ],
                        ),
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
                        Text(
                          '${a.municipio}, ${a.estado}',
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
