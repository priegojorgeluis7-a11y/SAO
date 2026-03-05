import 'package:drift/drift.dart';
import '../app_db.dart';
import '../tables.dart';

part 'catalog_dao.g.dart';

@DriftAccessor(
  tables: [
    CatActivities,
    CatSubcategories,
    CatPurposes,
    CatTopics,
    CatRelActivityTopics,
    CatResults,
    CatAttendees,
  ],
)
class CatalogDao extends DatabaseAccessor<AppDb> with _$CatalogDaoMixin {
  CatalogDao(super.db);

  Future<List<CatActivity>> getAllActivities() {
    return select(catActivities).get();
  }

  Future<List<CatActivity>> getEnabledActivities() {
    return (select(catActivities)
          ..where((t) => t.isEnabled.equals(true))
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .get();
  }

  Future<List<CatSubcategory>> subcategoriesByActivity(String activityId) {
    return (select(catSubcategories)
          ..where((t) => t.activityId.equals(activityId) & t.isEnabled.equals(true))
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .get();
  }

  Future<List<CatPurpose>> purposesByActivityAndSub(String activityId, String? subcategoryId) {
    final query = select(catPurposes)
      ..where((t) => t.activityId.equals(activityId) & t.isEnabled.equals(true));

    if (subcategoryId != null) {
      query.where((t) => t.subcategoryId.equals(subcategoryId) | t.subcategoryId.isNull());
    } else {
      query.where((t) => t.subcategoryId.isNull());
    }

    query.orderBy([(t) => OrderingTerm.asc(t.sortOrder)]);
    return query.get();
  }

  Future<List<CatTopic>> topicsByActivity(String activityId) async {
    final relRows = await (select(catRelActivityTopics)
          ..where((t) => t.activityId.equals(activityId)))
        .get();

    final topicIds = relRows.map((row) => row.topicId).toList();
    if (topicIds.isEmpty) {
      return [];
    }

    return (select(catTopics)
          ..where((t) => t.id.isIn(topicIds) & t.isEnabled.equals(true))
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .get();
  }

  Future<List<CatResult>> getResults() {
    return (select(catResults)
          ..where((t) => t.isEnabled.equals(true))
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .get();
  }
}
