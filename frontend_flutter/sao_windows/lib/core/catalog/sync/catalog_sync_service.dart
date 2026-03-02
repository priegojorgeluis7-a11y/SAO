import 'package:drift/drift.dart';
import '../../../data/local/app_db.dart';
import '../../../data/local/dao/catalog_dao.dart';
import '../../storage/kv_store.dart';
import '../api/catalog_api.dart';

class CatalogSyncService {
  CatalogSyncService({
    required this.db,
    required this.dao,
    required this.api,
    required this.kv,
  });

  final AppDb db;
  final CatalogDao dao;
  final CatalogApi api;
  final KvStore kv;

  Future<void> ensureCatalogUpToDate(String projectId) async {
    final key = 'catalog_version:$projectId';
    final localVersion = await kv.getString(key);
    final currentVersion = await api.getCurrentVersion(projectId: projectId);

    if (localVersion == null) {
      final effective = await api.getEffective(projectId: projectId, versionId: currentVersion);
      await _applyEffectiveSnapshot(currentVersion, effective);
      await kv.setString(key, currentVersion);
      return;
    }

    if (localVersion == currentVersion) {
      return;
    }

    try {
      final diff = await api.getDiff(
        projectId: projectId,
        fromVersionId: localVersion,
        toVersionId: currentVersion,
      );
      await _applyDiff(currentVersion, diff);
      await kv.setString(key, currentVersion);
    } catch (_) {
      final effective = await api.getEffective(projectId: projectId, versionId: currentVersion);
      await _applyEffectiveSnapshot(currentVersion, effective);
      await kv.setString(key, currentVersion);
    }
  }

  Future<void> _applyEffectiveSnapshot(String versionId, Map<String, dynamic> data) async {
    await db.transaction(() async {
      await db.delete(db.catRelActivityTopics).go();
      await db.delete(db.catPurposes).go();
      await db.delete(db.catSubcategories).go();
      await db.delete(db.catTopics).go();
      await db.delete(db.catResults).go();
      await db.delete(db.catAttendees).go();
      await db.delete(db.catActivities).go();

      await _upsertAll(versionId, data);
    });
  }

  Future<void> _applyDiff(String versionId, Map<String, dynamic> diff) async {
    final changes = Map<String, dynamic>.from(diff['changes'] as Map);

    await db.transaction(() async {
      await _applyDeletes(changes);
      await _applyUpserts(versionId, changes);
    });
  }

  Future<void> _applyDeletes(Map<String, dynamic> changes) async {
    final relDeletes = _stringList(changes['rel_activity_topics']?['deletes']);
    for (final key in relDeletes) {
      final parts = key.split('|');
      if (parts.length != 2) continue;
      await (db.delete(db.catRelActivityTopics)
            ..where((t) => t.activityId.equals(parts[0]) & t.topicId.equals(parts[1])))
          .go();
    }

    await _deletePurposes(_stringList(changes['purposes']?['deletes']));
    await _deleteSubcategories(_stringList(changes['subcategories']?['deletes']));
    await _deleteTopics(_stringList(changes['topics']?['deletes']));
    await _deleteResults(_stringList(changes['results']?['deletes']));
    await _deleteAttendees(_stringList(changes['attendees']?['deletes']));
    await _deleteActivities(_stringList(changes['activities']?['deletes']));
  }

  Future<void> _applyUpserts(String versionId, Map<String, dynamic> changes) async {
    final now = DateTime.now();

    final activities = _mapActivities(changes['activities']?['upserts'], versionId, now);
    final topics = _mapTopics(changes['topics']?['upserts'], versionId, now);
    final results = _mapResults(changes['results']?['upserts'], versionId, now);
    final attendees = _mapAttendees(changes['attendees']?['upserts'], versionId, now);
    final subcategories = _mapSubcategories(changes['subcategories']?['upserts'], versionId, now);
    final purposes = _mapPurposes(changes['purposes']?['upserts'], versionId, now);
    final rels = _mapRelActivityTopics(changes['rel_activity_topics']?['upserts'], versionId, now);

    await db.batch((batch) {
      if (activities.isNotEmpty) batch.insertAllOnConflictUpdate(db.catActivities, activities);
      if (topics.isNotEmpty) batch.insertAllOnConflictUpdate(db.catTopics, topics);
      if (results.isNotEmpty) batch.insertAllOnConflictUpdate(db.catResults, results);
      if (attendees.isNotEmpty) batch.insertAllOnConflictUpdate(db.catAttendees, attendees);
      if (subcategories.isNotEmpty) batch.insertAllOnConflictUpdate(db.catSubcategories, subcategories);
      if (purposes.isNotEmpty) batch.insertAllOnConflictUpdate(db.catPurposes, purposes);
      if (rels.isNotEmpty) batch.insertAllOnConflictUpdate(db.catRelActivityTopics, rels);
    });
  }

  Future<void> _upsertAll(String versionId, Map<String, dynamic> effective) async {
    final now = DateTime.now();

    final activities = _mapActivities(effective['activities'], versionId, now);
    final subcategories = _mapSubcategories(effective['subcategories'], versionId, now);
    final purposes = _mapPurposes(effective['purposes'], versionId, now);
    final topics = _mapTopics(effective['topics'], versionId, now);
    final rels = _mapRelActivityTopics(effective['rel_activity_topics'], versionId, now);
    final results = _mapResults(effective['results'], versionId, now);
    final attendees = _mapAttendees(effective['attendees'], versionId, now);

    await db.batch((batch) {
      batch.insertAllOnConflictUpdate(db.catActivities, activities);
      batch.insertAllOnConflictUpdate(db.catSubcategories, subcategories);
      batch.insertAllOnConflictUpdate(db.catPurposes, purposes);
      batch.insertAllOnConflictUpdate(db.catTopics, topics);
      batch.insertAllOnConflictUpdate(db.catRelActivityTopics, rels);
      batch.insertAllOnConflictUpdate(db.catResults, results);
      batch.insertAllOnConflictUpdate(db.catAttendees, attendees);
    });
  }

