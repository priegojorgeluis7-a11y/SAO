// lib/core/auth/pin_storage.dart
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../utils/logger.dart';

/// Almacena el PIN offline del usuario de forma segura.
/// El PIN nunca se guarda en texto plano; se almacena como SHA-256(salt:pin).
/// También cachea el perfil del usuario para sesiones offline.
class PinStorage {
  static const _pinHashKey = 'offline_pin_hash';
  static const _pinSaltKey = 'offline_pin_salt';
  static const _cachedUserKey = 'offline_cached_user';

  final FlutterSecureStorage _storage;

  const PinStorage(this._storage);

  bool _isSecureStorageCorruption(Object error) {
    final text = error.toString();
    return text.contains('AEADBadTagException') ||
        text.contains('KeyStoreException') ||
        text.contains('VERIFICATION_FAILED') ||
        text.contains('EncryptedSharedPreferences initialization failed');
  }

  Future<void> _resetSecureStorage() async {
    try {
      await _storage.deleteAll();
    } catch (_) {
      // Best-effort cleanup.
    }
  }

  // ----------------------------------------------------------------
  // PIN management
  // ----------------------------------------------------------------

  /// Guarda el PIN hasheado con salt aleatorio.
  Future<void> savePin(String pin) async {
    final salt = _generateSalt();
    final hash = _hashPin(pin, salt);
    try {
      await _storage.write(key: _pinSaltKey, value: salt);
      await _storage.write(key: _pinHashKey, value: hash);
      appLogger.d('PinStorage: PIN guardado');
    } catch (e) {
      if (_isSecureStorageCorruption(e)) {
        await _resetSecureStorage();
        await _storage.write(key: _pinSaltKey, value: salt);
        await _storage.write(key: _pinHashKey, value: hash);
        appLogger.w('PinStorage: secure storage was reset due to corruption');
        return;
      }
      rethrow;
    }
  }

  /// Verifica si el PIN ingresado coincide con el almacenado.
  Future<bool> verifyPin(String pin) async {
    try {
      final salt = await _storage.read(key: _pinSaltKey);
      final storedHash = await _storage.read(key: _pinHashKey);
      if (salt == null || storedHash == null) return false;
      return _hashPin(pin, salt) == storedHash;
    } catch (e) {
      if (_isSecureStorageCorruption(e)) {
        await _resetSecureStorage();
      }
      appLogger.e('PinStorage.verifyPin error: $e');
      return false;
    }
  }

  /// Devuelve true si hay un PIN configurado.
  Future<bool> hasPin() async {
    try {
      final hash = await _storage.read(key: _pinHashKey);
      return hash != null && hash.isNotEmpty;
    } catch (e) {
      if (_isSecureStorageCorruption(e)) {
        await _resetSecureStorage();
      }
      appLogger.e('PinStorage.hasPin error: $e');
      return false;
    }
  }

  /// Elimina el PIN y el usuario cacheado (al cerrar sesión o cambiar cuenta).
  Future<void> clearAll() async {
    try {
      await _storage.delete(key: _pinHashKey);
      await _storage.delete(key: _pinSaltKey);
      await _storage.delete(key: _cachedUserKey);
    } catch (e) {
      if (_isSecureStorageCorruption(e)) {
        await _resetSecureStorage();
      }
    }
    appLogger.d('PinStorage: datos limpiados');
  }

  // ----------------------------------------------------------------
  // Cached user profile (para sesión offline)
  // ----------------------------------------------------------------

  /// Cachea el perfil del usuario en almacenamiento seguro.
  Future<void> saveCachedUser(Map<String, dynamic> userJson) async {
    try {
      await _storage.write(key: _cachedUserKey, value: jsonEncode(userJson));
    } catch (e) {
      if (_isSecureStorageCorruption(e)) {
        await _resetSecureStorage();
      }
      appLogger.e('PinStorage.saveCachedUser error: $e');
    }
  }

  /// Recupera el perfil cacheado, o null si no existe.
  Future<Map<String, dynamic>?> getCachedUser() async {
    try {
      final raw = await _storage.read(key: _cachedUserKey);
      if (raw == null || raw.isEmpty) return null;
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (e) {
      if (_isSecureStorageCorruption(e)) {
        await _resetSecureStorage();
      }
      appLogger.e('PinStorage.getCachedUser error: $e');
      return null;
    }
  }

  // ----------------------------------------------------------------
  // Helpers privados
  // ----------------------------------------------------------------

  String _generateSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64Url.encode(bytes);
  }

  String _hashPin(String pin, String salt) {
    final bytes = utf8.encode('$salt:$pin');
    return sha256.convert(bytes).toString();
  }
}
