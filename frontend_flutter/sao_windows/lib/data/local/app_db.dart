// lib/data/local/app_db.dart
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'tables.dart';

part 'app_db.g.dart';

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'sigef_local.sqlite'));
    return NativeDatabase(file);
  });
}

@DriftDatabase(
  tables: [
    Roles, Users,
    Projects, ProjectSegments,
    CatalogVersions, CatalogActivityTypes, CatalogFields,
    CatActivities, CatSubcategories, CatPurposes, CatTopics,
    CatRelActivityTopics, CatResults, CatAttendees,
    CatalogIndex, CatalogBundleCache,
    Activities, ActivityFields, ActivityLog,
    LocalAssignments,
    Evidences,
    PendingUploads,
    SyncQueue, SyncState,
    LocalEvents,
    AgendaAssignments,
  ],
)
class AppDb extends _$AppDb {
  AppDb() : super(_openConnection());

  @override
  int get schemaVersion => 12;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _createIndexes();
          await _seedInitialData();
          await _createColoniasTable();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await _createIndexes();
          }
          if (from < 3) {
            await m.createTable(catActivities);
            await m.createTable(catSubcategories);
            await m.createTable(catPurposes);
            await m.createTable(catTopics);
            await m.createTable(catRelActivityTopics);
            await m.createTable(catResults);
            await m.createTable(catAttendees);
            await _createCatalogEffectiveIndexes();
          }
          if (from < 4) {
            await m.createTable(pendingUploads);
            await _createPendingUploadsIndexes();
          }
          if (from < 5) {
            await m.createTable(localEvents);
            await _createEventsIndexes();
          }
          if (from < 6) {
            await m.createTable(agendaAssignments);
            await _createAgendaAssignmentsIndexes();
          }
          if (from < 7) {
            // Add catalog_version_id to activities (congela el catálogo offline por actividad)
            await m.addColumn(activities, activities.catalogVersionId);
          }
          if (from < 8) {
            // Nuevas tablas de catálogo offline versionado
            await m.createTable(catalogIndex);
            await m.createTable(catalogBundleCache);
            await _createCatalogOfflineIndexes();
          }
          if (from < 9) {
            // Catálogo local de colonias por municipio
            await _createColoniasTable();
          }
          if (from < 10) {
            // Local assignments table para flujo de asignación desde mobile
            await m.createTable(localAssignments);
            await _createLocalAssignmentsIndexes();
          }
          if (from < 11) {
            await m.addColumn(syncQueue, syncQueue.errorCode);
            await m.addColumn(syncQueue, syncQueue.retryable);
            await m.addColumn(syncQueue, syncQueue.suggestedAction);
          }
          if (from < 12) {
            await _ensureActivitiesAssignedToUserIdColumn();
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON;');
          await _ensureActivitiesAssignedToUserIdColumn();
        },
      );

  Future<void> _ensureActivitiesAssignedToUserIdColumn() async {
    final columnRows = await customSelect(
      "PRAGMA table_info('activities');",
    ).get();
    final hasAssignedToUserId = columnRows.any(
      (row) => row.data['name'] == 'assigned_to_user_id',
    );

    if (!hasAssignedToUserId) {
      await customStatement(
        'ALTER TABLE activities '
        'ADD COLUMN assigned_to_user_id TEXT NULL REFERENCES users(id);',
      );
    }

    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_activities_assigned_to_user '
      'ON activities(assigned_to_user_id);',
    );
  }

  // ----------------------------
  // Seeds iniciales
  // ----------------------------
  Future<void> _seedInitialData() async {
    await batch((b) {
      b.insertAll(roles, [
        RolesCompanion.insert(id: const Value(1), name: 'ADMIN'),
        RolesCompanion.insert(id: const Value(2), name: 'COORD'),
        RolesCompanion.insert(id: const Value(3), name: 'SUPERVISOR'),
        RolesCompanion.insert(id: const Value(4), name: 'OPERATIVO'),
        RolesCompanion.insert(id: const Value(5), name: 'LECTOR'),
      ], mode: InsertMode.insertOrIgnore);

      // SyncState id=1 (único)
      b.insert(
        syncState,
        SyncStateCompanion.insert(id: const Value(1)),
        mode: InsertMode.insertOrIgnore,
      );
    });
  }

  // ----------------------------
  // Índices (SQLite) - “bien hechos”
  // ----------------------------
  Future<void> _createIndexes() async {
    // -------- Activities --------
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_activities_project_createdAt '
      'ON activities(project_id, created_at);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_activities_status '
      'ON activities(status);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_activities_type '
      'ON activities(activity_type_id);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_activities_segment '
      'ON activities(segment_id);',
    );

    // -------- ActivityFields --------
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_activity_fields_activity '
      'ON activity_fields(activity_id);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_activity_fields_key '
      'ON activity_fields(field_key);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_activity_fields_activity_key '
      'ON activity_fields(activity_id, field_key);',
    );

    // -------- ActivityLog --------
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_activity_log_activity '
      'ON activity_log(activity_id);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_activity_log_at '
      'ON activity_log(at);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_activity_log_activity_at '
      'ON activity_log(activity_id, at);',
    );

    // -------- Evidences --------
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_evidences_activity '
      'ON evidences(activity_id);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_evidences_status '
      'ON evidences(status);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_evidences_activity_status '
      'ON evidences(activity_id, status);',
    );

    // -------- SyncQueue --------
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_sync_queue_status_priority '
      'ON sync_queue(status, priority);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_sync_queue_entity '
      'ON sync_queue(entity, entity_id);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_sync_queue_entity_status '
      'ON sync_queue(entity, status);',
    );

    // -------- ProjectSegments / Catalog --------
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_project_segments_project '
      'ON project_segments(project_id);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_catalog_fields_activityType '
      'ON catalog_fields(activity_type_id);',
    );

    await _createCatalogEffectiveIndexes();
    await _createPendingUploadsIndexes();
    await _createAgendaAssignmentsIndexes();
  }

  Future<void> _createCatalogEffectiveIndexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_cat_subcategories_activity '
      'ON cat_subcategories(activity_id);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_cat_purposes_activity_subcategory '
      'ON cat_purposes(activity_id, subcategory_id);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_cat_rel_activity_topics_activity '
      'ON cat_rel_activity_topics(activity_id);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_cat_rel_activity_topics_topic '
      'ON cat_rel_activity_topics(topic_id);',
    );
  }

  Future<void> _createPendingUploadsIndexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_pending_uploads_status_retry '
      'ON pending_uploads(status, next_retry_at);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_pending_uploads_activity '
      'ON pending_uploads(activity_id);',
    );
  }

  Future<void> _createEventsIndexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_local_events_project_occurred '
      'ON local_events(project_id, occurred_at);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_local_events_sync_status '
      'ON local_events(sync_status);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_local_events_severity '
      'ON local_events(severity);',
    );
  }

  Future<void> _createAgendaAssignmentsIndexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_agenda_assignments_project_time '
      'ON agenda_assignments(project_id, start_at, end_at);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_agenda_assignments_resource '
      'ON agenda_assignments(resource_id);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_agenda_assignments_sync_status '
      'ON agenda_assignments(sync_status);',
    );
  }

  Future<void> _createLocalAssignmentsIndexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_local_assignments_project_assignee '
      'ON local_assignments(project_id, assignee_user_id);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_local_assignments_sync_status '
      'ON local_assignments(sync_status);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_local_assignments_created_at '
      'ON local_assignments(created_at);',
    );
  }

  Future<void> _createColoniasTable() async {
    await customStatement('''
      CREATE TABLE IF NOT EXISTS local_colonias (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        municipio TEXT NOT NULL,
        estado TEXT,
        colonia TEXT NOT NULL,
        usage_count INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        UNIQUE(municipio, colonia)
      )
    ''');
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_colonias_municipio '
      'ON local_colonias(municipio);',
    );
  }

  Future<void> _createCatalogOfflineIndexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_catalog_bundles_project '
      'ON catalog_bundle_cache(project_id);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_activities_catalog_version '
      'ON activities(catalog_version_id);',
    );
  }
}
