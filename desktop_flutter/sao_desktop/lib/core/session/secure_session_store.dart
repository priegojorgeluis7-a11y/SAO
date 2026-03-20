import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'session_store.dart';

/// Stores session tokens in the OS credential vault via flutter_secure_storage.
///
/// On Windows: uses DPAPI (Data Protection API) through Windows Credential
/// Manager — tokens are encrypted at rest and scoped to the current OS user.
/// Keys survive app updates as long as the user account remains the same.
///
/// Keys stored:
///   sao_access_token   — JWT access token
///   sao_refresh_token  — JWT refresh token
///   sao_expires_at     — access token expiry (epoch seconds, as string)
class SecureSessionStore implements DesktopSessionStore {
  static const _storage = FlutterSecureStorage(
    wOptions: WindowsOptions(useBackwardCompatibility: false),
  );

  static const _kAccess = 'sao_access_token';
  static const _kRefresh = 'sao_refresh_token';
  static const _kExpires = 'sao_expires_at';

  @override
  Future<SessionData?> read() async {
    final access = await _storage.read(key: _kAccess) ?? '';
    if (access.isEmpty) return null;
    final refresh = await _storage.read(key: _kRefresh) ?? '';
    final expiresRaw = await _storage.read(key: _kExpires);
    final expires = expiresRaw != null ? int.tryParse(expiresRaw) : null;
    return SessionData(
      accessToken: access,
      refreshToken: refresh,
      accessExpiresAtEpoch: expires,
    );
  }

  @override
  Future<void> write(SessionData data) async {
    await _storage.write(key: _kAccess, value: data.accessToken);
    await _storage.write(key: _kRefresh, value: data.refreshToken);
    if (data.accessExpiresAtEpoch != null) {
      await _storage.write(
        key: _kExpires,
        value: data.accessExpiresAtEpoch.toString(),
      );
    } else {
      await _storage.delete(key: _kExpires);
    }
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _kAccess);
    await _storage.delete(key: _kRefresh);
    await _storage.delete(key: _kExpires);
  }
}
