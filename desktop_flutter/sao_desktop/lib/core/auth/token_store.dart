import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

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

/// Persists the access token to disk so the user stays logged in
/// across app restarts. Uses a simple JSON file in the documents directory.
class TokenStore {
  TokenStore._();

  static String _current = '';
  static String _refresh = '';
  static int? _accessExpiresAtEpoch;
  static Future<File> Function()? _fileResolverForTest;

  /// The in-memory token, set after login or restore.
  static String get current => _current;
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
    final file = await _file();
    await file.writeAsString(
      jsonEncode({
        'token': _current,
        'refresh_token': _refresh,
        'access_expires_at_epoch': _accessExpiresAtEpoch,
      }),
    );
  }

  /// Loads the persisted token. Returns empty string if none found.
  static Future<String> load() async {
    final session = await loadSession();
    return session.accessToken;
  }

  static Future<TokenSessionData> loadSession() async {
    try {
      final file = await _file();
      if (await file.exists()) {
        final raw = await file.readAsString();
        final map = jsonDecode(raw) as Map<String, dynamic>;
        _current = (map['token'] as String?) ?? '';
        _refresh = (map['refresh_token'] as String?) ?? '';
        final expiresRaw = map['access_expires_at_epoch'];
        if (expiresRaw is int) {
          _accessExpiresAtEpoch = expiresRaw;
        } else if (expiresRaw is String) {
          _accessExpiresAtEpoch = int.tryParse(expiresRaw);
        } else {
          _accessExpiresAtEpoch = null;
        }
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

  static Future<void> clear() async {
    _current = '';
    _refresh = '';
    _accessExpiresAtEpoch = null;
    try {
      final file = await _file();
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  static Future<File> _file() async {
    final resolver = _fileResolverForTest;
    if (resolver != null) {
      return resolver();
    }
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/sao_session.json');
  }

  static void setFileResolverForTest(Future<File> Function()? resolver) {
    _fileResolverForTest = resolver;
  }
}
