/// Modelos compartidos para el servicio de consultas (FastAPI).
///
/// Contiene todos los modelos de datos usados por ApiConsultasService
/// y otros servicios/widgets que necesitan estas estructuras.
library;

// ============================================================
// VENTAS
// ============================================================

/// Modelo para una venta sin resolver
class VentaSinResolver {
  final int id;
  final String prefijo;
  final String fecha;
  final String producto;
  final int? cara;
  final double cantidad;
  final String unidad;
  final int total;
  final String operador;
  final String proceso;
  final String? estadoDatafono;
  final String? placa;
  final int? codigoAutorizacion;
  // Datos del cliente pre-cargados desde atributos
  final String? clienteNombre;
  final String? clienteIdentificacion;
  final int? clienteTipoDocumento;

  VentaSinResolver({
    required this.id,
    required this.prefijo,
    required this.fecha,
    required this.producto,
    this.cara,
    required this.cantidad,
    required this.unidad,
    required this.total,
    required this.operador,
    required this.proceso,
    this.estadoDatafono,
    this.placa,
    this.codigoAutorizacion,
    this.clienteNombre,
    this.clienteIdentificacion,
    this.clienteTipoDocumento,
  });

  factory VentaSinResolver.fromJson(Map<String, dynamic> json) {
    return VentaSinResolver(
      id: _toInt(json['id']),
      prefijo: json['prefijo'] ?? 'N/A',
      fecha: json['fecha'] ?? '',
      producto: json['producto'] ?? 'N/A',
      cara: _toIntNullable(json['cara']),
      cantidad: _toDouble(json['cantidad']),
      unidad: json['unidad'] ?? 'GL',
      total: _toInt(json['total']),
      operador: json['operador'] ?? 'N/A',
      proceso: json['proceso'] ?? 'Pendiente',
      estadoDatafono: json['estado_datafono'],
      placa: json['placa'],
      codigoAutorizacion: _toIntNullable(json['codigo_autorizacion']),
      clienteNombre: json['cliente_nombre'],
      clienteIdentificacion: json['cliente_identificacion'],
      clienteTipoDocumento: _toIntNullable(json['cliente_tipo_documento']),
    );
  }

  String get totalFormateado => '\$ ${_formatMiles(total)}';
  String get cantidadFormateada => '${cantidad.toStringAsFixed(3)} $unidad';

  static int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
  
  static int? _toIntNullable(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
  
  static double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  String _formatMiles(int value) {
    return value.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]}.',
    );
  }
}

/// Modelo para una venta del historial
class VentaHistorial {
  final int id;
  final String prefijo;
  final String fecha;
  final String producto;
  final int? cara;
  final double cantidad;
  final String unidad;
  final int total;
  final String operador;
  final String? placa;
  final int? idTransmision;
  final bool fidelizada;

  VentaHistorial({
    required this.id,
    required this.prefijo,
    required this.fecha,
    required this.producto,
    this.cara,
    required this.cantidad,
    required this.unidad,
    required this.total,
    required this.operador,
    this.placa,
    this.idTransmision,
    this.fidelizada = false,
  });

  /// Verifica si la venta aún puede ser fidelizada (dentro de 3 minutos)
  bool get puedeFidelizar {
    if (fidelizada) return false;
    try {
      final fechaVenta = DateTime.parse(fecha);
      final diferencia = DateTime.now().difference(fechaVenta);
      return diferencia.inMinutes < 3;
    } catch (_) {
      return false;
    }
  }

  /// Texto descriptivo de por qué no puede fidelizar
  String get motivoNoFidelizar {
    if (fidelizada) return 'Esta venta ya fue fidelizada';
    try {
      final fechaVenta = DateTime.parse(fecha);
      final diferencia = DateTime.now().difference(fechaVenta);
      if (diferencia.inMinutes >= 3) return 'Tiempo máximo de fidelización superado (3 min)';
    } catch (_) {}
    return '';
  }

