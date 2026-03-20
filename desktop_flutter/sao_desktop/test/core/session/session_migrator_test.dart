import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sao_desktop/core/session/legacy_file_session_store.dart';
import 'package:sao_desktop/core/session/session_migrator.dart';
import 'package:sao_desktop/core/session/session_store.dart';

// ---------------------------------------------------------------------------
// In-memory fake for DesktopSessionStore — avoids platform channel calls.
// ---------------------------------------------------------------------------

class _FakeSecureStore implements DesktopSessionStore {
  SessionData? _data;

  @override
  Future<SessionData?> read() async => _data;

  @override
  Future<void> write(SessionData data) async => _data = data;

  @override
  Future<void> clear() async => _data = null;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('sao_migrator_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('migrates_legacy_json_to_secure_store_and_deletes_file', () async {
    // Arrange: write a legacy session file.
    final legacyFile = File('${tempDir.path}/sao_session.json');
    await legacyFile.writeAsString(
      '{"token":"acc-tok","refresh_token":"ref-tok","access_expires_at_epoch":9999999999}',
    );

    final secure = _FakeSecureStore();
    final legacy = LegacyFileSessionStore(filePathOverride: legacyFile.path);

    // Act
    await SessionMigrator.migrateIfNeeded(
      secureStore: secure,
      legacyStore: legacy,
    );

    // Assert: data moved to secure store.
    expect(secure._data?.accessToken, 'acc-tok');
    expect(secure._data?.refreshToken, 'ref-tok');
    expect(secure._data?.accessExpiresAtEpoch, 9999999999);

    // Assert: legacy file deleted.
    expect(await legacyFile.exists(), isFalse);
  });

  test('secure_store_present_skips_migration', () async {
    // Arrange: secure store already has data; legacy file also exists.
    final legacyFile = File('${tempDir.path}/sao_session.json');
    await legacyFile.writeAsString(
      '{"token":"legacy-tok","refresh_token":"","access_expires_at_epoch":null}',
    );

    final secure = _FakeSecureStore();
    secure._data = const SessionData(
      accessToken: 'existing-tok',
      refreshToken: '',
      accessExpiresAtEpoch: null,
    );

    final legacy = LegacyFileSessionStore(filePathOverride: legacyFile.path);

    // Act
    await SessionMigrator.migrateIfNeeded(
      secureStore: secure,
      legacyStore: legacy,
    );

    // Assert: secure store unchanged (migration was skipped).
    expect(secure._data?.accessToken, 'existing-tok');

    // Assert: legacy file NOT deleted (migration never ran).
    expect(await legacyFile.exists(), isTrue);
  });

  test('logout_clears_secure_and_legacy', () async {
    // Arrange: both stores have data.
    final legacyFile = File('${tempDir.path}/sao_session.json');
    await legacyFile.writeAsString(
      '{"token":"old-tok","refresh_token":"old-ref","access_expires_at_epoch":null}',
    );

    final secure = _FakeSecureStore();
    secure._data = const SessionData(
      accessToken: 'live-tok',
      refreshToken: 'live-ref',
      accessExpiresAtEpoch: null,
    );

    // Act: clear both manually (mirrors what logout does).
    await secure.clear();
    await LegacyFileSessionStore(filePathOverride: legacyFile.path)
        .deleteIfExists();

    // Assert: secure store empty.
    expect(await secure.read(), isNull);

    // Assert: legacy file gone.
    expect(await legacyFile.exists(), isFalse);
  });
}
