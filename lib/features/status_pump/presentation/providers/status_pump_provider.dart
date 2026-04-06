import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../../core/services/socket_io_service.dart';
import '../../domain/entities/surtidor_estado.dart';

/// Evento emitido cuando un surtidor con APP TERPEL termina de despachar
/// La UI debe escuchar esto para enviar el pago al orquestador
class AppTerpelVentaTerminada {
  final int cara;
  final double monto;
  final String medioPago;
  
  AppTerpelVentaTerminada({required this.cara, required this.monto, required this.medioPago});
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

/// Provider para manejar el estado de los surtidores
/// Escucha eventos de Socket.IO y actualiza la UI
class StatusPumpProvider extends ChangeNotifier {
  final SocketIOService _socketService = SocketIOService();
  
  // Mapa de surtidores activos (cara -> estado)
  final Map<int, SurtidorEstado> _surtidores = {};
  bool _isConnected = false;
  String _connectionError = '';
  
  // Placas pendientes de RUMBO (cara -> {placa, clienteNombre})
  // Se asignan antes de que el surtidor comience a despachar
  final Map<int, _PlacaPendiente> _placasPendientes = {};
  
  StreamSubscription? _estadoSubscription;
  StreamSubscription? _connectionSubscription;

  // Stream para notificar cuando un surtidor con APP TERPEL termina de despachar
  final StreamController<AppTerpelVentaTerminada> _appTerpelTerminadaController =
      StreamController<AppTerpelVentaTerminada>.broadcast();
  Stream<AppTerpelVentaTerminada> get appTerpelTerminadaStream => _appTerpelTerminadaController.stream;

  // Stream para notificar cuando CUALQUIER venta termina (para impresión automática)
  final StreamController<VentaTerminada> _ventaTerminadaController =
      StreamController<VentaTerminada>.broadcast();
  Stream<VentaTerminada> get ventaTerminadaStream => _ventaTerminadaController.stream;

  // Getters
  Map<int, SurtidorEstado> get surtidores => Map.unmodifiable(_surtidores);
  List<SurtidorEstado> get surtidoresActivos => 
      _surtidores.values.where((s) => s.estado.estaActivo).toList();
  bool get isConnected => _isConnected;
  String get connectionError => _connectionError;
  bool get hasSurtidoresActivos => surtidoresActivos.isNotEmpty;

  /// Inicializar conexión con Flask
  void initialize({String host = 'http://127.0.0.1', int port = 5000}) {
    debugPrint('[StatusPumpProvider] Inicializando conexión a $host:$port');
    
    // Escuchar estados de surtidor
    _estadoSubscription = _socketService.estadoSurtidorStream.listen(
      _onEstadoSurtidorRecibido,
      onError: (error) {
        debugPrint('[StatusPumpProvider] Error en stream: $error');
        _connectionError = error.toString();
        notifyListeners();
      },
    );
    
    // Escuchar estado de conexión
    _connectionSubscription = _socketService.connectionStatusStream.listen(
      (connected) {
        _isConnected = connected;
        if (connected) {
          _connectionError = '';
        }
        notifyListeners();
      },
    );
    
    // Conectar
    _socketService.connect(host: host, port: port);
  }

