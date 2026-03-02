import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';

/// Token data model
class TokenData {
  final String accessToken;
  final String? refreshToken;
  final DateTime issuedAt;
  final DateTime? expiresAt;

  TokenData({
    required this.accessToken,
    this.refreshToken,
    required this.issuedAt,
    this.expiresAt,
  });

  /// Check if access token is expired or about to expire
  bool get isExpired {
    if (expiresAt == null) return false;
    // Consider expired if less than 1 minute remaining
    return DateTime.now().isAfter(expiresAt!.subtract(const Duration(minutes: 1)));
  }

  /// Check if token should be refreshed (within 5 minutes of expiry)
  bool get shouldRefresh {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!.subtract(const Duration(minutes: 5)));
  }

  Map<String, dynamic> toJson() => {
        'accessToken': accessToken,
        'refreshToken': refreshToken,
        'issuedAt': issuedAt.toIso8601String(),
        'expiresAt': expiresAt?.toIso8601String(),
      };

  factory TokenData.fromJson(Map<String, dynamic> json) => TokenData(
        accessToken: json['accessToken'] as String,
        refreshToken: json['refreshToken'] as String?,
        issuedAt: DateTime.parse(json['issuedAt'] as String),
        expiresAt: json['expiresAt'] != null
            ? DateTime.parse(json['expiresAt'] as String)
            : null,
      );

  TokenData copyWith({
    String? accessToken,
    String? refreshToken,
    DateTime? issuedAt,
    DateTime? expiresAt,
  }) {
    return TokenData(
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      issuedAt: issuedAt ?? this.issuedAt,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }
}

/// Secure token storage using FlutterSecureStorage
/// Stores JWT access and refresh tokens securely on device
class TokenStorage {
  static const String _tokenDataKey = 'auth_token_data';

  final FlutterSecureStorage _storage;
  TokenData? _cachedTokenData;

  TokenStorage(this._storage);

  /// Get cached token data or load from storage
  Future<TokenData?> getTokenData() async {
    if (_cachedTokenData != null) {
      return _cachedTokenData;
    }

    try {
      final jsonString = await _storage.read(key: _tokenDataKey);
      if (jsonString == null) return null;

      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      _cachedTokenData = TokenData.fromJson(json);
      return _cachedTokenData;
    } catch (e) {
      // If there's an error reading/parsing, clear the corrupted data
      await clear();
      return null;
    }
  }

  /// Get only the access token
  Future<String?> getAccessToken() async {
    final tokenData = await getTokenData();
    return tokenData?.accessToken;
  }

  /// Get only the refresh token
  Future<String?> getRefreshToken() async {
    final tokenData = await getTokenData();
    return tokenData?.refreshToken;
  }

  /// Save new token data
  Future<void> saveTokenData(TokenData tokenData) async {
    try {
      final jsonString = jsonEncode(tokenData.toJson());
      await _storage.write(key: _tokenDataKey, value: jsonString);
      _cachedTokenData = tokenData;
    } catch (e) {
      throw Exception('Failed to save token data: $e');
    }
  }

  /// Save tokens with automatic expiry calculation
  /// If expiresIn is provided (in seconds), calculates expiresAt
  Future<void> saveTokens({
    required String accessToken,
    String? refreshToken,
    int? expiresIn,
  }) async {
    final now = DateTime.now();
    final tokenData = TokenData(
      accessToken: accessToken,
      refreshToken: refreshToken,
      issuedAt: now,
      expiresAt: expiresIn != null ? now.add(Duration(seconds: expiresIn)) : null,
    );

    await saveTokenData(tokenData);
  }

  /// Update only the access token (used after refresh)
  Future<void> updateAccessToken({
    required String accessToken,
    int? expiresIn,
  }) async {
    final current = await getTokenData();
    if (current == null) {
      // If no existing tokens, save new ones
      await saveTokens(accessToken: accessToken, expiresIn: expiresIn);
      return;
    }

    final now = DateTime.now();
    final updated = current.copyWith(
      accessToken: accessToken,
      issuedAt: now,
      expiresAt: expiresIn != null ? now.add(Duration(seconds: expiresIn)) : null,
    );

    await saveTokenData(updated);
  }

  /// Check if we have a valid (non-expired) access token
  Future<bool> hasValidToken() async {
    final tokenData = await getTokenData();
    if (tokenData == null) return false;
    return !tokenData.isExpired;
  }

  /// Check if token should be refreshed
  Future<bool> shouldRefreshToken() async {
    final tokenData = await getTokenData();
    if (tokenData == null) return false;
    return tokenData.shouldRefresh;
  }

  /// Check if we have any tokens stored
  Future<bool> hasTokens() async {
    final tokenData = await getTokenData();
    return tokenData != null;
  }

  /// Clear all stored tokens
  Future<void> clear() async {
    await _storage.delete(key: _tokenDataKey);
    _cachedTokenData = null;
  }

  /// Clear cache (forces reload from storage on next access)
  void clearCache() {
    _cachedTokenData = null;
  }
}