  factory VentaHistorial.fromJson(Map<String, dynamic> json) {
    return VentaHistorial(
      id: _toInt(json['id']),
      prefijo: json['prefijo'] ?? 'N/A',
      fecha: json['fecha'] ?? '',
      producto: json['producto'] ?? 'N/A',
      cara: _toIntNullable(json['cara']),
      cantidad: _toDouble(json['cantidad']),
      unidad: json['unidad'] ?? 'GL',
      total: _toInt(json['total']),
      operador: json['operador'] ?? 'N/A',
      placa: json['placa'],
      idTransmision: _toIntNullable(json['id_transmision']),
      fidelizada: json['fidelizada'] == true,
    );
  }

  static int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
  
  static int? _toIntNullable(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
  
  static double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  String get totalFormateado => '\$ ${_formatMiles(total)}';
  String get cantidadFormateada => '${cantidad.toStringAsFixed(3)} $unidad';

  String _formatMiles(int value) {
    return value.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]}.',
    );
  }
}

/// Respuesta paginada de ventas
class VentasResponse<T> {
  final int total;
  final int pagina;
  final int porPagina;
  final int totalPaginas;
  final int? jornadaId;
  final List<T> ventas;

  VentasResponse({
    required this.total,
    required this.pagina,
    required this.porPagina,
    required this.totalPaginas,
    this.jornadaId,
    required this.ventas,
  });
}

// ============================================================
// CLIENTE
// ============================================================

/// Tipo de identificación (CC, NIT, CONSUMIDOR FINAL, etc.)
class TipoIdentificacion {
  final String nombre;
  final int codigo;
  final bool aplicaFidelizacion;
  final String caracteresPermitidos;
  final int limiteCaracteres;
  
  TipoIdentificacion({
    required this.nombre,
    required this.codigo,
    required this.aplicaFidelizacion,
    required this.caracteresPermitidos,
    required this.limiteCaracteres,
  });
  
  factory TipoIdentificacion.fromJson(Map<String, dynamic> json) {
    return TipoIdentificacion(
      nombre: json['nombre']?.toString() ?? '',
      codigo: parseInt(json['codigo']),
      aplicaFidelizacion: json['aplica_fidelizacion'] == true,
      caracteresPermitidos: json['caracteres_permitidos']?.toString() ?? '0123456789',
      limiteCaracteres: parseInt(json['limite_caracteres']),
    );
  }
  
  bool get esConsumidorFinal => nombre.toLowerCase().contains('consumidor') || codigo == 42;
  String get identificacionDefecto => esConsumidorFinal ? '222222222222' : '';
}

/// Resultado de consulta de cliente
class ClienteConsulta {
  final bool encontrado;
  final int? id;
  final String identificacion;
  final String nombre;
  final String? email;
  final String? telefono;
  final String? direccion;
  final String tipoIdentificacion;
  /// Respuesta COMPLETA del servicio Terpel (incluye extraData, regimenFiscal, codigoSAP, etc.)
  /// Se usa para construir el objeto factura_electronica que Java LazoExpress espera.
  final Map<String, dynamic>? rawResponse;
  
  ClienteConsulta({
    required this.encontrado,
    this.id,
    required this.identificacion,
    required this.nombre,
    this.email,
    this.telefono,
    this.direccion,
    required this.tipoIdentificacion,
    this.rawResponse,
  });
  
  factory ClienteConsulta.fromJson(Map<String, dynamic> json) {
    final cliente = json['cliente'] as Map<String, dynamic>?;
    return ClienteConsulta(
      encontrado: json['encontrado'] == true,
      id: cliente?['id'],
      identificacion: cliente?['identificacion']?.toString() ?? '',
      nombre: cliente?['nombre']?.toString() ?? 'CONSUMIDOR FINAL',
      email: cliente?['email']?.toString(),
      telefono: cliente?['telefono']?.toString(),
      direccion: cliente?['direccion']?.toString(),
      tipoIdentificacion: cliente?['tipo_identificacion']?.toString() ?? 'CONSUMIDOR FINAL',
      rawResponse: cliente?['raw_response'] as Map<String, dynamic>?,
    );
  }
  
  factory ClienteConsulta.consumidorFinal(String identificacion) {
    return ClienteConsulta(
      encontrado: false,
      identificacion: identificacion,
      nombre: 'CONSUMIDOR FINAL',
      tipoIdentificacion: 'CONSUMIDOR FINAL',
    );
  }
  
