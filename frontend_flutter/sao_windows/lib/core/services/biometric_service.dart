import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import '../utils/logger.dart';

enum BiometricAuthFailure {
  canceled,
  notSupported,
  notAvailable,
  notEnrolled,
  lockedOut,
  permanentLockout,
  other,
}

class BiometricAuthResult {
  final bool authenticated;
  final BiometricAuthFailure? failure;

  const BiometricAuthResult._({required this.authenticated, this.failure});

  const BiometricAuthResult.success() : this._(authenticated: true);

  const BiometricAuthResult.failure(BiometricAuthFailure reason)
      : this._(authenticated: false, failure: reason);
}

/// Servicio para autenticación biométrica (huella digital/Face ID)
class BiometricService {
  final LocalAuthentication _localAuth = LocalAuthentication();

  /// Verifica si el dispositivo tiene biometría disponible
  Future<bool> canCheckBiometrics() async {
    try {
      return await _localAuth.canCheckBiometrics;
    } catch (e) {
      appLogger.e('Error verificando biometría: $e');
      return false;
    }
  }

  /// Verifica si hay biometría configurada
  Future<bool> isDeviceSupported() async {
    try {
      return await _localAuth.isDeviceSupported();
    } catch (e) {
      appLogger.e('Error verificando soporte de dispositivo: $e');
      return false;
    }
  }

  /// Obtiene la lista de biometrías disponibles
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      appLogger.e('Error obteniendo biometrías: $e');
      return [];
    }
  }

  /// Autentica al usuario con biometría
  /// 
  /// [localizedReason] es el mensaje que se muestra al usuario
  Future<bool> authenticate({
    required String localizedReason,
    bool useErrorDialogs = true,
    bool stickyAuth = true,
    bool biometricOnly = true,
  }) async {
    final result = await authenticateWithResult(
      localizedReason: localizedReason,
      useErrorDialogs: useErrorDialogs,
      stickyAuth: stickyAuth,
      biometricOnly: biometricOnly,
    );
    return result.authenticated;
  }

  Future<BiometricAuthResult> authenticateWithResult({
    required String localizedReason,
    bool useErrorDialogs = true,
    bool stickyAuth = true,
    bool biometricOnly = true,
  }) async {
    try {
      final isSupported = await isDeviceSupported();
      if (!isSupported) {
        appLogger.w('Dispositivo no soporta biometría');
        return const BiometricAuthResult.failure(BiometricAuthFailure.notSupported);
      }

      final canCheck = await canCheckBiometrics();
      if (!canCheck) {
        appLogger.w('Biometría no disponible');
        return const BiometricAuthResult.failure(BiometricAuthFailure.notAvailable);
      }

      final authenticated = await _localAuth.authenticate(
        localizedReason: localizedReason,
        options: AuthenticationOptions(
          useErrorDialogs: useErrorDialogs,
          stickyAuth: stickyAuth,
          biometricOnly: biometricOnly,
        ),
      );
      if (authenticated) {
        return const BiometricAuthResult.success();
      }
      return const BiometricAuthResult.failure(BiometricAuthFailure.canceled);
    } on PlatformException catch (e) {
      final code = e.code.trim().toLowerCase();
      appLogger.e('Error en autenticación biométrica ($code): ${e.message}');

      if (code == 'notavailable' || code == 'no_hardware') {
        return const BiometricAuthResult.failure(BiometricAuthFailure.notSupported);
      }
      if (code == 'notenrolled') {
        return const BiometricAuthResult.failure(BiometricAuthFailure.notEnrolled);
      }
      if (code == 'lockedout') {
        return const BiometricAuthResult.failure(BiometricAuthFailure.lockedOut);
      }
      if (code == 'permanentlylockedout') {
        return const BiometricAuthResult.failure(BiometricAuthFailure.permanentLockout);
      }
      if (code == 'usercanceled' || code == 'systemcanceled') {
        return const BiometricAuthResult.failure(BiometricAuthFailure.canceled);
      }
      if (code == 'passcodenotset') {
        return const BiometricAuthResult.failure(BiometricAuthFailure.notAvailable);
      }

      return const BiometricAuthResult.failure(BiometricAuthFailure.other);
    } catch (e) {
      appLogger.e('Error en autenticación biométrica: $e');
      return const BiometricAuthResult.failure(BiometricAuthFailure.other);
    }
  }

  /// Verifica si tiene huella digital o Face ID configurado
  Future<bool> hasBiometricCredentials() async {
    final available = await getAvailableBiometrics();
    return available.contains(BiometricType.fingerprint) ||
        available.contains(BiometricType.face) ||
        available.contains(BiometricType.strong) ||
        available.contains(BiometricType.weak);
  }

  /// Obtiene el tipo de biometría disponible (para mostrar en UI)
  Future<String> getBiometricTypeLabel() async {
    final available = await getAvailableBiometrics();
    if (available.contains(BiometricType.face)) {
      return 'Face ID';
    } else if (available.contains(BiometricType.fingerprint)) {
      return 'Huella Digital';
    } else if (available.contains(BiometricType.strong)) {
      return 'Biométricos';
    } else {
      return 'Autenticación del dispositivo';
    }
  }
}
