/// Immutable session data persisted by a [DesktopSessionStore].
class SessionData {
  final String accessToken;
  final String refreshToken;
  final int? accessExpiresAtEpoch;

  const SessionData({
    required this.accessToken,
    required this.refreshToken,
    required this.accessExpiresAtEpoch,
  });

  Map<String, dynamic> toMap() => {
        'token': accessToken,
        'refresh_token': refreshToken,
        'access_expires_at_epoch': accessExpiresAtEpoch,
      };

  factory SessionData.fromMap(Map<String, dynamic> map) => SessionData(
        accessToken: (map['token'] as String?) ?? '',
        refreshToken: (map['refresh_token'] as String?) ?? '',
        accessExpiresAtEpoch: _parseInt(map['access_expires_at_epoch']),
      );

  static int? _parseInt(dynamic v) {
    if (v is int) return v;
    if (v is String) return int.tryParse(v);
    return null;
  }
}

/// Interface for session token persistence.
/// Concrete implementations: [SecureSessionStore] (production),
/// [_FileSessionStore] (tests via TokenStore.setFileResolverForTest).
abstract interface class DesktopSessionStore {
  /// Returns stored session data, or null if the store is empty.
  Future<SessionData?> read();

  /// Persists session data to the store.
  Future<void> write(SessionData data);

  /// Removes all session data from the store.
  Future<void> clear();
}