  bool get esConsumidorFinal => !encontrado || tipoIdentificacion == 'CONSUMIDOR FINAL';
}

// ============================================================
// MEDIOS DE PAGO
// ============================================================

/// Medio de pago disponible (de la BD)
class MedioPagoConsulta {
  final int id;
  final String codigo;
  final String nombre;
  final int codigoDian;
  final bool requiereVoucher;
  
  MedioPagoConsulta({
    required this.id,
    required this.codigo,
    required this.nombre,
    required this.codigoDian,
    required this.requiereVoucher,
  });
  
  factory MedioPagoConsulta.fromJson(Map<String, dynamic> json) {
    return MedioPagoConsulta(
      id: parseInt(json['id']),
      codigo: json['codigo']?.toString() ?? '',
      nombre: json['nombre']?.toString() ?? '',
      codigoDian: parseInt(json['codigo_dian']),
      requiereVoucher: json['requiere_voucher'] == true,
    );
  }
}

/// Medio de pago ya asignado a una venta
class MedioPagoVentaConsulta {
  final int id;
  final int medioPagoId;
  final String nombre;
  final String voucher;
  final double valor;
  final double valorRecibido;
  final double valorCambio;
  final int? codigoDian;
  
  MedioPagoVentaConsulta({
    required this.id,
    required this.medioPagoId,
    required this.nombre,
    required this.voucher,
    required this.valor,
    required this.valorRecibido,
    required this.valorCambio,
    this.codigoDian,
  });
  
  factory MedioPagoVentaConsulta.fromJson(Map<String, dynamic> json) {
    return MedioPagoVentaConsulta(
      id: parseInt(json['id']),
      medioPagoId: parseInt(json['medio_pago_id']),
      nombre: json['nombre']?.toString() ?? 'SIN NOMBRE',
      voucher: json['voucher']?.toString() ?? '',
      valor: parseDouble(json['valor']),
      valorRecibido: parseDouble(json['valor_recibido']),
      valorCambio: parseDouble(json['valor_cambio']),
      codigoDian: json['codigo_dian'] != null ? parseInt(json['codigo_dian']) : null,
    );
  }
}

/// Medio de pago para enviar al guardar (fnc_actualizar_medios_de_pagos)
class MedioPagoParaGuardar {
  final int ctMediosPagosId;
  final String descripcion;
  final double valorTotal;
  final double valorRecibido;
  final double valorCambio;
  final int? codigoDian;
  final String? numeroComprobante;
  
  MedioPagoParaGuardar({
    required this.ctMediosPagosId,
    this.descripcion = '',
    required this.valorTotal,
    required this.valorRecibido,
    this.valorCambio = 0,
    this.codigoDian,
    this.numeroComprobante,
  });
  
  Map<String, dynamic> toJson() => {
    'ct_medios_pagos_id': ctMediosPagosId,
    'descripcion': descripcion,
    'valor_total': valorTotal,
    'valor_recibido': valorRecibido,
    'valor_cambio': valorCambio,
    'codigo_dian': codigoDian,
    'numero_comprobante': numeroComprobante ?? '',
  };
}

/// Respuesta de actualizar medios de pago
class ActualizarMediosPagoResponse {
  final bool success;
  final String message;
  final int? movimientoId;
  
  ActualizarMediosPagoResponse({required this.success, required this.message, this.movimientoId});
}

/// Respuesta de actualizar datos de venta
class ActualizarDatosVentaResponse {
  final bool success;
  final String message;
  final int? movimientoId;
  
  ActualizarDatosVentaResponse({required this.success, required this.message, this.movimientoId});
}

// ============================================================
// APP TERPEL
// ============================================================

/// Estado del pago APP TERPEL (resultado de fnc_validar_botones_ventas_appterpel)
class AppTerpelEstado {
  final bool pagoEnProceso;
  final bool puedeGestionar;
  
  AppTerpelEstado({required this.pagoEnProceso, required this.puedeGestionar});
}

/// Respuesta del orquestador de pagos APP TERPEL (puerto 5555)
/// Java: PaymentResponse { IDSeguimiento, idTransaccion, estadoPago, technicalCode, mensaje }
class AppTerpelPagoResponse {
  final bool success;
  final String message;
  final int? movimientoId;
  final String idSeguimiento;
  final String idTransaccion;
  final String estadoPago;
  final int technicalCode;
  final String mensajeOrquestador;
  final String? error;
  
