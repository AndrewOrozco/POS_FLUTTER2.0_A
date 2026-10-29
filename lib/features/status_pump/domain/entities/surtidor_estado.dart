import 'package:flutter/material.dart';
import 'combustible_color.dart';
import 'status_pump_fase.dart';

/// Estados posibles de un surtidor
/// Basado en los códigos de Flask/Core Gilbarco
enum EstadoSurtidor {
  idle(100, 'ESPERA', 'En espera'),
  authorizationInProgress(101, 'AUTORIZANDO', 'Autorización en progreso'),
  fueling(103, 'DESPACHANDO', 'Despachando combustible'),
  terminatedPEOT(105, 'TERMINADO', 'Venta terminada (PEOT)'),
  terminatedFEOT(106, 'TERMINADO', 'Venta terminada (FEOT)'),
  unknown(0, 'DESCONOCIDO', 'Estado desconocido');

  final int codigo;
  final String nombre;
  final String descripcion;

  const EstadoSurtidor(this.codigo, this.nombre, this.descripcion);

  /// Obtener estado desde código numérico
  static EstadoSurtidor fromCodigo(int codigo) {
    return EstadoSurtidor.values.firstWhere(
      (e) => e.codigo == codigo,
      orElse: () => EstadoSurtidor.unknown,
    );
  }

  /// Estado simplificado para UI (1-4 como en la UI Java)
  int get estadoUI {
    switch (this) {
      case EstadoSurtidor.idle:
        return 1; // ESPERA
      case EstadoSurtidor.authorizationInProgress:
        return 2; // DESCOLGADA
      case EstadoSurtidor.fueling:
        return 3; // DESPACHO
      case EstadoSurtidor.terminatedPEOT:
      case EstadoSurtidor.terminatedFEOT:
        return 4; // FIN DE VENTA
      default:
        return 0;
    }
  }

  bool get estaActivo =>
      this == EstadoSurtidor.authorizationInProgress ||
      this == EstadoSurtidor.fueling ||
      this == EstadoSurtidor.terminatedPEOT ||
      this == EstadoSurtidor.terminatedFEOT;
}

/// Modelo de datos para el estado de un surtidor bajo arquitectura reactiva StatusPump NEW
class SurtidorEstado {
  final int surtidorId;
  final int cara;
  final int manguera;
  final EstadoSurtidor estado;
  final StatusPumpFase fase;
  final String producto;
  final double monto;
  final double volumen;
  final double precioUnidad;
  final String descripcion;
  final DateTime timestamp;

  // Temporizador y control de ciclo de vida
  final DateTime? deadlineFin;
  final bool gestionaVenta;
  final bool ventaAFidelizar;
  final bool isRumbo;
  final bool isClientePropio;
  final int idMovimiento;
  final bool ventaInsertadaEnBd;

  // Datos de cliente / vehículo
  final String? placa;
  final String? clienteNombre;
  final String? authorizationIdentifier;
  final String? medioPagoEspecial; // "APP TERPEL", "GOPASS", etc.

