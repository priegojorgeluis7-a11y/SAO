import 'package:local_auth/local_auth.dart';
import '../utils/logger.dart';

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
  }) async {
    try {
      final isSupported = await isDeviceSupported();
      if (!isSupported) {
        appLogger.w('Dispositivo no soporta biometría');
        return false;
      }

      final canCheck = await canCheckBiometrics();
      if (!canCheck) {
        appLogger.w('Biometría no disponible');
        return false;
      }

      return await _localAuth.authenticate(
        localizedReason: localizedReason,
        options: AuthenticationOptions(
          useErrorDialogs: useErrorDialogs,
          stickyAuth: stickyAuth,
          biometricOnly: true,
        ),
      );
    } catch (e) {
      appLogger.e('Error en autenticación biométrica: $e');
      return false;
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
