import 'session_store.dart';

/// Web stub for LegacyFileSessionStore.
/// On web there is no legacy file to migrate.
class LegacyFileSessionStore {
  const LegacyFileSessionStore({String? filePathOverride});

  Future<SessionData?> readAndDelete() async => null;

  Future<void> deleteIfExists() async {}
}
