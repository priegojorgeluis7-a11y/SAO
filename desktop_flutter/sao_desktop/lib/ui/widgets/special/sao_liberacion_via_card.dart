// lib/ui/widgets/special/sao_liberacion_via_card.dart
import 'package:flutter/material.dart';
import '../../theme/sao_colors.dart';
import '../../theme/sao_typography.dart';
import '../../theme/sao_spacing.dart';
import '../../theme/sao_radii.dart';

/// Tarjeta especializada para liberación de vía
/// 
/// Muestra estado de liberación con rango PK, timestamp, aprobador y evidencias.
class SaoLiberacionViaCard extends StatelessWidget {
  final String frente;
  final PKRange pkRange;
  final String status; // 'liberado', 'bloqueado', 'en_proceso'
  final DateTime timestamp;
  final String approvedBy;
  final int activities;
  final int evidences;
  final VoidCallback? onViewDetails;

  const SaoLiberacionViaCard({
    super.key,
    required this.frente,
    required this.pkRange,
    required this.status,
    required this.timestamp,
    required this.approvedBy,
    required this.activities,
    required this.evidences,
    this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(status);
    final statusLabel = _getStatusLabel(status);

    return Container(
      decoration: BoxDecoration(
        color: SaoColors.surface,
        borderRadius: BorderRadius.circular(SaoRadii.md),
        border: Border.all(color: statusColor, width: 2),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.all(SaoSpacing.md),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.14),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(SaoRadii.md - 2),
                topRight: Radius.circular(SaoRadii.md - 2),
              ),
            ),
            child: Row(
              children: [
                Icon(_getStatusIcon(status), color: statusColor, size: 28),
                SizedBox(width: SaoSpacing.sm),
                Text(
                  statusLabel,
                  style: SaoTypography.sectionTitle.copyWith(color: statusColor),
                ),
              ],
            ),
          ),
          // Content
          Padding(
            padding: EdgeInsets.all(SaoSpacing.cardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Frente: $frente', style: SaoTypography.bodyTextBold),
                SizedBox(height: SaoSpacing.xs),
                Text(
                  'Rango: PK ${_formatPK(pkRange.start)} - ${_formatPK(pkRange.end)}',
                  style: SaoTypography.pkLabel,
                ),
                SizedBox(height: SaoSpacing.md),
                Text('Liberado: ${_formatDate(timestamp)}', style: SaoTypography.bodyText),
                Text('Por: $approvedBy', style: SaoTypography.bodyText),
                SizedBox(height: SaoSpacing.md),
                Row(
                  children: [
                    Icon(Icons.check_circle, color: SaoColors.success, size: 16),
                    SizedBox(width: SaoSpacing.xs),
                    Text('$activities actividades aprobadas', style: SaoTypography.caption),
                  ],
                ),
                SizedBox(height: SaoSpacing.xs),
                Row(
                  children: [
                    Icon(Icons.photo_camera, color: SaoColors.info, size: 16),
                    SizedBox(width: SaoSpacing.xs),
                    Text('$evidences evidencias adjuntas', style: SaoTypography.caption),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'liberado':
        return SaoColors.success;
      case 'bloqueado':
        return SaoColors.error;
      default:
        return SaoColors.warning;
    }
  }

  String _getStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'liberado':
        return 'VÍA LIBERADA';
      case 'bloqueado':
        return 'VÍA BLOQUEADA';
      default:
        return 'EN PROCESO';
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'liberado':
        return Icons.check_circle;
      case 'bloqueado':
        return Icons.block;
      default:
        return Icons.pending;
    }
  }

  String _formatPK(double pk) {
    final km = pk.floor();
    final m = ((pk - km) * 1000).round();
    return '$km+${m.toString().padLeft(3, '0')}';
  }

  String _formatDate(DateTime dt) {
    return '${dt.day} ${_monthName(dt.month)} ${dt.year}, ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _monthName(int month) {
    const months = [
      'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
      'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
    ];
    return months[month - 1];
  }
}

/// Rango de PK
class PKRange {
  final double start;
  final double end;

  const PKRange({
    required this.start,
    required this.end,
  });
}
