import 'dart:convert';
import 'dart:io';

import '../session/legacy_file_session_store.dart';
import '../session/secure_session_store.dart';
import '../session/session_store.dart';

/// Typed container for the loaded session.
class TokenSessionData {
  final String accessToken;
  final String refreshToken;
  final int? accessTokenExpiresAtEpoch;

  const TokenSessionData({
    required this.accessToken,
    required this.refreshToken,
    required this.accessTokenExpiresAtEpoch,
  });

  bool get hasAccessToken => accessToken.trim().isNotEmpty;
  bool get hasRefreshToken => refreshToken.trim().isNotEmpty;
}

/// Static facade for session token management.
///
/// Maintains an in-memory cache so callers (BackendApiClient, SessionController)
/// avoid repeated keychain lookups.  Persistence is delegated to the active
/// [DesktopSessionStore], which defaults to [SecureSessionStore] (OS vault).
///
/// Test hook: call [setFileResolverForTest] to redirect I/O to a temp file
/// (backwards-compatible with existing tests).
class TokenStore {
  TokenStore._();

  // Production store — OS credential vault (DPAPI on Windows).
  // Replaced during tests via setFileResolverForTest.
  static DesktopSessionStore _store = SecureSessionStore();

  static String _current = '';
  static String _refresh = '';
  static int? _accessExpiresAtEpoch;

  /// The in-memory access token (empty if not authenticated).
  static String get current => _current;

  /// The in-memory refresh token (empty if none).
  static String get currentRefreshToken => _refresh;

  static int? get accessTokenExpiresAtEpoch => _accessExpiresAtEpoch;

  static bool get hasToken => _current.trim().isNotEmpty;
  static bool get hasRefreshToken => _refresh.trim().isNotEmpty;

  static bool get isAccessTokenExpired {
    final expiresAt = _accessExpiresAtEpoch;
    if (expiresAt == null) return false;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return now >= expiresAt;
  }

  static bool get shouldRefreshAccessToken {
    final expiresAt = _accessExpiresAtEpoch;
    if (expiresAt == null) return false;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return now >= (expiresAt - 60);
  }

  /// Persists tokens in the OS vault and updates the in-memory cache.
  static Future<void> save(
    String token, {
    String refreshToken = '',
    int? expiresInSeconds,
    int? accessExpiresAtEpoch,
  }) async {
    _current = token;
    _refresh = refreshToken;
    if (accessExpiresAtEpoch != null) {
      _accessExpiresAtEpoch = accessExpiresAtEpoch;
    } else if (expiresInSeconds != null && expiresInSeconds > 0) {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      _accessExpiresAtEpoch = now + expiresInSeconds;
    } else {
      _accessExpiresAtEpoch = null;
    }
    await _store.write(SessionData(
      accessToken: _current,
      refreshToken: _refresh,
      accessExpiresAtEpoch: _accessExpiresAtEpoch,
    ));
  }

  /// Loads the persisted access token into the in-memory cache.
  /// Returns empty string if nothing is stored.
  static Future<String> load() async {
    final session = await loadSession();
    return session.accessToken;
  }

  /// Loads the full session from persistent storage into the in-memory cache.
  static Future<TokenSessionData> loadSession() async {
    try {
      final data = await _store.read();
      if (data != null) {
        _current = data.accessToken;
        _refresh = data.refreshToken;
        _accessExpiresAtEpoch = data.accessExpiresAtEpoch;
      }
    } catch (_) {
      _current = '';
      _refresh = '';
      _accessExpiresAtEpoch = null;
    }
    return TokenSessionData(
      accessToken: _current,
      refreshToken: _refresh,
      accessTokenExpiresAtEpoch: _accessExpiresAtEpoch,
    );
  }

  /// Clears the in-memory cache, the OS vault, and any legacy file remnants.
  static Future<void> clear() async {
    _current = '';
    _refresh = '';
    _accessExpiresAtEpoch = null;
    await _store.clear();
    // Belt-and-suspenders: remove legacy file if it somehow still exists.
    await const LegacyFileSessionStore().deleteIfExists();
  }

  /// Test hook: redirects persistence to a plain JSON file via [resolver].
  /// Pass null to restore the default [SecureSessionStore].
  ///
  /// Keeps backwards compatibility with existing tests that used the old
  /// file-based implementation directly.
  static void setFileResolverForTest(Future<File> Function()? resolver) {
    if (resolver == null) {
      _store = SecureSessionStore();
    } else {
      _store = _FileSessionStore(resolver);
    }
  }
}

// ---------------------------------------------------------------------------
// Private file-based store — used only in tests via setFileResolverForTest.
// ---------------------------------------------------------------------------

class _FileSessionStore implements DesktopSessionStore {
  final Future<File> Function() _fileResolver;

  _FileSessionStore(this._fileResolver);

  @override
  Future<SessionData?> read() async {
    try {
      final file = await _fileResolver();
      if (!await file.exists()) return null;
      final raw = await file.readAsString();
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return SessionData.fromMap(map);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(SessionData data) async {
    final file = await _fileResolver();
    await file.writeAsString(jsonEncode(data.toMap()));
  }

  @override
  Future<void> clear() async {
    try {
      final file = await _fileResolver();
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }
}
