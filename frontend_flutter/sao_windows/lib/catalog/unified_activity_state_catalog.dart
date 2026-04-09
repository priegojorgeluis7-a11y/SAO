// Catálogo unificado de estados de actividades
// 
// Consolida ActivityStatus (Desktop) y StatusCatalog (Mobile)
// Proporciona una fuente única de verdad para:
// 1. Estados de UI (para mostrar al usuario)
// 2. Constantes de estado
// 3. Mapeo entre estados backend y UI
// 4. Labels, iconos, colores

import 'package:flutter/material.dart';

/// Mapeos entre estados del backend y estados de UI
abstract class ActivityStateMapping {
  /// Mapea EXECUTION_STATE del backend → UI state
  /// 
  /// PENDIENTE → nuevo
  /// EN_CURSO → enProgreso  
  /// REVISION_PENDIENTE → enRevision
  /// COMPLETADA → enRevision (waiting for review)
  /// CANCELED → cancelada
  static String executionToUIState(String executionState) {
    return switch (executionState.toUpperCase()) {
      'PENDIENTE' => UIActivityState.nuevo,
      'EN_CURSO' => UIActivityState.enProgreso,
      'REVISION_PENDIENTE' => UIActivityState.enRevision,
      'COMPLETADA' => UIActivityState.enRevision,
      'CANCELED' => UIActivityState.cancelada,
      _ => UIActivityState.nuevo,
    };
  }

  /// Mapea OPERATIONAL_STATE del backend → UI state
  /// 
  /// PENDIENTE → nuevo
  /// EN_CURSO → enProgreso
  /// POR_COMPLETAR → requiereCambios (form incomplete)
  /// CANCELADA → cancelada
  static String operationalToUIState(String operationalState) {
    return switch (operationalState.toUpperCase()) {
      'PENDIENTE' => UIActivityState.nuevo,
      'EN_CURSO' => UIActivityState.enProgreso,
      'POR_COMPLETAR' => UIActivityState.requiereCambios,
      'CANCELADA' => UIActivityState.cancelada,
      _ => UIActivityState.nuevo,
    };
  }

  /// Mapea REVIEW_STATE del backend → UI state
  /// 
  /// NOT_APPLICABLE → (use operational_state)
  /// PENDING_REVIEW → enRevision
  /// CHANGES_REQUIRED → requiereCambios
  /// APPROVED → aprobado
  /// REJECTED → rechazado
  static String reviewToUIState(String reviewState) {
    return switch (reviewState.toUpperCase()) {
      'NOT_APPLICABLE' => '', // Use operational state instead
      'PENDING_REVIEW' => UIActivityState.enRevision,
      'CHANGES_REQUIRED' => UIActivityState.requiereCambios,
      'APPROVED' => UIActivityState.aprobado,
      'REJECTED' => UIActivityState.rechazado,
      _ => UIActivityState.nuevo,
    };
  }

  /// Mapea SYNC_STATE del backend → UI indicator
  /// (No cambia el estado principal, sino que afecta presentación)
  /// 
  /// LOCAL_ONLY → offline o sincronizando
  /// READY_TO_SYNC → offline o sincronizando
  /// SYNC_IN_PROGRESS → sincronizando
  /// SYNCED → normal (no indicator)
  /// SYNC_ERROR → error
  static String syncToUIIndicator(String syncState) {
    return switch (syncState.toUpperCase()) {
      'LOCAL_ONLY' => 'offline',
      'READY_TO_SYNC' => 'offline',
      'SYNC_IN_PROGRESS' => 'sincronizando',
      'SYNCED' => '', // No indicator
      'SYNC_ERROR' => 'error',
      _ => '',
    };
  }

