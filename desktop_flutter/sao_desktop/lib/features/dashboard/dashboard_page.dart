import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;

import '../../core/providers/project_providers.dart';
import '../../ui/theme/sao_colors.dart';
import '../operations/validation_page_new_design.dart';
import 'dashboard_provider.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  DashboardKpiFilter _kpiFilter = DashboardKpiFilter.all;
  String _planningStatusFilter = 'todos';
  String _planningRiskFilter = 'todos';
  String _planningReviewFilter = 'todos';
  bool _mapFiltersExpanded = false;

  @override
  Widget build(BuildContext context) {
    final range = ref.watch(selectedDashboardRangeProvider);
    final selectedProjectId = ref.watch(activeProjectIdProvider).trim().toUpperCase();
    final availableProjectsAsync = ref.watch(availableProjectsProvider);
    final projectOptions = <String>{
      for (final raw in (availableProjectsAsync.valueOrNull ?? const <String>[]))
        if (raw.trim().isNotEmpty) raw.trim().toUpperCase(),
      if (selectedProjectId.isNotEmpty) selectedProjectId,
    }.toList()
      ..sort();
    final dashboardAsync = ref.watch(dashboardProvider);

    return Scaffold(
      backgroundColor: SaoColors.gray50,
      body: dashboardAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 56, color: Colors.grey),
              const SizedBox(height: 12),
              Text('No se pudo cargar el dashboard: $e'),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => ref.invalidate(dashboardProvider),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
        data: (data) {
          final filteredQueue = _applyFilters(data.queueItems);
          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(data, range, selectedProjectId, projectOptions),
                  const SizedBox(height: 16),
                  _buildKpis(context, data),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isCompact = constraints.maxWidth < 1200;
                      if (isCompact) {
                        return Column(
                          children: [
                            _buildProgressCard(data),
                            const SizedBox(height: 16),
                            _buildTopErrorsCard(data),
                            const SizedBox(height: 16),
                            _buildMapsPanel(data),
                          ],
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: _buildProgressCard(data),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildTopErrorsCard(data),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildMapsPanel(
                            data,
                            mapHeight: 360,
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildCriticalQueueTable(filteredQueue),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(
    DashboardData data,
    DashboardRange range,
    String selectedProjectId,
    List<String> projectOptions,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.radar_rounded, color: Colors.white, size: 28),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Torre de Control | SAO Desktop',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          _buildProjectSelector(selectedProjectId, projectOptions),
          const SizedBox(width: 12),
          _chipStat('Cola total', '${data.totalInQueue} actos'),
          const SizedBox(width: 12),
          _buildRangeSelector(range),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () => ref.invalidate(dashboardProvider),
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            tooltip: 'Actualizar',
          ),
        ],
      ),
    );
  }

  Widget _buildProjectSelector(String selectedProjectId, List<String> projectOptions) {
    final selectedValue = selectedProjectId;
    return DropdownButtonHideUnderline(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: DropdownButton<String>(
          value: selectedValue,
          dropdownColor: SaoColors.gray800,
          iconEnabledColor: Colors.white,
          style: const TextStyle(color: Colors.white),
          onChanged: (value) {
            if (value == null) return;
            ref.read(activeProjectIdProvider.notifier).select(value);
          },
          items: [
            const DropdownMenuItem(value: '', child: Text('Todos')),
            ...projectOptions.map(
              (projectId) => DropdownMenuItem(value: projectId, child: Text(projectId)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chipStat(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _buildRangeSelector(DashboardRange range) {
    return DropdownButtonHideUnderline(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: DropdownButton<DashboardRange>(
          value: range,
          dropdownColor: SaoColors.gray800,
          iconEnabledColor: Colors.white,
          style: const TextStyle(color: Colors.white),
          onChanged: (value) {
            if (value == null) return;
            ref.read(selectedDashboardRangeProvider.notifier).state = value;
          },
          items: const [
            DropdownMenuItem(value: DashboardRange.today, child: Text('Hoy')),
            DropdownMenuItem(value: DashboardRange.week, child: Text('Semana')),
            DropdownMenuItem(value: DashboardRange.month, child: Text('Mes')),
          ],
        ),
      ),
    );
  }

  Widget _buildKpis(BuildContext context, DashboardData data) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = constraints.maxWidth < 1200 ? 2 : 5;
        return GridView.count(
          crossAxisCount: count,
          childAspectRatio: 2.1,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _kpiCard(
              title: data.range == DashboardRange.today ? 'Aprobados hoy' : 'Aprobados periodo',
              value: data.approvedCount,
              subtitle: _trendSubtitle(data.approvedTrend),
              trend: data.approvedTrend,
              color: SaoColors.success,
              icon: Icons.check_circle_rounded,
              filter: DashboardKpiFilter.approved,
            ),
            _kpiCard(
              title: 'Rechazados',
              value: data.rejectedCount,
              subtitle: _trendSubtitle(data.rejectedTrend),
              trend: data.rejectedTrend,
              color: SaoColors.error,
              icon: Icons.cancel_rounded,
              filter: DashboardKpiFilter.rejected,
            ),
            _kpiCard(
              title: 'Necesitan correccion',
              value: data.needsFixCount,
              subtitle: _trendSubtitle(data.needsFixTrend),
              trend: data.needsFixTrend,
              color: SaoColors.warning,
              icon: Icons.edit_note_rounded,
              filter: DashboardKpiFilter.needsFix,
            ),
            _kpiCard(
              title: 'Pendientes revision',
              value: data.pendingCount,
              subtitle: _trendSubtitle(data.pendingTrend),
              trend: data.pendingTrend,
              color: SaoColors.info,
              icon: Icons.pending_actions_rounded,
              filter: DashboardKpiFilter.pending,
            ),
            _kpiCard(
              title: 'Tiempo promedio validacion',
              value: data.avgValidationHours.round(),
              subtitle: '${data.avgValidationHours.toStringAsFixed(1)} h',
              trend: const DashboardTrend(current: 0, previous: 0),
              color: SaoColors.primaryLight,
              icon: Icons.timer_outlined,
              filter: DashboardKpiFilter.all,
            ),
          ],
        );
      },
    );
  }

  Widget _kpiCard({
    required String title,
    required int value,
    required String subtitle,
    required DashboardTrend trend,
    required Color color,
    required IconData icon,
    required DashboardKpiFilter filter,
  }) {
    final selected = _kpiFilter == filter;
    final sparkline = _sparklinePoints(trend);
    return InkWell(
      onTap: () => setState(() => _kpiFilter = filter),
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: SaoColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? color : SaoColors.border,
            width: selected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: SaoColors.gray900.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const Spacer(),
                SizedBox(
                  width: 72,
                  height: 24,
                  child: CustomPaint(painter: _SparklinePainter(sparkline, color)),
                ),
              ],
            ),
            const Spacer(),
            Text(
              '$value',
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: color),
            ),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700, color: SaoColors.gray800)),
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(color: SaoColors.gray500, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressCard(DashboardData data) {
    final frontRows = data.frontProgress.map(_frontProgressRow).toList(growable: false);
    final useScroll = frontRows.length > 4;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: SaoColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SaoColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Avance de Validacion: Planeado vs Ejecutado por Tramo/Frente',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          if (data.frontProgress.isEmpty)
            const _EmptyState(
              icon: Icons.bar_chart_rounded,
              iconColor: SaoColors.gray300,
              message: 'Sin datos para el periodo seleccionado',
            )
          else if (useScroll)
            SizedBox(
              height: 240,
              child: Scrollbar(
                thumbVisibility: true,
                child: ListView(
                  children: frontRows,
                ),
              ),
            )
          else
            ...frontRows,
        ],
      ),
    );
  }

  Widget _buildTopErrorsCard(DashboardData data) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: SaoColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SaoColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.error_outline_rounded, size: 20, color: SaoColors.warning),
              SizedBox(width: 8),
              Text('Top 5 errores comunes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 12),
          if (data.topErrors.isEmpty)
            const _EmptyState(
              icon: Icons.check_circle_outline_rounded,
              iconColor: SaoColors.success,
              message: 'Sin errores detectados en el periodo',
            )
          else
            ...data.topErrors.take(5).map((item) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(child: Text(item.label, style: const TextStyle(color: SaoColors.gray700))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: SaoColors.gray100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('${item.count}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _frontProgressRow(FrontProgressItem item) {
    final ratio = item.planned == 0 ? 0.0 : (item.executed / item.planned).clamp(0, 1).toDouble();
    final pct = (ratio * 100).round();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.front,
                  style: const TextStyle(fontSize: 12, color: SaoColors.gray700, fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                '${item.executed}/${item.planned}',
                style: const TextStyle(fontSize: 12, color: SaoColors.gray600),
              ),
              const SizedBox(width: 8),
              Text(
                '$pct%',
                style: const TextStyle(fontSize: 12, color: SaoColors.info, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Align(
            alignment: Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: LinearProgressIndicator(
                minHeight: 12,
                value: ratio,
                borderRadius: BorderRadius.circular(10),
                backgroundColor: SaoColors.gray200,
                color: SaoColors.info,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapsPanel(
    DashboardData data, {
    double mapHeight = 280,
    double minCardHeight = 0,
  }) {
    final planningPoints = _filterPlanningMapPoints(data.geoPoints);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildMapCard(
          title: 'Mapa de Calor',
          subtitle: 'Actividades registradas del periodo seleccionado',
          points: planningPoints,
          summary: 'Planeacion · ${planningPoints.length} puntos',
          emptyMessage: 'Sin actividades registradas para esos filtros',
          filtersSection: _buildCompactMapFilters(),
          mapHeight: mapHeight,
          minCardHeight: minCardHeight,
        ),
      ],
    );
  }

  Widget _buildMapCard({
    required String title,
    required String subtitle,
    required List<DashboardGeoPoint> points,
    required String summary,
    required String emptyMessage,
    required Widget filtersSection,
    required double mapHeight,
    required double minCardHeight,
  }) {
    final locationCounts = _locationCountsFor(points);
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: minCardHeight),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: SaoColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: SaoColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(fontSize: 12, color: SaoColors.gray600)),
            const SizedBox(height: 12),
            filtersSection,
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: mapHeight,
                child: points.isEmpty
                    ? Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: SaoColors.gray50,
                          border: Border.all(color: SaoColors.gray300),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.map_rounded, size: 42, color: SaoColors.gray400),
                              const SizedBox(height: 8),
                              Text(summary, style: const TextStyle(fontWeight: FontWeight.w700, color: SaoColors.gray700)),
                              const SizedBox(height: 4),
                              Text(emptyMessage, style: const TextStyle(fontSize: 12, color: SaoColors.gray500)),
                            ],
                          ),
                        ),
                      )
                    : FlutterMap(
                        options: MapOptions(
                          initialCenter: _mapCenter(points),
                          initialZoom: points.length == 1 ? 11.0 : 8.0,
                          initialCameraFit: points.length > 1
                              ? CameraFit.bounds(
                                  bounds: _mapBounds(points),
                                  padding: const EdgeInsets.all(40),
                                )
                              : null,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'mx.sao.desktop',
                          ),
                          CircleLayer(
                            circles: points.map((item) {
                              final color = SaoColors.getRiskColor(item.risk);
                              return CircleMarker(
                                point: LatLng(item.lat, item.lon),
                                radius: 9,
                                color: color.withValues(alpha: 0.65),
                                borderColor: color,
                                borderStrokeWidth: 1.5,
                              );
                            }).toList(),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Conteo por estado/municipio', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            if (locationCounts.isEmpty)
              const _EmptyState(
                icon: Icons.location_off_outlined,
                iconColor: SaoColors.gray300,
                message: 'Sin ubicaciones disponibles',
              )
            else
              SizedBox(
                height: (locationCounts.length * 28.0).clamp(40.0, 160.0),
                child: Scrollbar(
                  thumbVisibility: locationCounts.length > 5,
                  child: ListView.builder(
                    itemCount: locationCounts.length,
                    itemBuilder: (context, index) {
                      final item = locationCounts[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            Expanded(child: Text(item.label, style: const TextStyle(color: SaoColors.gray700))),
                            Text('${item.count}', style: const TextStyle(fontWeight: FontWeight.w700)),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactMapFilters() {
    final activeCount = [_planningStatusFilter, _planningRiskFilter, _planningReviewFilter]
        .where((value) => value != 'todos')
        .length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: () => setState(() => _mapFiltersExpanded = !_mapFiltersExpanded),
              icon: Icon(
                _mapFiltersExpanded ? Icons.filter_alt_off_rounded : Icons.filter_alt_rounded,
                size: 16,
              ),
              label: Text('Filtros del mapa ($activeCount activos)'),
            ),
            if (activeCount > 0) ...[
              const SizedBox(width: 8),
              TextButton(
                onPressed: () {
                  setState(() {
                    _planningStatusFilter = 'todos';
                    _planningRiskFilter = 'todos';
                    _planningReviewFilter = 'todos';
                  });
                },
                child: const Text('Limpiar'),
              ),
            ],
          ],
        ),
        if (_mapFiltersExpanded) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 116,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildInlineFilterGroup(
                  title: 'Estado',
                  chips: [
                    _mapFilterChip('Todos', _planningStatusFilter == 'todos', () => setState(() => _planningStatusFilter = 'todos'), SaoColors.gray600),
                    _mapFilterChip('Pendiente', _planningStatusFilter == 'PENDIENTE', () => setState(() => _planningStatusFilter = 'PENDIENTE'), SaoColors.statusPendiente),
                    _mapFilterChip('En curso', _planningStatusFilter == 'EN_CURSO', () => setState(() => _planningStatusFilter = 'EN_CURSO'), SaoColors.statusEnCampo),
                    _mapFilterChip('En revision', _planningStatusFilter == 'REVISION_PENDIENTE', () => setState(() => _planningStatusFilter = 'REVISION_PENDIENTE'), SaoColors.statusEnValidacion),
                    _mapFilterChip('Completada', _planningStatusFilter == 'COMPLETADA', () => setState(() => _planningStatusFilter = 'COMPLETADA'), SaoColors.statusAprobado),
                  ],
                ),
                const SizedBox(width: 12),
                _buildInlineFilterGroup(
                  title: 'Riesgo',
                  chips: [
                    _mapFilterChip('Todos', _planningRiskFilter == 'todos', () => setState(() => _planningRiskFilter = 'todos'), SaoColors.gray600),
                    _mapFilterChip('Bajo', _planningRiskFilter == 'bajo', () => setState(() => _planningRiskFilter = 'bajo'), SaoColors.riskLow),
                    _mapFilterChip('Medio', _planningRiskFilter == 'medio', () => setState(() => _planningRiskFilter = 'medio'), SaoColors.riskMedium),
                    _mapFilterChip('Alto', _planningRiskFilter == 'alto', () => setState(() => _planningRiskFilter = 'alto'), SaoColors.riskHigh),
                    _mapFilterChip('Prioritario', _planningRiskFilter == 'prioritario', () => setState(() => _planningRiskFilter = 'prioritario'), SaoColors.riskPriority),
                  ],
                ),
                const SizedBox(width: 12),
                _buildInlineFilterGroup(
                  title: 'Revision',
                  chips: [
                    _mapFilterChip('Todas', _planningReviewFilter == 'todos', () => setState(() => _planningReviewFilter = 'todos'), SaoColors.gray600),
                    _mapFilterChip('Aprobada', _planningReviewFilter == 'APROBADO', () => setState(() => _planningReviewFilter = 'APROBADO'), SaoColors.statusAprobado),
                    _mapFilterChip('Pendiente', _planningReviewFilter == 'PENDIENTE_REVISION', () => setState(() => _planningReviewFilter = 'PENDIENTE_REVISION'), SaoColors.statusEnValidacion),
                    _mapFilterChip('Rechazada', _planningReviewFilter == 'RECHAZADO', () => setState(() => _planningReviewFilter = 'RECHAZADO'), SaoColors.statusRechazado),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildInlineFilterGroup({required String title, required List<Widget> chips}) {
    return Container(
      width: 280,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: SaoColors.gray50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: SaoColors.gray200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: SaoColors.gray600),
          ),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 8, children: chips),
        ],
      ),
    );
  }

  LatLng _mapCenter(List<DashboardGeoPoint> points) {
    final lat = points.map((p) => p.lat).reduce((a, b) => a + b) / points.length;
    final lon = points.map((p) => p.lon).reduce((a, b) => a + b) / points.length;
    return LatLng(lat, lon);
  }

  LatLngBounds _mapBounds(List<DashboardGeoPoint> points) {
    double minLat = points.first.lat;
    double maxLat = points.first.lat;
    double minLon = points.first.lon;
    double maxLon = points.first.lon;
    for (final p in points) {
      if (p.lat < minLat) minLat = p.lat;
      if (p.lat > maxLat) maxLat = p.lat;
      if (p.lon < minLon) minLon = p.lon;
      if (p.lon > maxLon) maxLon = p.lon;
    }
    return LatLngBounds(
      LatLng(minLat - 0.1, minLon - 0.1),
      LatLng(maxLat + 0.1, maxLon + 0.1),
    );
  }

  Widget _mapFilterChip(String label, bool active, VoidCallback onTap, Color color) {
    final inactiveBorder = color == SaoColors.gray600 ? SaoColors.gray300 : color.withValues(alpha: 0.55);
    final inactiveText = color == SaoColors.gray600 ? SaoColors.gray600 : color.withValues(alpha: 0.95);
    final inactiveBg = color == SaoColors.gray600 ? SaoColors.gray100 : color.withValues(alpha: 0.06);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.16) : inactiveBg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: active ? color : inactiveBorder),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? color : inactiveText,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildCriticalQueueTable(List<ValidationQueueItem> items) {
    final sorted = [...items]
      ..sort((a, b) {
        if (a.isOver24h == b.isOver24h) {
          return b.createdAt.compareTo(a.createdAt);
        }
        return a.isOver24h ? -1 : 1;
      });

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: SaoColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SaoColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Cola de Validacion Critica', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text(
            'Pendientes de revision con prioridad alta y rezago >24h',
            style: TextStyle(color: SaoColors.gray600),
          ),
          const SizedBox(height: 12),
          if (sorted.isEmpty)
            const _EmptyState(
              icon: Icons.local_cafe_rounded,
              iconColor: SaoColors.success,
              message: 'Todo al dia. No hay validaciones criticas pendientes con rezago mayor a 24h',
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: const WidgetStatePropertyAll(SaoColors.gray100),
                columns: const [
                  DataColumn(label: Text('ID')),
                  DataColumn(label: Text('Proyecto')),
                  DataColumn(label: Text('Usuario')),
                  DataColumn(label: Text('Tipo')),
                  DataColumn(label: Text('PK / Ubicacion')),
                  DataColumn(label: Text('Riesgo')),
                  DataColumn(label: Text('Accion')),
                ],
                rows: sorted.take(25).map((item) {
                  final riskColor = SaoColors.getRiskColor(item.risk);
                  return DataRow(
                    color: item.isOver24h
                        ? WidgetStateProperty.all(SaoColors.alertBg)
                        : null,
                    cells: [
                      DataCell(Text(_shortId(item.id))),
                      DataCell(Text(item.projectId)),
                      DataCell(Text(item.userName)),
                      DataCell(Text(item.activityType)),
                      DataCell(Text('${item.pk} · ${item.municipality.isNotEmpty ? item.municipality : item.front}')),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: riskColor.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            item.risk.toUpperCase(),
                            style: TextStyle(color: riskColor, fontWeight: FontWeight.w700, fontSize: 11),
                          ),
                        ),
                      ),
                      DataCell(
                        FilledButton.icon(
                          onPressed: () => _openReviewPage(item.id),
                          style: item.isOver24h
                              ? FilledButton.styleFrom(
                                  backgroundColor: SaoColors.error,
                                  foregroundColor: Colors.white,
                                )
                              : null,
                          icon: const Icon(Icons.rate_review_rounded, size: 16),
                          label: const Text('Revisar ahora'),
                        ),
                      ),
                    ],
                  );
                }).toList(growable: false),
              ),
            ),
        ],
      ),
    );
  }

  List<ValidationQueueItem> _applyFilters(List<ValidationQueueItem> items) {
    return items.where((item) {
      final byKpi = switch (_kpiFilter) {
        DashboardKpiFilter.all => true,
        DashboardKpiFilter.pending => item.status == 'PENDIENTE_REVISION',
        DashboardKpiFilter.approved => item.status == 'APROBADO',
        DashboardKpiFilter.rejected => item.status == 'RECHAZADO',
        DashboardKpiFilter.needsFix => item.status == 'NECESITA_CORRECCION' || item.status == 'EN_CURSO',
      };
      return byKpi;
    }).toList(growable: false);
  }

  List<DashboardGeoPoint> _filterPlanningMapPoints(List<DashboardGeoPoint> items) {
    return items.where((item) {
      final byStatus = _planningStatusFilter == 'todos' || _normalizeExecutionStatus(item.status) == _planningStatusFilter;
      final byRisk = _planningRiskFilter == 'todos' || item.risk == _planningRiskFilter;
      final byReview = _planningReviewFilter == 'todos' || _normalizeReviewStatus(item.reviewStatus) == _planningReviewFilter;
      return byStatus && byRisk && byReview;
    }).toList(growable: false);
  }

  List<LocationCountItem> _locationCountsFor(List<DashboardGeoPoint> points) {
    final counts = <String, int>{};
    for (final item in points) {
      final label = item.municipality.isNotEmpty
          ? '${item.municipality}${item.state.isNotEmpty ? ' / ${item.state}' : ''}'
          : (item.front.isNotEmpty ? item.front : 'Sin ubicacion');
      counts[label] = (counts[label] ?? 0) + 1;
    }
    final result = counts.entries
        .map((entry) => LocationCountItem(label: entry.key, count: entry.value))
        .toList(growable: false);
    result.sort((a, b) => b.count.compareTo(a.count));
    return result;
  }

  String _normalizeExecutionStatus(String raw) {
    final normalized = raw.trim().toUpperCase().replaceAll(' ', '_');
    if (normalized == 'PENDIENTE_REVISION') return 'REVISION_PENDIENTE';
    if (normalized == 'EN_REVISION') return 'REVISION_PENDIENTE';
    if (normalized == 'PROGRAMADA') return 'PENDIENTE';
    return normalized;
  }

  String _normalizeReviewStatus(String raw) {
    final normalized = raw.trim().toUpperCase().replaceAll(' ', '_');
    if (normalized == 'APROBADA') return 'APROBADO';
    if (normalized == 'RECHAZADA') return 'RECHAZADO';
    if (normalized == 'PENDIENTE' || normalized == 'EN_REVISION') return 'PENDIENTE_REVISION';
    return normalized;
  }

  String _trendSubtitle(DashboardTrend trend) {
    if (trend.previous == 0 && trend.current == 0) return 'Sin cambios vs periodo anterior';
    if (trend.delta == 0) return 'Sin cambios vs periodo anterior';
    final direction = trend.delta > 0 ? 'subiendo' : 'bajando';
    return '${trend.delta.abs()} vs periodo anterior · $direction';
  }

  List<double> _sparklinePoints(DashboardTrend trend) {
    final prev = trend.previous.toDouble();
    final curr = trend.current.toDouble();
    final mid = (prev + curr) / 2;
    final floor = (prev * 0.7).clamp(0.0, double.infinity).toDouble();
    return [floor, prev, mid, curr];
  }

  String _shortId(String id) {
    if (id.length <= 10) return id;
    return '${id.substring(0, 8)}...';
  }

  void _openReviewPage(String activityId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ValidationPageNewDesign(initialActivityId: activityId),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> values;
  final Color color;

  _SparklinePainter(this.values, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final minV = values.reduce((a, b) => a < b ? a : b);
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final delta = (maxV - minV).abs() < 0.001 ? 1.0 : (maxV - minV);

    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = i / (values.length - 1) * size.width;
      final y = size.height - ((values[i] - minV) / delta * size.height);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    // Filled area under the sparkline
    final areaPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      areaPath,
      Paint()
        ..color = color.withValues(alpha: 0.15)
        ..style = PaintingStyle.fill,
    );

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) {
    return oldDelegate.values != values || oldDelegate.color != color;
  }
}

// ---------------------------------------------------------------------------
// Shared empty-state widget
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String message;

  const _EmptyState({
    required this.icon,
    required this.iconColor,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 36, color: iconColor.withValues(alpha: 0.6)),
            const SizedBox(height: 8),
            Text(message, style: const TextStyle(color: SaoColors.gray500)),
          ],
        ),
      ),
    );
  }
}
