// lib/features/sync/services/auto_sync_service.dart
import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import '../../../core/catalog/sync/catalog_sync_service.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/connectivity_service.dart';
import '../../../core/storage/kv_store.dart';
import '../../../core/utils/logger.dart';
import 'sync_service.dart';

/// Triggers [SyncService.pushPendingChanges] automatically:
///   1. When network connectivity is restored (foreground).
///   2. Every [interval] while the app is in the foreground and connected.
///
/// Call [start] once at app launch and [dispose] on app termination.
class AutoSyncService {
  static const _defaultInterval = Duration(minutes: 15);

  final SyncService _syncService;
  final ConnectivityService _connectivity;
  final CatalogSyncService _catalogSyncService;
  final ApiClient _apiClient;
  final KvStore _kv;
  final Duration _interval;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  Timer? _periodicTimer;
  bool _isSyncing = false;
  bool _isCatalogDailySyncRunning = false;
  bool _wasOnWifi = false;

  static const String _catalogDailyWifiSyncDateKey = 'catalog_daily_wifi_sync_date';

  AutoSyncService({
    required SyncService syncService,
    required ConnectivityService connectivity,
    required CatalogSyncService catalogSyncService,
    required ApiClient apiClient,
    required KvStore kv,
    Duration interval = _defaultInterval,
  })  : _syncService = syncService,
        _connectivity = connectivity,
        _catalogSyncService = catalogSyncService,
        _apiClient = apiClient,
        _kv = kv,
        _interval = interval;

  /// Start auto-sync listeners.
  void start() {
    // 1. Sync when connectivity is restored
    _connectivitySub = _connectivity.onConnectivityChanged.listen(_onConnectivityChanged);

    // 2. Periodic sync while app is running
    _periodicTimer = Timer.periodic(_interval, (_) => _triggerSync('periodic'));

    // Trigger daily catalog refresh if app starts already on Wi-Fi.
    _primeWifiDailyCatalogSync();

    appLogger.d('🔄 AutoSyncService started (interval=${_interval.inMinutes}m)');
  }

  /// Stop all listeners and timers.
  void dispose() {
    _connectivitySub?.cancel();
    _periodicTimer?.cancel();
    appLogger.d('🔄 AutoSyncService disposed');
  }

  Future<void> _onConnectivityChanged(List<ConnectivityResult> results) async {
    final hasNetwork = results.contains(ConnectivityResult.mobile) ||
        results.contains(ConnectivityResult.wifi) ||
        results.contains(ConnectivityResult.ethernet);
    final isOnWifi = results.contains(ConnectivityResult.wifi);

    if (isOnWifi && !_wasOnWifi) {
      await _triggerDailyCatalogSyncOnFirstWifi();
    }
    _wasOnWifi = isOnWifi;

    if (hasNetwork) {
      appLogger.i('🌐 Network restored — triggering sync');
      await _triggerSync('connectivity_restored');
    }
  }

  Future<void> _primeWifiDailyCatalogSync() async {
    try {
      final current = await Connectivity().checkConnectivity();
      final isOnWifi = current.contains(ConnectivityResult.wifi);
      _wasOnWifi = isOnWifi;
      if (isOnWifi) {
        await _triggerDailyCatalogSyncOnFirstWifi();
      }
    } catch (_) {
      // Keep startup resilient even if connectivity probing fails.
    }
  }

  Future<void> _triggerDailyCatalogSyncOnFirstWifi() async {
    if (_isCatalogDailySyncRunning) return;
    _isCatalogDailySyncRunning = true;

    try {
      final today = DateTime.now().toIso8601String().split('T').first;
      final lastRun = await _kv.getString(_catalogDailyWifiSyncDateKey);
      if (lastRun == today) {
        return;
      }

      final projectIds = await _resolveScopedProjectIdsForCatalogDailySync();
      if (projectIds.isEmpty) {
        await _kv.setString(_catalogDailyWifiSyncDateKey, today);
        return;
      }

      appLogger.i('📚 First Wi-Fi connection of the day — syncing catalog for ${projectIds.length} project(s)');
      await _catalogSyncService.syncAllIfNeeded(projectIds);
      await _kv.setString(_catalogDailyWifiSyncDateKey, today);
    } catch (e) {
      if (kDebugMode) debugPrint('[AutoSyncService] Daily Wi-Fi catalog sync error: $e');
    } finally {
      _isCatalogDailySyncRunning = false;
    }
  }

  Future<List<String>> _resolveScopedProjectIdsForCatalogDailySync() async {
    try {
      final response = await _apiClient.get<dynamic>('/me/projects');
      final data = response.data;
      final rows = data is List
          ? data
          : (data is Map && data['projects'] is List ? data['projects'] as List<dynamic> : const <dynamic>[]);

      final ids = rows
          .map((item) => Map<String, dynamic>.from(item as Map))
          .map((row) {
            final raw = row['project_id'] ?? row['code'] ?? row['id'] ?? '';
            return raw.toString().trim().toUpperCase();
          })
          .where((id) => id.isNotEmpty && id != 'TODOS' && id != 'ALL')
          .toSet()
          .toList()
        ..sort();

      if (ids.isNotEmpty) {
        return ids;
      }
    } catch (_) {
      // Fallback to selected project when endpoint is unavailable.
    }

    final selected = (await _kv.getString('selected_project') ?? '').trim().toUpperCase();
    if (selected.isNotEmpty && selected != 'TODOS' && selected != 'ALL') {
      return [selected];
    }
    return const <String>[];
  }

  Future<void> _triggerSync(String reason) async {
    if (_isSyncing) return; // Prevent overlap
    _isSyncing = true;

    try {
      final hasNet = await _connectivity.hasConnection();
      if (!hasNet) return;

      appLogger.d('⚡ AutoSync trigger: $reason');
      await _syncService.pushPendingChanges();
    } catch (e) {
      if (kDebugMode) debugPrint('[AutoSyncService] Error: $e');
    } finally {
      _isSyncing = false;
    }
  }

  /// Best-effort push flush, safe to call on app background/pause.
  /// Does nothing if already syncing or no network is available.
  Future<void> triggerPushOnce(String reason) => _triggerSync(reason);
}
