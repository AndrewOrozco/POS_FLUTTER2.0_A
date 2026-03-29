import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Servicio singleton para recibir notificaciones de pago del orquestador Go
/// via WebSocket directo (ws://localhost:5555/ws/notifications)
class PaymentWebSocketService {
  static final PaymentWebSocketService _instance = PaymentWebSocketService._internal();
  factory PaymentWebSocketService() => _instance;
  PaymentWebSocketService._internal();

  WebSocketChannel? _channel;
  bool _isConnected = false;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 50;
  StreamSubscription? _subscription;

  String _host = '127.0.0.1';
  int _port = 5555;

  // Flag: si true, el CountdownDialog está activo y consume las notificaciones
  // de APP TERPEL. home_page NO debe mostrar su AlertDialog para evitar duplicados.
  bool countdownDialogActive = false;

  // Stream para notificaciones de pago
  final StreamController<PaymentNotification> _notificationController =
      StreamController<PaymentNotification>.broadcast();
  final StreamController<bool> _connectionStatusController =
      StreamController<bool>.broadcast();

  // Streams públicos
  Stream<PaymentNotification> get notificationStream => _notificationController.stream;
  Stream<bool> get connectionStatusStream => _connectionStatusController.stream;
  bool get isConnected => _isConnected;

  /// Conectar al WebSocket del orquestador Go (puerto 5555)
  void connect({String host = '127.0.0.1', int port = 5555}) {
    _host = host;
    _port = port;
    _doConnect();
  }

  void _doConnect() {
    if (_isConnected) {
      print('[PaymentWS] Ya conectado');
      return;
    }

    final url = 'ws://$_host:$_port/ws/notifications';
    print('[PaymentWS] Conectando a: $url');

    try {
      _channel = WebSocketChannel.connect(Uri.parse(url));

      _subscription = _channel!.stream.listen(
        (data) {
          if (!_isConnected) {
            _isConnected = true;
            _reconnectAttempts = 0;
            _connectionStatusController.add(true);
            print('[PaymentWS] Conectado al orquestador');
          }
          _onMessage(data);
        },
        onError: (error) {
          print('[PaymentWS] Error: $error');
          _onDisconnected();
        },
        onDone: () {
          print('[PaymentWS] Conexión cerrada');
          _onDisconnected();
        },
      );

      // Marcar como conectado después de crear el channel
      // (el stream listener confirmará la conexión real al recibir el welcome)
    } catch (e) {
      print('[PaymentWS] Error al conectar: $e');
      _isConnected = false;
      _connectionStatusController.add(false);
      _scheduleReconnect();
    }
  }

  void _onMessage(dynamic data) {
    try {
      final json = jsonDecode(data.toString());

      // Ignorar mensajes de tipo "connected" (welcome message del hub)
      if (json['type'] == 'connected') {
        print('[PaymentWS] ${json['message']}');
        return;
      }

      final notification = PaymentNotification(
        titulo: json['titulo']?.toString() ?? '',
        mensaje: json['mensaje']?.toString() ?? '',
        estado: json['estado'] == true,
        codigo: json['codigo']?.toString() ?? '0',
        tipo: json['tipo']?.toString() ?? '',
      );

      print('[PaymentWS] Notificacion: ${notification.titulo} - '
          '${notification.estado ? "APROBADO" : "RECHAZADO"} - ${notification.mensaje}');

      _notificationController.add(notification);
    } catch (e) {
      print('[PaymentWS] Error parseando mensaje: $e');
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
      print('[PaymentWS] Maximo de reconexiones alcanzado');
      return;
    }

    _reconnectTimer?.cancel();
    // Backoff: 3s, 5s, 8s, 10s, 10s, 10s...
    final delaySec = (_reconnectAttempts < 3) ? 3 + _reconnectAttempts * 2 : 10;
    _reconnectAttempts++;

    print('[PaymentWS] Reintentando en ${delaySec}s (intento $_reconnectAttempts/$_maxReconnectAttempts)');
    _reconnectTimer = Timer(Duration(seconds: delaySec), () => _doConnect());
  }

  /// Desconectar
  void disconnect() {
    _reconnectTimer?.cancel();
    _reconnectAttempts = _maxReconnectAttempts;
    _subscription?.cancel();
    _subscription = null;
    if (_channel != null) {
      print('[PaymentWS] Desconectando...');
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

/// Notificación de pago del orquestador
/// Misma estructura que SendError del Go: {titulo, mensaje, estado, codigo}
class PaymentNotification {
  final String titulo;   // "APP TERPEL", "GOPASS", etc.
  final String mensaje;  // "Pago Exitoso" o mensaje de error
  final bool estado;     // true = aprobado, false = rechazado
  final String codigo;   // "4" = APP TERPEL, "3" = GOPASS, "0" = otro
  final String tipo;     // "pendiente" = listo para escanear, "" = resultado final

  PaymentNotification({
    required this.titulo,
    required this.mensaje,
    required this.estado,
    required this.codigo,
    this.tipo = '',
  });

  bool get isAppTerpel => codigo == '4';
  bool get isGopass => codigo == '3';
  bool get isAprobado => estado;
  bool get isRechazado => !estado;
  bool get isPendiente => tipo == 'pendiente';
}
