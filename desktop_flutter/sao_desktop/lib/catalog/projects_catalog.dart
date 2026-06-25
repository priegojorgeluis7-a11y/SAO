// lib/catalog/projects_catalog.dart
import 'package:flutter/material.dart';
import '../ui/theme/sao_colors.dart';

/// Catálogo global de proyectos (compartido Mobile + Desktop)
class ProjectType {
  final String id;
  final String label;
  final String description;
  final Color accentColor;
  final String? acronym;
  final bool isActive;
  final DateTime? startDate;
  final DateTime? endDate;

  const ProjectType({
    required this.id,
    required this.label,
    required this.description,
    required this.accentColor,
    this.acronym,
    this.isActive = true,
    this.startDate,
    this.endDate,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProjectType &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Catálogo de proyectos del SAO
class ProjectsCatalog {
  ProjectsCatalog._();

  // ============================================================
  // PROYECTOS DEL SISTEMA
  // ============================================================
  
  static const tmq = ProjectType(
    id: 'TMQ',
    label: 'Tren México-Querétaro',
    acronym: 'TMQ',
    description: 'Tren México-Querétaro',
    accentColor: Color(0xFF059669),
    isActive: true,
  );

  static const tap = ProjectType(
    id: 'TAP',
    label: 'Tren AIFA-Pachuca',
    acronym: 'TAP',
    description: 'Tren AIFA-Pachuca',
    accentColor: Color(0xFF3B82F6),
    isActive: true,
  );

  static const tqi = ProjectType(
    id: 'TQI',
    label: 'Tren Querétaro-Irapuato',
    acronym: 'TQI',
    description: 'Tren Querétaro-Irapuato',
    accentColor: Color(0xFF8B5CF6),
    isActive: true,
  );

  static const tsnl = ProjectType(
    id: 'TSNL',
    label: 'Tren Suburbano Nuevo León',
    acronym: 'TSNL',
    description: 'Tren Suburbano Nuevo León',
    accentColor: Color(0xFFF59E0B),
    isActive: true,
  );

  static const tqsl = ProjectType(
    id: 'TQSL',
    label: 'Tren Querétaro-San Luis Potosí',
    acronym: 'TQSL',
    description: 'Tren Querétaro-San Luis Potosí',
    accentColor: Color(0xFFEC4899),
    isActive: true,
  );

  static const tsls = ProjectType(
    id: 'TSLS',
    label: 'Tren Saltillo-San Luis Potosí',
    acronym: 'TSLS',
    description: 'Tren Saltillo-San Luis Potosí',
    accentColor: Color(0xFF06B6D4),
    isActive: true,
  );

  // ============================================================
  // LISTA COMPLETA
  // ============================================================
  static const List<ProjectType> all = [
    tmq,
    tap,
    tqi,
    tsnl,
    tqsl,
    tsls,
  ];


  // ============================================================
  // HELPERS
  // ============================================================
  
  /// Buscar proyecto por ID
  static ProjectType? findById(String id) {
    try {
      return all.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Buscar proyecto por acrónimo
  static ProjectType? findByAcronym(String acronym) {
    try {
      return all.firstWhere(
        (p) => p.acronym?.toLowerCase() == acronym.toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }

  /// Buscar proyecto por label
  static ProjectType? findByLabel(String label) {
    try {
      return all.firstWhere(
        (p) => p.label.toLowerCase().contains(label.toLowerCase()),
      );
    } catch (_) {
      return null;
    }
  }

  /// Obtener solo IDs
  static List<String> get ids => all.map((p) => p.id).toList();

  /// Obtener solo labels
  static List<String> get labels => all.map((p) => p.label).toList();

  /// Obtener solo acrónimos
  static List<String> get acronyms => 
      all.map((p) => p.acronym ?? p.id).toList();

  /// Items para DropdownButton
  static List<DropdownMenuItem<String>> dropdownItems({
    bool useId = true,
    bool onlyActive = true,
  }) {
    final projects = onlyActive ? activeProjects : all;
    
    return projects.map((project) {
      return DropdownMenuItem<String>(
        value: useId ? project.id : project.label,
        child: Row(
          children: [
            Container(
              width: 4,
              height: 16,
              decoration: BoxDecoration(
                color: project.accentColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(project.acronym ?? project.id,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(width: 4),
            const Text('-', style: TextStyle(color: SaoColors.gray400)),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                project.label,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  /// Proyectos activos
  static List<ProjectType> get activeProjects {
    return all.where((p) => p.isActive).toList();
  }

  /// Chip widget para proyecto
  static Widget chip(String projectId, {double? fontSize}) {
    final project = findById(projectId) ?? tmq;

    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: project.accentColor.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: project.accentColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: project.accentColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            project.acronym ?? project.id,
            style: TextStyle(
              fontSize: fontSize ?? 11,
              fontWeight: FontWeight.w700,
              color: project.accentColor,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  /// Badge con nombre completo
  static Widget badge(String projectId, {double? fontSize, bool showFull = false}) {
    final project = findById(projectId) ?? tmq;

    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: project.accentColor.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: project.accentColor.withValues(alpha: 0.4)),
      ),
      child: Text(
        showFull ? project.label : (project.acronym ?? project.id),
        style: TextStyle(
          fontSize: fontSize ?? 12,
          fontWeight: FontWeight.w600,
          color: project.accentColor,
        ),
      ),
    );
  }

  /// Obtener color por ID
  static Color getColor(String projectId) {
    return findById(projectId)?.accentColor ?? SaoColors.gray500;
  }

  /// Barra de color para identificar proyecto
  static Widget colorBar(String projectId, {double width = 4, double? height}) {
    final project = findById(projectId);
    
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: project?.accentColor ?? SaoColors.gray300,
        borderRadius: BorderRadius.circular(width / 2),
      ),
    );
  }
}
