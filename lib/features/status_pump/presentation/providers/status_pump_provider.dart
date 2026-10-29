import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../../core/services/socket_io_service.dart';
import '../../../../core/services/notification_websocket_service.dart';
import '../../../../core/services/api_consultas_service.dart';
import '../../domain/entities/surtidor_estado.dart';
import '../../domain/entities/status_pump_fase.dart';
import '../../domain/ports/in/status_pump_use_cases.dart';

/// Evento emitido cuando un surtidor con APP TERPEL termina de despachar
/// La UI debe escuchar esto para enviar el pago al orquestador
class AppTerpelVentaTerminada {
  final int cara;
  final double monto;
  final String medioPago;

  AppTerpelVentaTerminada({
    required this.cara,
    required this.monto,
    required this.medioPago,
  });
}

/// Evento emitido cuando CUALQUIER venta termina de despachar (PEOT/FEOT)
/// Usado para disparar la impresión automática del ticket
class VentaTerminada {
  final int cara;
  final double monto;
  final DateTime timestamp;

  VentaTerminada({required this.cara, required this.monto})
      : timestamp = DateTime.now();
}

/// Placa pendiente de asignar cuando el surtidor comience a despachar
class _PlacaPendiente {
  final String placa;
  final String? clienteNombre;
  final DateTime timestamp;

  _PlacaPendiente({required this.placa, this.clienteNombre})
      : timestamp = DateTime.now();

  /// Expirar después de 5 minutos (margen amplio para autorización RUMBO)
  bool get expirada => DateTime.now().difference(timestamp).inMinutes > 5;
}

/// Provider para manejar el estado de los surtidores según arquitectura reactiva StatusPump NEW
/// Escucha eventos de Socket.IO (SurtidorAPI) y gestiona el ciclo de vida y temporizadores
class StatusPumpProvider extends ChangeNotifier {
  final SocketIOService _socketService = SocketIOService();
  final SeleccionarCaraUseCase _seleccionarCaraUseCase = SeleccionarCaraUseCase();
  final ConfirmarVentaLazoUseCase _confirmarVentaLazoUseCase = ConfirmarVentaLazoUseCase();
  final MarcarVentaGestionadaUseCase _marcarVentaGestionadaUseCase = MarcarVentaGestionadaUseCase();

  // Tiempos oficiales de expiración (en segundos)
  static const int tiempoExpiracionNoGestionadaSegundos = 80; // Margen visible amplio (60-80s)
  static const int tiempoExpiracionGestionadaSegundos = 10;   // 10 segundos tras gestionar

  // Mapa de surtidores activos (cara -> estado)
  final Map<int, SurtidorEstado> _surtidores = {};
  bool _isConnected = false;
  String _connectionError = '';

  // Cara seleccionada por el operario en el selector de mangueras
  int? _caraSeleccionada;

  // Placas pendientes de RUMBO (cara -> {placa, clienteNombre})
  final Map<int, _PlacaPendiente> _placasPendientes = {};

  // Temporizador de 1 segundo para actualizar la cuenta regresiva en pantalla
  Timer? _expiryTimer;

  StreamSubscription? _estadoSubscription;
  StreamSubscription? _connectionSubscription;
  StreamSubscription? _notifSubscription;

  // Stream para notificar cuando un surtidor con APP TERPEL termina de despachar
  final StreamController<AppTerpelVentaTerminada> _appTerpelTerminadaController =
      StreamController<AppTerpelVentaTerminada>.broadcast();
  Stream<AppTerpelVentaTerminada> get appTerpelTerminadaStream =>
      _appTerpelTerminadaController.stream;

  // Stream para notificar cuando CUALQUIER venta termina (para impresión automática)
  final StreamController<VentaTerminada> _ventaTerminadaController =
      StreamController<VentaTerminada>.broadcast();
  Stream<VentaTerminada> get ventaTerminadaStream =>
      _ventaTerminadaController.stream;

  // Getters
  Map<int, SurtidorEstado> get surtidores => Map.unmodifiable(_surtidores);

  /// Lista de surtidores que están despachando o en ventana de fin de despacho
  List<SurtidorEstado> get surtidoresActivos =>
      _surtidores.values.where((s) => s.estaActivo).toList();