  Future<void> _deleteActivities(List<String> ids) async {
    if (ids.isEmpty) return;
    await (db.delete(db.catActivities)..where((t) => t.id.isIn(ids))).go();
  }

  Future<void> _deleteSubcategories(List<String> ids) async {
    if (ids.isEmpty) return;
    await (db.delete(db.catSubcategories)..where((t) => t.id.isIn(ids))).go();
  }

  Future<void> _deletePurposes(List<String> ids) async {
    if (ids.isEmpty) return;
    await (db.delete(db.catPurposes)..where((t) => t.id.isIn(ids))).go();
  }

  Future<void> _deleteTopics(List<String> ids) async {
    if (ids.isEmpty) return;
    await (db.delete(db.catTopics)..where((t) => t.id.isIn(ids))).go();
  }

  Future<void> _deleteResults(List<String> ids) async {
    if (ids.isEmpty) return;
    await (db.delete(db.catResults)..where((t) => t.id.isIn(ids))).go();
  }

  Future<void> _deleteAttendees(List<String> ids) async {
    if (ids.isEmpty) return;
    await (db.delete(db.catAttendees)..where((t) => t.id.isIn(ids))).go();
  }

  List<String> _stringList(dynamic value) {
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    return [];
  }

  List<CatActivitiesCompanion> _mapActivities(dynamic items, String versionId, DateTime now) {
    final list = _mapList(items);
    return list
        .map((item) => CatActivitiesCompanion.insert(
              id: item['id'] as String,
              name: item['name_effective'] as String,
              description: Value(item['description'] as String?),
              isEnabled: Value(item['is_enabled_effective'] as bool? ?? true),
              sortOrder: Value(item['sort_order_effective'] as int? ?? 0),
              versionId: versionId,
              updatedAt: now,
            ))
        .toList();
  }

  List<CatSubcategoriesCompanion> _mapSubcategories(dynamic items, String versionId, DateTime now) {
    final list = _mapList(items);
    return list
        .map((item) => CatSubcategoriesCompanion.insert(
              id: item['id'] as String,
              activityId: item['activity_id'] as String,
              name: item['name_effective'] as String,
              description: Value(item['description'] as String?),
              isEnabled: Value(item['is_enabled_effective'] as bool? ?? true),
              sortOrder: Value(item['sort_order_effective'] as int? ?? 0),
              versionId: versionId,
              updatedAt: now,
            ))
        .toList();
  }

  List<CatPurposesCompanion> _mapPurposes(dynamic items, String versionId, DateTime now) {
    final list = _mapList(items);
    return list
        .map((item) => CatPurposesCompanion.insert(
              id: item['id'] as String,
              activityId: item['activity_id'] as String,
              subcategoryId: Value(item['subcategory_id'] as String?),
              name: item['name_effective'] as String,
              isEnabled: Value(item['is_enabled_effective'] as bool? ?? true),
              sortOrder: Value(item['sort_order_effective'] as int? ?? 0),
              versionId: versionId,
              updatedAt: now,
            ))
        .toList();
  }

  List<CatTopicsCompanion> _mapTopics(dynamic items, String versionId, DateTime now) {
    final list = _mapList(items);
    return list
        .map((item) => CatTopicsCompanion.insert(
              id: item['id'] as String,
              type: Value(item['type'] as String?),
              description: Value(item['description'] as String?),
              name: item['name_effective'] as String,
              isEnabled: Value(item['is_enabled_effective'] as bool? ?? true),
              sortOrder: Value(item['sort_order_effective'] as int? ?? 0),
              versionId: versionId,
              updatedAt: now,
            ))
        .toList();
  }

  List<CatRelActivityTopicsCompanion> _mapRelActivityTopics(dynamic items, String versionId, DateTime now) {
    final list = _mapList(items);
    return list
        .map((item) => CatRelActivityTopicsCompanion.insert(
              activityId: item['activity_id'] as String,
              topicId: item['topic_id'] as String,
              isEnabled: Value(item['is_enabled_effective'] as bool? ?? true),
              versionId: versionId,
              updatedAt: now,
            ))
        .toList();
  }

  List<CatResultsCompanion> _mapResults(dynamic items, String versionId, DateTime now) {
    final list = _mapList(items);
    return list
        .map((item) => CatResultsCompanion.insert(
              id: item['id'] as String,
              name: item['name_effective'] as String,
              category: Value(item['category'] as String?),
              severity: Value(item['severity_effective'] as String?),
              isEnabled: Value(item['is_enabled_effective'] as bool? ?? true),
              sortOrder: Value(item['sort_order_effective'] as int? ?? 0),
              versionId: versionId,
              updatedAt: now,
            ))
        .toList();
  }

  List<CatAttendeesCompanion> _mapAttendees(dynamic items, String versionId, DateTime now) {
    final list = _mapList(items);
    return list
        .map((item) => CatAttendeesCompanion.insert(
              id: item['id'] as String,
              type: item['type'] as String,
              description: Value(item['description'] as String?),
              name: item['name_effective'] as String,
              isEnabled: Value(item['is_enabled_effective'] as bool? ?? true),
              sortOrder: Value(item['sort_order_effective'] as int? ?? 0),
              versionId: versionId,
              updatedAt: now,
            ))
        .toList();
  }

  List<Map<String, dynamic>> _mapList(dynamic value) {
    if (value is List) {
      return value.cast<Map<String, dynamic>>();
    }
    return [];
  }
}
