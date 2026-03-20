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
    label: 'TMQ',
    acronym: 'TMQ',
    description: 'Tren Maya Quintana Roo',
    accentColor: Color(0xFF059669),
    isActive: true,
  );

  static const tap = ProjectType(
    id: 'TAP',
    label: 'Tren Aeropuerto - Pachuca',
    acronym: 'TAP',
    description: 'Proyecto Tren Interurbano México-Toluca',
    accentColor: Color(0xFF3B82F6),
    isActive: true,
  );

  static const snl = ProjectType(
    id: 'SNL',
    label: 'Sistema Nacional de Logística',
    acronym: 'SNL',
    description: 'Infraestructura logística nacional',
    accentColor: Color(0xFF8B5CF6),
    isActive: true,
  );

  static const qir = ProjectType(
    id: 'QIR',
    label: 'Querétaro - Irapuato',
    acronym: 'QIR',
    description: 'Carretera Querétaro - Irapuato',
    accentColor: Color(0xFFF59E0B),
    isActive: true,
  );

  static const csr = ProjectType(
    id: 'CSR',
    label: 'Corredor Siervo de la Nación',
    acronym: 'CSR',
    description: 'Mejoramiento de carreteras federales',
    accentColor: Color(0xFFEC4899),
    isActive: true,
  );

  static const ipp = ProjectType(
    id: 'IPP',
    label: 'Infraestructura Portuaria',
    acronym: 'IPP',
    description: 'Modernización de puertos estratégicos',
    accentColor: Color(0xFF06B6D4),
    isActive: true,
  );

  static const aer = ProjectType(
    id: 'AER',
    label: 'Aeropuertos Estratégicos',
    acronym: 'AER',
    description: 'Red de aeropuertos regionales',
    accentColor: Color(0xFF6366F1),
    isActive: true,
  );

  static const gen = ProjectType(
    id: 'GEN',
    label: 'Proyecto General',
    acronym: 'GEN',
    description: 'Actividades generales sin proyecto específico',
    accentColor: SaoColors.gray600,
    isActive: true,
  );

  // ============================================================
  // LISTA COMPLETA
  // ============================================================
  static const List<ProjectType> all = [
    tmq,
    tap,
    snl,
    qir,
    csr,
    ipp,
    aer,
    gen,
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
    final project = findById(projectId) ?? gen;
    
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
    final project = findById(projectId) ?? gen;
    
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
