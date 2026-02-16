import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as IO;

/// Servicio singleton para manejar la conexión Socket.IO con LazoExpress
/// Escucha eventos de ventas pendientes en tiempo real desde ms-lazo-express
class LazoExpressSocketService {
  static final LazoExpressSocketService _instance = LazoExpressSocketService._internal();
  factory LazoExpressSocketService() => _instance;
  LazoExpressSocketService._internal();

  IO.Socket? _socket;
  bool _isConnected = false;

  // Stream controllers para eventos
  final StreamController<Map<String, dynamic>> _ventasPendientesController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _ventasFEController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<bool> _connectionStatusController =
      StreamController<bool>.broadcast();

  // Streams públicos
  Stream<Map<String, dynamic>> get ventasPendientesStream =>
      _ventasPendientesController.stream;
  Stream<Map<String, dynamic>> get ventasFEStream =>
      _ventasFEController.stream;
  Stream<bool> get connectionStatusStream => _connectionStatusController.stream;

  bool get isConnected => _isConnected;

  /// Conectar al servidor LazoExpress
  /// Por defecto usa localhost:8010 (donde corre LazoExpress)
  void connect({String host = 'http://127.0.0.1', int port = 8010}) {
    if (_socket != null && _isConnected) {
      print('[LazoExpressSocket] Ya está conectado');
      return;
    }

    final url = '$host:$port';
    print('[LazoExpressSocket] ====================================');
    print('[LazoExpressSocket] Intentando conectar a: $url');
    print('[LazoExpressSocket] ====================================');

    try {
      _socket = IO.io(
        url,
        <String, dynamic>{
          'transports': ['websocket'],
          'autoConnect': false,
          'reconnection': true,
          'reconnectionAttempts': 10,
          'reconnectionDelay': 2000,
          'reconnectionDelayMax': 10000,
          'timeout': 20000,
          'forceNew': true,
        },
      );

      _setupListeners();
      _socket!.connect();
      print('[LazoExpressSocket] Socket creado, esperando conexión...');
    } catch (e) {
      print('[LazoExpressSocket] ERROR creando socket: $e');
      _connectionStatusController.add(false);
    }
  }

  /// Configurar listeners de eventos
  void _setupListeners() {
    _socket!.onConnect((_) {
      print('[LazoExpressSocket] ✅ Conectado a LazoExpress');
      _isConnected = true;
      _connectionStatusController.add(true);
    });

    _socket!.onDisconnect((_) {
      print('[LazoExpressSocket] ❌ Desconectado de LazoExpress');
      _isConnected = false;
      _connectionStatusController.add(false);
    });

    _socket!.onConnectError((error) {
      print('[LazoExpressSocket] ⚠️ Error de conexión: $error');
      _isConnected = false;
      _connectionStatusController.add(false);
    });

    _socket!.onReconnect((_) {
      print('[LazoExpressSocket] 🔄 Reconectado a LazoExpress');
      _isConnected = true;
      _connectionStatusController.add(true);
    });

    // Escuchar evento de ventas pendientes desde LazoExpress (ms-lazo-express)
    _socket!.on('ventas_pendientes', (data) {
      print('[LazoExpressSocket] 💰 Ventas pendientes recibidas: $data');
      if (data != null) {
        _ventasPendientesController.add(Map<String, dynamic>.from(data));
      }
    });

    // Escuchar evento de ventas FE (Facturación Electrónica + Datafono)
    _socket!.on('ventas_fe', (data) {
      print('[LazoExpressSocket] 📋 Ventas FE recibidas: $data');
      if (data != null) {
        _ventasFEController.add(Map<String, dynamic>.from(data));
      }
    });
  }

  /// Desconectar del servidor
  void disconnect() {
    if (_socket != null) {
      print('[LazoExpressSocket] Desconectando...');
      _socket!.disconnect();
      _socket!.dispose();
      _socket = null;
      _isConnected = false;
      _connectionStatusController.add(false);
    }
  }

  /// Liberar recursos
  void dispose() {
    disconnect();
    _ventasPendientesController.close();
    _ventasFEController.close();
    _connectionStatusController.close();
  }
}