  SurtidorEstado({
    required this.surtidorId,
    required this.cara,
    required this.manguera,
    required this.estado,
    this.fase = StatusPumpFase.idle,
    this.producto = '',
    this.monto = 0.0,
    this.volumen = 0.0,
    this.precioUnidad = 0.0,
    this.descripcion = '',
    DateTime? timestamp,
    this.deadlineFin,
    this.gestionaVenta = false,
    this.ventaAFidelizar = false,
    this.isRumbo = false,
    this.isClientePropio = false,
    this.idMovimiento = 0,
    this.ventaInsertadaEnBd = false,
    this.placa,
    this.clienteNombre,
    this.authorizationIdentifier,
    this.medioPagoEspecial,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Segundos restantes para el vencimiento de FIN_DESPACHO (ej. 80s -> 0s)
  int get segundosRestantesFin {
    if (deadlineFin == null) return 0;
    final diff = deadlineFin!.difference(DateTime.now()).inSeconds;
    return diff > 0 ? diff : 0;
  }

  /// Indica si la cara está en fase de despacho activo
  bool get esDespachando =>
      fase == StatusPumpFase.despacho || estado == EstadoSurtidor.fueling;

  /// Indica si la cara está en ventana de fin de despacho
  bool get esFinDespacho =>
      fase == StatusPumpFase.finDespacho ||
      estado == EstadoSurtidor.terminatedPEOT ||
      estado == EstadoSurtidor.terminatedFEOT;

  /// Indica si la venta está terminada pero pendiente de gestión
  bool get esVentaPendienteGestion => esFinDespacho && !gestionaVenta;

  /// Indica si el botón Asignar datos debe estar disponible
  bool get puedeAsignarDatos => esFinDespacho && !gestionaVenta;

  /// Determina si la cara debe mostrarse en la UI activa
  bool get estaActivo =>
      esDespachando ||
      esFinDespacho ||
      estado == EstadoSurtidor.authorizationInProgress;

  /// Color corporativo de combustible asignado a esta manguera
  Color get colorProducto => CombustibleColor.fromProducto(producto);

  /// Regla de negocio ISO: Ventas especiales (Rumbo, fidelizada, cliente propio)
  bool get esVentaEspecial =>
      ventaAFidelizar || isRumbo || isClientePropio;

  /// Regla de negocio: Si es venta especial, Medios de Pago está deshabilitado
  bool get permiteMediosPago => !esVentaEspecial;

  /// Factory desde JSON recibido de Flask SurtidorAPI
  factory SurtidorEstado.fromFlaskJson(Map<String, dynamic> json) {
    final codigoEstado = json['codigoEstadoSurtidor'] ?? 
                         json['estado_publico'] ?? 
                         json['estado'] ?? 0;
    
    final est = EstadoSurtidor.fromCodigo(codigoEstado);

    // Determinar fase inicial según código
    StatusPumpFase faseInicial = StatusPumpFase.idle;
    if (est == EstadoSurtidor.fueling || est == EstadoSurtidor.authorizationInProgress) {
      faseInicial = StatusPumpFase.despacho;
    } else if (est == EstadoSurtidor.terminatedPEOT || est == EstadoSurtidor.terminatedFEOT) {
      faseInicial = StatusPumpFase.finDespacho;
    }

    return SurtidorEstado(
      surtidorId: json['surtidor_id'] ?? json['surtidor'] ?? 0,
      cara: json['numeroCara'] ?? json['cara'] ?? 0,
      manguera: json['numeroMangueraSurtidor'] ?? json['manguera'] ?? 1,
      estado: est,
      fase: faseInicial,
      producto: json['producto'] ?? '',
      monto: (json['monto'] ?? 0).toDouble(),
      volumen: (json['volumen'] ?? 0).toDouble(),
      precioUnidad: (json['precioUnidad'] ?? 0).toDouble(),
      descripcion: json['descripcion'] ?? json['mensaje'] ?? '',
      placa: json['placa'],
      clienteNombre: json['clienteNombre'],
      authorizationIdentifier: json['saleAuthorizationIdentifier'],
      medioPagoEspecial: json['medioPagoEspecial'],
    );
  }

  /// Copiar con nuevos valores
  SurtidorEstado copyWith({
    int? surtidorId,
    int? cara,
    int? manguera,
    EstadoSurtidor? estado,
    StatusPumpFase? fase,
    String? producto,
    double? monto,
    double? volumen,
    double? precioUnidad,
    String? descripcion,
    DateTime? deadlineFin,
    bool? gestionaVenta,
    bool? ventaAFidelizar,
    bool? isRumbo,
    bool? isClientePropio,
    int? idMovimiento,
    bool? ventaInsertadaEnBd,
    String? placa,
    String? clienteNombre,
    String? authorizationIdentifier,
    String? medioPagoEspecial,
  }) {
    return SurtidorEstado(
      surtidorId: surtidorId ?? this.surtidorId,
      cara: cara ?? this.cara,
      manguera: manguera ?? this.manguera,
      estado: estado ?? this.estado,
      fase: fase ?? this.fase,
      producto: producto ?? this.producto,
      monto: monto ?? this.monto,
      volumen: volumen ?? this.volumen,
      precioUnidad: precioUnidad ?? this.precioUnidad,
      descripcion: descripcion ?? this.descripcion,
      deadlineFin: deadlineFin ?? this.deadlineFin,
      gestionaVenta: gestionaVenta ?? this.gestionaVenta,
      ventaAFidelizar: ventaAFidelizar ?? this.ventaAFidelizar,
      isRumbo: isRumbo ?? this.isRumbo,
      isClientePropio: isClientePropio ?? this.isClientePropio,
      idMovimiento: idMovimiento ?? this.idMovimiento,
      ventaInsertadaEnBd: ventaInsertadaEnBd ?? this.ventaInsertadaEnBd,
      placa: placa ?? this.placa,
      clienteNombre: clienteNombre ?? this.clienteNombre,
      authorizationIdentifier: authorizationIdentifier ?? this.authorizationIdentifier,
      medioPagoEspecial: medioPagoEspecial ?? this.medioPagoEspecial,
    );
  }

  @override
  String toString() {
    return 'SurtidorEstado(cara: $cara, fase: $fase, estado: ${estado.nombre}, monto: $monto, volumen: $volumen, restantes: ${segundosRestantesFin}s)';
  }
}
