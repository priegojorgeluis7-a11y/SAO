import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math' as math;
import '../../ui/theme/sao_colors.dart';
import 'dashboard_provider.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        data: (data) => _DashboardContent(data: data, onRefresh: () => ref.invalidate(dashboardProvider)),
      ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  final DashboardData data;
  final VoidCallback onRefresh;

  const _DashboardContent({required this.data, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final approvedPct = data.totalInQueue > 0
        ? (data.approvedToday / data.totalInQueue * 100).round()
        : 0;

    return CustomScrollView(
      slivers: [
        // Header
        SliverToBoxAdapter(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [SaoColors.primary, SaoColors.gray900],
              ),
              boxShadow: [
                BoxShadow(
                  color: SaoColors.gray900.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.radar_rounded, color: SaoColors.onPrimary, size: 32),
                const SizedBox(width: 12),
                const Text(
                  'Torre de Control | SAO Desktop',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: SaoColors.onPrimary,
                  ),
                ),
                const Spacer(),
                _buildQuickStat('Proyecto', data.projectId, Icons.location_on_rounded),
                const SizedBox(width: 16),
                _buildQuickStat(
                    'Cola total', '${data.totalInQueue} actos', Icons.list_rounded),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: SaoColors.onPrimary),
                  tooltip: 'Actualizar dashboard',
                  onPressed: onRefresh,
                ),
              ],
            ),
          ),
        ),

        // KPIs Grid
        SliverPadding(
          padding: const EdgeInsets.all(24),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              childAspectRatio: 1.5,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            delegate: SliverChildListDelegate([
              _buildKpiCard(
                context,
                'Aprobados hoy',
                '${data.approvedToday}',
                '$approvedPct% de la cola',
                Icons.check_circle_rounded,
                SaoColors.success,
              ),
              _buildKpiCard(
                context,
                'Rechazados',
                '${data.rejectedCount}',
                'Requieren corrección',
                Icons.cancel_rounded,
                SaoColors.error,
                isAlert: data.rejectedCount > 0,
              ),
              _buildKpiCard(
                context,
                'Necesitan corrección',
                '${data.needsFixCount}',
                'En espera de campo',
                Icons.edit_note_rounded,
                SaoColors.statusPendiente,
              ),
              _buildKpiCard(
                context,
                'Pendientes revisión',
                '${data.pendingCount}',
                'Esperando validación',
                Icons.pending_actions_rounded,
                SaoColors.primary,
              ),
            ]),
          ),
        ),

        // Charts row
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          sliver: SliverToBoxAdapter(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: _buildDonutChart(context, approvedPct.toDouble()),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 3,
                  child: _buildHeatMapPlaceholder(context),
                ),
              ],
            ),
          ),
        ),

        const SliverPadding(padding: EdgeInsets.all(12)),

        // Recent activity
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          sliver: SliverToBoxAdapter(
            child: _buildRecentActivity(context, data.recentItems),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickStat(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: SaoColors.onPrimary.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: SaoColors.onPrimary, size: 16),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label,
                  style: TextStyle(
                    color: SaoColors.onPrimary.withOpacity(0.7),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  )),
              Text(value,
                  style: const TextStyle(
                    color: SaoColors.onPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  )),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard(
    BuildContext context,
    String title,
    String value,
    String subtitle,
    IconData icon,
    Color color, {
    bool isAlert = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: SaoColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: isAlert ? Border.all(color: color, width: 2) : null,
        boxShadow: [
          BoxShadow(
            color: SaoColors.gray900.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
          ]),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: color,
                    height: 1,
                  )),
              const SizedBox(height: 8),
              Text(title,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: SaoColors.gray800)),
              const SizedBox(height: 4),
              Text(subtitle,
                  style: const TextStyle(fontSize: 12, color: SaoColors.gray600)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDonutChart(BuildContext context, double pct) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: SaoColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: SaoColors.gray900.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Avance de Validación',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          Center(
            child: SizedBox(
              width: 200,
              height: 200,
              child: CustomPaint(painter: _DonutChartPainter(pct.toDouble())),
            ),
          ),
          const SizedBox(height: 24),
          _buildLegendItem('Aprobados', '$pct%', SaoColors.success),
          const SizedBox(height: 8),
          _buildLegendItem('Pendientes', '${100 - pct}%', SaoColors.border),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, String value, Color color) {
    return Row(
      children: [
        Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(4))),
        const SizedBox(width: 12),
        Text(label,
            style: TextStyle(fontSize: 14, color: SaoColors.gray700)),
        const Spacer(),
        Text(value,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: SaoColors.gray800)),
      ],
    );
  }

  Widget _buildHeatMapPlaceholder(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: SaoColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: SaoColors.gray900.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Mapa de Calor - Actividad Hoy',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
              decoration: BoxDecoration(
                color: SaoColors.gray50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: SaoColors.gray300),
              ),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.map_rounded, size: 48, color: SaoColors.gray400),
                    SizedBox(height: 12),
                    Text('Visualización GIS',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: SaoColors.gray600)),
                    SizedBox(height: 8),
                    Text('Integración con Google Maps/Mapbox próximamente',
                        style: TextStyle(fontSize: 12, color: SaoColors.gray500)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivity(BuildContext context, List<RecentActivityItem> items) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: SaoColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: SaoColors.gray900.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text('Actividad Reciente',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text('Sin actividad reciente',
                    style: TextStyle(color: SaoColors.gray500)),
              ),
            )
          else
            ...items.expand((item) {
              final statusColor = switch (item.status) {
                'APROBADO' => SaoColors.success,
                'RECHAZADO' => SaoColors.error,
                _ => SaoColors.primary,
              };
              final statusIcon = switch (item.status) {
                'APROBADO' => Icons.check_circle_rounded,
                'RECHAZADO' => Icons.cancel_rounded,
                _ => Icons.pending_actions_rounded,
              };
              final statusLabel = switch (item.status) {
                'APROBADO' => 'Aprobado',
                'RECHAZADO' => 'Rechazado',
                _ => 'Pendiente revisión',
              };
              return [
                _buildActivityItem(
                  item.id,
                  statusLabel,
                  item.activityType,
                  item.front,
                  statusColor,
                  statusIcon,
                ),
                if (item != items.last) const Divider(height: 24),
              ];
            }),
        ],
      ),
    );
  }

  Widget _buildActivityItem(
    String id,
    String action,
    String activityType,
    String front,
    Color color,
    IconData icon,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text(
                  id.length > 20 ? '${id.substring(0, 20)}…' : id,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      fontFamily: 'monospace',
                      color: SaoColors.gray700),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(action,
                      style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w600, color: color)),
                ),
              ]),
              const SizedBox(height: 4),
              Text('$activityType · $front',
                  style: const TextStyle(fontSize: 12, color: SaoColors.gray600)),
            ],
          ),
        ),
        const Icon(Icons.chevron_right_rounded, color: SaoColors.gray400),
      ],
    );
  }
}

// Custom Painter para Gráfica de Dona
class _DonutChartPainter extends CustomPainter {
  final double percentage;

  _DonutChartPainter(this.percentage);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const strokeWidth = 30.0;

    final bgPaint = Paint()
      ..color = SaoColors.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius - strokeWidth / 2, bgPaint);

    final completedPaint = Paint()
      ..shader = LinearGradient(colors: [
        SaoColors.success,
        SaoColors.success.withOpacity(0.8)
      ]).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final sweepAngle = (percentage / 100) * 2 * math.pi;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
      -math.pi / 2,
      sweepAngle,
      false,
      completedPaint,
    );

    final textPainter = TextPainter(
      text: TextSpan(children: [
        TextSpan(
          text: '${percentage.toInt()}',
          style: const TextStyle(
              fontSize: 48, fontWeight: FontWeight.bold, color: SaoColors.success),
        ),
        const TextSpan(
          text: '%',
          style: TextStyle(
              fontSize: 32, fontWeight: FontWeight.bold, color: SaoColors.success),
        ),
      ]),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas,
        Offset(center.dx - textPainter.width / 2, center.dy - textPainter.height / 2));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
