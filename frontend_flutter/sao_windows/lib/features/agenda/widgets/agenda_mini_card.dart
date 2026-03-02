// lib/features/agenda/widgets/agenda_mini_card.dart

import 'package:flutter/material.dart';
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
    final riskColor = _getRiskColor(item.risk);

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
              left: BorderSide(color: riskColor, width: 6),
            ),
            color: Colors.white,
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
                        color: Color(0xFF111827),
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
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.location,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
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
                    backgroundColor: const Color(0xFF3B82F6),
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
        return const Color(0xFF10B981);
      case RiskLevel.medio:
        return const Color(0xFFFBBF24);
      case RiskLevel.alto:
        return const Color(0xFFF97316);
      case RiskLevel.prioritario:
        return const Color(0xFFEF4444);
    }
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
        return (Icons.cloud_queue_rounded, const Color(0xFF9CA3AF));
      case SyncStatus.uploading:
        return (Icons.cloud_upload_rounded, const Color(0xFFFBBF24));
      case SyncStatus.synced:
        return (Icons.cloud_done_rounded, const Color(0xFF10B981));
      case SyncStatus.error:
        return (Icons.cloud_off_rounded, const Color(0xFFEF4444));
    }
  }
}
