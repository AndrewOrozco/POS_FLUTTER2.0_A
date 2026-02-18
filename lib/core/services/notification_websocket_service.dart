import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Servicio singleton para recibir notificaciones del backend Python (8020)
/// via WebSocket (ws://localhost:8020/ws/notifications).
/// 
/// Emite notificaciones tipo Steam cuando:
/// - 7011 falla (facturador caído)
/// - Impresión OK/error desde backend
/// - Cualquier evento del backend que Flutter deba saber
class NotificationWebSocketService {
  static final NotificationWebSocketService _instance =
      NotificationWebSocketService._internal();
  factory NotificationWebSocketService() => _instance;
  NotificationWebSocketService._internal();

  WebSocketChannel? _channel;
  bool _isConnected = false;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 100;
  StreamSubscription? _subscription;

  String _host = '127.0.0.1';
  int _port = 8020;

  // Stream para notificaciones
  final StreamController<BackendNotification> _notificationController =
      StreamController<BackendNotification>.broadcast();
  final StreamController<bool> _connectionStatusController =
      StreamController<bool>.broadcast();

  // Streams públicos
  Stream<BackendNotification> get notificationStream =>
      _notificationController.stream;
  Stream<bool> get connectionStatusStream => _connectionStatusController.stream;
  bool get isConnected => _isConnected;

  /// Conectar al WebSocket del backend Python (puerto 8020)
  void connect({String host = '127.0.0.1', int port = 8020}) {
    _host = host;
    _port = port;
    _doConnect();
  }

  void _doConnect() {
    if (_isConnected) return;

    final url = 'ws://$_host:$_port/ws/notifications';
    print('[NotificationWS] Conectando a: $url');

    try {
      _channel = WebSocketChannel.connect(Uri.parse(url));

      _subscription = _channel!.stream.listen(
        (data) {
          if (!_isConnected) {
            _isConnected = true;
            _reconnectAttempts = 0;
            _connectionStatusController.add(true);
            print('[NotificationWS] ✅ Conectado al backend Python');
          }
          _onMessage(data);
        },
        onError: (error) {
          print('[NotificationWS] Error: $error');
          _onDisconnected();
        },
        onDone: () {
          print('[NotificationWS] Conexión cerrada');
          _onDisconnected();
        },
      );
    } catch (e) {
      print('[NotificationWS] Error al conectar: $e');
      _isConnected = false;
      _connectionStatusController.add(false);
      _scheduleReconnect();
    }
  }

  void _onMessage(dynamic data) {
    try {
      final json = jsonDecode(data.toString());

      // Ignorar welcome messages
      if (json['type'] == 'connected') {
        print('[NotificationWS] ${json['message']}');
        return;
      }

      final notification = BackendNotification(
        type: json['type']?.toString() ?? 'unknown',
        title: json['title']?.toString() ?? '',
        message: json['message']?.toString() ?? '',
        cara: json['cara'] is int ? json['cara'] : null,
        movimientoId: json['movimiento_id'] is int ? json['movimiento_id'] : null,
        severity: json['severity']?.toString() ?? 'info',
      );

      print('[NotificationWS] Notificación: [${notification.type}] '
          '${notification.title} - ${notification.message}');

      _notificationController.add(notification);
    } catch (e) {
      print('[NotificationWS] Error parseando mensaje: $e');
    }
  }

  void _onDisconnected() {
    _isConnected = false;
    _connectionStatusController.add(false);
    _subscription?.cancel();
    _subscription = null;
    _channel = null;
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      print('[NotificationWS] Máximo de reconexiones alcanzado');
      return;
    }

    _reconnectTimer?.cancel();
    final delaySec = (_reconnectAttempts < 3) ? 3 + _reconnectAttempts * 2 : 10;
    _reconnectAttempts++;

    print('[NotificationWS] Reintentando en ${delaySec}s '
        '(intento $_reconnectAttempts/$_maxReconnectAttempts)');
    _reconnectTimer = Timer(Duration(seconds: delaySec), () => _doConnect());
  }

  /// Desconectar
  void disconnect() {
    _reconnectTimer?.cancel();
    _reconnectAttempts = _maxReconnectAttempts;
    _subscription?.cancel();
    _subscription = null;
    if (_channel != null) {
      _channel!.sink.close();
      _channel = null;
      _isConnected = false;
      _connectionStatusController.add(false);
    }
  }

  /// Liberar recursos
  void dispose() {
    disconnect();
    _notificationController.close();
    _connectionStatusController.close();
  }
}

/// Notificación del backend Python
class BackendNotification {
  final String type;       // "fe_error", "fe_ok", "print_ok", "print_error"
  final String title;      // Título para mostrar
  final String message;    // Mensaje detallado
  final int? cara;         // Cara afectada (opcional)
  final int? movimientoId; // Movimiento afectado (opcional)
  final String severity;   // "info", "warning", "error", "success"

  BackendNotification({
    required this.type,
    required this.title,
    required this.message,
    this.cara,
    this.movimientoId,
    required this.severity,
  });

  bool get isError => severity == 'error' || severity == 'warning';
  bool get isSuccess => severity == 'success';
}
