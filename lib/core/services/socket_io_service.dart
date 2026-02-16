import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as IO;

/// Servicio singleton para manejar la conexión Socket.IO con Flask
/// Escucha eventos de estado de surtidores en tiempo real
class SocketIOService {
  static final SocketIOService _instance = SocketIOService._internal();
  factory SocketIOService() => _instance;
  SocketIOService._internal();

  IO.Socket? _socket;
  bool _isConnected = false;

  // Stream controllers para eventos
  final StreamController<Map<String, dynamic>> _estadoSurtidorController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<bool> _connectionStatusController =
      StreamController<bool>.broadcast();

  // Streams públicos
  Stream<Map<String, dynamic>> get estadoSurtidorStream =>
      _estadoSurtidorController.stream;
  Stream<bool> get connectionStatusStream => _connectionStatusController.stream;

  bool get isConnected => _isConnected;

  /// Conectar al servidor Flask
  /// Por defecto usa localhost:5000 (donde corre Flask)
  void connect({String host = 'http://127.0.0.1', int port = 5000}) {
    if (_socket != null && _isConnected) {
      print('[SocketIO] Ya está conectado');
      return;
    }

    final url = '$host:$port';
    print('[SocketIO] ====================================');
    print('[SocketIO] Intentando conectar a: $url');
    print('[SocketIO] ====================================');

    try {
      // Crear socket con configuración específica para Flask-SocketIO
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
      print('[SocketIO] Socket creado con config manual, esperando conexión...');
    } catch (e) {
      print('[SocketIO] ERROR creando socket: $e');
      _connectionStatusController.add(false);
    }
  }

  /// Configurar listeners de eventos
  void _setupListeners() {
    _socket!.onConnect((_) {
      print('[SocketIO] ✅ Conectado al servidor Flask');
      _isConnected = true;
      _connectionStatusController.add(true);
    });

    _socket!.onDisconnect((_) {
      print('[SocketIO] ❌ Desconectado del servidor');
      _isConnected = false;
      _connectionStatusController.add(false);
    });

    _socket!.onConnectError((error) {
      print('[SocketIO] ⚠️ Error de conexión: $error');
      _isConnected = false;
      _connectionStatusController.add(false);
    });

    _socket!.onReconnect((_) {
      print('[SocketIO] 🔄 Reconectado');
      _isConnected = true;
      _connectionStatusController.add(true);
    });

    // Escuchar evento de estado de surtidor desde Flask
    _socket!.on('estado_surtidor', (data) {
      print('[SocketIO] 📡 Estado surtidor recibido: $data');
      if (data != null) {
        _estadoSurtidorController.add(Map<String, dynamic>.from(data));
      }
    });

    // Escuchar evento de cliente conectado (confirmación)
    _socket!.on('cliente_conectado', (data) {
      print('[SocketIO] 👋 Servidor confirmó conexión: $data');
    });
  }

  /// Desconectar del servidor
  void disconnect() {
    if (_socket != null) {
      print('[SocketIO] Desconectando...');
      _socket!.disconnect();
      _socket!.dispose();
      _socket = null;
      _isConnected = false;
      _connectionStatusController.add(false);
    }
  }

  /// Emitir evento al servidor (si necesitas enviar datos)
  void emit(String event, dynamic data) {
    if (_socket != null && _isConnected) {
      _socket!.emit(event, data);
    } else {
      print('[SocketIO] No conectado, no se puede emitir: $event');
    }
  }

  /// Liberar recursos
  void dispose() {
    disconnect();
    _estadoSurtidorController.close();
    _connectionStatusController.close();
  }
}
