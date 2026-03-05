// lib/ui/widgets/special/sao_evidence_gallery.dart
import 'package:flutter/material.dart';
import '../../theme/sao_colors.dart';
import '../../theme/sao_typography.dart';
import '../../theme/sao_spacing.dart';
import '../../theme/sao_radii.dart';

/// Galería de evidencias fotográficas con geolocalización
/// 
/// Grid responsivo de thumbnails con PK badge y geolocalización.
class SaoEvidenceGallery extends StatelessWidget {
  final List<EvidenceImage> images;
  final ValueChanged<EvidenceImage>? onImageTap;

  const SaoEvidenceGallery({
    super.key,
    required this.images,
    this.onImageTap,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: SaoSpacing.sm,
        mainAxisSpacing: SaoSpacing.sm,
      ),
      itemCount: images.length,
      itemBuilder: (context, index) {
        final image = images[index];
        return _EvidenceThumbnail(
          image: image,
          onTap: () => onImageTap?.call(image),
        );
      },
    );
  }
}

class _EvidenceThumbnail extends StatelessWidget {
  final EvidenceImage image;
  final VoidCallback? onTap;

  const _EvidenceThumbnail({
    required this.image,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(SaoRadii.md),
      child: Stack(
        children: [
          // Thumbnail placeholder
          Container(
            decoration: BoxDecoration(
              color: SaoColors.gray200,
              borderRadius: BorderRadius.circular(SaoRadii.md),
              border: Border.all(color: SaoColors.border),
            ),
            child: const Center(
              child: Icon(Icons.photo, color: SaoColors.gray400, size: 40),
            ),
          ),
          // PK Badge
          Positioned(
            top: SaoSpacing.xs,
            right: SaoSpacing.xs,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: SaoSpacing.xs,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: SaoColors.actionPrimary,
                borderRadius: BorderRadius.circular(SaoRadii.sm),
              ),
              child: Text(
                _formatPK(image.pk),
                style: SaoTypography.caption.copyWith(
                  color: SaoColors.onActionPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          // Location icon
          if (image.location != null)
            Positioned(
              bottom: SaoSpacing.xs,
              left: SaoSpacing.xs,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: SaoColors.surface.withValues(alpha: 0.9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.location_on,
                  color: SaoColors.error,
                  size: 14,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatPK(double pk) {
    final km = pk.floor();
    final m = ((pk - km) * 1000).round();
    return '$km+${m.toString().padLeft(3, '0')}';
  }
}

/// Imagen de evidencia
class EvidenceImage {
  final String url;
  final String? thumbnail;
  final DateTime timestamp;
  final LatLng? location;
  final double pk;

  const EvidenceImage({
    required this.url,
    this.thumbnail,
    required this.timestamp,
    this.location,
    required this.pk,
  });
}

/// Coordenadas geográficas
class LatLng {
  final double latitude;
  final double longitude;

  const LatLng(this.latitude, this.longitude);
}
