import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:flutter/foundation.dart';

/// Servicio singleton para manejar la conexión Socket.IO con Flask
/// Escucha eventos de estado de surtidores en tiempo real
///
/// Reconexión robusta:
///   - Socket.IO intenta reconectar hasta 99999 veces (prácticamente infinito)
///   - Si Socket.IO agota sus reintentos, un Timer de respaldo destruye
///     el socket viejo y crea uno nuevo cada 10 segundos
class SocketIOService {
  static final SocketIOService _instance = SocketIOService._internal();
  factory SocketIOService() => _instance;
  SocketIOService._internal();

  io.Socket? _socket;
  bool _isConnected = false;
  Timer? _reconnectTimer;

  // Guardar host/port para poder reconectar desde el fallback
  String _lastHost = 'http://127.0.0.1';
  int _lastPort = 5000;

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
    _lastHost = host;
    _lastPort = port;

    // Si ya está conectado, no hacer nada
    if (_socket != null && _isConnected) {
      debugPrint('[SocketIO] Ya está conectado');
      return;
    }

    // Si el socket existe pero NO está conectado (quedó zombie),
    // destruirlo y crear uno nuevo
    if (_socket != null && !_isConnected) {
      debugPrint('[SocketIO] Socket zombie detectado, destruyendo...');
      _destroySocket();
    }

    // Cancelar cualquier timer de reconexión manual pendiente
    _reconnectTimer?.cancel();

    final url = '$host:$port';
    debugPrint('[SocketIO] ====================================');
    debugPrint('[SocketIO] Intentando conectar a: $url');
    debugPrint('[SocketIO] ====================================');

    try {
      // Crear socket con reconexión robusta
      _socket = io.io(
        url,
        <String, dynamic>{
          'transports': ['websocket'],
          'autoConnect': false,
          'reconnection': true,
          'reconnectionAttempts': 99999,  // Prácticamente infinito
          'reconnectionDelay': 2000,
          'reconnectionDelayMax': 10000,
          'timeout': 20000,
          // NO usar forceNew: interfiere con la reconexión automática
        },
      );

      _setupListeners();
      _socket!.connect();
      debugPrint('[SocketIO] Socket creado, esperando conexión...');
    } catch (e) {
      debugPrint('[SocketIO] ERROR creando socket: $e');
      _connectionStatusController.add(false);
      _scheduleFullReconnect();
    }
  }

  /// Configurar listeners de eventos
  void _setupListeners() {
    _socket!.onConnect((_) {
      debugPrint('[SocketIO] ✅ Conectado al servidor Flask');
      _isConnected = true;
      _reconnectTimer?.cancel(); // Cancelar reconexión manual si había
      _connectionStatusController.add(true);
    });

    _socket!.onDisconnect((_) {
      debugPrint('[SocketIO] ❌ Desconectado del servidor');
      _isConnected = false;
      _connectionStatusController.add(false);
      // Socket.IO intentará reconectar automáticamente (hasta 99999 veces)
    });

    _socket!.onConnectError((error) {
      debugPrint('[SocketIO] ⚠️ Error de conexión: $error');
      _isConnected = false;
      _connectionStatusController.add(false);
    });

    _socket!.onReconnect((_) {
      debugPrint('[SocketIO] 🔄 Reconectado exitosamente');
      _isConnected = true;
      _reconnectTimer?.cancel();
      _connectionStatusController.add(true);
    });

    _socket!.onReconnectAttempt((attemptNumber) {
      debugPrint('[SocketIO] 🔄 Intento de reconexión #$attemptNumber');
    });

    _socket!.onReconnectFailed((_) {
      // Esto solo pasa si se agotan los 99999 intentos (muy raro)
      // o si hay un error catastrófico. Activar reconexión manual.
      debugPrint('[SocketIO] ⚠️ Reconexión Socket.IO agotada, activando respaldo manual...');
      _scheduleFullReconnect();
    });

    _socket!.onReconnectError((error) {
      debugPrint('[SocketIO] ⚠️ Error en reconexión: $error');
    });

    // Escuchar evento de estado de surtidor desde Flask
    _socket!.on('estado_surtidor', (data) {
      debugPrint('[SocketIO] 📡 Estado surtidor recibido: $data');
      if (data != null) {
        _estadoSurtidorController.add(Map<String, dynamic>.from(data));
      }
    });

    // Escuchar evento de cliente conectado (confirmación)
    _socket!.on('cliente_conectado', (data) {
      debugPrint('[SocketIO] 👋 Servidor confirmó conexión: $data');
    });
  }

  /// Reconexión manual de respaldo:
  /// Destruye el socket viejo y crea uno completamente nuevo.
  /// Se activa cuando Socket.IO agota sus reintentos internos.
  void _scheduleFullReconnect() {
    _reconnectTimer?.cancel();
    debugPrint('[SocketIO] ⏰ Reintento completo en 10 segundos...');
    _reconnectTimer = Timer(const Duration(seconds: 10), () {
      debugPrint('[SocketIO] 🔁 Ejecutando reconexión completa (nuevo socket)');
      _destroySocket();
      connect(host: _lastHost, port: _lastPort);
    });
  }

  /// Destruir socket sin activar reconexión
  void _destroySocket() {
    if (_socket != null) {
      _socket!.clearListeners();
      _socket!.disconnect();
      _socket!.dispose();
      _socket = null;
    }
    _isConnected = false;
  }

  /// Desconectar del servidor (intencional, cancela todo)
  void disconnect() {
    _reconnectTimer?.cancel();
    if (_socket != null) {
      debugPrint('[SocketIO] Desconectando...');
      _destroySocket();
      _connectionStatusController.add(false);
    }
  }

  /// Emitir evento al servidor (si necesitas enviar datos)
  void emit(String event, dynamic data) {
    if (_socket != null && _isConnected) {
      _socket!.emit(event, data);
    } else {
      debugPrint('[SocketIO] No conectado, no se puede emitir: $event');
    }
  }

  /// Liberar recursos
  void dispose() {
    disconnect();
    _estadoSurtidorController.close();
    _connectionStatusController.close();
  }
}