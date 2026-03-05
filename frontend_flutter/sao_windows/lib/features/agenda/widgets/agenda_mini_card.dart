// lib/features/agenda/widgets/agenda_mini_card.dart

import 'package:flutter/material.dart';
import '../../../ui/theme/sao_colors.dart';
import '../models/agenda_item.dart';
import '../models/resource.dart';

class AgendaMiniCard extends StatelessWidget {
  final AgendaItem item;
  final Resource resource;
  final VoidCallback? onTap;

  const AgendaMiniCard({
    super.key,
    required this.item,
    required this.resource,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = _getBorderColor();

    return Material(
      borderRadius: BorderRadius.circular(12),
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border(
              left: BorderSide(color: borderColor, width: 6),
            ),
            color: SaoColors.surface,
          ),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatTimeRange(),
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        color: SaoColors.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: SaoColors.gray800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.location,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: SaoColors.statusBorrador,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: SaoColors.info,
                    backgroundImage: resource.avatarUrl != null
                        ? NetworkImage(resource.avatarUrl!)
                        : null,
                    child: resource.avatarUrl == null
                        ? Text(
                            resource.initials,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(height: 4),
                  _SyncIcon(status: item.syncStatus),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimeRange() {
    final start = '${item.start.hour.toString().padLeft(2, '0')}:${item.start.minute.toString().padLeft(2, '0')}';
    final end = '${item.end.hour.toString().padLeft(2, '0')}:${item.end.minute.toString().padLeft(2, '0')}';
    return '$start - $end';
  }

  Color _getRiskColor(RiskLevel level) {
    switch (level) {
      case RiskLevel.bajo:
        return SaoColors.success;
      case RiskLevel.medio:
        return SaoColors.warning;
      case RiskLevel.alto:
        return SaoColors.riskHigh;
      case RiskLevel.prioritario:
        return SaoColors.riskPriority;
    }
  }

  Color _getBorderColor() {
    final parsed = _parseHexColor(item.colorSnapshot);
    return parsed ?? _getRiskColor(item.risk);
  }

  Color? _parseHexColor(String? hexColor) {
    if (hexColor == null || hexColor.trim().isEmpty) return null;

    var normalized = hexColor.trim().replaceFirst('#', '');
    if (normalized.length == 6) {
      normalized = 'FF$normalized';
    }
    if (normalized.length != 8) return null;

    final value = int.tryParse(normalized, radix: 16);
    if (value == null) return null;

    return Color(value);
  }
}

class _SyncIcon extends StatelessWidget {
  final SyncStatus status;

  const _SyncIcon({required this.status});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _getIconAndColor();
    return Icon(icon, size: 14, color: color);
  }

  (IconData, Color) _getIconAndColor() {
    switch (status) {
      case SyncStatus.pending:
        return (Icons.cloud_queue_rounded, SaoColors.gray400);
      case SyncStatus.uploading:
        return (Icons.cloud_upload_rounded, SaoColors.warning);
      case SyncStatus.synced:
        return (Icons.cloud_done_rounded, SaoColors.success);
      case SyncStatus.error:
        return (Icons.cloud_off_rounded, SaoColors.error);
    }
  }
}
