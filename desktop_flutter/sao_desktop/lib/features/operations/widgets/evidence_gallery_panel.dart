import 'dart:io';

import 'package:flutter/material.dart';
import '../../../data/models/activity_model.dart';
import '../../../data/repositories/evidence_repository.dart';
import '../../../ui/theme/sao_colors.dart';
import '../../../ui/theme/sao_spacing.dart';
import '../../../ui/theme/sao_radii.dart';
import '../../../ui/theme/sao_typography.dart';
import '../../../ui/widgets/sao_evidence_viewer.dart';
import 'gps_validation_banner.dart';
import 'caption_editor_widget.dart';

/// Panel de galería de evidencias rediseñado con SaoEvidenceViewer
class EvidenceGalleryPanel extends StatefulWidget {
  final ActivityWithDetails? activity;
  final int selectedIndex;
  final Function(int) onSelectEvidence;

  const EvidenceGalleryPanel({
    super.key,
    required this.activity,
    required this.selectedIndex,
    required this.onSelectEvidence,
  });

  @override
  State<EvidenceGalleryPanel> createState() => _EvidenceGalleryPanelState();
}

class _EvidenceGalleryPanelState extends State<EvidenceGalleryPanel> {
  final EvidenceRepository _evidenceRepository = EvidenceRepository();
  final Map<String, Future<String?>> _imageUrlFutureCache = {};

