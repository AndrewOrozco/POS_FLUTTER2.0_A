import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  StreamController<bool> connectionStatusController =
      StreamController<bool>.broadcast();

  void initialize() {
    _connectivity.onConnectivityChanged.listen(_updateConnectionStatus);
    checkConnection();
  }

  Future<void> checkConnection() async {
    final result = await _connectivity.checkConnectivity();
    _updateConnectionStatus(result);
  }

  void _updateConnectionStatus(List<ConnectivityResult> results) {
    // Si hay al menos una conexión activa (WiFi, móvil, ethernet)
    bool hasConnection = results.any(
      (result) =>
          result == ConnectivityResult.wifi ||
          result == ConnectivityResult.mobile ||
          result == ConnectivityResult.ethernet,
    );

    connectionStatusController.add(hasConnection);
  }

  void dispose() {
    connectionStatusController.close();
  }
}