  AppTerpelPagoResponse({
    required this.success,
    required this.message,
    this.movimientoId,
    this.idSeguimiento = '',
    this.idTransaccion = '',
    this.estadoPago = '',
    this.technicalCode = 0,
    this.mensajeOrquestador = '',
    this.error,
  });
  
  factory AppTerpelPagoResponse.fromJson(Map<String, dynamic> json) {
    return AppTerpelPagoResponse(
      success: json['success'] == true,
      message: json['message']?.toString() ?? '',
      movimientoId: json['movimiento_id'] != null ? parseInt(json['movimiento_id']) : null,
      idSeguimiento: json['id_seguimiento']?.toString() ?? '',
      idTransaccion: json['id_transaccion']?.toString() ?? '',
      estadoPago: json['estado_pago']?.toString() ?? '',
      technicalCode: parseInt(json['technical_code']),
      mensajeOrquestador: json['mensaje_orquestador']?.toString() ?? '',
      error: json['error']?.toString(),
    );
  }
}

// ============================================================
// VENTAS EN CURSO
// ============================================================

/// Respuesta de guardar medio de pago en ventas_curso (desde Status Pump)
class GuardarMedioVentaCursoResponse {
  final bool success;
  final String message;
  
  GuardarMedioVentaCursoResponse({required this.success, required this.message});
}

/// Venta activa por cara (para resolver movimiento_id)
class VentaActivaCara {
  final bool found;
  final int? movimientoId;
  final int cara;
  final String? source;
  final double? monto;
  final double? volumen;
  final String? estado;
  final bool statusPump;
  
  VentaActivaCara({
    required this.found,
    this.movimientoId,
    required this.cara,
    this.source,
    this.monto,
    this.volumen,
    this.estado,
    this.statusPump = false,
  });
  
  factory VentaActivaCara.fromJson(Map<String, dynamic> json) {
    return VentaActivaCara(
      found: json['found'] == true,
      movimientoId: json['movimiento_id'] != null ? parseInt(json['movimiento_id']) : null,
      cara: parseInt(json['cara']),
      source: json['source']?.toString(),
      monto: json['monto'] != null ? parseDouble(json['monto']) : null,
      volumen: json['volumen'] != null ? parseDouble(json['volumen']) : null,
      estado: json['estado']?.toString(),
      statusPump: json['status_pump'] == true,
    );
  }
}

// ============================================================
// GOPASS
// ============================================================

/// Placa GOPASS consultada desde CentralPoint
class PlacaGopass {
  final String placa;
  final String tagGopass;
  final String nombreUsuario;
  final String isla;
  final String fechahora;
  
  PlacaGopass({
    required this.placa,
    this.tagGopass = '',
    this.nombreUsuario = '',
    this.isla = '',
    this.fechahora = '',
  });
  
  factory PlacaGopass.fromJson(Map<String, dynamic> json) {
    return PlacaGopass(
      placa: json['placa']?.toString() ?? '',
      tagGopass: (json['tagGopass'] ?? json['tag_gopass'])?.toString() ?? '',
      nombreUsuario: (json['nombreUsuario'] ?? json['nombre_usuario'])?.toString() ?? '',
      isla: json['isla']?.toString() ?? '',
      fechahora: json['fechahora']?.toString() ?? '',
    );
  }

  /// Valida 3 o 6 dígitos de la placa (Java: ValidarPlacaGoPassUseCase)
  bool validarDigitos(String digitos) {
    if (digitos.length == 3) {
      return placa.toUpperCase().endsWith(digitos.toUpperCase());
    } else if (digitos.length == 6) {
      return placa.toUpperCase() == digitos.toUpperCase();
    }
    return false;
  }
}

/// Respuesta de consulta de placas GOPASS
class PlacasGopassResponse {
  final bool success;
  final String message;
  final List<PlacaGopass> placas;
  
  PlacasGopassResponse({required this.success, required this.message, required this.placas});
}

// ============================================================
// RUMBO (Gestión de Flotas)
// ============================================================

