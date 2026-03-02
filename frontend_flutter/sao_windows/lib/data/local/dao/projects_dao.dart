// lib/data/local/dao/projects_dao.dart
import 'package:drift/drift.dart';

import '../app_db.dart';
import '../tables.dart';

part 'projects_dao.g.dart';

@DriftAccessor(tables: [Projects])
class ProjectsDao extends DatabaseAccessor<AppDb> with _$ProjectsDaoMixin {
  ProjectsDao(super.db);

  Stream<List<Project>> watchActiveProjects() {
    return (select(projects)
          ..where((t) => t.isActive.equals(true))
          ..orderBy([(t) => OrderingTerm.asc(t.code)]))
        .watch();
  }

  Future<int> upsertProject(ProjectsCompanion row) {
    return into(projects).insertOnConflictUpdate(row);
  }

  Future<int> deactivateProject(String id) {
    return (update(projects)..where((t) => t.id.equals(id)))
        .write(const ProjectsCompanion(isActive: Value(false)));
  }
}
