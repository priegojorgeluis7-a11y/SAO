// lib/catalog/risk_catalog.dart
import 'package:flutter/material.dart';
import '../ui/theme/sao_colors.dart';

/// Catálogo global de niveles de riesgo (compartido Mobile + Desktop)
/// 📱 HOMOLOGADO con app móvil: bajo, medio, alto, prioritario
class RiskLevel {
  final String id;
  final String label;
  final Color color;
  final Color backgroundColor;
  final int priority; // Mayor número = mayor prioridad
  final String emoji;

  const RiskLevel({
    required this.id,
    required this.label,
    required this.color,
    required this.backgroundColor,
    required this.priority,
    required this.emoji,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RiskLevel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Catálogo de riesgos del SAO
class RiskCatalog {
  RiskCatalog._();

  // ============================================================
  // NIVELES DE RIESGO (homologados con app móvil)
  // ============================================================
  
  static const bajo = RiskLevel(
    id: 'bajo',
    label: 'BAJO',
    color: SaoColors.riskLow,
    backgroundColor: Color(0x2416A34A), // riskLow con 14% opacidad
    priority: 1,
    emoji: '🟢',
  );

  static const medio = RiskLevel(
    id: 'medio',
    label: 'MEDIO',
    color: SaoColors.riskMedium,
    backgroundColor: Color(0x24F59E0B), // riskMedium con 14% opacidad
    priority: 2,
    emoji: '🟡',
  );

  static const alto = RiskLevel(
    id: 'alto',
    label: 'ALTO',
    color: SaoColors.riskHigh,
    backgroundColor: Color(0x24F97316), // riskHigh con 14% opacidad
    priority: 3,
    emoji: '🟠',
  );

  static const prioritario = RiskLevel(
    id: 'prioritario',
    label: 'PRIORITARIO', // 📱 Homologado con app móvil (no "CRÍTICO")
    color: SaoColors.riskPriority,
    backgroundColor: Color(0x24DC2626), // riskPriority con 14% opacidad
    priority: 4,
    emoji: '🔴',
  );

  // ⚠️ Alias para compatibilidad con código legacy
  static const critical = prioritario;

  // ============================================================
  // LISTA COMPLETA
  // ============================================================
  static const List<RiskLevel> all = [
    bajo,
    medio,
    alto,
    prioritario,
  ];

  // ============================================================
  // HELPERS
  // ============================================================
  
  /// Buscar nivel por ID (soporta variaciones de nomenclatura)
  static RiskLevel? findById(String id) {
    final normalized = id.toLowerCase().trim();
    
    // Mapeo de variaciones
    switch (normalized) {
      case 'bajo':
      case 'low':
        return bajo;
      case 'medio':
      case 'medium':
        return medio;
      case 'alto':
      case 'high':
        return alto;
      case 'prioritario':
      case 'priority':
      case 'crítico':
      case 'critico':
      case 'critical':
        return prioritario;
      default:
        return null;
    }
  }

  /// Buscar por prioridad numérica
  static RiskLevel? findByPriority(int priority) {
    try {
      return all.firstWhere((r) => r.priority == priority);
    } catch (_) {
      return null;
    }
  }

  /// Obtener solo IDs
  static List<String> get ids => all.map((r) => r.id).toList();

  /// Obtener solo labels
  static List<String> get labels => all.map((r) => r.label).toList();

  /// Items para DropdownButton
  static List<DropdownMenuItem<String>> dropdownItems({bool useId = true}) {
    return all.map((risk) {
      return DropdownMenuItem<String>(
        value: useId ? risk.id : risk.label,
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: risk.color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(risk.label),
          ],
        ),
      );
    }).toList();
  }

  /// Ordenados por prioridad (menor a mayor)
  static List<RiskLevel> get orderedByPriority {
    final list = List<RiskLevel>.from(all);
    list.sort((a, b) => a.priority.compareTo(b.priority));
    return list;
  }

  /// Ordenados por prioridad (mayor a menor)
  static List<RiskLevel> get orderedByPriorityDesc {
    final list = List<RiskLevel>.from(all);
    list.sort((a, b) => b.priority.compareTo(a.priority));
    return list;
  }

  /// Niveles de alto riesgo (>=3)
  static List<RiskLevel> get highRiskLevels {
    return all.where((r) => r.priority >= 3).toList();
  }

  /// Badge widget para riesgo (homologado con mobile: círculo + texto)
  static Widget badge(String riskId, {double? fontSize, bool showLabel = true}) {
    final risk = findById(riskId) ?? medio;
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: fontSize != null ? fontSize * 0.7 : 8,
          height: fontSize != null ? fontSize * 0.7 : 8,
          decoration: BoxDecoration(
            color: risk.color,
            shape: BoxShape.circle,
          ),
        ),
        if (showLabel) ...[
          const SizedBox(width: 6),
          Text(
            risk.label,
            style: TextStyle(
              fontSize: fontSize ?? 11,
              fontWeight: FontWeight.w600,
              color: risk.color,
            ),
          ),
        ],
      ],
    );
  }

  /// Pill badge con fondo coloreado
  static Widget pill(String riskId, {double? fontSize}) {
    final risk = findById(riskId) ?? medio;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: risk.backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: risk.color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: risk.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            risk.label,
            style: TextStyle(
              fontSize: fontSize ?? 11,
              fontWeight: FontWeight.w700,
              color: risk.color,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  /// Obtener color por ID
  static Color getColor(String riskId) {
    return findById(riskId)?.color ?? SaoColors.gray500;
  }

  /// Obtener background color por ID
  static Color getBackgroundColor(String riskId) {
    return findById(riskId)?.backgroundColor ?? SaoColors.gray100;
  }
}