  int? get caraSeleccionada => _caraSeleccionada;
  bool get isConnected => _isConnected;
  String get connectionError => _connectionError;
  bool get hasSurtidoresActivos => surtidoresActivos.isNotEmpty;

  /// Cambia la cara enfocada en pantalla (Uso del caso de uso SeleccionarCaraUseCase)
  void seleccionarCara(int cara) {
    final nueva = _seleccionarCaraUseCase.execute(
      caraActual: _caraSeleccionada,
      nuevaCara: cara,
      surtidores: _surtidores,
    );
    if (nueva != _caraSeleccionada) {
      _caraSeleccionada = nueva;
      notifyListeners();
    }
  }

  /// Inicializar conexión con Flask SurtidorAPI
  void initialize({String host = 'http://127.0.0.1', int port = 5000}) {
    debugPrint('[StatusPumpProvider] Inicializando conexión a $host:$port');

    _estadoSubscription = _socketService.estadoSurtidorStream.listen(
      _onEstadoSurtidorRecibido,
      onError: (error) {
        debugPrint('[StatusPumpProvider] Error en stream: $error');
        _connectionError = error.toString();
        notifyListeners();
      },
    );

    _connectionSubscription = _socketService.connectionStatusStream.listen(
      (connected) {
        _isConnected = connected;
        if (connected) {
          _connectionError = '';
        }
        notifyListeners();
      },
    );

    _socketService.connect(host: host, port: port);

    // Escuchar notificaciones del backend Python (8020) para confirmaciones de LazoExpress
    _notifSubscription?.cancel();
    _notifSubscription = NotificationWebSocketService().notificationStream.listen((notif) {
      if (notif.cara != null) {
        if (notif.type == 'venta_insertada' ||
            notif.type == 'fe_ok' ||
            notif.type == 'lazo_insertada' ||
            notif.movimientoId != null) {
          debugPrint('[StatusPumpProvider] Notificación de inserción de venta recibida: cara=${notif.cara}, mov=${notif.movimientoId}');
          confirmarVentaLazo(notif.cara!, movimientoId: notif.movimientoId);
        }
      }
    });
  }

