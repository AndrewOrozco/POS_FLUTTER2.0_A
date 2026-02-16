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
      this == EstadoSurtidor.fueling;
}

/// Modelo de datos para el estado de un surtidor
class SurtidorEstado {
  final int surtidorId;
  final int cara;
  final int manguera;
  final EstadoSurtidor estado;
  final String producto;
  final double monto;
  final double volumen;
  final double precioUnidad;
  final String descripcion;
  final DateTime timestamp;

  // Datos opcionales para ventas RUMBO/GOPASS/APP TERPEL
  final String? placa;
  final String? clienteNombre;
  final String? authorizationIdentifier;
  final String? medioPagoEspecial; // "APP TERPEL", "GOPASS", etc.

  SurtidorEstado({
    required this.surtidorId,
    required this.cara,
    required this.manguera,
    required this.estado,
    this.producto = '',
    this.monto = 0.0,
    this.volumen = 0.0,
    this.precioUnidad = 0.0,
    this.descripcion = '',
    DateTime? timestamp,
    this.placa,
    this.clienteNombre,
    this.authorizationIdentifier,
    this.medioPagoEspecial,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Factory desde JSON de Flask
  factory SurtidorEstado.fromFlaskJson(Map<String, dynamic> json) {
    final codigoEstado = json['codigoEstadoSurtidor'] ?? 
                         json['estado_publico'] ?? 
                         json['estado'] ?? 0;
    
    return SurtidorEstado(
      surtidorId: json['surtidor_id'] ?? json['surtidor'] ?? 0,
      cara: json['numeroCara'] ?? json['cara'] ?? 0,
      manguera: json['numeroMangueraSurtidor'] ?? json['manguera'] ?? 0,
      estado: EstadoSurtidor.fromCodigo(codigoEstado),
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
    String? producto,
    double? monto,
    double? volumen,
    double? precioUnidad,
    String? descripcion,
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
      producto: producto ?? this.producto,
      monto: monto ?? this.monto,
      volumen: volumen ?? this.volumen,
      precioUnidad: precioUnidad ?? this.precioUnidad,
      descripcion: descripcion ?? this.descripcion,
      placa: placa ?? this.placa,
      clienteNombre: clienteNombre ?? this.clienteNombre,
      authorizationIdentifier: authorizationIdentifier ?? this.authorizationIdentifier,
      medioPagoEspecial: medioPagoEspecial ?? this.medioPagoEspecial,
    );
  }

  @override
  String toString() {
    return 'SurtidorEstado(cara: $cara, estado: ${estado.nombre}, monto: $monto, volumen: $volumen)';
  }
}
