// lib/ui/widgets/special/sao_pk_indicator.dart
import 'package:flutter/material.dart';
import '../../theme/sao_colors.dart';
import '../../theme/sao_spacing.dart';

/// Indicador visual de posición PK (barra horizontal tipo corredor)
/// 
/// Muestra progresivas (PK) con markers de estaciones y actividades.
class SaoPKIndicator extends StatelessWidget {
  final double currentPK;
  final double startPK;
  final double endPK;
  final List<PKMarker> markers;
  final List<PKActivity> activities;

  const SaoPKIndicator({
    super.key,
    required this.currentPK,
    required this.startPK,
    required this.endPK,
    this.markers = const [],
    this.activities = const [],
  });

  @override
  Widget build(BuildContext context) {
    // TODO: Implementar barra horizontal con escala PK
    return Container(
      height: 60,
      padding: EdgeInsets.all(SaoSpacing.md),
      color: SaoColors.gray100,
      child: const Center(
        child: Text('PK Indicator (TODO)'),
      ),
    );
  }
}

/// Marker de estación/punto importante
class PKMarker {
  final double pk;
  final String label;

  const PKMarker({
    required this.pk,
    required this.label,
  });
}

/// Actividad en PK específico
class PKActivity {
  final double pk;
  final String type;
  final String status;

  const PKActivity({
    required this.pk,
    required this.type,
    required this.status,
  });
}
