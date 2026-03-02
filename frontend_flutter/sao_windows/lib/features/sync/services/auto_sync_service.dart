// lib/features/sync/services/auto_sync_service.dart
import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import '../../../core/services/connectivity_service.dart';
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
  final Duration _interval;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  Timer? _periodicTimer;
  bool _isSyncing = false;

  AutoSyncService({
    required SyncService syncService,
    required ConnectivityService connectivity,
    Duration interval = _defaultInterval,
  })  : _syncService = syncService,
        _connectivity = connectivity,
        _interval = interval;

  /// Start auto-sync listeners.
  void start() {
    // 1. Sync when connectivity is restored
    _connectivitySub = _connectivity.onConnectivityChanged.listen(_onConnectivityChanged);

    // 2. Periodic sync while app is running
    _periodicTimer = Timer.periodic(_interval, (_) => _triggerSync('periodic'));

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

    if (hasNetwork) {
      appLogger.i('🌐 Network restored — triggering sync');
      await _triggerSync('connectivity_restored');
    }
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
}