  /// Maneja los eventos de estado del surtidor desde Socket.IO
  void _onEstadoSurtidorRecibido(Map<String, dynamic> data) {
    try {
      final estado = SurtidorEstado.fromFlaskJson(data);
      final cara = estado.cara;
      if (cara <= 0) return;

      final existente = _surtidores[cara];

      // Auto-seleccionar la primera cara que aparezca si no hay ninguna seleccionada
      _caraSeleccionada ??= cara;

      // ─────────────────────────────────────────────────────────────
      // CASO 1: IDLE / EN ESPERA (Estado 100)
      // ─────────────────────────────────────────────────────────────
      if (estado.estado == EstadoSurtidor.idle) {
        // Solo remover si NO estamos en fin de despacho activo
        if (existente == null || !existente.esFinDespacho) {
          _surtidores.remove(cara);
          if (_caraSeleccionada == cara) {
            _caraSeleccionada = surtidoresActivos.firstOrNull?.cara;
          }
          notifyListeners();
        }
        return;
      }

      // ─────────────────────────────────────────────────────────────
      // CASO 2: FIN DE DESPACHO (Estados 105 PEOT o 106 FEOT)
      // ─────────────────────────────────────────────────────────────
      if (estado.estado == EstadoSurtidor.terminatedPEOT ||
          estado.estado == EstadoSurtidor.terminatedFEOT) {
        
        final yaEnFin = existente != null && existente.esFinDespacho;

        // Si ya estamos en fin de despacho y llega un evento secundario con monto 0 (ej. reseteo 106 en CoreGilbarco),
        // ignorar para no sobrescribir la venta final ni el contador
        if (yaEnFin && estado.monto <= 0 && existente.monto > 0) {
          debugPrint('[STATUS_PUMP_AUDIT] Cara $cara: ignorando evento 106 duplicado con monto 0. Venta preservada: ${existente.monto}');
          return;
        }

        final montoFinal = estado.monto > 0 ? estado.monto : (existente?.monto ?? 0.0);
        final volumenFinal = estado.volumen > 0 ? estado.volumen : (existente?.volumen ?? 0.0);
        final gestionada = existente?.gestionaVenta ?? false;
        final esEspecial = existente?.esVentaEspecial ?? false;

        // Calcular duración del temporizador: 10s si ya fue gestionada, 80s si está pendiente
        final segundosExpiracion = (gestionada || esEspecial)
            ? tiempoExpiracionGestionadaSegundos
            : tiempoExpiracionNoGestionadaSegundos;

        // Si es la primera vez que entra a fin de despacho, crear deadline
        final deadline = yaEnFin && existente.deadlineFin != null
            ? existente.deadlineFin!
            : DateTime.now().add(Duration(seconds: segundosExpiracion));

        final actualizado = (existente ?? estado).copyWith(
          estado: estado.estado,
          fase: StatusPumpFase.finDespacho,
          monto: montoFinal,
          volumen: volumenFinal,
          precioUnidad: estado.precioUnidad > 0 ? estado.precioUnidad : existente?.precioUnidad,
          producto: estado.producto.isNotEmpty ? estado.producto : existente?.producto,
          deadlineFin: deadline,
        );

        _surtidores[cara] = actualizado;
        debugPrint('[STATUS_PUMP_AUDIT] Fin despacho registrado en cara $cara: monto=$montoFinal vol=$volumenFinal expiraEn=${segundosExpiracion}s');

        // Notificar venta terminada para impresión automática
        if (!yaEnFin) {
          debugPrint('[StatusPumpProvider] Venta terminada en cara $cara - monto: $montoFinal, expira en ${segundosExpiracion}s');
          _ventaTerminadaController.add(VentaTerminada(cara: cara, monto: montoFinal));

          // Verificar si tenía APP TERPEL asignado
          if (existente?.medioPagoEspecial != null &&
              existente!.medioPagoEspecial!.toUpperCase().contains('APP TERPEL')) {
            _appTerpelTerminadaController.add(AppTerpelVentaTerminada(
              cara: cara,
              monto: montoFinal,
              medioPago: existente.medioPagoEspecial!,
            ));
          }

          // Consultar asincrónicamente si LazoExpress ya insertó la venta en backend
          _consultarInsercionLazoExpress(cara);
        }

        _asegurarTimerExpiracion();
        notifyListeners();
        return;
      }

      // ─────────────────────────────────────────────────────────────
      // CASO 3: DESPACHANDO (Estado 103) o DESCOLGADA (Estado 101)
      // ─────────────────────────────────────────────────────────────
      final tienePlaca = existente != null && existente.placa != null && existente.placa!.isNotEmpty;
      final tieneMedioEspecial = existente != null && existente.medioPagoEspecial != null && existente.medioPagoEspecial!.isNotEmpty;

      // Verificar si hay placa pendiente de RUMBO
      final pendiente = _placasPendientes[cara];
      final tienePendiente = pendiente != null && !pendiente.expirada;

      // Determinar si comienza un nuevo despacho en esta cara
      final estabaDespachando = existente != null && existente.esDespachando;
      final iniciaDespacho = (estado.estado == EstadoSurtidor.fueling ||
              estado.estado == EstadoSurtidor.authorizationInProgress) &&
          !estabaDespachando;

      // Si la cara estaba en FIN_DESPACHO y ahora empieza nueva venta en la misma cara, reiniciar estado
      final esNuevaVentaMismaCara = existente != null && existente.esFinDespacho;

      _surtidores[cara] = estado.copyWith(
        fase: StatusPumpFase.despacho,
        deadlineFin: null,
        gestionaVenta: esNuevaVentaMismaCara ? false : (existente?.gestionaVenta ?? false),
        ventaInsertadaEnBd: esNuevaVentaMismaCara ? false : (existente?.ventaInsertadaEnBd ?? false),
        idMovimiento: esNuevaVentaMismaCara ? 0 : (existente?.idMovimiento ?? 0),
        placa: tienePlaca
            ? existente.placa
            : (tienePendiente ? pendiente.placa : estado.placa),
        clienteNombre: tienePlaca
            ? existente.clienteNombre
            : (tienePendiente ? pendiente.clienteNombre : estado.clienteNombre),
        medioPagoEspecial: tieneMedioEspecial
            ? existente.medioPagoEspecial
            : estado.medioPagoEspecial,
      );

      if (tienePendiente) {
        _placasPendientes.remove(cara);
      }

      // ERROR 1 SOLUCIÓN: Cuando comienza un despacho en cualquier cara,
      // la interfaz debe enfocar automáticamente esa cara sin sobrescribir
      // la información de las ventas en otras caras.
      if (iniciaDespacho || _caraSeleccionada == null) {
        _caraSeleccionada = cara;
        debugPrint('[STATUS_PUMP_AUDIT] Despacho iniciado en cara $cara -> Enfocada automáticamente');
      }

      notifyListeners();
    } catch (e) {
      debugPrint('[StatusPumpProvider] Error parseando estado: $e');
    }
  }