  /// Manejar estado de surtidor recibido de Flask
  void _onEstadoSurtidorRecibido(Map<String, dynamic> data) {
    try {
      final estado = SurtidorEstado.fromFlaskJson(data);
      debugPrint('[StatusPumpProvider] Estado recibido: $estado');
      
      // Actualizar o agregar surtidor
      if (estado.estado == EstadoSurtidor.idle || 
          estado.estado == EstadoSurtidor.terminatedPEOT ||
          estado.estado == EstadoSurtidor.terminatedFEOT) {
        final existente = _surtidores[estado.cara];
        
        // Emitir evento de venta terminada para TODAS las ventas (impresión automática)
        if (estado.estado == EstadoSurtidor.terminatedPEOT || 
            estado.estado == EstadoSurtidor.terminatedFEOT) {
          final montoVenta = existente?.monto ?? 0.0;
          debugPrint('[StatusPumpProvider] Venta terminada en cara ${estado.cara}, monto: $montoVenta');
          _ventaTerminadaController.add(VentaTerminada(
            cara: estado.cara,
            monto: montoVenta,
          ));
        }
        
        // Verificar si tenía APP TERPEL asignado
        if (existente != null && 
            existente.medioPagoEspecial != null &&
            existente.medioPagoEspecial!.toUpperCase().contains('APP TERPEL') &&
            (estado.estado == EstadoSurtidor.terminatedPEOT || 
             estado.estado == EstadoSurtidor.terminatedFEOT)) {
          // La venta terminó de despachar Y tenía APP TERPEL asignado
          // → Emitir evento para que la UI envíe al orquestador
          debugPrint('[StatusPumpProvider] Venta con APP TERPEL terminada en cara ${estado.cara}');
          _appTerpelTerminadaController.add(AppTerpelVentaTerminada(
            cara: estado.cara,
            monto: existente.monto,
            medioPago: existente.medioPagoEspecial!,
          ));
        }
        // Remover si está en espera o terminado
        _surtidores.remove(estado.cara);
      } else {
        // Preservar placa/clienteNombre/medioPagoEspecial si ya estaban asignados
        // (Flask no sabe de GOPASS/APP TERPEL, así que no envía estos datos)
        final existente = _surtidores[estado.cara];
        final tienePlaca = existente != null && existente.placa != null && existente.placa!.isNotEmpty;
        final tieneMedioEspecial = existente != null && existente.medioPagoEspecial != null && existente.medioPagoEspecial!.isNotEmpty;
        
        // Verificar si hay placa pendiente de RUMBO para esta cara
        final pendiente = _placasPendientes[estado.cara];
        final tienePendiente = pendiente != null && !pendiente.expirada;
        
        if (tienePlaca || tieneMedioEspecial) {
          // Actualizar datos del surtidor PERO conservar placa, clienteNombre y medioPagoEspecial
          _surtidores[estado.cara] = estado.copyWith(
            placa: tienePlaca ? existente.placa : null,
            clienteNombre: tienePlaca ? existente.clienteNombre : null,
            medioPagoEspecial: tieneMedioEspecial ? existente.medioPagoEspecial : null,
          );
        } else if (tienePendiente) {
          // Aplicar placa pendiente de RUMBO (primera vez que aparece el surtidor)
          _surtidores[estado.cara] = estado.copyWith(
            placa: pendiente.placa,
            clienteNombre: pendiente.clienteNombre,
          );
          _placasPendientes.remove(estado.cara);
          debugPrint('[StatusPumpProvider] Placa RUMBO aplicada: cara=${estado.cara} placa=${pendiente.placa}');
        } else {
          _surtidores[estado.cara] = estado;
        }
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('[StatusPumpProvider] Error parseando estado: $e');
    }
  }

  /// Obtener estado de un surtidor específico
  SurtidorEstado? getSurtidor(int cara) => _surtidores[cara];

  /// Asignar placa GOPASS a un surtidor (después de seleccionar medio de pago)
  /// Actualiza el SurtidorEstado con la placa y nombre del cliente
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

  /// Pre-asignar placa RUMBO a una cara (antes de que comience a despachar)
  /// Cuando el surtidor aparezca en el mapa, la placa se aplicará automáticamente
  void asignarPlacaRumbo(int cara, String placa, {String? clienteNombre}) {
    // Si el surtidor ya existe, aplicar directamente
    final surtidor = _surtidores[cara];
    if (surtidor != null) {
      _surtidores[cara] = surtidor.copyWith(
        placa: placa,
        clienteNombre: clienteNombre,
      );
      notifyListeners();
    } else {
      // Guardar como pendiente para cuando el surtidor aparezca
      _placasPendientes[cara] = _PlacaPendiente(
        placa: placa,
        clienteNombre: clienteNombre,
      );
    }
    debugPrint('[StatusPumpProvider] Placa RUMBO asignada: cara=$cara placa=$placa');
  }

  /// Asignar medio de pago especial (APP TERPEL, etc.) a un surtidor
  /// Muestra un badge en la tarjeta del surtidor
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
    return surtidor?.estado.estaActivo ?? false;
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
    _socketService.disconnect();
    _surtidores.clear();
    _isConnected = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _estadoSubscription?.cancel();
    _connectionSubscription?.cancel();
    _appTerpelTerminadaController.close();
    _ventaTerminadaController.close();
    _socketService.dispose();
    super.dispose();
  }
}