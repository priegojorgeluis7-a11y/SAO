// lib/catalog/status_catalog.dart
import 'package:flutter/material.dart';
import '../ui/theme/sao_colors.dart';

/// Catálogo global de estados del flujo de operaciones (compartido Mobile + Desktop)
/// Fuente única de verdad para estados de actividades/operaciones
class StatusType {
  final String id;
  final String label;
  final Color color;
  final Color backgroundColor;
  final IconData icon;
  final int order; // Para ordenar en UI
  final bool isTerminal; // Estado final del flujo
  final List<String> nextStates; // Estados válidos siguientes

  const StatusType({
    required this.id,
    required this.label,
    required this.color,
    required this.backgroundColor,
    required this.icon,
    required this.order,
    this.isTerminal = false,
    this.nextStates = const [],
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StatusType &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Catálogo de estados del SAO
class StatusCatalog {
  StatusCatalog._();

  // ============================================================
  // ESTADOS DEL FLUJO
  // ============================================================
  
  static const nuevo = StatusType(
    id: 'nuevo',
    label: 'Nuevo',
    color: SaoColors.actionPrimary,
    backgroundColor: Color(0xFFE0E7FF),
    icon: Icons.fiber_new,
    order: 1,
    nextStates: ['en_revision', 'rechazado'],
  );

  static const enRevision = StatusType(
    id: 'en_revision',
    label: 'En Revisión',
    color: Color(0xFFF59E0B),
    backgroundColor: Color(0xFFFEF3C7),
    icon: Icons.rate_review,
    order: 2,
    nextStates: ['aprobado', 'rechazado', 'requiere_cambios'],
  );

  static const requiereCambios = StatusType(
    id: 'requiere_cambios',
    label: 'Requiere Cambios',
    color: Color(0xFFF59E0B),
    backgroundColor: Color(0xFFFEF3C7),
    icon: Icons.edit_note,
    order: 3,
    nextStates: ['en_revision', 'rechazado'],
  );

  static const aprobado = StatusType(
    id: 'aprobado',
    label: 'Aprobado',
    color: SaoColors.success,
    backgroundColor: Color(0xFFD1FAE5),
    icon: Icons.check_circle,
    order: 4,
    nextStates: ['sincronizado'],
  );

  static const rechazado = StatusType(
    id: 'rechazado',
    label: 'Rechazado',
    color: SaoColors.error,
    backgroundColor: Color(0xFFFEE2E2),
    icon: Icons.cancel,
    order: 5,
    isTerminal: true,
    nextStates: [],
  );

  static const sincronizado = StatusType(
    id: 'sincronizado',
    label: 'Sincronizado',
    color: Color(0xFF10B981),
    backgroundColor: Color(0xFFD1FAE5),
    icon: Icons.cloud_done,
    order: 6,
    isTerminal: true,
    nextStates: [],
  );

  static const offline = StatusType(
    id: 'offline',
    label: 'Sin Conexión',
    color: SaoColors.gray600,
    backgroundColor: SaoColors.gray100,
    icon: Icons.cloud_off,
    order: 7,
    nextStates: ['sincronizado', 'conflicto'],
  );

  static const conflicto = StatusType(
    id: 'conflicto',
    label: 'Conflicto',
    color: Color(0xFFDC2626),
    backgroundColor: Color(0xFFFEE2E2),
    icon: Icons.error_outline,
    order: 8,
    nextStates: ['en_revision'],
  );

  static const borrador = StatusType(
    id: 'borrador',
    label: 'Borrador',
    color: SaoColors.gray500,
    backgroundColor: SaoColors.gray100,
    icon: Icons.edit_note,  // Ícono alternativo para borrador
    order: 0,
    nextStates: ['nuevo', 'en_revision'],
  );

  // ============================================================
  // LISTA COMPLETA
  // ============================================================
  static const List<StatusType> all = [
    borrador,
    nuevo,
    enRevision,
    requiereCambios,
    aprobado,
    rechazado,
    sincronizado,
    offline,
    conflicto,
  ];

  // ============================================================
  // HELPERS
  // ============================================================
  
  /// Buscar estado por ID
  static StatusType? findById(String id) {
    try {
      return all.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Buscar estado por label
  static StatusType? findByLabel(String label) {
    try {
      return all.firstWhere(
        (s) => s.label.toLowerCase() == label.toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }

  /// Obtener solo IDs
  static List<String> get ids => all.map((s) => s.id).toList();

  /// Obtener solo labels
  static List<String> get labels => all.map((s) => s.label).toList();

  /// Items para DropdownButton
  static List<DropdownMenuItem<String>> dropdownItems({bool useId = true}) {
    return all.map((status) {
      return DropdownMenuItem<String>(
        value: useId ? status.id : status.label,
        child: Row(
          children: [
            Icon(status.icon, size: 16, color: status.color),
            const SizedBox(width: 8),
            Text(status.label),
          ],
        ),
      );
    }).toList();
  }

  /// Estados activos (no terminales)
  static List<StatusType> get activeStates {
    return all.where((s) => !s.isTerminal).toList();
  }

  /// Estados terminales
  static List<StatusType> get terminalStates {
    return all.where((s) => s.isTerminal).toList();
  }

  /// Estados ordenados por flujo
  static List<StatusType> get orderedByFlow {
    final list = List<StatusType>.from(all);
    list.sort((a, b) => a.order.compareTo(b.order));
    return list;
  }

  /// Validar transición entre estados
  static bool canTransitionTo(String fromId, String toId) {
    final from = findById(fromId);
    if (from == null) return false;
    return from.nextStates.contains(toId);
  }

  /// Badge widget para estado
  static Widget badge(String statusId, {double? fontSize}) {
    final status = findById(statusId) ?? nuevo;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: status.backgroundColor,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: status.color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.icon, size: fontSize ?? 12, color: status.color),
          const SizedBox(width: 4),
          Text(
            status.label.toUpperCase(),
            style: TextStyle(
              fontSize: fontSize ?? 11,
              fontWeight: FontWeight.w700,
              color: status.color,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
