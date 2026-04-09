// lib/data/local/services/assignee_resolver.dart
/// Servicio para resolver asignado (assignee) de actividad mediante fallbacks
/// cuando el campo directo assigned_to_user_id es null.
///
/// Fallback chain:
/// 1. assigned_to_user_id (columna directa en Activities)
/// 2. ActivityFields('assignee_user_id')
/// 3. AgendaAssignments directa por activityId
/// 4. Detección automática: proyecto + PK + título normalizado

import 'package:drift/drift.dart';

import '../app_db.dart';

class AssigneeResolver {
  final AppDb _db;

  AssigneeResolver(this._db);

  /// Resuelve el user ID asignado a una actividad usando fallbacks
  Future<String?> resolveAssignedToUserId(String activityId) async {
    // 1. Leer desde Activities directamente
    final activity = await _db.getActivityById(activityId);
    if (activity != null && activity.assignedToUserId != null && activity.assignedToUserId!.trim().isNotEmpty) {
      return activity.assignedToUserId!.trim();
    }

    // 2. Fallback: ActivityFields
    final fieldId = '$activityId:assignee_user_id';
    final field = await (_db.select(_db.activityFields)
          ..where((t) => t.id.equals(fieldId)))
        .getSingleOrNull();
    if (field != null && field.valueText != null && field.valueText!.trim().isNotEmpty) {
      return field.valueText!.trim();
    }

    if (activity == null) {
      return null;
    }

    // 3. Fallback: AgendaAssignments directa
    final directAssignment = await (_db.select(_db.agendaAssignments)
          ..where((t) => t.activityId.equals(activityId)))
        .getSingleOrNull();
    if (directAssignment != null && directAssignment.resourceId != null && directAssignment.resourceId!.trim().isNotEmpty) {
      return directAssignment.resourceId!.trim();
    }

    // 4. Fallback: Detección automática por proyecto + PK + título normalizado
    final autoDetected = await _resolveByProjectPkTitle(
      projectId: activity.projectId,
      pk: activity.pk,
      title: activity.title,
      createdAt: activity.createdAt,
    );
    return autoDetected;
  }

  /// Detección automática: busca AgendaAssignments que coincida por proyecto + PK + título normalizado
  Future<String?> _resolveByProjectPkTitle({
    required String projectId,
    required int? pk,
    required String title,
    required DateTime createdAt,
  }) async {
    if (pk == null || title.trim().isEmpty) {
      return null;
    }

    final normalizedTitle = title.trim().toLowerCase();
    final day = DateTime(createdAt.year, createdAt.month, createdAt.day);

    // Buscar en AgendaAssignments del proyecto
    final candidates = await (_db.select(_db.agendaAssignments)
          ..where((t) =>
              t.projectId.equals(projectId) &
              t.pk.equals(pk)))
        .get();

    if (candidates.isEmpty) {
      return null;
    }

    // Preferir asignaciones del mismo día si existe
    final sameDayAssignments = candidates.where((c) {
      final candidateDay = DateTime(c.startAt.year, c.startAt.month, c.startAt.day);
      return candidateDay.isAtSameMomentAs(day);
    }).toList();

    if (sameDayAssignments.isNotEmpty) {
      final match = sameDayAssignments.firstWhere(
        (c) => (c.title.trim().toLowerCase() == normalizedTitle),
        orElse: () => sameDayAssignments.first,
      );
      if (match.resourceId != null && match.resourceId!.trim().isNotEmpty) {
        return match.resourceId!.trim();
      }
    }

    // Fallback: usar la más reciente
    final mostRecent = candidates.reduce((a, b) => a.updatedAt.isAfter(b.updatedAt) ? a : b);
    if (mostRecent.resourceId != null && mostRecent.resourceId!.trim().isNotEmpty) {
      return mostRecent.resourceId!.trim();
    }

    return null;
  }
}
