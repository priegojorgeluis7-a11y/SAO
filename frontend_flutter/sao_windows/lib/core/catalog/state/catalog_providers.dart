import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/di/service_locator.dart';
import '../../../data/local/app_db.dart';
import '../../../data/local/dao/catalog_dao.dart';
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
