// lib/catalog/activity_catalog.dart
import 'package:flutter/material.dart';
import '../ui/theme/sao_colors.dart';

/// Catálogo global de tipos de actividad (compartido Mobile + Desktop)
/// Fuente única de verdad para actividades del SAO
class ActivityType {
  final String id;
  final String label;
  final IconData icon;
  final String defaultRisk;
  final bool requiresEvidence;
  final List<String> allowedRoles;
  final String? description;

  const ActivityType({
    required this.id,
    required this.label,
    required this.icon,
    this.defaultRisk = 'medio',
    this.requiresEvidence = true,
    this.allowedRoles = const ['operativo', 'coordinador', 'admin'],
    this.description,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ActivityType &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Catálogo de actividades del SAO
class ActivityCatalog {
  ActivityCatalog._();

  // ============================================================
  // TIPOS DE ACTIVIDAD (homologados con catalogos.json de mobile)
  // ============================================================
  
  static const caminamiento = ActivityType(
    id: 'CAM',
    label: 'Caminamiento',
    icon: Icons.directions_walk,
    defaultRisk: 'medio',
    requiresEvidence: true,
    description: 'Recorrido territorial para verificación',
    allowedRoles: ['operativo', 'coordinador', 'admin'],
  );

  static const reunion = ActivityType(
    id: 'REU',
    label: 'Reunión',
    icon: Icons.groups,
    defaultRisk: 'bajo',
    requiresEvidence: true,
    description: 'Reunión con actores relevantes',
    allowedRoles: ['coordinador', 'admin'],
  );

  static const asamblea = ActivityType(
    id: 'ASP',
    label: 'Asamblea Protocolizada',
    icon: Icons.people,
    defaultRisk: 'alto',
    requiresEvidence: true,
    description: 'Acto formal agrario para aprobar acuerdos y COP',
    allowedRoles: ['coordinador', 'admin'],
  );

  static const consulta = ActivityType(
    id: 'CIN',
    label: 'Consulta Indígena',
    icon: Icons.chat_bubble_outline,
    defaultRisk: 'alto',
    requiresEvidence: true,
    description: 'Proceso de participación conforme al Convenio 169 OIT',
    allowedRoles: ['coordinador', 'admin'],
  );

  static const socializacion = ActivityType(
    id: 'SOC',
    label: 'Socialización',
    icon: Icons.share,
    defaultRisk: 'medio',
    requiresEvidence: true,
    description: 'Presentación y sensibilización comunitaria',
    allowedRoles: ['operativo', 'coordinador', 'admin'],
  );

  static const acompaniamiento = ActivityType(
    id: 'AIN',
    label: 'Acompañamiento Institucional',
    icon: Icons.assistant_direction,
    defaultRisk: 'medio',
    requiresEvidence: true,
    description: 'Supervisión y documentación interinstitucional',
    allowedRoles: ['coordinador', 'admin'],
  );

  // ============================================================
  // LISTA COMPLETA
  // ============================================================
  static const List<ActivityType> all = [
    caminamiento,
    reunion,
    asamblea,
    consulta,
    socializacion,
    acompaniamiento,
  ];

  // ============================================================
  // HELPERS
  // ============================================================
  
  /// Buscar actividad por ID
  static ActivityType? findById(String id) {
    try {
      return all.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Buscar actividad por label
  static ActivityType? findByLabel(String label) {
    try {
      return all.firstWhere(
        (a) => a.label.toLowerCase() == label.toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }

  /// Obtener solo IDs
  static List<String> get ids => all.map((a) => a.id).toList();

  /// Obtener solo labels
  static List<String> get labels => all.map((a) => a.label).toList();

  /// Items para DropdownButton
  static List<DropdownMenuItem<String>> dropdownItems({bool useId = true}) {
    return all.map((activity) {
      return DropdownMenuItem<String>(
        value: useId ? activity.id : activity.label,
        child: Row(
          children: [
            Icon(activity.icon, size: 16, color: SaoColors.gray700),
            const SizedBox(width: 8),
            Text(activity.label),
          ],
        ),
      );
    }).toList();
  }

  /// Filtrar por roles permitidos
  static List<ActivityType> filterByRole(String role) {
    return all.where((a) => a.allowedRoles.contains(role)).toList();
  }

  /// Actividades que requieren evidencia
  static List<ActivityType> get requiresEvidence {
    return all.where((a) => a.requiresEvidence).toList();
  }

  /// Obtener color del icono según el riesgo por defecto
  static Color getIconColor(ActivityType activity) {
    return SaoColors.getRiskColor(activity.defaultRisk);
  }
}
