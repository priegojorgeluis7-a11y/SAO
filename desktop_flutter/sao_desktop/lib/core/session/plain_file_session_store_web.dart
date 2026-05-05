import 'session_store.dart';

/// Web stub for PlainFileSessionStore.
/// On web, SecureSessionStore (flutter_secure_storage_web) is used instead.
class PlainFileSessionStore implements DesktopSessionStore {
  const PlainFileSessionStore();

  @override
  Future<SessionData?> read() async => null;

  @override
  Future<void> write(SessionData data) async {}

  @override
  Future<void> clear() async {}
}
