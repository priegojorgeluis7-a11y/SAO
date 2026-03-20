// lib/features/catalog/data/catalog_offline_repository.dart
import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/utils/logger.dart';
import '../../../data/local/app_db.dart';

/// Repositorio Drift para el índice de catálogos descargados y sus bundles cacheados.
///
/// Responsabilidades:
///   1. Registrar qué versión de catálogo está activa por proyecto (`catalog_index`).
///   2. Almacenar bundles completos por (project_id, version_id) (`catalog_bundles`).
///   3. GC seguro: eliminar bundles huérfanos que ninguna actividad referencia.
class CatalogOfflineRepository {
  final AppDb _db;

  CatalogOfflineRepository({required AppDb db}) : _db = db;

  // ── Index ────────────────────────────────────────────────────────────────

  /// Registra o actualiza el version_id activo para un proyecto.
  Future<void> upsertIndex({
    required String projectId,
    required String versionId,
    String? hash,
  }) async {
    await _db.into(_db.catalogIndex).insertOnConflictUpdate(
          CatalogIndexCompanion(
            projectId: Value(projectId),
            activeVersionId: Value(versionId),
            hash: Value(hash),
            updatedAt: Value(DateTime.now().toUtc()),
          ),
        );
    appLogger.d('📑 CatalogIndex updated: $projectId → $versionId');
  }

  /// Devuelve el version_id activo del proyecto, o null si no hay entrada.
  Future<String?> getActiveVersionId(String projectId) async {
    final row = await (_db.select(_db.catalogIndex)
          ..where((t) => t.projectId.equals(projectId)))
        .getSingleOrNull();
    return row?.activeVersionId;
  }

  // ── Bundle cache ──────────────────────────────────────────────────────────

  /// Persiste el JSON completo de un bundle para (project, version).
  /// Idempotente — usa insertOnConflictUpdate.
  Future<void> saveBundle({
    required String projectId,
    required String versionId,
    required Map<String, dynamic> bundleJson,
  }) async {
    await _db.into(_db.catalogBundleCache).insertOnConflictUpdate(
          CatalogBundleCacheCompanion(
            projectId: Value(projectId),
            versionId: Value(versionId),
            jsonBlob: Value(jsonEncode(bundleJson)),
            createdAt: Value(DateTime.now().toUtc()),
          ),
        );
    appLogger.d('📦 CatalogBundle saved: $projectId@$versionId');
  }

  /// Recupera el JSON del bundle para (project, version), o null si no existe.
  Future<Map<String, dynamic>?> getBundle({
    required String projectId,
    required String versionId,
  }) async {
    final row = await (_db.select(_db.catalogBundleCache)
          ..where(
            (t) =>
                t.projectId.equals(projectId) & t.versionId.equals(versionId),
          ))
        .getSingleOrNull();
    if (row == null) return null;
    return jsonDecode(row.jsonBlob) as Map<String, dynamic>;
  }

  // ── GC ────────────────────────────────────────────────────────────────────

  /// Elimina bundles que ninguna actividad local referencia.
  ///
  /// Un bundle es "huérfano" cuando:
  ///   - no es el version activo en `catalog_index`, Y
  ///   - ninguna fila en `activities` tiene `catalog_version_id = versionId`.
  ///
  /// Retorna el número de bundles eliminados.
  Future<int> gcOrphanBundles() async {
    final bundles = await _db.select(_db.catalogBundleCache).get();
    final activeVersions = await _db.select(_db.catalogIndex).get();
    final activeSet = {
      for (final idx in activeVersions) '${idx.projectId}:${idx.activeVersionId}'
    };

    int deleted = 0;
    for (final bundle in bundles) {
      final key = '${bundle.projectId}:${bundle.versionId}';
      if (activeSet.contains(key)) continue; // versión activa → conservar

      // ¿Alguna actividad local referencia esta versión?
      final refCount = await (_db.select(_db.activities)
            ..where(
              (a) =>
                  a.projectId.equals(bundle.projectId) &
                  a.catalogVersionId.equals(bundle.versionId),
            ))
          .get();

      if (refCount.isNotEmpty) continue; // hay actividades → conservar

      await (_db.delete(_db.catalogBundleCache)
            ..where(
              (t) =>
                  t.projectId.equals(bundle.projectId) &
                  t.versionId.equals(bundle.versionId),
            ))
          .go();
      appLogger.i(
        '🗑️ GC: deleted orphan bundle $key (no activities reference it)',
      );
      deleted++;
    }

    if (deleted > 0) {
      appLogger.i('🧹 CatalogBundle GC: $deleted bundles removed');
    }
    return deleted;
  }
}
