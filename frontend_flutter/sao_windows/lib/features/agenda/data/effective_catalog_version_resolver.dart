import '../../../core/di/service_locator.dart';
import '../../../core/storage/kv_store.dart';

class EffectiveCatalogVersionResolver {
  const EffectiveCatalogVersionResolver();

  Future<String?> resolve({
    required String? projectId,
    String? fallbackVersionId,
  }) async {
    final normalizedProjectId = projectId?.trim();
    if (normalizedProjectId == null || normalizedProjectId.isEmpty) {
      return fallbackVersionId;
    }

    final key = 'catalog_version:$normalizedProjectId';
    final kvStore = getIt<KvStore>();
    final fromKv = await kvStore.getString(key);
    return fromKv ?? fallbackVersionId;
  }
}
