import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sao_windows/core/auth/token_storage.dart';

// Simple mock implementation of FlutterSecureStorage for testing
class MockSecureStorage implements FlutterSecureStorage {
  final Map<String, String> _storage = {};

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return _storage[key];
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      _storage.remove(key);
    } else {
      _storage[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _storage.remove(key);
  }

  @override
  Future<void> deleteAll({
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _storage.clear();
  }

  @override
  Future<Map<String, String>> readAll({
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return Map<String, String>.from(_storage);
  }

  @override
  Future<bool> containsKey({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return _storage.containsKey(key);
  }

  // Provide default implementations for remaining methods using noSuchMethod
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  group('TokenStorage', () {
    late MockSecureStorage mockStorage;
    late TokenStorage tokenStorage;

    setUp(() {
      mockStorage = MockSecureStorage();
      tokenStorage = TokenStorage(mockStorage);
    });

    tearDown(() async {
      await mockStorage.deleteAll();
    });

    test('saveTokens stores access and refresh tokens', () async {
      await tokenStorage.saveTokens(
        accessToken: 'access_token_123',
        refreshToken: 'refresh_token_456',
        expiresIn: 3600,
      );

      final accessToken = await tokenStorage.getAccessToken();
      final refreshToken = await tokenStorage.getRefreshToken();

      expect(accessToken, 'access_token_123');
      expect(refreshToken, 'refresh_token_456');
    });

    test('getAccessToken returns null when no token stored', () async {
      final accessToken = await tokenStorage.getAccessToken();
      expect(accessToken, isNull);
    });

    test('getRefreshToken returns null when no token stored', () async {
      final refreshToken = await tokenStorage.getRefreshToken();
      expect(refreshToken, isNull);
    });

    test('hasTokens returns false when no tokens stored', () async {
      final hasTokens = await tokenStorage.hasTokens();
      expect(hasTokens, false);
    });

    test('hasTokens returns true when tokens are stored', () async {
      await tokenStorage.saveTokens(
        accessToken: 'access_token_123',
        refreshToken: 'refresh_token_456',
      );

      final hasTokens = await tokenStorage.hasTokens();
      expect(hasTokens, true);
    });

    test('clear removes all tokens', () async {
      await tokenStorage.saveTokens(
        accessToken: 'access_token_123',
        refreshToken: 'refresh_token_456',
      );

      await tokenStorage.clear();

      final accessToken = await tokenStorage.getAccessToken();
      final refreshToken = await tokenStorage.getRefreshToken();

      expect(accessToken, isNull);
      expect(refreshToken, isNull);
    });

    test('updateAccessToken updates only access token', () async {
      // Save initial tokens
      await tokenStorage.saveTokens(
        accessToken: 'old_access_token',
        refreshToken: 'refresh_token_456',
      );

      // Update access token
      await tokenStorage.updateAccessToken(
        accessToken: 'new_access_token',
      );

      final accessToken = await tokenStorage.getAccessToken();
      final refreshToken = await tokenStorage.getRefreshToken();

      expect(accessToken, 'new_access_token');
      expect(refreshToken, 'refresh_token_456'); // Should remain unchanged
    });

    test('hasValidToken returns false for expired tokens', () async {
      await tokenStorage.saveTokens(
        accessToken: 'access_token_123',
        expiresIn: -10, // Expired 10 seconds ago
      );

      final hasValidToken = await tokenStorage.hasValidToken();
      expect(hasValidToken, false);
    });

    test('hasValidToken returns true for non-expired tokens', () async {
      await tokenStorage.saveTokens(
        accessToken: 'access_token_123',
        expiresIn: 3600, // Expires in 1 hour
      );

      final hasValidToken = await tokenStorage.hasValidToken();
      expect(hasValidToken, true);
    });

    test('shouldRefreshToken returns true when close to expiry', () async {
      await tokenStorage.saveTokens(
        accessToken: 'access_token_123',
        expiresIn: 240, // Expires in 4 minutes (< 5 minute threshold)
      );

      final shouldRefresh = await tokenStorage.shouldRefreshToken();
      expect(shouldRefresh, true);
    });

    test('shouldRefreshToken returns false when not close to expiry', () async {
      await tokenStorage.saveTokens(
        accessToken: 'access_token_123',
        expiresIn: 3600, // Expires in 1 hour
      );

      final shouldRefresh = await tokenStorage.shouldRefreshToken();
      expect(shouldRefresh, false);
    });

    test('TokenData.isExpired checks expiration correctly', () {
      final now = DateTime.now();

      // Expired token
      final expiredToken = TokenData(
        accessToken: 'token',
        issuedAt: now.subtract(const Duration(hours: 1)),
        expiresAt: now.subtract(const Duration(minutes: 5)),
      );
      expect(expiredToken.isExpired, true);

      // Valid token
      final validToken = TokenData(
        accessToken: 'token',
        issuedAt: now,
        expiresAt: now.add(const Duration(hours: 1)),
      );
      expect(validToken.isExpired, false);
    });

    test('TokenData.shouldRefresh checks refresh threshold correctly', () {
      final now = DateTime.now();

      // Should refresh (< 5 minutes to expiry)
      final shouldRefreshToken = TokenData(
        accessToken: 'token',
        issuedAt: now,
        expiresAt: now.add(const Duration(minutes: 4)),
      );
      expect(shouldRefreshToken.shouldRefresh, true);

      // Should not refresh (> 5 minutes to expiry)
      final noRefreshToken = TokenData(
        accessToken: 'token',
        issuedAt: now,
        expiresAt: now.add(const Duration(minutes: 10)),
      );
      expect(noRefreshToken.shouldRefresh, false);
    });

    test('TokenData serialization/deserialization works correctly', () async {
      final now = DateTime.now();
      final tokenData = TokenData(
        accessToken: 'access_123',
        refreshToken: 'refresh_456',
        issuedAt: now,
        expiresAt: now.add(const Duration(hours: 1)),
      );

      await tokenStorage.saveTokenData(tokenData);
      final retrieved = await tokenStorage.getTokenData();

      expect(retrieved?.accessToken, tokenData.accessToken);
      expect(retrieved?.refreshToken, tokenData.refreshToken);
      expect(retrieved?.issuedAt.toIso8601String(), tokenData.issuedAt.toIso8601String());
      expect(retrieved?.expiresAt?.toIso8601String(), tokenData.expiresAt?.toIso8601String());
    });

    test('handles corrupted data gracefully', () async {
      // Write invalid JSON directly to storage
      await mockStorage.write(
        key: 'auth_token_data',
        value: 'invalid json data',
      );

      // Should return null and clear corrupted data
      final tokenData = await tokenStorage.getTokenData();
      expect(tokenData, isNull);

      // Verify storage was cleared
      final hasTokens = await tokenStorage.hasTokens();
      expect(hasTokens, false);
    });
  });
}
