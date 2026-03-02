import 'package:connectivity_plus/connectivity_plus.dart';

/// Servicio para detectar conectividad de red
class ConnectivityService {
  final Connectivity _connectivity = Connectivity();

  /// Verifica si hay conexión a internet
  Future<bool> hasConnection() async {
    final result = await _connectivity.checkConnectivity();
    return result.contains(ConnectivityResult.mobile) ||
        result.contains(ConnectivityResult.wifi) ||
        result.contains(ConnectivityResult.ethernet);
  }

  /// Stream de cambios en la conectividad
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      _connectivity.onConnectivityChanged;

  /// Verifica si está en modo offline
  Future<bool> isOffline() async {
    return !(await hasConnection());
  }
}