  /// Mapper principal: Calcula UI state considerando todos los estados backend
  /// 
  /// Prioridad: review > operational > execution
  static String calculateUIState({
    required String executionState,
    required String operationalState,
    required String reviewState,
    required String syncState,
  }) {
    // Priority 1: Terminal review states
    if (reviewState.toUpperCase() == 'APPROVED') {
      return UIActivityState.aprobado;
    }
    if (reviewState.toUpperCase() == 'REJECTED') {
      return UIActivityState.rechazado;
    }

    // Priority 2: Review pending (waiting or changes needed)
    if (reviewState.toUpperCase() == 'PENDING_REVIEW') {
      return UIActivityState.enRevision;
    }
    if (reviewState.toUpperCase() == 'CHANGES_REQUIRED') {
      return UIActivityState.requiereCambios;
    }

    // Priority 3: Operational state (primary for active activities)
    final opState = operationalToUIState(operationalState);
    if (opState.isNotEmpty && opState != UIActivityState.nuevo) {
      return opState;
    }

    // Priority 4: Execution state (fallback)
    return executionToUIState(executionState);
  }
}

/// Estados UI unificados (Mobile + Desktop)
/// 
/// Reemplaza:
/// - StatusCatalog.nuevo, enRevision, etc (Mobile)
/// - ActivityStatus.pendingReview, approved, etc (Desktop)
abstract class UIActivityState {
  static const String nuevo = 'nuevo';
  static const String enProgreso = 'enProgreso';
  static const String enRevision = 'enRevision';
  static const String requiereCambios = 'requiereCambios';
  static const String aprobado = 'aprobado';
  static const String rechazado = 'rechazado';
  static const String cancelada = 'cancelada';
  static const String borrador = 'borrador';
  static const String offline = 'offline';
  static const String conflicto = 'conflicto';
  static const String sincronizado = 'sincronizado';

  /// Todos los estados válidos
  static const List<String> allStates = [
    nuevo,
    enProgreso,
    enRevision,
    requiereCambios,
    aprobado,
    rechazado,
    cancelada,
    borrador,
    offline,
    conflicto,
    sincronizado,
  ];

  /// Valida si un estado es válido
  static bool isValid(String? state) => allStates.contains(state);
}

/// Definición visual de estados de actividad
class ActivityStateDefinition {
  final String id;
  final String label; // Label en español
  final IconData icon;
  final Color color;
  final String description;

  const ActivityStateDefinition({
    required this.id,
    required this.label,
    required this.icon,
    required this.color,
    required this.description,
  });
}

/// Catálogo visual de estados (Mobile + Desktop)
class UnifiedActivityStateCatalog {
  UnifiedActivityStateCatalog._();

  /// Definiciones de estados con información visual
  static const Map<String, ActivityStateDefinition> definitions = {
    UIActivityState.nuevo: ActivityStateDefinition(
      id: UIActivityState.nuevo,
      label: 'Nuevo',
      icon: Icons.add_circle_outline,
      color: Color(0xFF3B82F6), // Blue
      description: 'Actividad nueva, no iniciada',
    ),
    UIActivityState.enProgreso: ActivityStateDefinition(
      id: UIActivityState.enProgreso,
      label: 'En Progreso',
      icon: Icons.hourglass_bottom,
      color: Color(0xFFF59E0B), // Amber
      description: 'Actividad en curso',
    ),
    UIActivityState.enRevision: ActivityStateDefinition(
      id: UIActivityState.enRevision,
      label: 'En Revisión',
      icon: Icons.assessment,
      color: Color(0xFFEF4444), // Red
      description: 'Completada, esperando revisión',
    ),
    UIActivityState.requiereCambios: ActivityStateDefinition(
      id: UIActivityState.requiereCambios,
      label: 'Requiere Cambios',
      icon: Icons.edit,
      color: Color(0xFFEC4899), // Pink
      description: 'Coordinador pidió cambios',
    ),
    UIActivityState.aprobado: ActivityStateDefinition(
      id: UIActivityState.aprobado,
      label: 'Aprobado',
      icon: Icons.check_circle,
      color: Color(0xFF10B981), // Green
      description: 'Aprobado por coordinador',
    ),
    UIActivityState.rechazado: ActivityStateDefinition(
      id: UIActivityState.rechazado,
      label: 'Rechazado',
      icon: Icons.cancel,
      color: Color(0xFF6B7280), // Gray
      description: 'Rechazado por coordinador',
    ),
    UIActivityState.cancelada: ActivityStateDefinition(
      id: UIActivityState.cancelada,
      label: 'Cancelada',
      icon: Icons.block,
      color: Color(0xFF6B7280), // Gray
      description: 'Cancelada por usuario',
    ),
    UIActivityState.borrador: ActivityStateDefinition(
      id: UIActivityState.borrador,
      label: 'Borrador',
      icon: Icons.drafts,
      color: Color(0xFF9CA3AF), // Light Gray
      description: 'En borrador, no enviada',
    ),
    UIActivityState.offline: ActivityStateDefinition(
      id: UIActivityState.offline,
      label: 'Sin conexión',
      icon: Icons.cloud_off,
      color: Color(0xFFF87171), // Red
      description: 'Pendiente de sincronizar',
    ),
    UIActivityState.conflicto: ActivityStateDefinition(
      id: UIActivityState.conflicto,
      label: 'Conflicto',
      icon: Icons.warning,
      color: Color(0xFFFBBF24), // Amber
      description: 'Conflicto de datos',
    ),
    UIActivityState.sincronizado: ActivityStateDefinition(
      id: UIActivityState.sincronizado,
      label: 'Sincronizado',
      icon: Icons.cloud_done,
      color: Color(0xFF06B6D4), // Cyan
      description: 'Sincronizado con servidor',
    ),
  };