/// Información de una manguera disponible para RUMBO
class MangueraRumbo {
  final int surtidor;
  final int cara;
  final int manguera;
  final int grado;
  final int productoId;
  final String productoDescripcion;
  final double productoPrecio;
  final int familiaId;
  final String familiaDescripcion;
  final bool bloqueado;
  final String? motivoBloqueo;
  final bool esUrea;

  MangueraRumbo({
    required this.surtidor,
    required this.cara,
    required this.manguera,
    required this.grado,
    required this.productoId,
    required this.productoDescripcion,
    required this.productoPrecio,
    required this.familiaId,
    required this.familiaDescripcion,
    this.bloqueado = false,
    this.motivoBloqueo,
    this.esUrea = false,
  });

  factory MangueraRumbo.fromJson(Map<String, dynamic> json) {
    return MangueraRumbo(
      surtidor: parseInt(json['surtidor']),
      cara: parseInt(json['cara']),
      manguera: parseInt(json['manguera']),
      grado: parseInt(json['grado']),
      productoId: parseInt(json['producto_id']),
      productoDescripcion: json['producto_descripcion'] ?? 'N/A',
      productoPrecio: parseDouble(json['producto_precio']),
      familiaId: parseInt(json['familia_id']),
      familiaDescripcion: json['familia_descripcion'] ?? 'N/A',
      bloqueado: json['bloqueado'] == true,
      motivoBloqueo: json['motivo_bloqueo'],
      esUrea: json['es_urea'] == true,
    );
  }
}

/// Medio de identificación RUMBO (Ibutton, RFID, Tarjeta, Código)
class MedioIdentificacionRumbo {
  final int id;
  final String descripcion;
  final bool requiereLector;
  final String icono;

  MedioIdentificacionRumbo({
    required this.id,
    required this.descripcion,
    required this.requiereLector,
    required this.icono,
  });

  factory MedioIdentificacionRumbo.fromJson(Map<String, dynamic> json) {
    return MedioIdentificacionRumbo(
      id: parseInt(json['id']),
      descripcion: json['descripcion'] ?? '',
      requiereLector: json['requiere_lector'] == true,
      icono: json['icono'] ?? 'help',
    );
  }
}

/// Respuesta de autorización RUMBO
class AutorizarRumboResponse {
  final bool autorizado;
  final String mensaje;
  final String? identificadorAutorizacion;
  final String? placaVehiculo;
  final String? nombreCliente;
  final String? documentoCliente;
  final String? programaCliente;
  final double? montoMaximo;
  final double? cantidadMaxima;
  final bool requiereDatosAdicionales;
  final bool requierePlaca;
  final bool requiereCodigoSeguridad;
  final int? timeoutAutorizacion;      // Segundos para despachar
  final int? timeoutDatosAdicionales;  // Segundos para datos adicionales
  final Map<String, dynamic>? dataCompleta;
  final bool esUrea;                   // Si es UREA/AdBlue, flujo diferente
  final double? litrosAutorizados;     // Solo para UREA: litros que puede despachar

  AutorizarRumboResponse({
    required this.autorizado,
    required this.mensaje,
    this.identificadorAutorizacion,
    this.placaVehiculo,
    this.nombreCliente,
    this.documentoCliente,
    this.programaCliente,
    this.montoMaximo,
    this.cantidadMaxima,
    this.requiereDatosAdicionales = false,
    this.requierePlaca = false,
    this.requiereCodigoSeguridad = false,
    this.timeoutAutorizacion,
    this.timeoutDatosAdicionales,
    this.dataCompleta,
    this.esUrea = false,
    this.litrosAutorizados,
  });

