import 'session_store.dart';

/// Web stub for LegacyFileSessionStore.
/// On web there is no legacy file to migrate.
class LegacyFileSessionStore {
  final String? _filePathOverride;

  const LegacyFileSessionStore({String? filePathOverride})
      : _filePathOverride = filePathOverride;

  Future<SessionData?> readAndDelete() async => null;

  Future<void> deleteIfExists() async {}
}
