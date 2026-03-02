import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../data/models/activity_model.dart';
import '../../../ui/theme/sao_colors.dart';
import '../../../ui/theme/sao_spacing.dart';
import '../../../ui/theme/sao_radii.dart';
import '../../../ui/theme/sao_typography.dart';
import '../../../ui/widgets/sao_evidence_viewer.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_spacing.dart';
import 'gps_validation_banner.dart';
import 'caption_editor_widget.dart';

/// Panel de galería de evidencias rediseñado con SaoEvidenceViewer
class EvidenceGalleryPanel extends StatelessWidget {
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
  Widget build(BuildContext context) {
    if (activity == null || activity!.evidences.isEmpty) {
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
              Icon(Icons.photo_library_outlined, size: 64, color: SaoColors.gray400),
              SizedBox(height: SaoSpacing.lg),
              Text(
                'Sin evidencias',
                style: SaoTypography.bodyText.copyWith(color: SaoColors.gray500),
              ),
            ],
          ),
        ),
      );
    }

    final evidence = activity!.evidences[selectedIndex];
    
    // Calculate GPS validation status (mock)
    final gpsStatus = _calculateGpsStatus(activity!);
    final distance = _calculateDistance(activity!, 150.0); // Mock: 150m

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
            padding: EdgeInsets.all(SaoSpacing.md),
            child: GpsValidationBanner(
              status: gpsStatus,
              pkLabel: 'PK 142+000',
              gpsCoordinates: '${activity!.activity.gpsLatitude?.toStringAsFixed(4) ?? '20.6295'}°N, ${activity!.activity.gpsLongitude?.toStringAsFixed(4) ?? '100.3161'}°W',
              distanceInMeters: distance,
              onViewMap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Abriendo mapa con ubicación...'),
                    backgroundColor: SaoColors.info,
                  ),
                );
              },
              onEditGps: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Funcionalidad de edición de GPS (próximamente)'),
                    backgroundColor: SaoColors.warning,
                  ),
                );
              },
            ),
          ),

          Divider(height: 1, color: SaoColors.border),

          // Evidence Viewer
          Expanded(
            child: Container(
              color: SaoColors.gray900,
              child: SaoEvidenceViewer(
                imageUrl: 'https://via.placeholder.com/800x600/e5e7eb/6b7280?text=Evidencia+${selectedIndex + 1}', // TODO: evidence.fileUrl
                caption: evidence.caption,
                latitude: evidence.latitude,
                longitude: evidence.longitude,
                capturedAt: evidence.capturedAt,
                currentIndex: selectedIndex,
                totalCount: activity!.evidences.length,
                onPrevious: selectedIndex > 0
                    ? () => onSelectEvidence(selectedIndex - 1)
                    : null,
                onNext: selectedIndex < activity!.evidences.length - 1
                    ? () => onSelectEvidence(selectedIndex + 1)
                    : null,
                onFullscreen: () {
                  // Modo pantalla completa
                  showDialog(
                    context: context,
                    builder: (context) => Dialog.fullscreen(
                      child: SaoEvidenceViewer(
                        imageUrl: 'https://via.placeholder.com/800x600/e5e7eb/6b7280?text=Evidencia+${selectedIndex + 1}',
                        caption: evidence.caption,
                        latitude: evidence.latitude,
                        longitude: evidence.longitude,
                        capturedAt: evidence.capturedAt,
                        currentIndex: selectedIndex,
                        totalCount: activity!.evidences.length,
                        onPrevious: selectedIndex > 0
                            ? () => onSelectEvidence(selectedIndex - 1)
                            : null,
                        onNext: selectedIndex < activity!.evidences.length - 1
                            ? () => onSelectEvidence(selectedIndex + 1)
                            : null,
                        onMapView: () {
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
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
                    SnackBar(
                      content: Text('Abriendo ubicación GPS en mapa...'),
                      backgroundColor: SaoColors.info,
                    ),
                  );
                },
              ),
            ),
          ),

          Divider(height: 1, color: SaoColors.border),

          // Caption Editor
          Padding(
            padding: EdgeInsets.all(SaoSpacing.md),
            child: CaptionEditorWidget(
              initialCaption: evidence.caption ?? '',
              evidenceId: evidence.id,
              maxLines: 2,
              onSaveCaption: (newCaption) {
                print('Caption guardado: $newCaption');
              },
              onCancel: () {
                print('Edición cancelada');
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Calcula el estado de validación GPS vs PK
  GpsValidationStatus _calculateGpsStatus(ActivityWithDetails activity) {
    // Mock: Simular diferentes estados según la distancia
    // En producción, calcular distancia real usando coordenadas
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

  /// Calcula distancia aproximada entre PIN y GPS (mock)
  double _calculateDistance(ActivityWithDetails activity, double mockDistance) {
    // TODO: Implementar cálculo real usando Haversine formula
    // Por ahora retornar valor mock para demostración
    return mockDistance;
