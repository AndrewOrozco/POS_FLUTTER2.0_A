import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Configuración central de la aplicación Terpel POS.
///
/// Lee todas las variables desde el archivo `.env` en la raíz del proyecto.
/// Cada servicio tiene su propio **host** independiente, permitiendo que
/// corran en diferentes máquinas de la red.
///
/// Ejemplo `.env`:
/// ```
/// HOST_CONSULTAS=127.0.0.1       # FastAPI local
/// HOST_LAZOEXPRESS=192.168.1.100  # LazoExpress en servidor
/// HOST_FLASK=192.168.1.100        # Flask en servidor
/// HOST_PAGOS=192.168.1.100        # Orquestador en servidor
/// ```
class AppEnv {
  AppEnv._(); // No instanciar

  // ── Hosts por servicio ───────────────────────────────────────

  /// Backend Python FastAPI (api-consultas-flutter) — normalmente local
  static String get hostConsultas =>
      dotenv.env['HOST_CONSULTAS'] ?? '127.0.0.1';

  /// LazoExpress Java/Node — puede estar en otro equipo
  static String get hostLazoExpress =>
      dotenv.env['HOST_LAZOEXPRESS'] ?? '127.0.0.1';

  /// Flask / Socket.IO Status Pump — puede estar en otro equipo
  static String get hostFlask =>
      dotenv.env['HOST_FLASK'] ?? '127.0.0.1';

  /// Orquestador de Pagos WebSocket — puede estar en otro equipo
  static String get hostPagos =>
      dotenv.env['HOST_PAGOS'] ?? '127.0.0.1';

  // ── Puertos ─────────────────────────────────────────────────

  static int get portConsultas =>
      int.tryParse(dotenv.env['PORT_CONSULTAS'] ?? '8020') ?? 8020;

  static int get portLazoExpress =>
      int.tryParse(dotenv.env['PORT_LAZOEXPRESS'] ?? '8010') ?? 8010;

  static int get portFlask =>
      int.tryParse(dotenv.env['PORT_FLASK'] ?? '5000') ?? 5000;

  static int get portPagos =>
      int.tryParse(dotenv.env['PORT_PAGOS'] ?? '5555') ?? 5555;

  // ── URLs completas pre-armadas ───────────────────────────────

  /// Base URL para la API de consultas Python FastAPI
  static String get urlConsultas =>
      'http://$hostConsultas:$portConsultas';

  /// WebSocket de notificaciones del backend FastAPI
  static String get urlNotificacionesWs =>
      'ws://$hostConsultas:$portConsultas/ws/notifications';

  /// Base URL para LazoExpress (con protocolo http://)
  static String get urlLazoExpress =>
      'http://$hostLazoExpress:$portLazoExpress';

  /// Host con protocolo para Socket.IO Flask
  static String get urlFlask =>
      'http://$hostFlask';

  /// Host con protocolo para Socket.IO LazoExpress
  static String get urlLazoExpressSocket =>
      'http://$hostLazoExpress';
}