  factory AutorizarRumboResponse.fromJson(Map<String, dynamic> json) {
    return AutorizarRumboResponse(
      autorizado: json['autorizado'] == true,
      mensaje: json['mensaje'] ?? '',
      identificadorAutorizacion: json['identificador_autorizacion'],
      placaVehiculo: json['placa_vehiculo'],
      nombreCliente: json['nombre_cliente'],
      documentoCliente: json['documento_cliente'],
      programaCliente: json['programa_cliente'],
      montoMaximo: (json['monto_maximo'] is num) ? (json['monto_maximo'] as num).toDouble() : null,
      cantidadMaxima: (json['cantidad_maxima'] is num) ? (json['cantidad_maxima'] as num).toDouble() : null,
      requiereDatosAdicionales: json['requiere_datos_adicionales'] == true,
      requierePlaca: json['requiere_placa'] == true,
      requiereCodigoSeguridad: json['requiere_codigo_seguridad'] == true,
      timeoutAutorizacion: parseIntNullable(json['timeout_autorizacion']),
      timeoutDatosAdicionales: parseIntNullable(json['timeout_datos_adicionales']),
      dataCompleta: json['data_completa'] is Map<String, dynamic> 
          ? json['data_completa'] 
          : null,
      esUrea: json['es_urea'] == true,
      litrosAutorizados: (json['litros_autorizados'] is num) ? (json['litros_autorizados'] as num).toDouble() : null,
    );
  }
}

// ============================================================
// GoPass - Transacción
// ============================================================

class TransaccionGopass {
  final int? idTransaccionGopass;
  final int? idVentaTerpel;
  final int? idMovimiento;
  final String? idMovimientoCompuesto;
  final int? isla;
  final int? surtidor;
  final int? cara;
  final int? valor;
  final String placa;
  final String codigoEds;
  final String estado;
  final String fecha;

  TransaccionGopass({
    this.idTransaccionGopass,
    this.idVentaTerpel,
    this.idMovimiento,
    this.idMovimientoCompuesto,
    this.isla,
    this.surtidor,
    this.cara,
    this.valor,
    this.placa = '',
    this.codigoEds = '',
    this.estado = '',
    this.fecha = '',
  });

  factory TransaccionGopass.fromJson(Map<String, dynamic> json) {
    return TransaccionGopass(
      idTransaccionGopass: parseIntNullable(json['id_transaccion_gopass']),
      idVentaTerpel: parseIntNullable(json['id_venta_terpel']),
      idMovimiento: parseIntNullable(json['id_movimiento']),
      idMovimientoCompuesto: json['id_movimiento_compuesto']?.toString(),
      isla: parseIntNullable(json['isla']),
      surtidor: parseIntNullable(json['surtidor']),
      cara: parseIntNullable(json['cara']),
      valor: parseIntNullable(json['valor']),
      placa: json['placa']?.toString() ?? '',
      codigoEds: json['codigo_eds']?.toString() ?? '',
      estado: json['estado']?.toString() ?? '',
      fecha: json['fecha']?.toString() ?? '',
    );
  }

  /// Estado legible: 2=ACEPTADO, 3/4/5=RECHAZADO, otro=PENDIENTE
  String get estadoTexto {
    switch (estado) {
      case '2':
        return 'ACEPTADO';
      case '3':
      case '4':
      case '5':
        return 'RECHAZADO';
      default:
        return 'PENDIENTE';
    }
  }

  bool get esAceptado => estado == '2';
  bool get esRechazado => ['3', '4', '5'].contains(estado);
  bool get esPendiente => !esAceptado && !esRechazado;
}

// ============================================================
// GoPass - Venta disponible para pago
// ============================================================

class VentaGopass {
  final int id;
  final String fecha;
  final double ventaTotal;
  final int? consecutivo;
  final String prefijo;
  final String cara;
  final double cantidad;
  final double precioProducto;
  final String descripcion;
  final int? estadoGopass;

  VentaGopass({
    required this.id,
    this.fecha = '',
    this.ventaTotal = 0,
    this.consecutivo,
    this.prefijo = '',
    this.cara = '',
    this.cantidad = 0,
    this.precioProducto = 0,
    this.descripcion = '',
    this.estadoGopass,
  });

  factory VentaGopass.fromJson(Map<String, dynamic> json) {
    return VentaGopass(
      id: parseInt(json['id']),
      fecha: json['fecha']?.toString() ?? '',
      ventaTotal: parseDouble(json['venta_total']),
      consecutivo: parseIntNullable(json['consecutivo']),
      prefijo: json['prefijo']?.toString() ?? '',
      cara: json['cara']?.toString() ?? '',
      cantidad: parseDouble(json['cantidad']),
      precioProducto: parseDouble(json['precio_producto']),
      descripcion: json['descripcion']?.toString() ?? '',
      estadoGopass: parseIntNullable(json['estado_gopass']),
    );
  }

