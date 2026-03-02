import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math' as math;
import '../../ui/theme/sao_colors.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: SaoColors.gray50,
      body: CustomScrollView(
        slivers: [
          // Header de Control
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
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.radar_rounded, color: SaoColors.onPrimary, size: 32),
                      SizedBox(width: 12),
                      Text(
                        'Torre de Control | SAO Desktop',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: SaoColors.onPrimary,
                        ),
                      ),
                      Spacer(),
                      _buildQuickStat('Proyecto TMQ', 'Tramo 4', Icons.location_on_rounded),
                      SizedBox(width: 16),
                      _buildQuickStat('Última Sync', 'Hace 2 min', Icons.sync_rounded),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // KPIs Grid
          SliverPadding(
            padding: const EdgeInsets.all(24),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                childAspectRatio: 1.5,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              delegate: SliverChildListDelegate([
                _buildKpiCard(
                  context,
                  'Avance Físico',
                  '68%',
                  'vs. 72% programado',
                  Icons.show_chart_rounded,
                  SaoColors.primary,
                  trend: -4,
                ),
                _buildKpiCard(
                  context,
                  'Incidencias Críticas',
                  '3',
                  'Requieren atención',
                  Icons.warning_rounded,
                  SaoColors.error,
                  isAlert: true,
                ),
                _buildKpiCard(
                  context,
                  'Fuerza Operativa',
                  '12/15',
                  'Ingenieros activos',
                  Icons.engineering_rounded,
                  SaoColors.success,
                  trend: 0,
                ),
                _buildKpiCard(
                  context,
                  'Pendientes Validación',
                  '10',
                  'Esperando revisión',
                  Icons.pending_actions_rounded,
                  SaoColors.statusPendiente,
                ),
              ]),
            ),
          ),
          // Sección de Análisis
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            sliver: SliverToBoxAdapter(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Gráfica de Dona (Avance)
                  Expanded(
                    flex: 2,
                    child: _buildDonutChart(context),
                  ),
                  SizedBox(width: 16),
                  // Mapa de Calor (Placeholder)
                  Expanded(
                    flex: 3,
                    child: _buildHeatMapPlaceholder(context),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(padding: EdgeInsets.all(12)),
          // Actividad Reciente
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            sliver: SliverToBoxAdapter(
              child: _buildRecentActivity(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStat(String label, String value, IconData icon) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: SaoColors.onPrimary.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: SaoColors.onPrimary, size: 16),
          SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: SaoColors.onPrimary.withOpacity(0.7),
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  color: SaoColors.onPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
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
    int? trend,
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
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              Spacer(),
              if (trend != null)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: trend >= 0 ? SaoColors.success.withOpacity(0.1) : SaoColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        trend >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                        size: 14,
                        color: trend >= 0 ? SaoColors.success : SaoColors.error,
                      ),
                      SizedBox(width: 4),
                      Text(
                        '${trend.abs()}%',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: trend >= 0 ? SaoColors.success : SaoColors.error,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: isAlert ? 40 : 36,
                  fontWeight: FontWeight.bold,
                  color: color,
                  height: 1,
                ),
              ),
              SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: SaoColors.gray800,
                ),
              ),
              SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: SaoColors.gray600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDonutChart(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: SaoColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: SaoColors.gray900.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Avance Físico del Proyecto',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 24),
          Center(
            child: SizedBox(
              width: 200,
              height: 200,
              child: CustomPaint(
                painter: _DonutChartPainter(68),
              ),
            ),
          ),
          SizedBox(height: 24),
          _buildLegendItem('Completado', '68%', SaoColors.success),
          SizedBox(height: 8),
          _buildLegendItem('Programado', '72%', SaoColors.primary),
          SizedBox(height: 8),
          _buildLegendItem('Pendiente', '32%', SaoColors.border),
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
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(fontSize: 14, color: SaoColors.gray700),
        ),
        Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: SaoColors.gray800,
          ),
        ),
      ],
    );
  }

  Widget _buildHeatMapPlaceholder(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: SaoColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: SaoColors.gray900.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Mapa de Calor - Actividad Hoy',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Spacer(),
              IconButton(
                icon: Icon(Icons.fullscreen_rounded),
                onPressed: () {},
                tooltip: 'Ver mapa completo',
              ),
            ],
          ),
          SizedBox(height: 16),
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
              decoration: BoxDecoration(
                color: SaoColors.gray50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: SaoColors.gray300),
              ),
              child: Stack(
                children: [
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.map_rounded, size: 48, color: SaoColors.gray400),
                        SizedBox(height: 12),
                        Text(
                          'Visualización GIS',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: SaoColors.gray600,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Integración con Google Maps/Mapbox próximamente',
                          style: TextStyle(fontSize: 12, color: SaoColors.gray500),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: SaoColors.success,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: SaoColors.onPrimary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          SizedBox(width: 6),
                          Text(
                            '12 activos ahora',
                            style: TextStyle(
                              color: SaoColors.onPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivity(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: SaoColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: SaoColors.gray900.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Actividad Reciente',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Spacer(),
              TextButton.icon(
                onPressed: () {},
                icon: Icon(Icons.history_rounded, size: 18),
                label: Text('Ver todo'),
              ),
            ],
          ),
          SizedBox(height: 16),
          _buildActivityItem(
            'ACT-2026-894',
            'Validación aprobada',
            'Ing. Maria González',
            'Hace 2 min',
            SaoColors.success,
            Icons.check_circle_rounded,
          ),
          Divider(height: 24),
          _buildActivityItem(
            'ACT-2026-893',
            'Solicitud de corrección enviada',
            'Coord. Pedro Ramírez',
            'Hace 5 min',
            SaoColors.statusPendiente,
            Icons.edit_rounded,
          ),
          Divider(height: 24),
          _buildActivityItem(
            'ACT-2026-892',
            'Nueva actividad subida',
            'Ing. Juan Pérez',
            'Hace 10 min',
            SaoColors.primary,
            Icons.upload_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(
    String id,
    String action,
    String user,
    String time,
    Color color,
    IconData icon,
  ) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    id,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      fontFamily: 'monospace',
                      color: SaoColors.gray700,
                    ),
                  ),
                  SizedBox(width: 8),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      action,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 4),
              Text(
                '$user • $time',
                style: TextStyle(
                  fontSize: 12,
                  color: SaoColors.gray600,
                ),
              ),
            ],
          ),
        ),
        Icon(Icons.chevron_right_rounded, color: SaoColors.gray400),
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
    final strokeWidth = 30.0;

    // Fondo (Pendiente)
    final bgPaint = Paint()
      ..color = SaoColors.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius - strokeWidth / 2, bgPaint);

    // Completado
    final completedPaint = Paint()
      ..shader = LinearGradient(
        colors: [SaoColors.success, SaoColors.success.withOpacity(0.8)],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
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

    // Texto central
    final textPainter = TextPainter(
      text: TextSpan(
        children: [
          TextSpan(
            text: '${percentage.toInt()}',
            style: TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: SaoColors.success,
            ),
          ),
          TextSpan(
            text: '%',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: SaoColors.success,
            ),
          ),
        ],
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(center.dx - textPainter.width / 2, center.dy - textPainter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
