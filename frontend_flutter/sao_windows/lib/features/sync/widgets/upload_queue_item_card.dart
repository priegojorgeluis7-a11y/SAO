import 'package:flutter/material.dart';

import '../../../ui/theme/sao_colors.dart';
import '../models/sync_models.dart';

class UploadQueueItemCard extends StatelessWidget {
  const UploadQueueItemCard({
    super.key,
    required this.item,
    this.onRetry,
    this.onResolveConflict,
  });

  final UploadQueueItem item;
  final VoidCallback? onRetry;
  final VoidCallback? onResolveConflict;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: SaoColors.gray200,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              item.icon,
              size: 22,
              color: item.color,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: SaoColors.gray400,
                  ),
                ),
                if (item.status == UploadItemStatus.uploading && item.progress != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: item.progress,
                        backgroundColor: SaoColors.gray200,
                        valueColor: AlwaysStoppedAnimation(item.color),
                        minHeight: 6,
                      ),
                    ),
                  ),
                if (item.status == UploadItemStatus.error && item.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      item.errorMessage!,
                      style: const TextStyle(
                        fontSize: 11,
                        color: SaoColors.error,
                      ),
                    ),
                  ),
                if (item.status == UploadItemStatus.error &&
                    item.suggestedAction != null &&
                    item.suggestedAction!.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Accion sugerida: ${item.suggestedAction!}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: SaoColors.warning,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (item.status == UploadItemStatus.pending)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: SaoColors.warningBg,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(
                children: [
                  Icon(Icons.hourglass_empty_rounded, size: 14, color: SaoColors.warning),
                  SizedBox(width: 4),
                  Text(
                    'Esperando',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: SaoColors.warning,
                    ),
                  ),
                ],
              ),
            )
          else if (item.status == UploadItemStatus.uploading)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: SaoColors.infoLight,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(item.color),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${(item.progress! * 100).toInt()}%',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: item.color,
                    ),
                  ),
                ],
              ),
            )
          else if (item.status == UploadItemStatus.error)
            IconButton(
              icon: Icon(
                item.isConflict
                    ? Icons.merge_type_rounded
                    : (item.retryable
                        ? Icons.refresh_rounded
                        : Icons.sync_disabled_rounded),
                size: 20,
              ),
              color: item.retryable || item.isConflict
                  ? SaoColors.error
                  : SaoColors.gray400,
              onPressed: item.isConflict
                  ? onResolveConflict
                  : (item.retryable ? onRetry : null),
              tooltip: item.isConflict
                  ? 'Resolver conflicto'
                  : (item.retryable ? 'Reintentar' : 'No reintentable'),
            ),
        ],
      ),
    );
  }
}