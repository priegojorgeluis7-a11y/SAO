// lib/features/evidence/presentation/widgets/evidence_preview_card.dart
// Widget to display a preview of captured evidence (image/video).

import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../ui/theme/sao_colors.dart';
import '../../../../ui/theme/sao_typography.dart';
import '../../services/camera_capture_service.dart';

class EvidencePreviewCard extends StatelessWidget {
  final CapturedEvidence evidence;
  final double? maxHeight;

  const EvidencePreviewCard({
    super.key,
    required this.evidence,
    this.maxHeight = 300,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Preview image/video thumbnail
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(4),
            ),
            child: Container(
              width: double.infinity,
              height: maxHeight ?? 300,
              color: Colors.grey[300],
              child: evidence.mimeType.startsWith('image/')
                  ? Image.file(
                      File(evidence.localPath),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Center(
                          child: Icon(Icons.broken_image, size: 48, color: Colors.grey),
                        );
                      },
                    )
                  : Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(color: Colors.black),
                        const Icon(Icons.play_circle_filled, size: 64, color: Colors.white),
                      ],
                    ),
            ),
          ),

          // File info
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      evidence.mimeType.startsWith('image/') ? Icons.image : Icons.videocam,
                      color: SaoColors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        evidence.displayName,
                        style: SaoTypography.labelMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  children: [
                    _InfoChip(
                      label: 'File Size',
                      value: evidence.fileSizeDisplay,
                      icon: Icons.storage,
                    ),
                    if (evidence.isCompressed)
                      const _InfoChip(
                        label: 'Compressed',
                        value: '✓',
                        icon: Icons.compress,
                      ),
                    _InfoChip(
                      label: 'Captured',
                      value: _formatTime(evidence.capturedAt),
                      icon: Icons.access_time,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) {
      return '--:--';
    }
    return '${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _InfoChip({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: SaoColors.primary),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: SaoTypography.bodySmall.copyWith(fontSize: 10)),
            Text(value, style: SaoTypography.labelMedium.copyWith(fontSize: 12)),
          ],
        ),
      ],
    );
  }
}
