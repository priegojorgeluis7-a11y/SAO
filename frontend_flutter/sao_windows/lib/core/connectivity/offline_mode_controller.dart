import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../di/service_locator.dart';
import '../storage/kv_store.dart';

const offlineModeKey = 'offline_mode';

final offlineModeProvider =
    StateNotifierProvider<OfflineModeController, bool>((ref) {
  final controller = OfflineModeController(kv: getIt<KvStore>());
  unawaited(controller.load());
  return controller;
});

class OfflineModeController extends StateNotifier<bool> {
  OfflineModeController({required KvStore kv})
      : _kv = kv,
        super(true);

  final KvStore _kv;
  bool _hasLoaded = false;

  Future<void> load() async {
    if (_hasLoaded) return;
    final storedValue = await _kv.getString(offlineModeKey);
    if (storedValue != null) {
      state = storedValue.toLowerCase() == 'true';
    }
    _hasLoaded = true;
  }

  Future<void> setOffline(bool value) async {
    state = value;
    _hasLoaded = true;
    await _kv.setString(offlineModeKey, value.toString());
  }
}