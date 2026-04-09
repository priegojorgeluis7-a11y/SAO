import 'package:flutter_test/flutter_test.dart';
import 'package:sao_windows/core/connectivity/offline_mode_controller.dart';
import 'package:sao_windows/core/storage/kv_store.dart';

class _FakeKvStore implements KvStore {
  _FakeKvStore([this.value]);

  String? value;

  @override
  Future<String?> getString(String key) async => value;

  @override
  Future<void> setString(String key, String value) async {
    this.value = value;
  }

  @override
  Future<void> remove(String key) async {
    value = null;
  }
}

void main() {
  group('OfflineModeController', () {
    test('defaults to online when no setting was stored yet', () async {
      final controller = OfflineModeController(kv: _FakeKvStore());

      await controller.load();

      expect(controller.state, isFalse);
    });

    test('restores stored offline preference when present', () async {
      final controller = OfflineModeController(kv: _FakeKvStore('true'));

      await controller.load();

      expect(controller.state, isTrue);
    });
  });
}
