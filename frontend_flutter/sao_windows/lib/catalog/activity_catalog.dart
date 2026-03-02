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
    id: 'ASA',
    label: 'Asamblea',
    icon: Icons.people,
    defaultRisk: 'alto',
    requiresEvidence: true,
    description: 'Asamblea comunitaria',
    allowedRoles: ['coordinador', 'admin'],
  );

  static const consulta = ActivityType(
    id: 'CON',
    label: 'Consulta',
    icon: Icons.chat_bubble_outline,
    defaultRisk: 'bajo',
    requiresEvidence: false,
    description: 'Consulta o entrevista',
    allowedRoles: ['operativo', 'coordinador', 'admin'],
  );

  static const supervision = ActivityType(
    id: 'SUP',
    label: 'Supervisión',
    icon: Icons.assessment,
    defaultRisk: 'medio',
    requiresEvidence: true,
    description: 'Supervisión de obra o proyecto',
    allowedRoles: ['coordinador', 'admin', 'auditor'],
  );

  static const capacitacion = ActivityType(
    id: 'CAP',
    label: 'Capacitación',
    icon: Icons.school,
    defaultRisk: 'bajo',
    requiresEvidence: true,
    description: 'Sesión de capacitación',
    allowedRoles: ['coordinador', 'admin'],
  );

  static const inspeccion = ActivityType(
    id: 'INS',
    label: 'Inspección',
    icon: Icons.search,
    defaultRisk: 'alto',
    requiresEvidence: true,
    description: 'Inspección técnica',
    allowedRoles: ['coordinador', 'admin', 'auditor'],
  );

  static const levantamiento = ActivityType(
    id: 'LEV',
    label: 'Levantamiento',
    icon: Icons.draw,
    defaultRisk: 'medio',
    requiresEvidence: true,
    description: 'Levantamiento topográfico o de información',
    allowedRoles: ['operativo', 'coordinador', 'admin'],
  );

  // ============================================================
  // LISTA COMPLETA
  // ============================================================
  static const List<ActivityType> all = [
    caminamiento,
    reunion,
    asamblea,
    consulta,
    supervision,
    capacitacion,
    inspeccion,
    levantamiento,
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