  String get ventaTotalFormateada {
    final str = ventaTotal.toInt().toString();
    final buffer = StringBuffer();
    int count = 0;
    for (int i = str.length - 1; i >= 0; i--) {
      buffer.write(str[i]);
      count++;
      if (count % 3 == 0 && i > 0) buffer.write('.');
    }
    return '\$${buffer.toString().split('').reversed.join('')}';
  }
}

// ============================================================
// Canastilla - Producto
// ============================================================

class ImpuestoProducto {
  final int id;
  final String descripcion;
  final double porcentaje;
  final double valor;
  final bool ivaIncluido;
  /// Tipo de impuesto: '%' = porcentaje, '$' = valor fijo
  final String tipoImpuesto;

  ImpuestoProducto({
    this.id = 0,
    this.descripcion = '',
    this.porcentaje = 0,
    this.valor = 0,
    this.ivaIncluido = false,
    this.tipoImpuesto = '%',
  });

  factory ImpuestoProducto.fromJson(Map<String, dynamic> json) {
    // DB: porcentaje_valor = tipo ('%' o '$'), valor = número real
    final tipo = json['porcentaje_valor']?.toString() ?? '%';
    final valorNum = parseDouble(json['valor']);
    return ImpuestoProducto(
      id: parseInt(json['impuesto_id'] ?? json['id']),
      descripcion: json['descripcion']?.toString() ?? '',
      // Para '%': valor es el porcentaje (ej: 19). Para '$': porcentaje=0
      porcentaje: tipo == '%' ? valorNum : 0,
      valor: valorNum,
      ivaIncluido: json['iva_incluido'] == true || json['iva_incluido'] == 'S',
      tipoImpuesto: tipo,
    );
  }

  Map<String, dynamic> toJson() => {
    'identificadorImpuesto': id,
    'nombreImpuesto': descripcion,
    'tipoImpuesto': ivaIncluido ? 'INCLUIDO' : 'ADICIONAL',
    'valorImpAplicado': porcentaje,
    'valorImpuestoAplicado': valor,
  };
}

class IngredienteProducto {
  final int id;
  final String descripcion;
  final double cantidad;
  final double costo;
  final double saldo;

  IngredienteProducto({
    this.id = 0,
    this.descripcion = '',
    this.cantidad = 0,
    this.costo = 0,
    this.saldo = 0,
  });

  factory IngredienteProducto.fromJson(Map<String, dynamic> json) {
    return IngredienteProducto(
      id: parseInt(json['ingredientes_id'] ?? json['id']),
      descripcion: json['ing_descripcion'] ?? json['descripcion'] ?? '',
      cantidad: parseDouble(json['cantidad']),
      costo: parseDouble(json['ing_costo'] ?? json['costo']),
      saldo: parseDouble(json['ing_saldo'] ?? json['saldo']),
    );
  }
}

class ProductoCanastilla {
  final int id;
  final String plu;
  final String descripcion;
  final double precio;
  final int tipo;
  final String estado;
  final String unidadesMedida;
  final double saldo;
  final double costo;
  final String codigoBarra;
  final int categoriaId;
  final String categoriaDescripcion;
  final bool esCompuesto;
  final List<ImpuestoProducto> impuestos;
  final List<IngredienteProducto> ingredientes;

  ProductoCanastilla({
    required this.id,
    this.plu = '',
    this.descripcion = '',
    this.precio = 0,
    this.tipo = 0,
    this.estado = 'A',
    this.unidadesMedida = '',
    this.saldo = 0,
    this.costo = 0,
    this.codigoBarra = '',
    this.categoriaId = -1,
    this.categoriaDescripcion = 'OTROS',
    this.esCompuesto = false,
    this.impuestos = const [],
    this.ingredientes = const [],
  });

