import 'legacy_file_session_store.dart';
import 'secure_session_store.dart';
import 'session_store.dart';

/// One-shot migration from the legacy plain-text sao_session.json to
/// [SecureSessionStore] (OS credential vault).
///
/// Safe to call on every startup — idempotent once SecureStore has data.
class SessionMigrator {
  /// Migrates legacy token file to secure storage if not already done.
  ///
  /// Logic:
  ///   1. If SecureStore already has an access token → skip (already migrated).
  ///   2. If legacy file exists → read, write to SecureStore, delete file.
  ///   3. If legacy file missing → nothing to do.
  ///
  /// [secureStore] and [legacyStore] are injectable for testing.
  static Future<void> migrateIfNeeded({
    DesktopSessionStore? secureStore,
    LegacyFileSessionStore? legacyStore,
  }) async {
    try {
      final secure = secureStore ?? SecureSessionStore();
      final legacy = legacyStore ?? const LegacyFileSessionStore();

      final existing = await secure.read();
      if (existing != null) return; // already using secure store

      final legacyData = await legacy.readAndDelete();
      if (legacyData == null) return; // no legacy session

      await secure.write(legacyData);
      // Log without token values — safe for crash reporters.
      // ignore: avoid_print
      print('[SAO] Session migrated from legacy file to secure credential store.');
    } catch (e) {
      // Migration failure is non-fatal: user will be prompted to log in.
      // ignore: avoid_print
      print('[SAO] Session migration skipped: $e');
    }
  }
}