  /// Obtiene la definición de un estado
  static ActivityStateDefinition getDefinition(String state) {
    return definitions[state] ??
        ActivityStateDefinition(
          id: state,
          label: state,
          icon: Icons.help,
          color: const Color(0xFF9CA3AF),
          description: 'Estado desconocido',
        );
  }

  /// Obtiene el label en español de un estado
  static String getLabel(String state) => getDefinition(state).label;

  /// Obtiene el icono de un estado
  static IconData getIcon(String state) => getDefinition(state).icon;

  /// Obtiene el color de un estado
  static Color getColor(String state) => getDefinition(state).color;

  /// Obtiene todas las transiciones permitidas desde un estado
  /// (Basado en StatusCatalog.nextStatesFor)
  static List<String> getValidTransitions(String state) {
    return switch (state) {
      UIActivityState.nuevo => [
        UIActivityState.enProgreso,
        UIActivityState.cancelada,
      ],
      UIActivityState.enProgreso => [
        UIActivityState.enRevision,
        UIActivityState.requiereCambios,
        UIActivityState.cancelada,
      ],
      UIActivityState.enRevision => [
        UIActivityState.aprobado,
        UIActivityState.rechazado,
        UIActivityState.requiereCambios,
      ],
      UIActivityState.requiereCambios => [
        UIActivityState.nuevo,
        UIActivityState.enProgreso,
        UIActivityState.cancelada,
      ],
      UIActivityState.aprobado => [], // Terminal
      UIActivityState.rechazado => [], // Terminal
      UIActivityState.cancelada => [], // Terminal
      UIActivityState.borrador => [
        UIActivityState.nuevo,
        UIActivityState.cancelada,
      ],
      UIActivityState.offline => [
        UIActivityState.nuevo, // After sync
        UIActivityState.requiereCambios,
        UIActivityState.conflicto,
      ],
      UIActivityState.conflicto => [
        UIActivityState.nuevo,
        UIActivityState.cancelada,
      ],
      UIActivityState.sincronizado => [
        UIActivityState.nuevo,
        UIActivityState.aprobado,
        UIActivityState.rechazado,
      ],
      _ => [],
    };
  }
}

/// Constantes de estado para compatibilidad backwards
/// (Reemplaza ActivityStatus de Desktop)
abstract class LegacyActivityStatus {
  static const String pendingReview = 'PENDING_REVIEW';
  static const String approved = 'APPROVED';
  static const String rejected = 'REJECTED';
  static const String needsFix = 'NEEDS_FIX';
  static const String corrected = 'CORRECTED';
  static const String conflict = 'CONFLICT';

  /// Mapea legacy status al nuevo UIActivityState
  static String toUIState(String legacyStatus) {
    return switch (legacyStatus.toUpperCase()) {
      'PENDING_REVIEW' => UIActivityState.enRevision,
      'APPROVED' => UIActivityState.aprobado,
      'REJECTED' => UIActivityState.rechazado,
      'NEEDS_FIX' => UIActivityState.requiereCambios,
      'CORRECTED' => UIActivityState.nuevo,
      'CONFLICT' => UIActivityState.conflicto,
      _ => UIActivityState.nuevo,
    };
  }
}
