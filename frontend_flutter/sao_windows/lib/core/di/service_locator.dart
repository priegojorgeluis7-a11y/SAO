// lib/core/di/service_locator.dart
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../data/local/app_db.dart';
import '../../data/local/dao/catalog_dao.dart';
import '../../features/catalog/catalog_repository.dart';
import '../../features/evidence/pending_evidence_store.dart';
import '../../features/evidence/data/evidence_upload_repository.dart';
import '../../features/evidence/data/evidence_upload_retry_worker.dart';
import '../../features/auth/data/auth_service.dart';
import '../../features/sync/data/sync_api_repository.dart';
import '../../features/sync/services/sync_service.dart';
import '../../features/sync/services/auto_sync_service.dart';
import '../../features/events/data/events_api_repository.dart';
import '../../features/agenda/data/territory_api_repository.dart';
import '../../features/events/data/events_local_repository.dart';
import '../catalog/api/catalog_api.dart';
import '../catalog/sync/catalog_sync_service.dart';
import '../services/connectivity_service.dart';
import '../services/biometric_service.dart';
import '../storage/kv_store.dart';
import '../auth/token_storage.dart';
import '../network/api_client.dart';
import '../network/api_config.dart';
import '../notifications/push_notifications_service.dart';

final getIt = GetIt.instance;

/// Configura todas las dependencias de la app
Future<void> setupServiceLocator({bool prewarmCatalog = true}) async {
  // SharedPreferences (singleton)
  final prefs = await SharedPreferences.getInstance();
  getIt.registerLazySingleton<SharedPreferences>(() => prefs);

  // Secure Storage (singleton)
  const secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      resetOnError: true,
    ),
  );
  getIt.registerLazySingleton<FlutterSecureStorage>(() => secureStorage);

  // API Configuration (singleton)
  final apiConfig = ApiConfig();
  const defineBackendUrl = String.fromEnvironment('SAO_BACKEND_URL', defaultValue: '');
  const defineBaseUrl = String.fromEnvironment('SAO_API_BASE', defaultValue: '');
  final storedBaseUrl = prefs.getString('api_base_url_override');
  if (defineBackendUrl.trim().isNotEmpty || defineBaseUrl.trim().isNotEmpty) {
    apiConfig.setBaseUrl(ApiConfig.defaultBaseUrl);
  } else if (storedBaseUrl != null && storedBaseUrl.trim().isNotEmpty) {
    apiConfig.setBaseUrl(storedBaseUrl.trim());
  }
  getIt.registerLazySingleton<ApiConfig>(() => apiConfig);

  // Token Storage (singleton)
  getIt.registerLazySingleton<TokenStorage>(
    () => TokenStorage(getIt<FlutterSecureStorage>()),
  );

  // API Client (singleton) - depends on TokenStorage
  getIt.registerLazySingleton<ApiClient>(
    () => ApiClient(
      tokenStorage: getIt<TokenStorage>(),
      config: getIt<ApiConfig>(),
    ),
  );

  // Push notifications (FCM)
  getIt.registerLazySingleton<PushNotificationsService>(
    () => PushNotificationsService(apiClient: getIt<ApiClient>()),
  );

  // Connectivity Service (singleton)
  getIt.registerLazySingleton<ConnectivityService>(ConnectivityService.new);

  // Biometric Service (singleton)
  getIt.registerLazySingleton<BiometricService>(BiometricService.new);

  // Auth Service (singleton)
  getIt.registerLazySingleton<AuthService>(
    () => AuthService(
      getIt<FlutterSecureStorage>(),
      getIt<SharedPreferences>(),
      getIt<ConnectivityService>(),
      getIt<ApiConfig>(),
    ),
  );

  // Database (singleton - única instancia)
  getIt.registerLazySingleton<AppDb>(AppDb.new);

  // KV Store (singleton)
  getIt.registerLazySingleton<KvStore>(
    () => SharedPrefsKvStore(getIt<SharedPreferences>()),
  );

  // Catalog API (singleton)
  // Fix: usa ApiClient en vez de AuthService.
  // AuthService leía el token de 'access_token' pero el login moderno
  // lo guarda en 'auth_token_data' (TokenStorage). Resultado: token null → 401.
  // ApiClient usa la misma TokenStorage que AuthRepository → token correcto.
  getIt.registerLazySingleton<CatalogApi>(
    () => CatalogApi(getIt<ApiClient>()),
  );

  // Catalog DAO (singleton)
  getIt.registerLazySingleton<CatalogDao>(() => CatalogDao(getIt<AppDb>()));

  // Catalog Sync (singleton)
  getIt.registerLazySingleton<CatalogSyncService>(
    () => CatalogSyncService(
      db: getIt<AppDb>(),
      dao: getIt<CatalogDao>(),
      api: getIt<CatalogApi>(),
      kv: getIt<KvStore>(),
    ),
  );

  // Repositories (singleton)
  final catalogRepo = CatalogRepository();
  if (prewarmCatalog) {
    await catalogRepo.init(); // Pre-inicializar catálogos
  }
  getIt.registerLazySingleton<CatalogRepository>(() => catalogRepo);

  // Stores (factory - nueva instancia cada vez)
  getIt.registerFactory<PendingEvidenceStore>(PendingEvidenceStore.new);

  // Evidence upload (signed URL + offline retries)
  getIt.registerLazySingleton<EvidenceUploadRepository>(
    () => EvidenceUploadRepository(
      apiClient: getIt<ApiClient>(),
      db: getIt<AppDb>(),
    ),
  );
  getIt.registerLazySingleton<EvidenceUploadRetryWorker>(
    () => EvidenceUploadRetryWorker(
      db: getIt<AppDb>(),
      repository: getIt<EvidenceUploadRepository>(),
    ),
  );

  // Sync push/pull
  getIt.registerLazySingleton<SyncApiRepository>(
    () => SyncApiRepository(apiClient: getIt<ApiClient>()),
  );
  getIt.registerLazySingleton<SyncService>(
    () => SyncService(
      apiRepository: getIt<SyncApiRepository>(),
      db: getIt<AppDb>(),
      eventsApiRepository: getIt<EventsApiRepository>(),
      evidenceUploadRetryWorker: getIt<EvidenceUploadRetryWorker>(),
    ),
  );
  getIt.registerLazySingleton<AutoSyncService>(
    () => AutoSyncService(
      syncService: getIt<SyncService>(),
      connectivity: getIt<ConnectivityService>(),
    ),
  );

  // Events module
  getIt.registerLazySingleton<EventsApiRepository>(
    () => EventsApiRepository(apiClient: getIt<ApiClient>()),
  );
  getIt.registerLazySingleton<EventsLocalRepository>(
    () => EventsLocalRepository(db: getIt<AppDb>()),
  );

  // Territory module
  getIt.registerLazySingleton<TerritoryApiRepository>(
    () => TerritoryApiRepository(apiClient: getIt<ApiClient>()),
  );
}

/// Limpia todas las dependencias (útil para testing)
Future<void> resetServiceLocator() async {
  await getIt.reset();
}
