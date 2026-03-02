// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'catalog_dao.dart';

// ignore_for_file: type=lint
mixin _$CatalogDaoMixin on DatabaseAccessor<AppDb> {
  $CatActivitiesTable get catActivities => attachedDatabase.catActivities;
  $CatSubcategoriesTable get catSubcategories =>
      attachedDatabase.catSubcategories;
  $CatPurposesTable get catPurposes => attachedDatabase.catPurposes;
  $CatTopicsTable get catTopics => attachedDatabase.catTopics;
  $CatRelActivityTopicsTable get catRelActivityTopics =>
      attachedDatabase.catRelActivityTopics;
  $CatResultsTable get catResults => attachedDatabase.catResults;
  $CatAttendeesTable get catAttendees => attachedDatabase.catAttendees;
  CatalogDaoManager get managers => CatalogDaoManager(this);
}

class CatalogDaoManager {
  final _$CatalogDaoMixin _db;
  CatalogDaoManager(this._db);
  $$CatActivitiesTableTableManager get catActivities =>
      $$CatActivitiesTableTableManager(_db.attachedDatabase, _db.catActivities);
  $$CatSubcategoriesTableTableManager get catSubcategories =>
      $$CatSubcategoriesTableTableManager(
        _db.attachedDatabase,
        _db.catSubcategories,
      );
  $$CatPurposesTableTableManager get catPurposes =>
      $$CatPurposesTableTableManager(_db.attachedDatabase, _db.catPurposes);
  $$CatTopicsTableTableManager get catTopics =>
      $$CatTopicsTableTableManager(_db.attachedDatabase, _db.catTopics);
  $$CatRelActivityTopicsTableTableManager get catRelActivityTopics =>
      $$CatRelActivityTopicsTableTableManager(
        _db.attachedDatabase,
        _db.catRelActivityTopics,
      );
  $$CatResultsTableTableManager get catResults =>
      $$CatResultsTableTableManager(_db.attachedDatabase, _db.catResults);
  $$CatAttendeesTableTableManager get catAttendees =>
      $$CatAttendeesTableTableManager(_db.attachedDatabase, _db.catAttendees);
}