  factory ProductoCanastilla.fromJson(Map<String, dynamic> json) {
    final impList = (json['impuestos'] as List?)
        ?.map((e) => ImpuestoProducto.fromJson(e as Map<String, dynamic>))
        .toList() ?? [];
    final ingList = (json['ingredientes'] as List?)
        ?.map((e) => IngredienteProducto.fromJson(e as Map<String, dynamic>))
        .toList() ?? [];

    return ProductoCanastilla(
      id: parseInt(json['id']),
      plu: json['plu']?.toString() ?? '',
      descripcion: json['descripcion']?.toString() ?? '',
      precio: parseDouble(json['precio']),
      tipo: parseInt(json['tipo']),
      estado: json['estado']?.toString() ?? 'A',
      unidadesMedida: json['unidades_medida']?.toString() ?? '',
      saldo: parseDouble(json['saldo']),
      costo: parseDouble(json['costo']),
      codigoBarra: json['codigo_barra']?.toString() ?? '',
      categoriaId: parseInt(json['categoria_id']),
      categoriaDescripcion: json['categoria_descripcion']?.toString() ?? 'OTROS',
      esCompuesto: json['es_compuesto'] == true,
      impuestos: impList,
      ingredientes: ingList,
    );
  }

  /// Calcula el impuesto total para una cantidad dada
  double calcularImpuesto(int cantidad) {
    double total = 0;
    for (final imp in impuestos) {
      if (imp.tipoImpuesto == r'$') {
        // Impuesto fijo por unidad (ej: IMPOCONSUMO $0)
        total += imp.valor * cantidad;
      } else {
        // Impuesto porcentual (ej: IVA 19%)
        if (imp.ivaIncluido) {
          total += (precio * cantidad) - ((precio * cantidad) / (1 + imp.porcentaje / 100));
        } else {
          total += (precio * cantidad) * (imp.porcentaje / 100);
        }
      }
    }
    return total;
  }

  bool get tieneStock => saldo > 0;
}

class CategoriaCanastilla {
  final int id;
  final String descripcion;
  final int totalProductos;

  CategoriaCanastilla({
    required this.id,
    this.descripcion = '',
    this.totalProductos = 0,
  });

  factory CategoriaCanastilla.fromJson(Map<String, dynamic> json) {
    return CategoriaCanastilla(
      id: parseInt(json['id']),
      descripcion: json['descripcion']?.toString() ?? '',
      totalProductos: parseInt(json['total_productos']),
    );
  }
}

class ItemCarrito {
  final ProductoCanastilla producto;
  int cantidad;

  ItemCarrito({required this.producto, this.cantidad = 1});

  double get subtotal => producto.precio * cantidad;
  double get impuestoTotal => producto.calcularImpuesto(cantidad);
  double get total => subtotal;

  Map<String, dynamic> toDetalleJson() {
    return {
      'identificador_producto': producto.id,
      'nombre_producto': producto.descripcion,
      'identificacion_producto': producto.plu,
      'cantidad_venta': cantidad.toDouble(),
      'costo_producto': producto.costo,
      'precio_producto': producto.precio,
      'descuento_total': 0.0,
      'subtotal_venta': subtotal,
      'atributos': {
        'categoriaId': producto.categoriaId,
        'categoriaDescripcion': producto.categoriaDescripcion,
        'tipo': producto.tipo,
        'cortecia': false,
        'base': subtotal - impuestoTotal,
        'total': subtotal,
        'precio_unitario': producto.precio,
        'impuesto': impuestoTotal,
        'precioProducto': producto.precio,
      },
      'ingredientes_aplicados': [],
      'impuestos_aplicados': producto.impuestos.map((i) => i.toJson()).toList(),
    };
  }
}

class MedioPagoCanastilla {
  final int id;
  final String descripcion;
  final String codigoExterno;
  final String tipo;

  MedioPagoCanastilla({
    required this.id,
    this.descripcion = '',
    this.codigoExterno = '',
    this.tipo = '',
  });

  factory MedioPagoCanastilla.fromJson(Map<String, dynamic> json) {
    return MedioPagoCanastilla(
      id: parseInt(json['id']),
      descripcion: json['descripcion']?.toString() ?? '',
      codigoExterno: json['codigo_externo']?.toString() ?? '',
      tipo: json['tipo']?.toString() ?? '',
    );
  }
}

// ============================================================
// Funciones de utilidad para parseo de tipos
// ============================================================

int parseInt(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

int? parseIntNullable(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

double parseDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}
