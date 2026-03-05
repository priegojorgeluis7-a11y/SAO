import '../../../data/local/dao/catalog_dao.dart';

class EffectiveActivityRecord {
  final String id;
  final String name;
  final bool isEnabled;
  final int sortOrder;
  final String? versionId;
  final String? colorHex;
  final String? severity;

  const EffectiveActivityRecord({
    required this.id,
    required this.name,
    required this.isEnabled,
    required this.sortOrder,
    this.versionId,
    this.colorHex,
    this.severity,
  });
}

class EffectiveActivityOption {
  final String id;
  final String name;
  final int sortOrder;
  final String? versionId;
  final String? colorHex;
  final String? severity;

  const EffectiveActivityOption({
    required this.id,
    required this.name,
    required this.sortOrder,
    this.versionId,
    this.colorHex,
    this.severity,
  });
}

abstract class EffectiveActivitiesLocalStore {
  Future<List<EffectiveActivityRecord>> getAllActivities();
}

class DriftEffectiveActivitiesLocalStore implements EffectiveActivitiesLocalStore {
  DriftEffectiveActivitiesLocalStore(this._catalogDao);

  final CatalogDao _catalogDao;

  @override
  Future<List<EffectiveActivityRecord>> getAllActivities() async {
    final rows = await _catalogDao.getAllActivities();
    return rows
        .map(
          (row) => EffectiveActivityRecord(
            id: row.id,
            name: row.name,
            isEnabled: row.isEnabled,
            sortOrder: row.sortOrder,
            versionId: row.versionId,
          ),
        )
        .toList();
  }
}

class EffectiveActivitiesRepository {
  EffectiveActivitiesRepository({required EffectiveActivitiesLocalStore localStore})
      : _localStore = localStore;

  final EffectiveActivitiesLocalStore _localStore;

  Future<List<EffectiveActivityOption>> listEnabledOrdered() async {
    final rows = await _localStore.getAllActivities();
    final enabled = rows
        .where((row) => row.isEnabled)
        .map(
          (row) => EffectiveActivityOption(
            id: row.id,
            name: row.name,
            sortOrder: row.sortOrder,
            versionId: row.versionId,
            colorHex: row.colorHex,
            severity: row.severity,
          ),
        )
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    return enabled;
  }
}
