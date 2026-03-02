// lib/features/operations/widgets/gps_validation_banner.dart
import 'package:flutter/material.dart';
import '../../../ui/sao_ui.dart';

/// Estado de validación GPS vs PK
enum GpsValidationStatus {
  /// GPS coincide exactamente (< 50m)
  perfect,
  
  /// GPS cercano al PK (50-200m)
  acceptable,
  
  /// GPS con desviación significativa (200-800m)
  warning,
  
  /// GPS fuera de rango (> 800m)
  error,
}

class GpsValidationBanner extends StatelessWidget {
  const GpsValidationBanner({
    super.key,
    required this.status,
    required this.pkLabel,
    required this.gpsCoordinates,
    this.distanceInMeters,
    this.onEditGps,
    this.onViewMap,
  });

  final GpsValidationStatus status;
  final String pkLabel;              // e.g., "142+000"
  final String gpsCoordinates;       // e.g., "20.6295°N, 100.3161°W"
  final double? distanceInMeters;
  final VoidCallback? onEditGps;
  final VoidCallback? onViewMap;

  Color get _bannerColor {
    switch (status) {
      case GpsValidationStatus.perfect:
        return SaoColors.success;
      case GpsValidationStatus.acceptable:
        return SaoColors.info;
      case GpsValidationStatus.warning:
        return SaoColors.warning;
      case GpsValidationStatus.error:
        return SaoColors.error;
    }
  }

  Color get _backgroundColor {
    return _bannerColor.withOpacity(0.08);
  }

  IconData get _icon {
    switch (status) {
      case GpsValidationStatus.perfect:
        return Icons.check_circle_rounded;
      case GpsValidationStatus.acceptable:
        return Icons.info_rounded;
      case GpsValidationStatus.warning:
        return Icons.warning_rounded;
      case GpsValidationStatus.error:
        return Icons.error_rounded;
    }
  }

  String get _title {
    switch (status) {
      case GpsValidationStatus.perfect:
        return 'GPS validado✓';
      case GpsValidationStatus.acceptable:
        return 'GPS aceptable';
      case GpsValidationStatus.warning:
        return '⚠️ Desviación significativa';
      case GpsValidationStatus.error:
        return '❌ GPS fuera de rango';
    }
  }

  String get _subtitle {
    switch (status) {
      case GpsValidationStatus.perfect:
        return 'La ubicación GPS coincide con el PK declarado';
      case GpsValidationStatus.acceptable:
        return 'GPS cercano al PK (variación < 200m)';
      case GpsValidationStatus.warning:
        return 'La ubicación GPS se desvía ${distanceInMeters?.toStringAsFixed(0)}m del PK';
      case GpsValidationStatus.error:
        return '❌ REQUISITE: Justificación obligatoria para aceptar';
    }
  }

  @override
  Widget build(BuildContext context) {
    final showJustification = status == GpsValidationStatus.error;

    return Container(
      padding: EdgeInsets.all(SaoSpacing.md),
      decoration: BoxDecoration(
        color: _backgroundColor,
        border: Border(
          left: BorderSide(
            color: _bannerColor,
            width: 4,
          ),
          top: BorderSide(
            color: _bannerColor.withOpacity(0.3),
            width: 1,
          ),
          bottom: BorderSide(
            color: _bannerColor.withOpacity(0.3),
            width: 1,
          ),
          right: BorderSide(
            color: _bannerColor.withOpacity(0.3),
            width: 1,
          ),
        ),
        borderRadius: BorderRadius.circular(SaoRadii.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Icon + Title
          Row(
            children: [
              Icon(
                _icon,
                color: _bannerColor,
                size: 20,
              ),
              SizedBox(width: SaoSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _title,
                      style: SaoTypography.bodyTextBold.copyWith(
                        fontSize: 14,
                        color: _bannerColor,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      _subtitle,
                      style: SaoTypography.caption.copyWith(
                        fontSize: 13,
                        color: _bannerColor.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: SaoSpacing.sm),
              // Quick actions
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (onViewMap != null)
                    Tooltip(
                      message: 'Ver en mapa',
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: onViewMap,
                          borderRadius: BorderRadius.circular(6),
                          child: Padding(
                            padding: EdgeInsets.all(SaoSpacing.xs),
                            child: Icon(
                              Icons.map_rounded,
                              color: _bannerColor,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (onEditGps != null) ...[
                    SizedBox(width: SaoSpacing.xs),
                    Tooltip(
                      message: 'Editar GPS',
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: onEditGps,
                          borderRadius: BorderRadius.circular(6),
                          child: Padding(
                            padding: EdgeInsets.all(SaoSpacing.xs),
                            child: Icon(
                              Icons.edit_location_rounded,
                              color: _bannerColor,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),

          SizedBox(height: SaoSpacing.md),

          // Details grid: PK y GPS
          Container(
            padding: EdgeInsets.all(SaoSpacing.sm),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.5),
              borderRadius: BorderRadius.circular(SaoRadii.sm),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _DetailItem(
                    label: 'PK',
                    value: pkLabel,
                  ),
                ),
                Expanded(
                  child: _DetailItem(
                    label: 'GPS Capturado',
                    value: gpsCoordinates,
                  ),
                ),
                if (distanceInMeters != null)
                  Expanded(
                    child: _DetailItem(
                      label: 'Distancia',
                      value: '${distanceInMeters!.toStringAsFixed(1)}m',
                    ),
                  ),
              ],
            ),
          ),

          // Justification field if error status
          if (showJustification) ...[
            SizedBox(height: SaoSpacing.md),
            Container(
              padding: EdgeInsets.all(SaoSpacing.sm),
              decoration: BoxDecoration(
                color: SaoColors.error.withOpacity(0.05),
                border: Border.all(
                  color: SaoColors.error.withOpacity(0.3),
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(SaoRadii.sm),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.description_rounded,
                        size: 16,
                        color: SaoColors.error,
                      ),
                      SizedBox(width: SaoSpacing.xs),
                      Text(
                        'Justificación requerida',
                        style: SaoTypography.caption.copyWith(
                          fontWeight: FontWeight.w600,
                          color: SaoColors.error,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: SaoSpacing.sm),
                  TextField(
                    maxLines: 3,
                    minLines: 2,
                    decoration: InputDecoration(
                      hintText: 'Explicar discrepancia de ubicación...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(SaoRadii.sm),
                        borderSide: BorderSide(
                          color: SaoColors.border,
                          width: 1,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(SaoRadii.sm),
                        borderSide: BorderSide(
                          color: SaoColors.border,
                          width: 1,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(SaoRadii.sm),
                        borderSide: BorderSide(
                          color: SaoColors.primary,
                          width: 2,
                        ),
                      ),
                      contentPadding: EdgeInsets.all(SaoSpacing.sm),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    style: SaoTypography.bodyText,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Item de detalle en la grid
class _DetailItem extends StatelessWidget {
  const _DetailItem({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: SaoTypography.caption.copyWith(
            fontSize: 12,
            color: SaoColors.gray600,
          ),
        ),
        SizedBox(height: 3),
        Text(
          value,
          style: SaoTypography.mono.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