  /// Inicia el temporizador de 1 segundo para la cuenta regresiva de fin de despacho
  void _asegurarTimerExpiracion() {
    if (_expiryTimer != null && _expiryTimer!.isActive) return;

    _expiryTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final ahora = DateTime.now();
      bool hayCambios = false;
      final carasABorrar = <int>[];

      for (final entry in _surtidores.entries) {
        final s = entry.value;
        if (s.esFinDespacho && s.deadlineFin != null) {
          if (ahora.isAfter(s.deadlineFin!)) {
            // CRITERIO 9: Los temporizadores de fin de despacho NO eliminan ventas pendientes de gestión.
            // Solo archivar si YA fue gestionada (gestionaVenta == true o ventaInsertadaEnBd == true).
            if (s.gestionaVenta || s.ventaInsertadaEnBd) {
              carasABorrar.add(entry.key);
            }
            hayCambios = true;
          } else {
            // Cada segundo decrementa el número mostrado en pantalla
            hayCambios = true;
          }
        }
      }

      for (final cara in carasABorrar) {
        debugPrint('[StatusPumpProvider] Cara $cara expiró tiempo de Fin Despacho -> Archivada');
        _surtidores.remove(cara);
        if (_caraSeleccionada == cara) {
          _caraSeleccionada = surtidoresActivos.firstOrNull?.cara;
        }
      }

      // Detener el timer si ya no hay caras en fin de despacho
      final quedanEnFin = _surtidores.values.any((s) => s.esFinDespacho);
      if (!quedanEnFin) {
        timer.cancel();
        _expiryTimer = null;
      }

      if (hayCambios) {
        notifyListeners();
      }
    });
  }

  /// Confirmación recibida de LazoExpress de que la venta fue insertada en BD (ERROR 2)
  void confirmarVentaLazo(int cara, {int? movimientoId}) {
    final existente = _surtidores[cara];
    if (existente == null) return;

    debugPrint('[STATUS_PUMP_AUDIT] Confirmación LazoExpress recibida para cara $cara (movimientoId: $movimientoId)');
    final actualizado = _confirmarVentaLazoUseCase.execute(
      surtidor: existente,
      movimientoId: movimientoId,
      nuevoDeadline: DateTime.now().add(
        const Duration(seconds: tiempoExpiracionGestionadaSegundos),
      ),
    );

    _surtidores[cara] = actualizado;
    _asegurarTimerExpiracion();
    notifyListeners();
  }

  /// Consultar de forma no bloqueante a FastAPI si la venta ya está registrada en BD
  Future<void> _consultarInsercionLazoExpress(int cara) async {
    try {
      final res = await ApiConsultasService().getVentasSinResolver(limite: 5);
      final ventaMatch = res.ventas.where((v) => v.cara == cara).firstOrNull;
      if (ventaMatch != null) {
        debugPrint('[StatusPumpProvider] Venta confirmada en backend para cara $cara: mov=${ventaMatch.id}');
        confirmarVentaLazo(cara, movimientoId: ventaMatch.id);
      }
    } catch (e) {
      debugPrint('[StatusPumpProvider] Verificación de venta en backend diferida: $e');
    }
  }

  /// Marca la venta como gestionada (ej. tras guardar datos de factura)
  /// Si la cara ya está en Fin de Despacho, reduce el temporizador a 10s
  void marcarVentaGestionada(int cara) {
    final surtidor = _surtidores[cara];
    if (surtidor != null) {
      final actualizado = _marcarVentaGestionadaUseCase.execute(
        surtidor: surtidor,
        nuevoDeadline: DateTime.now().add(
          const Duration(seconds: tiempoExpiracionGestionadaSegundos),
        ),
      );
      _surtidores[cara] = actualizado;
      _asegurarTimerExpiracion();
      notifyListeners();
    }
  }

  /// Obtener estado de un surtidor específico
  SurtidorEstado? getSurtidor(int cara) => _surtidores[cara];

  /// Asignar placa a un surtidor (después de seleccionar medio de pago)
  void asignarPlaca(int cara, String placa, {String? clienteNombre}) {
    final surtidor = _surtidores[cara];
    if (surtidor != null) {
      _surtidores[cara] = surtidor.copyWith(
        placa: placa,
        clienteNombre: clienteNombre,
      );
      notifyListeners();
    }
  }

  /// Pre-asignar placa RUMBO a una cara antes de que comience a despachar
  void asignarPlacaRumbo(int cara, String placa, {String? clienteNombre}) {
    final surtidor = _surtidores[cara];
    if (surtidor != null) {
      _surtidores[cara] = surtidor.copyWith(
        placa: placa,
        clienteNombre: clienteNombre,
        isRumbo: true,
      );
      notifyListeners();
    } else {
      _placasPendientes[cara] = _PlacaPendiente(
        placa: placa,
        clienteNombre: clienteNombre,
      );
    }
    debugPrint('[StatusPumpProvider] Placa RUMBO asignada: cara=$cara placa=$placa');
  }

  /// Asignar medio de pago especial (APP TERPEL, etc.)
  void asignarMedioPagoEspecial(int cara, String medioPago) {
    final surtidor = _surtidores[cara];
    if (surtidor != null) {
      _surtidores[cara] = surtidor.copyWith(
        medioPagoEspecial: medioPago,
      );
      notifyListeners();
    }
  }

  /// Verificar si un surtidor está activo
  bool isSurtidorActivo(int cara) {
    final surtidor = _surtidores[cara];
    return surtidor?.estaActivo ?? false;
  }

  /// Reconectar manualmente
  void reconnect() {
    _socketService.disconnect();
    Future.delayed(const Duration(seconds: 1), () {
      _socketService.connect();
    });
  }

  /// Desconectar
  void disconnect() {
    _expiryTimer?.cancel();
    _socketService.disconnect();
    _surtidores.clear();
    _isConnected = false;
    notifyListeners();
  }

  /// Método para testing de widgets y providers
  @visibleForTesting
  void simulateEstadoForTesting({
    required int cara,
    required String producto,
    required double monto,
    required double volumen,
    required double precio,
    required StatusPumpFase fase,
    int? segundosRestantes,
    bool gestionaVenta = false,
    bool ventaInsertadaEnBd = false,
  }) {
    _surtidores[cara] = SurtidorEstado(
      surtidorId: 1,
      cara: cara,
      manguera: 1,
      estado: fase == StatusPumpFase.despacho
          ? EstadoSurtidor.fueling
          : EstadoSurtidor.terminatedFEOT,
      fase: fase,
      producto: producto,
      monto: monto,
      volumen: volumen,
      precioUnidad: precio,
      gestionaVenta: gestionaVenta,
      ventaInsertadaEnBd: ventaInsertadaEnBd,
      deadlineFin: segundosRestantes != null
          ? DateTime.now().add(Duration(seconds: segundosRestantes))
          : null,
    );
    _caraSeleccionada = cara;
    notifyListeners();
  }

  @override
  void dispose() {
    _expiryTimer?.cancel();
    _estadoSubscription?.cancel();
    _connectionSubscription?.cancel();
    _appTerpelTerminadaController.close();
    _ventaTerminadaController.close();
    _socketService.dispose();
    super.dispose();
  }
}