import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/di/service_locator.dart';
import '../../../data/local/app_db.dart';
import '../../../data/local/dao/catalog_dao.dart';
import '../../../features/catalog/data/catalog_offline_repository.dart';
import '../api/catalog_api.dart';
import '../sync/catalog_sync_service.dart';
import '../../storage/kv_store.dart';

final appDbProvider = Provider<AppDb>((ref) {
  return getIt<AppDb>();
});

final catalogDaoProvider = Provider<CatalogDao>((ref) {
  return getIt<CatalogDao>();
});

final catalogApiProvider = Provider<CatalogApi>((ref) {
  return getIt<CatalogApi>();
});

final catalogSyncServiceProvider = Provider<CatalogSyncService>((ref) {
  return getIt<CatalogSyncService>();
});

final kvStoreProvider = Provider<KvStore>((ref) {
  return getIt<KvStore>();
});

final catalogOfflineRepositoryProvider = Provider<CatalogOfflineRepository>((ref) {
  return CatalogOfflineRepository(db: ref.watch(appDbProvider));
});

/// Versión activa en catálogo local para un projectId dado.
/// Devuelve null si no hay bundle descargado.
final catalogActiveVersionProvider =
    FutureProvider.autoDispose.family<String?, String>((ref, projectId) async {
  final repo = ref.watch(catalogOfflineRepositoryProvider);
  return repo.getActiveVersionId(projectId);
});

/// ProjectId seleccionado actualmente (persistido en KvStore).
final selectedProjectIdProvider = FutureProvider.autoDispose<String?>((ref) {
  final kv = ref.watch(kvStoreProvider);
  return kv.getString('selected_project');
});
