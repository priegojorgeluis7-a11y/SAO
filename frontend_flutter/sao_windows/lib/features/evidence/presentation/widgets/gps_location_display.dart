// lib/features/evidence/presentation/widgets/gps_location_display.dart
// Widget to display GPS location information captured with evidence.

import 'package:flutter/material.dart';
import '../../../../ui/theme/sao_colors.dart';
import '../../../../ui/theme/sao_typography.dart';
import '../../services/gps_tagging_service.dart';

class GpsLocationDisplay extends StatelessWidget {
  final GpsLocation location;
  final bool compact;

  const GpsLocationDisplay({
    super.key,
    required this.location,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return _buildCompactView();
    } else {
      return _buildExpandedView();
    }
  }

  Widget _buildCompactView() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.location_on, size: 16, color: SaoColors.primary),
        const SizedBox(width: 4),
        Text(
          location.toShortString(),
          style: SaoTypography.bodySmall,
        ),
      ],
    );
  }

  Widget _buildExpandedView() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.location_on, color: SaoColors.primary, size: 20),
                SizedBox(width: 8),
                Text('GPS Location Tagged', style: SaoTypography.labelMedium),
              ],
            ),
            const SizedBox(height: 16),
            _buildLocationRow(
              icon: Icons.public,
              label: 'Coordinates',
              value: '${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}',
            ),
            if (location.accuracy != null) ...[
              const SizedBox(height: 8),
              _buildLocationRow(
                icon: Icons.precision_manufacturing,
                label: 'Accuracy',
                value: '±${location.accuracy!.toStringAsFixed(1)} m',
                color: _getAccuracyColor(location.accuracy!),
              ),
            ],
            if (location.altitude != null) ...[
              const SizedBox(height: 8),
              _buildLocationRow(
                icon: Icons.height,
                label: 'Altitude',
                value: '${location.altitude!.toStringAsFixed(1)} m',
              ),
            ],
            if (location.heading != null) ...[
              const SizedBox(height: 8),
              _buildLocationRow(
                icon: Icons.navigation,
                label: 'Heading',
                value: '${location.heading!.toStringAsFixed(0)}°',
              ),
            ],
            if (location.speed != null) ...[
              const SizedBox(height: 8),
              _buildLocationRow(
                icon: Icons.speed,
                label: 'Speed',
                value: '${(location.speed! * 3.6).toStringAsFixed(1)} km/h',
              ),
            ],
            const SizedBox(height: 8),
            _buildLocationRow(
              icon: Icons.access_time,
              label: 'Timestamp',
              value: _formatTimestamp(location.timestamp),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationRow({
    required IconData icon,
    required String label,
    required String value,
    Color? color,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color ?? SaoColors.primary),
        const SizedBox(width: 12),
        SizedBox(
          width: 100,
          child: Text(label, style: SaoTypography.bodySmall.copyWith(color: Colors.grey)),
        ),
        Expanded(
          child: Text(
            value,
            style: SaoTypography.bodyMedium.copyWith(fontWeight: FontWeight.w500),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  Color _getAccuracyColor(double accuracy) {
    if (accuracy < 10) return Colors.green;
    if (accuracy < 50) return Colors.orange;
    return Colors.red;
  }

  String _formatTimestamp(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
  }
}