  @override
  void didUpdateWidget(covariant EvidenceGalleryPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldId = oldWidget.activity?.activity.id;
    final newId = widget.activity?.activity.id;
    if (oldId != newId) {
      _imageUrlFutureCache.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.activity == null || widget.activity!.evidences.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: SaoColors.surface,
          borderRadius: BorderRadius.circular(SaoRadii.md),
          border: Border.all(color: SaoColors.border),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.photo_library_outlined, size: 64, color: SaoColors.gray400),
              const SizedBox(height: SaoSpacing.lg),
              Text(
                'Sin evidencias',
                style: SaoTypography.bodyText.copyWith(color: SaoColors.gray500),
              ),
            ],
          ),
        ),
      );
    }

    final evidence = widget.activity!.evidences[widget.selectedIndex];
    final imageUrlFuture = _imageUrlFutureCache.putIfAbsent(
      evidence.id,
      () => _resolveImageUrl(evidence),
    );
    
    // Calculate GPS validation status
    final gpsStatus = _calculateGpsStatus(widget.activity!);
    final distance = _calculateDistance(widget.activity!, 150.0);

    return Container(
      decoration: BoxDecoration(
        color: SaoColors.surface,
        borderRadius: BorderRadius.circular(SaoRadii.md),
        border: Border.all(color: SaoColors.border),
      ),
      child: Column(
        children: [
          // GPS Validation Banner
          Padding(
            padding: const EdgeInsets.all(SaoSpacing.md),
            child: GpsValidationBanner(
              status: gpsStatus,
              pkLabel: 'PK 142+000',
              gpsCoordinates: '${widget.activity!.activity.latitude?.toStringAsFixed(4) ?? '20.6295'}°N, ${widget.activity!.activity.longitude?.toStringAsFixed(4) ?? '100.3161'}°W',
              distanceInMeters: distance,
              onViewMap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Abriendo mapa con ubicación...'),
                    backgroundColor: SaoColors.info,
                  ),
                );
              },
              onEditGps: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Funcionalidad de edición de GPS (próximamente)'),
                    backgroundColor: SaoColors.warning,
                  ),
                );
              },
            ),
          ),

          const Divider(height: 1, color: SaoColors.border),

          // Evidence Viewer
          Expanded(
            child: Container(
              color: SaoColors.gray900,
              child: FutureBuilder<String?>(
                future: imageUrlFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final imageUrl = snapshot.data?.trim();
                  if (snapshot.hasError || imageUrl == null || imageUrl.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(SaoSpacing.lg),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.broken_image_rounded,
                              size: 48,
                              color: SaoColors.gray400,
                            ),
                            const SizedBox(height: SaoSpacing.sm),
                            Text(
                              'No se pudo cargar la foto de evidencia',
                              textAlign: TextAlign.center,
                              style: SaoTypography.caption.copyWith(
                                color: SaoColors.gray500,
                              ),
                            ),
                            const SizedBox(height: SaoSpacing.sm),
                            TextButton.icon(
                              onPressed: () {
                                _imageUrlFutureCache.remove(evidence.id);
                                setState(() {});
                              },
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('Reintentar'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return _buildEvidenceViewer(context, evidence, imageUrl);
                },
              ),
            ),
          ),

          const Divider(height: 1, color: SaoColors.border),

          // Caption Editor
          Padding(
            padding: const EdgeInsets.all(SaoSpacing.md),
            child: CaptionEditorWidget(
              initialCaption: evidence.caption ?? '',
              evidenceId: evidence.id,
              maxLines: 2,
              onSaveCaption: (newCaption) {
                debugPrint('Caption guardado: $newCaption');
              },
              onCancel: () {
                debugPrint('Edición cancelada');
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEvidenceViewer(
    BuildContext context,
    Evidence evidence,
    String imageUrl,
  ) {
    return SaoEvidenceViewer(
      imageUrl: imageUrl,
      caption: evidence.caption,
      latitude: evidence.latitude,
      longitude: evidence.longitude,
      capturedAt: evidence.capturedAt,
      currentIndex: widget.selectedIndex,
      totalCount: widget.activity!.evidences.length,
      onPrevious: widget.selectedIndex > 0
          ? () => widget.onSelectEvidence(widget.selectedIndex - 1)
          : null,
      onNext: widget.selectedIndex < widget.activity!.evidences.length - 1
          ? () => widget.onSelectEvidence(widget.selectedIndex + 1)
          : null,
      onFullscreen: () {
        showDialog(
          context: context,
          builder: (context) => Dialog.fullscreen(
            child: SaoEvidenceViewer(
              imageUrl: imageUrl,
              caption: evidence.caption,
              latitude: evidence.latitude,
              longitude: evidence.longitude,
              capturedAt: evidence.capturedAt,
              currentIndex: widget.selectedIndex,
              totalCount: widget.activity!.evidences.length,
              onPrevious: widget.selectedIndex > 0
                  ? () => widget.onSelectEvidence(widget.selectedIndex - 1)
                  : null,
              onNext: widget.selectedIndex < widget.activity!.evidences.length - 1
                  ? () => widget.onSelectEvidence(widget.selectedIndex + 1)
                  : null,
              onMapView: () {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Abriendo ubicación en mapa...'),
                    backgroundColor: SaoColors.success,
                  ),
                );
              },
            ),
          ),
        );
      },
      onMapView: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Abriendo ubicación GPS en mapa...'),
            backgroundColor: SaoColors.info,
          ),
        );
      },
    );
  }

  /// Calcula el estado de validación GPS vs PK
  GpsValidationStatus _calculateGpsStatus(ActivityWithDetails activity) {
    // Simular diferentes estados según la distancia
    // Pendiente: calcular distancia real usando coordenadas
    final distance = _calculateDistance(activity, 0);
    
    if (distance < 50) {
      return GpsValidationStatus.perfect;
    } else if (distance < 200) {
      return GpsValidationStatus.acceptable;
    } else if (distance < 800) {
      return GpsValidationStatus.warning;
    } else {
      return GpsValidationStatus.error;
    }
  }

  /// Calcula distancia aproximada entre PIN y GPS
  double _calculateDistance(ActivityWithDetails activity, double fallbackDistance) {
    // TODO: Implementar cálculo real usando Haversine formula
    return fallbackDistance;
  }

  Future<String?> _resolveImageUrl(Evidence evidence) async {
    final rawPath = evidence.filePath.trim();
    if (rawPath.isEmpty) return null;

    if (rawPath.startsWith('backend://')) {
      try {
        final signedUrl = await _evidenceRepository.getDownloadSignedUrl(evidence.id);
        return signedUrl.trim().isEmpty ? null : signedUrl;
      } catch (_) {
        return null;
      }
    }

    if (rawPath.startsWith('pending://')) {
      return null;
    }

    if (rawPath.startsWith('http://') ||
        rawPath.startsWith('https://') ||
        rawPath.startsWith('file://')) {
      return rawPath;
    }

    final file = File(rawPath);
    if (file.existsSync()) {
      return file.path;
    }

    return rawPath;
  }
}
