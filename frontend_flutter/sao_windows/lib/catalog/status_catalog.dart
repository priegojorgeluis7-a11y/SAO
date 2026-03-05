// lib/catalog/status_catalog.dart
import 'package:flutter/material.dart';
import '../ui/theme/sao_colors.dart';
import '../features/catalog/catalog_repository.dart';
import 'roles_catalog.dart';

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

  const StatusType({
    required this.id,
    required this.label,
    required this.color,
    required this.backgroundColor,
    required this.icon,
    required this.order,
    this.isTerminal = false,
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
  );

  static const enRevision = StatusType(
    id: 'en_revision',
    label: 'En Revisión',
    color: Color(0xFFF59E0B),
    backgroundColor: Color(0xFFFEF3C7),
    icon: Icons.rate_review,
    order: 2,
  );

  static const requiereCambios = StatusType(
    id: 'requiere_cambios',
    label: 'Requiere Cambios',
    color: Color(0xFFF59E0B),
    backgroundColor: Color(0xFFFEF3C7),
    icon: Icons.edit_note,
    order: 3,
  );

  static const aprobado = StatusType(
    id: 'aprobado',
    label: 'Aprobado',
    color: SaoColors.success,
    backgroundColor: Color(0xFFD1FAE5),
    icon: Icons.check_circle,
    order: 4,
  );

  static const rechazado = StatusType(
    id: 'rechazado',
    label: 'Rechazado',
    color: SaoColors.error,
    backgroundColor: Color(0xFFFEE2E2),
    icon: Icons.cancel,
    order: 5,
    isTerminal: true,
  );

  static const sincronizado = StatusType(
    id: 'sincronizado',
    label: 'Sincronizado',
    color: Color(0xFF10B981),
    backgroundColor: Color(0xFFD1FAE5),
    icon: Icons.cloud_done,
    order: 6,
    isTerminal: true,
  );

  static const offline = StatusType(
    id: 'offline',
    label: 'Sin Conexión',
    color: SaoColors.gray600,
    backgroundColor: SaoColors.gray100,
    icon: Icons.cloud_off,
    order: 7,
  );

  static const conflicto = StatusType(
    id: 'conflicto',
    label: 'Conflicto',
    color: Color(0xFFDC2626),
    backgroundColor: Color(0xFFFEE2E2),
    icon: Icons.error_outline,
    order: 8,
  );

  static const borrador = StatusType(
    id: 'borrador',
    label: 'Borrador',
    color: SaoColors.gray500,
    backgroundColor: SaoColors.gray100,
    icon: Icons.edit_note,  // Ícono alternativo para borrador
    order: 0,
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

  /// Siguientes estados válidos según catálogo efectivo (rules.workflow).
  static List<String> nextStatesFor({
    required String status,
    required String role,
    String? activityType,
    required CatalogData catalog,
  }) {
    final workflowNode = _workflowNodeFor(catalog, activityType: activityType);
    if (workflowNode == null) return const [];

    final transitions = _transitionsFrom(workflowNode);
    if (transitions.isEmpty) return const [];

    final from = status.trim().toLowerCase();
    final result = <String>[];

    for (final transition in transitions) {
      final transitionFrom = (transition['from'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      if (transitionFrom != from) continue;
      if (!_roleAllowed(transition, role)) continue;
      if (!_permissionsAllowed(transition, role)) continue;

      for (final toState in _toStatesFromTransition(transition)) {
        if (!result.contains(toState)) {
          result.add(toState);
        }
      }
    }

    return result;
  }

  static Map<String, dynamic>? _workflowNodeFor(
    CatalogData catalog, {
    String? activityType,
  }) {
    final workflowRaw = catalog.rules['workflow'];
    if (workflowRaw is! Map) return null;

    final workflow = workflowRaw.cast<String, dynamic>();
    final typeCode = activityType?.trim();

    if (typeCode != null && typeCode.isNotEmpty) {
      final byType = _typedWorkflow(workflow, typeCode);
      if (byType != null) return byType;
    }

    final global = workflow['global'] ?? workflow['default'];
    if (global is Map) {
      return global.cast<String, dynamic>();
    }

    return workflow;
  }

  static Map<String, dynamic>? _typedWorkflow(
    Map<String, dynamic> workflow,
    String activityType,
  ) {
    const keys = <String>[
      'by_activity_type',
      'byActivityType',
      'by_type',
      'byType',
      'types',
    ];

    for (final key in keys) {
      final raw = workflow[key];
      if (raw is! Map) continue;
      final typed = raw.cast<String, dynamic>();

      final direct = typed[activityType];
      if (direct is Map) return direct.cast<String, dynamic>();

      final normalizedType = activityType.toLowerCase();
      for (final entry in typed.entries) {
        if (entry.key.toLowerCase() == normalizedType && entry.value is Map) {
          return (entry.value as Map).cast<String, dynamic>();
        }
      }
    }

    return null;
  }

  static List<Map<String, dynamic>> _transitionsFrom(Map<String, dynamic> workflowNode) {
    final transitions = workflowNode['transitions'];
    if (transitions is! List) return const <Map<String, dynamic>>[];

    return transitions
        .whereType<Map>()
        .map((m) => m.cast<String, dynamic>())
        .toList(growable: false);
  }

  static List<String> _toStatesFromTransition(Map<String, dynamic> transition) {
    final to = transition['to'];
    if (to is List) {
      return to
          .map((e) => e.toString().trim().toLowerCase())
          .where((e) => e.isNotEmpty)
          .toList(growable: false);
    }

    final single = to?.toString().trim().toLowerCase() ?? '';
    if (single.isEmpty) return const [];
    return <String>[single];
  }

  static bool _roleAllowed(Map<String, dynamic> transition, String role) {
    final rawRoles = transition['roles'];
    if (rawRoles is! List || rawRoles.isEmpty) return true;

    final normalizedRole = role.trim().toLowerCase();
    final allowed = rawRoles
        .map((e) => e.toString().trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toSet();

    return allowed.contains(normalizedRole);
  }

  static bool _permissionsAllowed(Map<String, dynamic> transition, String role) {
    final rawPermissions = transition['required_permissions'];
    if (rawPermissions is! List || rawPermissions.isEmpty) return true;

    final required = rawPermissions
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
    if (required.isEmpty) return true;

    return required.every((permission) => RolesCatalog.hasPermission(role, permission));
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
