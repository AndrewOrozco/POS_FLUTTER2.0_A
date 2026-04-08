/// Servicio para conectarse al backend de consultas (FastAPI).
///
/// Usa las mismas funciones SQL que la UI de Java:
/// - fnc_consultar_ventas_pendientes
/// - fnc_consultar_ventas
/// - fnc_actualizar_medios_de_pagos
/// - fnc_validar_botones_ventas_appterpel
library;

import 'dart:convert';
import 'package:http/http.dart' as http;

// Re-exportar modelos para que todos los que importan api_consultas_service
// sigan teniendo acceso a los modelos sin cambiar sus imports.
export '../models/api_models.dart';

import '../models/api_models.dart';
import 'package:flutter/foundation.dart';

/// Servicio para el API de consultas (FastAPI)
class ApiConsultasService {
  static const String _host = '127.0.0.1';
  static const int _port = 8020;
  
  String get _baseUrl => 'http://$_host:$_port';

  // ============================================================
  // VENTAS
  // ============================================================

  /// Obtener ventas sin resolver (fnc_consultar_ventas_pendientes)
  Future<VentasResponse<VentaSinResolver>> getVentasSinResolver({
    int? jornadaId,
    int promotorId = 0,
    int limite = 20,
    int pagina = 1,
  }) async {
    try {
      var url = '$_baseUrl/ventas/sin-resolver?promotor_id=$promotorId&limite=$limite&pagina=$pagina';
      if (jornadaId != null) url += '&jornada_id=$jornadaId';
      
      final uri = Uri.parse(url);
      debugPrint('[ApiConsultas] GET $uri');
      
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final ventasJson = data['ventas'] as List<dynamic>;
        
        debugPrint('[ApiConsultas] Ventas sin resolver: ${data['total']} (página ${data['pagina']}/${data['total_paginas']})');
        
        return VentasResponse<VentaSinResolver>(
          total: parseInt(data['total']),
          pagina: parseInt(data['pagina']),
          porPagina: parseInt(data['por_pagina']),
          totalPaginas: parseInt(data['total_paginas']),
          jornadaId: parseIntNullable(data['jornada_id']),
          ventas: ventasJson.map((v) => VentaSinResolver.fromJson(v)).toList(),
        );
      } else {
        debugPrint('[ApiConsultas] Error ${response.statusCode}: ${response.body}');
        return VentasResponse(total: 0, pagina: 1, porPagina: limite, totalPaginas: 1, ventas: []);
      }
    } catch (e) {
      debugPrint('[ApiConsultas] Error en getVentasSinResolver: $e');
      return VentasResponse(total: 0, pagina: 1, porPagina: limite, totalPaginas: 1, ventas: []);
    }
  }

  /// Obtener historial de ventas (fnc_consultar_ventas)
  Future<VentasResponse<VentaHistorial>> getHistorialVentas({
    int? jornadaId,
    int promotorId = 0,
    int limite = 20,
    int pagina = 1,
  }) async {
    try {
      var url = '$_baseUrl/ventas/historial?promotor_id=$promotorId&limite=$limite&pagina=$pagina';
      if (jornadaId != null) url += '&jornada_id=$jornadaId';
      
      final uri = Uri.parse(url);
      debugPrint('[ApiConsultas] GET $uri');
      
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final ventasJson = data['ventas'] as List<dynamic>;
        
        debugPrint('[ApiConsultas] Historial ventas: ${data['total']} (página ${data['pagina']}/${data['total_paginas']})');
        
        return VentasResponse<VentaHistorial>(
          total: parseInt(data['total']),
          pagina: parseInt(data['pagina']),
          porPagina: parseInt(data['por_pagina']),
          totalPaginas: parseInt(data['total_paginas']),
          jornadaId: parseIntNullable(data['jornada_id']),
          ventas: ventasJson.map((v) => VentaHistorial.fromJson(v)).toList(),
        );
      } else {
        debugPrint('[ApiConsultas] Error ${response.statusCode}: ${response.body}');
        return VentasResponse(total: 0, pagina: 1, porPagina: limite, totalPaginas: 1, ventas: []);
      }
    } catch (e) {
      debugPrint('[ApiConsultas] Error en getHistorialVentas: $e');
      return VentasResponse(total: 0, pagina: 1, porPagina: limite, totalPaginas: 1, ventas: []);
    }
  }

  /// Verificar salud del servicio
  Future<bool> checkHealth() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/health')).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // ============================================================
  // CLIENTES Y TIPOS DE IDENTIFICACIÓN
  // ============================================================
  
  /// Obtener tipos de identificación disponibles
  Future<List<TipoIdentificacion>> getTiposIdentificacion() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/ventas/tipos-identificacion')).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final tiposJson = data['tipos'] as List<dynamic>;
        return tiposJson.map((t) => TipoIdentificacion.fromJson(t)).toList();
      }
      return _tiposPredeterminados();
    } catch (e) {
      debugPrint('[ApiConsultas] Error getTiposIdentificacion: $e');
      return _tiposPredeterminados();
    }
  }
  
  List<TipoIdentificacion> _tiposPredeterminados() {
    return [
      TipoIdentificacion(nombre: 'Cedula de ciudadania', codigo: 13, aplicaFidelizacion: true, caracteresPermitidos: '0123456789', limiteCaracteres: 10),
      TipoIdentificacion(nombre: 'NIT', codigo: 31, aplicaFidelizacion: true, caracteresPermitidos: '0123456789', limiteCaracteres: 15),
      TipoIdentificacion(nombre: 'Cedula de extranjeria', codigo: 22, aplicaFidelizacion: true, caracteresPermitidos: '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ', limiteCaracteres: 15),
      TipoIdentificacion(nombre: 'Consumidor final', codigo: 42, aplicaFidelizacion: false, caracteresPermitidos: '0123456789', limiteCaracteres: 12),
    ];
  }
  
  /// Consultar cliente por identificación
  Future<ClienteConsulta> consultarCliente(String identificacion, {int tipoDocumento = 13}) async {
    try {
      final url = '$_baseUrl/ventas/consultar-cliente?identificacion=$identificacion&tipo_documento=$tipoDocumento';
      debugPrint('[ApiConsultas] GET $url');
      
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('[ApiConsultas] Respuesta cliente: $data');
        return ClienteConsulta.fromJson(data);
      }
      debugPrint('[ApiConsultas] Error HTTP ${response.statusCode}');
      return ClienteConsulta.consumidorFinal(identificacion);
    } catch (e) {
      debugPrint('[ApiConsultas] Error consultarCliente: $e');
      return ClienteConsulta.consumidorFinal(identificacion);
    }
  }

  // ============================================================
  // DATOS FACTURA (ventas_curso) - Status Pump
  // ============================================================
  
  /// Guardar datos de factura en ventas_curso (venta activa en bomba).
  /// Replica el flujo de Java SurtidorDao.generarDatosSurtidorVentasCurso.
  /// Guarda: DatosFactura + factura_electronica + statusPump.
  Future<ActualizarDatosVentaResponse> guardarDatosFacturaVentasCurso({
    required int cara,
    Map<String, dynamic>? facturaElectronica,
    int? tipoDocumento,
    String? identificacionCliente,
    String? nombreCliente,
    String? placa,
    String? odometro,
    bool fidelizar = false,
    bool facturacionElectronica = false,
  }) async {
    try {
      final body = {
        'cara': cara,
        if (facturaElectronica != null) 'factura_electronica': facturaElectronica,
        if (tipoDocumento != null) 'tipo_documento': tipoDocumento,
        if (identificacionCliente != null) 'identificacion_cliente': identificacionCliente,
        if (nombreCliente != null) 'nombre_cliente': nombreCliente,
        if (placa != null) 'placa': placa,
        if (odometro != null) 'odometro': odometro,
        'fidelizar': fidelizar,
        'facturacion_electronica': facturacionElectronica,
      };
      
      debugPrint('[ApiConsultas] POST guardar-datos-factura-ventas-curso: cara=$cara, '
          'cliente=$nombreCliente, FE=$facturacionElectronica');
      
      final response = await http.post(
        Uri.parse('$_baseUrl/ventas/guardar-datos-factura-ventas-curso'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      ).timeout(const Duration(seconds: 15));
      
      debugPrint('[ApiConsultas] Response ${response.statusCode}: ${response.body}');
      final data = json.decode(response.body);
      
      return ActualizarDatosVentaResponse(
        success: data['success'] == true,
        message: data['message'] ?? '',
        movimientoId: null,
      );
    } catch (e) {
      debugPrint('[ApiConsultas] Error guardarDatosFacturaVentasCurso: $e');
      return ActualizarDatosVentaResponse(
        success: false,
        message: 'Error de conexión: $e',
        movimientoId: null,
      );
    }
  }
  
  // ============================================================
  // MEDIOS DE PAGO
  // ============================================================
  
  /// Obtener medios de pago ya asignados a una venta
  Future<List<MedioPagoVentaConsulta>> getMediosPagoVenta(int movimientoId) async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/ventas/medios-pago-venta/$movimientoId')).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final mediosJson = data['medios'] as List<dynamic>;
        debugPrint('[ApiConsultas] Medios de venta $movimientoId: ${mediosJson.length}');
        return mediosJson.map((m) => MedioPagoVentaConsulta.fromJson(m)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('[ApiConsultas] Error getMediosPagoVenta: $e');
      return [];
    }
  }
  
  /// Actualizar datos de una venta (placa, cliente, etc.)
  Future<ActualizarDatosVentaResponse> actualizarDatosVenta({
    required int movimientoId,
    String? placa,
    int? odometro,
    String? nombreCliente,
    String? identificacionCliente,
    int? tipoDocumento,
    String? orden,
    bool? esCredito,
  }) async {
    try {
      final body = {
        'movimiento_id': movimientoId,
        if (placa != null && placa.isNotEmpty) 'placa': placa.toUpperCase(),
        if (odometro != null) 'odometro': odometro,
        if (nombreCliente != null && nombreCliente.isNotEmpty) 'nombre_cliente': nombreCliente,
        if (identificacionCliente != null && identificacionCliente.isNotEmpty) 'identificacion_cliente': identificacionCliente,
        if (tipoDocumento != null) 'tipo_documento': tipoDocumento,
        if (orden != null && orden.isNotEmpty) 'orden': orden,
        if (esCredito != null) 'es_credito': esCredito,
      };
      
      debugPrint('[ApiConsultas] POST actualizar-datos-venta: $body');
      
      final response = await http.post(
        Uri.parse('$_baseUrl/ventas/actualizar-datos-venta'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      ).timeout(const Duration(seconds: 15));
      
      debugPrint('[ApiConsultas] Response ${response.statusCode}: ${response.body}');
      final data = json.decode(response.body);
      
      return ActualizarDatosVentaResponse(success: data['success'] == true, message: data['message'] ?? '', movimientoId: data['movimiento_id']);
    } catch (e) {
      debugPrint('[ApiConsultas] Error actualizarDatosVenta: $e');
      return ActualizarDatosVentaResponse(success: false, message: 'Error de conexión: $e', movimientoId: movimientoId);
    }
  }
  
  /// Actualizar medios de pago (fnc_actualizar_medios_de_pagos)
  Future<ActualizarMediosPagoResponse> actualizarMediosPago({
    required int movimientoId,
    required List<MedioPagoParaGuardar> mediosPagos,
    String? identificadorEquipo,
  }) async {
    try {
      final body = {
        'movimiento_id': movimientoId,
        'medios_pagos': mediosPagos.map((m) => m.toJson()).toList(),
        if (identificadorEquipo != null) 'identificador_equipo': identificadorEquipo,
      };
      
      debugPrint('[ApiConsultas] POST actualizar-medios-pago: $body');
      
      final response = await http.post(
        Uri.parse('$_baseUrl/ventas/actualizar-medios-pago'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      ).timeout(const Duration(seconds: 15));
      
      debugPrint('[ApiConsultas] Response ${response.statusCode}: ${response.body}');
      final data = json.decode(response.body);
      
      return ActualizarMediosPagoResponse(success: data['success'] == true, message: data['message'] ?? '', movimientoId: data['movimiento_id']);
    } catch (e) {
      debugPrint('[ApiConsultas] Error actualizarMediosPago: $e');
      return ActualizarMediosPagoResponse(success: false, message: 'Error de conexión: $e', movimientoId: movimientoId);
    }
  }
  
  /// Enviar a Facturación Electrónica (7011) una venta resuelta.
  /// Llama al endpoint /ventas/sin-resolver/resolver-y-enviar-fe
  /// que registra en transmision + envía a 7011 + opcionalmente imprime.
  Future<Map<String, dynamic>> enviarFEVentaSinResolver({
    required int movimientoId,
    required Map<String, dynamic> payloadFe,
    bool imprimirDespues = true,
  }) async {
    try {
      final body = {
        'identificador_movimiento': movimientoId,
        'payload_fe': payloadFe,
        'imprimir_despues': imprimirDespues,
      };
      
      debugPrint('[ApiConsultas] POST ventas/sin-resolver/resolver-y-enviar-fe: mov=$movimientoId, imprimir=$imprimirDespues');
      
      final response = await http.post(
        Uri.parse('$_baseUrl/ventas/sin-resolver/resolver-y-enviar-fe'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      ).timeout(const Duration(seconds: 35));
      
      debugPrint('[ApiConsultas] FE Response ${response.statusCode}: ${response.body}');
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return {'ok': false, 'error_7011': 'HTTP ${response.statusCode}'};
    } catch (e) {
      debugPrint('[ApiConsultas] Error enviarFEVentaSinResolver: $e');
      return {'ok': false, 'error_7011': 'Error: $e'};
    }
  }
  
  /// Obtener medios de pago disponibles
  /// [traerEfectivo] = true para Status Pump, false para Ventas Sin Resolver
  Future<List<MedioPagoConsulta>> getMediosPago({bool traerEfectivo = true}) async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/ventas/medios-pago?traer_efectivo=$traerEfectivo')).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final mediosJson = data['medios'] as List<dynamic>;
        return mediosJson.map((m) => MedioPagoConsulta.fromJson(m)).toList();
      }
      return [MedioPagoConsulta(id: 1, codigo: '01', nombre: 'EFECTIVO', codigoDian: 10, requiereVoucher: false)];
    } catch (e) {
      debugPrint('[ApiConsultas] Error getMediosPago: $e');
      return [MedioPagoConsulta(id: 1, codigo: '01', nombre: 'EFECTIVO', codigoDian: 10, requiereVoucher: false)];
    }
  }

  // ============================================================
  // APP TERPEL
  // ============================================================
  
  /// Asignar APP TERPEL a una venta sin resolver SIN gestionarla.
  /// Java: guardarMedioAppTerpel() + estado=4 (pendiente).
  /// NO llama fnc_actualizar_medios_de_pagos. La venta sigue en "sin resolver".
  Future<AppTerpelPagoResponse> asignarAppTerpelVenta({
    required int movimientoId,
    int medioPagoId = 106,
    String medioDescripcion = 'APP TERPEL',
    double valorTotal = 0,
  }) async {
    try {
      final body = {
        'movimiento_id': movimientoId,
        'medio_pago_id': medioPagoId,
        'medio_descripcion': medioDescripcion,
        'valor_total': valorTotal,
      };
      
      debugPrint('[ApiConsultas] POST appterpel/asignar: $body');
      
      final response = await http.post(
        Uri.parse('$_baseUrl/ventas/appterpel/asignar'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      ).timeout(const Duration(seconds: 15));
      
      debugPrint('[ApiConsultas] AppTerpel Asignar Response ${response.statusCode}: ${response.body}');
      final data = json.decode(response.body);
      
      return AppTerpelPagoResponse(
        success: data['success'] == true,
        message: data['message']?.toString() ?? '',
        movimientoId: data['movimiento_id'] != null ? parseInt(data['movimiento_id']) : movimientoId,
      );
    } catch (e) {
      debugPrint('[ApiConsultas] Error asignarAppTerpelVenta: $e');
      return AppTerpelPagoResponse(
        success: false,
        message: 'Error de conexión: $e',
        movimientoId: movimientoId,
      );
    }
  }
  
  /// Consultar estado del pago APP TERPEL (fnc_validar_botones_ventas_appterpel)
  Future<AppTerpelEstado> getAppTerpelEstado(int movimientoId) async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/ventas/appterpel-estado/$movimientoId')).timeout(const Duration(seconds: 10));
      final data = json.decode(response.body);
      return AppTerpelEstado(pagoEnProceso: data['pago_en_proceso'] == true, puedeGestionar: data['puede_gestionar'] == true);
    } catch (e) {
      debugPrint('[ApiConsultas] Error getAppTerpelEstado: $e');
      return AppTerpelEstado(pagoEnProceso: false, puedeGestionar: true);
    }
  }
  
  /// Enviar pago APP TERPEL al orquestador (puerto 5555)
  /// Java: EnviandoMedioPago.java → POST http://localhost:5555/v1/payments/
  Future<AppTerpelPagoResponse> enviarPagoAppTerpel({
    required int movimientoId,
    String medioDescripcion = 'APP TERPEL',
  }) async {
    try {
      final body = {
        'movimiento_id': movimientoId,
        'medio_descripcion': medioDescripcion,
      };
      
      debugPrint('[ApiConsultas] POST appterpel/enviar-pago: $body');
      
      final response = await http.post(
        Uri.parse('$_baseUrl/ventas/appterpel/enviar-pago'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      ).timeout(const Duration(seconds: 35));
      
      debugPrint('[ApiConsultas] AppTerpel Response ${response.statusCode}: ${response.body}');
      final data = json.decode(response.body);
      
      return AppTerpelPagoResponse.fromJson(data);
    } catch (e) {
      debugPrint('[ApiConsultas] Error enviarPagoAppTerpel: $e');
      return AppTerpelPagoResponse(
        success: false,
        message: 'Error de conexión con el orquestador: $e',
        movimientoId: movimientoId,
      );
    }
  }
  
  /// Obtener tiempo configurado para mensaje APP TERPEL (default 30s)
  Future<int> getTiempoMensajeAppTerpel() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/ventas/appterpel/tiempo-mensaje'),
      ).timeout(const Duration(seconds: 10));
      
      final data = json.decode(response.body);
      return data['tiempo_segundos'] ?? 30;
    } catch (e) {
      debugPrint('[ApiConsultas] Error getTiempoMensajeAppTerpel: $e');
      return 30; // Default como en Java
    }
  }

  // ============================================================
  // VENTAS EN CURSO (Status Pump)
  // ============================================================
  
  /// Guardar medio de pago en ventas_curso (flujo Status Pump)
  Future<GuardarMedioVentaCursoResponse> guardarMedioVentaCurso({
    required int cara,
    required int medioPagoId,
    String descripcion = '',
    String? placa,
    String? numeroComprobante,
    bool esGopass = false,
    bool esAppTerpel = false,
  }) async {
    try {
      final body = {
        'cara': cara,
        'medio_pago_id': medioPagoId,
        'medio_pago_descripcion': descripcion,
        'placa': placa ?? '',
        'numero_comprobante': numeroComprobante ?? '',
        'es_gopass': esGopass,
        'es_app_terpel': esAppTerpel,
      };
      
      debugPrint('[ApiConsultas] POST guardar-medio-ventas-curso: $body');
      
      final response = await http.post(
        Uri.parse('$_baseUrl/ventas/guardar-medio-ventas-curso'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      ).timeout(const Duration(seconds: 15));
      
      debugPrint('[ApiConsultas] Response ${response.statusCode}: ${response.body}');
      final data = json.decode(response.body);
      
      return GuardarMedioVentaCursoResponse(success: data['success'] == true, message: data['message'] ?? '');
    } catch (e) {
      debugPrint('[ApiConsultas] Error guardarMedioVentaCurso: $e');
      return GuardarMedioVentaCursoResponse(success: false, message: 'Error de conexión: $e');
    }
  }
  
  /// Limpiar flag isAppTerpel de ventas_curso para una cara.
  /// Se llama después de que la venta APP TERPEL termina de despachar,
  /// para evitar que la siguiente venta herede el flag.
  Future<bool> limpiarAppTerpelVentasCurso(int cara) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/ventas/limpiar-appterpel-ventas-curso'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'cara': cara}),
      ).timeout(const Duration(seconds: 10));
      
      final data = json.decode(response.body);
      debugPrint('[ApiConsultas] limpiarAppTerpel cara $cara: ${data['message']}');
      return data['success'] == true;
    } catch (e) {
      debugPrint('[ApiConsultas] Error limpiarAppTerpelVentasCurso: $e');
      return false;
    }
  }

  /// Obtener venta activa por cara (resolver movimiento_id real)
  Future<VentaActivaCara> getVentaActivaPorCara(int cara) async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/ventas/venta-activa-cara/$cara')).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return VentaActivaCara.fromJson(data);
      }
      return VentaActivaCara(found: false, cara: cara);
    } catch (e) {
      debugPrint('[ApiConsultas] Error getVentaActivaPorCara: $e');
      return VentaActivaCara(found: false, cara: cara);
    }
  }

  // ============================================================
  // GOPASS
  // ============================================================
  
  /// Consultar placas GOPASS (proxy a CentralPoint puerto 7011)
  Future<PlacasGopassResponse> consultarPlacasGoPass({required int cara, String? isla, String? surtidor}) async {
    try {
      final body = {
        'cara': cara,
        if (isla != null) 'isla': isla,
        if (surtidor != null) 'surtidor': surtidor,
      };
      
      debugPrint('[ApiConsultas] POST gopass/consultar-placas: $body');
      
      final response = await http.post(
        Uri.parse('$_baseUrl/ventas/gopass/consultar-placas'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      ).timeout(const Duration(seconds: 35));
      
      debugPrint('[ApiConsultas] GOPASS Response ${response.statusCode}: ${response.body}');
      
      final data = json.decode(response.body);
      final placasJson = data['placas'] as List<dynamic>? ?? [];
      
      return PlacasGopassResponse(
        success: data['success'] == true,
        message: data['message'] ?? '',
        placas: placasJson.map((p) => PlacaGopass.fromJson(p)).toList(),
      );
    } catch (e) {
      debugPrint('[ApiConsultas] Error consultarPlacasGoPass: $e');
      return PlacasGopassResponse(success: false, message: 'Error de conexión: $e', placas: []);
    }
  }

  // ============================================================
  // RUMBO (Gestión de Flotas)
  // ============================================================

  /// Obtener mangueras disponibles para RUMBO
  Future<List<MangueraRumbo>> getManguerasRumbo() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/rumbo/mangueras'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List<dynamic>;
        return data.map((m) => MangueraRumbo.fromJson(m)).toList();
      }
      debugPrint('[ApiConsultas] Error getManguerasRumbo: ${response.statusCode}');
      return [];
    } catch (e) {
      debugPrint('[ApiConsultas] Error getManguerasRumbo: $e');
      return [];
    }
  }

  /// Obtener medios de identificación disponibles para RUMBO
  Future<List<MedioIdentificacionRumbo>> getMediosIdentificacionRumbo() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/rumbo/medios-identificacion'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final mediosJson = data['medios'] as List<dynamic>;
        return mediosJson.map((m) => MedioIdentificacionRumbo.fromJson(m)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('[ApiConsultas] Error getMediosIdentificacionRumbo: $e');
      return [];
    }
  }

  /// Solicitar autorización RUMBO
  Future<AutorizarRumboResponse> autorizarRumbo({
    required int surtidor,
    required int cara,
    required int manguera,
    required int grado,
    required int valorOdometro,
    required int codigoFamiliaProducto,
    required double precioVentaUnidad,
    required int medioAutorizacion,
    required String serialIdentificador,
    String codigoSeguridad = '',
    int? identificadorPromotor,
    int? idPromotor,
    int codigoTipoIdentificador = 1,
    int? codigoProducto,
  }) async {
    try {
      final body = <String, dynamic>{
        'surtidor': surtidor,
        'cara': cara,
        'manguera': manguera,
        'grado': grado,
        'valor_odometro': valorOdometro,
        'codigo_familia_producto': codigoFamiliaProducto,
        'precio_venta_unidad': precioVentaUnidad,
        'medio_autorizacion': medioAutorizacion,
        'serial_identificador': serialIdentificador,
        'codigo_seguridad': codigoSeguridad,
        'codigo_tipo_identificador': codigoTipoIdentificador,
        if (identificadorPromotor != null) 'identificador_promotor': identificadorPromotor,
        if (idPromotor != null) 'id_promotor': idPromotor,
        if (codigoProducto != null) 'codigo_producto': codigoProducto,
      };

      debugPrint('[ApiConsultas] POST rumbo/autorizar: $body');

      final response = await http.post(
        Uri.parse('$_baseUrl/rumbo/autorizar'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      ).timeout(const Duration(seconds: 35));

      debugPrint('[ApiConsultas] RUMBO autorizar response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return AutorizarRumboResponse.fromJson(data);
      }
      return AutorizarRumboResponse(
        autorizado: false,
        mensaje: 'Error HTTP ${response.statusCode}',
      );
    } catch (e) {
      debugPrint('[ApiConsultas] Error autorizarRumbo: $e');
      return AutorizarRumboResponse(
        autorizado: false,
        mensaje: 'Error de conexión: $e',
      );
    }
  }

  /// Enviar datos adicionales post-autorización RUMBO
  Future<bool> enviarDatosAdicionalesRumbo({
    required String identificadorAutorizacion,
    String? placa,
    String? codigoSeguridad,
    String? informacionAdicional,
  }) async {
    try {
      final body = {
        'identificador_autorizacion': identificadorAutorizacion,
        if (placa != null) 'placa': placa,
        if (codigoSeguridad != null) 'codigo_seguridad': codigoSeguridad,
        if (informacionAdicional != null) 'informacion_adicional': informacionAdicional,
      };

      final response = await http.post(
        Uri.parse('$_baseUrl/rumbo/datos-adicionales'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['exito'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('[ApiConsultas] Error enviarDatosAdicionalesRumbo: $e');
      return false;
    }
  }

  /// Consultar lectura pendiente de identificador (Ibutton/RFID) para una cara.
  /// Usa long-polling: espera hasta [segundosEspera] segundos por una lectura.
  /// [tipo]: 'turno' (promotorId > 0, empleado) o 'rumbo' (promotorId <= 0, vehículo)
  /// Retorna {medio, serial, promotor_id, promotor_nombre} o null si no hay.
  Future<Map<String, dynamic>?> getLecturaIdentificadorRumbo({
    required int cara,
    int segundosEspera = 10,
    String tipo = 'rumbo',
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/rumbo/lectura-identificador/$cara?esperar=$segundosEspera&tipo=$tipo'),
      ).timeout(Duration(seconds: segundosEspera + 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['disponible'] == true && data['lectura'] != null) {
          return Map<String, dynamic>.from(data['lectura']);
        }
      }
      return null;
    } catch (e) {
      debugPrint('[ApiConsultas] Error getLecturaIdentificadorRumbo: $e');
      return null;
    }
  }

  /// Limpiar lectura pendiente de una cara
  Future<void> limpiarLecturaIdentificadorRumbo(int cara, {String tipo = 'rumbo'}) async {
    try {
      await http.delete(
        Uri.parse('$_baseUrl/rumbo/lectura-identificador/$cara?tipo=$tipo'),
      ).timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('[ApiConsultas] Error limpiarLecturaIdentificadorRumbo: $e');
    }
  }

  /// Confirmar venta UREA: insertar en ct_movimientos para que aparezca en "Ventas sin resolver"
  /// Java: RumboView.insertInformacionMovimiento() → fnc_insertar_ct_movimientos
  Future<Map<String, dynamic>> confirmarVentaUrea({
    required int surtidor,
    required int cara,
    required int valorOdometro,
    required int codigoFamiliaProducto,
    required double precioVentaUnidad,
    required String serialIdentificador,
    required int medioAutorizacion,
    required Map<String, dynamic> dataCompleta,
    String codigoSeguridad = '',
    int codigoTipoIdentificador = 1,
    int identificadorGrado = 0,
    double cantidadSuministrada = 0,
  }) async {
    try {
      final body = {
        'surtidor': surtidor,
        'cara': cara,
        'valor_odometro': valorOdometro,
        'codigo_familia_producto': codigoFamiliaProducto,
        'precio_venta_unidad': precioVentaUnidad,
        'serial_identificador': serialIdentificador,
        'medio_autorizacion': medioAutorizacion,
        'data_completa': dataCompleta,
        'codigo_seguridad': codigoSeguridad,
        'codigo_tipo_identificador': codigoTipoIdentificador,
        'identificador_grado': identificadorGrado,
        'cantidad_suministrada': cantidadSuministrada,
      };

      final response = await http.post(
        Uri.parse('$_baseUrl/rumbo/confirmar-urea'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return {'exito': false, 'mensaje': 'Error HTTP ${response.statusCode}'};
    } catch (e) {
      debugPrint('[ApiConsultas] Error confirmarVentaUrea: $e');
      return {'exito': false, 'mensaje': 'Error: $e'};
    }
  }

  /// Obtener detalles de una venta UREA desde ct_movimientos (para pantalla finalizar en ventas sin resolver)
  Future<Map<String, dynamic>> getDetallesUreaVenta(int movimientoId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/rumbo/detalles-urea/$movimientoId'),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return {};
    } catch (e) {
      debugPrint('[ApiConsultas] Error getDetallesUreaVenta: $e');
      return {};
    }
  }

  /// Finalizar venta UREA desde "Ventas sin resolver" (actualizar cantidad y total)
  Future<Map<String, dynamic>> finalizarUreaSinResolver({
    required int movimientoId,
    required double cantidadSuministrada,
    required double precioUrea,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/rumbo/finalizar-urea-sin-resolver'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'movimiento_id': movimientoId,
          'cantidad_suministrada': cantidadSuministrada,
          'precio_urea': precioUrea,
        }),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return {'exito': false, 'mensaje': 'Error HTTP ${response.statusCode}'};
    } catch (e) {
      debugPrint('[ApiConsultas] Error finalizarUreaSinResolver: $e');
      return {'exito': false, 'mensaje': 'Error: $e'};
    }
  }

  // ============================================================
  // TURNOS (Gestión de Jornadas)
  // ============================================================

  /// Obtener surtidores de la estación con host (para leer totalizadores)
  Future<List<Map<String, dynamic>>> getSurtidoresEstacion() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/turnos/surtidores-estacion'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final surtidores = data['surtidores'] as List<dynamic>;
        debugPrint('[ApiConsultas] Surtidores estación: ${surtidores.length}');
        return surtidores.cast<Map<String, dynamic>>();
      }
      debugPrint('[ApiConsultas] Error getSurtidoresEstacion: ${response.statusCode}');
      return [];
    } catch (e) {
      debugPrint('[ApiConsultas] Error getSurtidoresEstacion: $e');
      return [];
    }
  }

  /// Leer totalizadores de un surtidor via puerto 8019
  Future<Map<String, dynamic>> getTotalizadores({
    required int surtidor,
    required String host,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/turnos/totalizadores'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'surtidor': surtidor, 'host': host}),
      ).timeout(const Duration(seconds: 35));

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      return {'exito': false, 'mensaje': 'Error HTTP ${response.statusCode}', 'data': []};
    } catch (e) {
      debugPrint('[ApiConsultas] Error getTotalizadores: $e');
      return {'exito': false, 'mensaje': 'Error: $e', 'data': []};
    }
  }

  /// Validar un promotor por identificación y/o personas_id, con PIN opcional
  Future<Map<String, dynamic>> validarPromotor(String identificacion, {String? pin, int? personasId}) async {
    try {
      final body = <String, dynamic>{'identificacion': identificacion};
      if (pin != null && pin.isNotEmpty) body['pin'] = pin;
      if (personasId != null && personasId > 0) body['personas_id'] = personasId;

      final response = await http.post(
        Uri.parse('$_baseUrl/turnos/validar-promotor'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      return {'exito': false, 'mensaje': 'Error HTTP ${response.statusCode}'};
    } catch (e) {
      debugPrint('[ApiConsultas] Error validarPromotor: $e');
      return {'exito': false, 'mensaje': 'Error: $e'};
    }
  }

  /// Iniciar turno (jornada) de un promotor
  Future<Map<String, dynamic>> iniciarTurno({
    required int personasId,
    int saldo = 0,
    List<int> surtidores = const [],
    List<dynamic>? totalizadores,
    bool esPrincipal = true,
  }) async {
    try {
      final body = {
        'personas_id': personasId,
        'saldo': saldo,
        'surtidores': surtidores,
        'totalizadores': totalizadores,
        'es_principal': esPrincipal,
      };

      debugPrint('[ApiConsultas] POST turnos/iniciar: persona=$personasId saldo=$saldo');

      final response = await http.post(
        Uri.parse('$_baseUrl/turnos/iniciar'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      ).timeout(const Duration(seconds: 60));

      debugPrint('[ApiConsultas] Turno iniciar response: ${response.statusCode}');

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      return {'exito': false, 'mensaje': 'Error HTTP ${response.statusCode}'};
    } catch (e) {
      debugPrint('[ApiConsultas] Error iniciarTurno: $e');
      return {'exito': false, 'mensaje': 'Error: $e'};
    }
  }

  /// Finalizar turno (jornada) de uno o varios promotores
  Future<Map<String, dynamic>> finalizarTurno({
    required List<Map<String, dynamic>> personas,
    List<dynamic>? totalizadoresFinales,
    bool esPrincipal = false,
  }) async {
    try {
      final body = {
        'personas': personas,
        'totalizadoresFinales': totalizadoresFinales,
        'es_principal': esPrincipal,
      };

      final response = await http.put(
        Uri.parse('$_baseUrl/turnos/finalizar'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      return {'exito': false, 'mensaje': 'Error HTTP ${response.statusCode}'};
    } catch (e) {
      debugPrint('[ApiConsultas] Error finalizarTurno: $e');
      return {'exito': false, 'mensaje': 'Error: $e'};
    }
  }

  /// Obtener turnos activos
  Future<List<Map<String, dynamic>>> getTurnosActivosApi() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/turnos/activos'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final turnos = data['turnos'] as List<dynamic>;
        return turnos.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      debugPrint('[ApiConsultas] Error getTurnosActivosApi: $e');
      return [];
    }
  }

  // ============================================================
  // FIDELIZACIÓN (Club Terpel / Vive Terpel)
  // ============================================================

  /// Validar si un cliente existe en el programa de fidelización
  Future<Map<String, dynamic>> validarClienteFidelizacion({
    required String numeroIdentificacion,
    int codigoTipoIdentificacion = 1,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/fidelizacion/validar-cliente'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'numero_identificacion': numeroIdentificacion,
          'codigo_tipo_identificacion': codigoTipoIdentificacion,
        }),
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      return {'exito': false, 'mensaje': 'Error HTTP ${response.statusCode}'};
    } catch (e) {
      debugPrint('[ApiConsultas] Error validarClienteFidelizacion: $e');
      return {'exito': false, 'mensaje': 'Error: $e'};
    }
  }

  /// Acumular puntos de fidelización para una venta
  Future<Map<String, dynamic>> acumularPuntosFidelizacion({
    required int movimientoId,
    required String numeroIdentificacion,
    int codigoTipoIdentificacion = 1,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/fidelizacion/acumular'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'movimiento_id': movimientoId,
          'numero_identificacion': numeroIdentificacion,
          'codigo_tipo_identificacion': codigoTipoIdentificacion,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      return {'exito': false, 'mensaje': 'Error HTTP ${response.statusCode}'};
    } catch (e) {
      debugPrint('[ApiConsultas] Error acumularPuntosFidelizacion: $e');
      return {'exito': false, 'mensaje': 'Error: $e'};
    }
  }

  /// Verificar si una venta ya fue fidelizada
  Future<bool> estaFidelizada(int movimientoId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/fidelizacion/estado/$movimientoId'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['fidelizada'] == true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Imprimir ticket de venta
  /// Java: ImpresionVenta.impirmir() → POST localhost:8001/print-ticket/sales
  Future<Map<String, dynamic>> imprimirVenta({
    required int movimientoId,
    String reportType = 'FACTURA',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/ventas/imprimir'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'movimiento_id': movimientoId,
          'report_type': reportType,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      return {'exito': false, 'mensaje': 'Error HTTP ${response.statusCode}'};
    } catch (e) {
      debugPrint('[ApiConsultas] Error imprimirVenta: $e');
      return {'exito': false, 'mensaje': 'Error: $e'};
    }
  }

  // ============================================================
  // GoPass - Estado de Pagos
  // ============================================================

  /// Obtener transacciones GoPass (últimos N días)
  /// Java: GetTransacionesGoPassUseCase → fnc_recuperar_ventas_gopass(dias)
  Future<List<TransaccionGopass>> obtenerTransaccionesGopass({int dias = 30}) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/gopass/transacciones?dias=$dias'),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final lista = data['transacciones'] as List? ?? [];
        return lista.map((e) => TransaccionGopass.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('[ApiConsultas] Error obtenerTransaccionesGopass: $e');
      return [];
    }
  }

  /// Imprimir factura GoPass
  /// Java: ImpresionAdapter → POST localhost:8001/print-ticket/sales (con body de consumidor final)
  Future<Map<String, dynamic>> imprimirGopass({
    required int movimientoId,
    String reportType = 'FACTURA',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/gopass/imprimir'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'movimiento_id': movimientoId,
          'report_type': reportType,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      return {'exito': false, 'mensaje': 'Error HTTP ${response.statusCode}'};
    } catch (e) {
      debugPrint('[ApiConsultas] Error imprimirGopass: $e');
      return {'exito': false, 'mensaje': 'Error: $e'};
    }
  }

  /// Obtener ventas disponibles para pago GoPass
  Future<List<VentaGopass>> obtenerVentasGopass() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/gopass/ventas-disponibles'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final lista = data['ventas'] as List? ?? [];
        return lista.map((e) => VentaGopass.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('[ApiConsultas] Error obtenerVentasGopass: $e');
      return [];
    }
  }

  /// Consultar placas GoPass para una venta
  Future<List<PlacaGopass>> consultarPlacasGopass(int ventaId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/gopass/consultar-placas/$ventaId'),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['exito'] == true) {
          final lista = data['placas'] as List? ?? [];
          return lista.map((e) => PlacaGopass.fromJson(e)).toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('[ApiConsultas] Error consultarPlacasGopass: $e');
      return [];
    }
  }

  /// Procesar pago GoPass
  Future<Map<String, dynamic>> procesarPagoGopass({
    required int ventaId,
    required String placa,
    String tagGopass = '',
    String nombreUsuario = '',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/gopass/procesar-pago'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'venta_id': ventaId,
          'placa': placa,
          'tag_gopass': tagGopass,
          'nombre_usuario': nombreUsuario,
        }),
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      return {'exito': false, 'mensaje': 'Error HTTP ${response.statusCode}'};
    } catch (e) {
      debugPrint('[ApiConsultas] Error procesarPagoGopass: $e');
      return {'exito': false, 'mensaje': 'Error: $e'};
    }
  }

  /// Consultar estado de un pago GoPass
  /// Java: ConsultarEstadoPagoGoPassPort → POST localhost:7011/api/consultaEstado
  Future<Map<String, dynamic>> consultarEstadoGopass({
    required int idTransaccionGopass,
    required int idVentaTerpel,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/gopass/consultar-estado'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'id_transaccion_gopass': idTransaccionGopass,
          'id_venta_terpel': idVentaTerpel,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      return {'exito': false, 'mensaje': 'Error HTTP ${response.statusCode}'};
    } catch (e) {
      debugPrint('[ApiConsultas] Error consultarEstadoGopass: $e');
      return {'exito': false, 'mensaje': 'Error: $e'};
    }
  }

  // ============================================================
  //  CANASTILLA
  // ============================================================

  /// Obtener productos de canastilla (paginado, con búsqueda y filtro)
  Future<Map<String, dynamic>> obtenerProductosCanastilla({
    int page = 1,
    int pageSize = 50,
    String? buscar,
    int? categoriaId,
  }) async {
    try {
      final params = <String, String>{
        'page': page.toString(),
        'page_size': pageSize.toString(),
      };
      if (buscar != null && buscar.isNotEmpty) params['buscar'] = buscar;
      if (categoriaId != null && categoriaId > 0) {
        params['categoria_id'] = categoriaId.toString();
      }

      final uri = Uri.parse('$_baseUrl/canastilla/productos')
          .replace(queryParameters: params);
      final response = await http.get(uri).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      return {'total': 0, 'productos': []};
    } catch (e) {
      debugPrint('[ApiConsultas] Error obtenerProductosCanastilla: $e');
      return {'total': 0, 'productos': []};
    }
  }

  /// Obtener categorías de canastilla
  Future<List<CategoriaCanastilla>> obtenerCategoriasCanastilla() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/canastilla/categorias'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final list = data['categorias'] as List? ?? [];
        return list
            .map((e) =>
                CategoriaCanastilla.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('[ApiConsultas] Error obtenerCategoriasCanastilla: $e');
      return [];
    }
  }

  /// Obtener medios de pago disponibles
  Future<List<MedioPagoCanastilla>> obtenerMediosPagoCanastilla() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/canastilla/medios-pago'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final list = data['medios_pago'] as List? ?? [];
        return list
            .map((e) =>
                MedioPagoCanastilla.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('[ApiConsultas] Error obtenerMediosPagoCanastilla: $e');
      return [];
    }
  }

  /// Procesar venta de canastilla
  Future<Map<String, dynamic>> procesarVentaCanastilla(Map<String, dynamic> body) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/canastilla/procesar-venta'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(body),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      return {'exito': false, 'mensaje': 'Error HTTP ${response.statusCode}'};
    } catch (e) {
      debugPrint('[ApiConsultas] Error procesarVentaCanastilla: $e');
      return {'exito': false, 'mensaje': 'Error de conexión: $e'};
    }
  }

  // ============================================================
  //  SURTIDORES
  // ============================================================

  /// Obtener el estado detallado de las mangueras de los surtidores
  Future<Map<String, dynamic>> obtenerManguerasSurtidores() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/surtidores/mangueras'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      return {'exito': false, 'data': []};
    } catch (e) {
      debugPrint('[ApiConsultas] Error obtenerManguerasSurtidores: $e');
      return {'exito': false, 'data': [], 'mensaje': e.toString()};
    }
  }

  /// Aplicar actualización de bloqueos
  Future<Map<String, dynamic>> aplicarBloqueosSurtidores(List<Map<String, dynamic>> bloqueos) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/surtidores/bloqueo'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'bloqueos': bloqueos}),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      return {'exito': false, 'mensaje': 'Error HTTP ${response.statusCode}'};
    } catch (e) {
      debugPrint('[ApiConsultas] Error aplicarBloqueosSurtidores: $e');
      return {'exito': false, 'mensaje': e.toString()};
    }
  }

  /// Limpiar salto de lectura de una manguera (envía comando al Core Gilbarco)
  Future<Map<String, dynamic>> arreglarSaltoLecturaSurtidor(int configuracionId) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/surtidores/arreglar_salto'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'configuracion_id': configuracionId}),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      return {'exito': false, 'mensaje': 'Error HTTP ${response.statusCode}'};
    } catch (e) {
      debugPrint('[ApiConsultas] Error arreglarSaltoLecturaSurtidor: $e');
      return {'exito': false, 'mensaje': e.toString()};
    }
  }

  /// Crear autorización especial (1=Predeterminado, 2=Calibracion, 3=Consumo Propio)
  Future<Map<String, dynamic>> crearAutorizacionEspecialSurtidor({
    required int surtidor,
    required int cara,
    required int manguera,
    required int tipoVenta,
    int monto = 0,
    int volumen = 0,
    int? promotorId,
  }) async {
    try {
      final body = {
        'surtidor': surtidor,
        'cara': cara,
        'manguera': manguera,
        'tipo_venta': tipoVenta,
        'monto': monto,
        'volumen': volumen,
        if (promotorId != null) 'promotor_id': promotorId,
      };

      final response = await http.post(
        Uri.parse('$_baseUrl/surtidores/tipo-venta'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      return {'exito': false, 'mensaje': 'Error HTTP ${response.statusCode}'};
    } catch (e) {
      debugPrint('[ApiConsultas] Error crearAutorizacionEspecialSurtidor: $e');
      return {'exito': false, 'mensaje': e.toString()};
    }
  }

  /// Cambiar precio de una manguera particular
  Future<Map<String, dynamic>> aplicarCambioPrecioSurtidor({
    required int surtidor,
    required int cara,
    required int manguera,
    required int nuevoPrecio,
  }) async {
    try {
      final body = {
        'surtidor': surtidor,
        'cara': cara,
        'manguera': manguera,
        'nuevo_precio': nuevoPrecio,
      };

      final response = await http.post(
        Uri.parse('$_baseUrl/surtidores/cambio-precio'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      return {'exito': false, 'mensaje': 'Error HTTP ${response.statusCode}'};
    } catch (e) {
      debugPrint('[ApiConsultas] Error aplicarCambioPrecioSurtidor: $e');
      return {'exito': false, 'mensaje': e.toString()};
    }
  }

  /// Obtener el historial de remisiones de SAP
  Future<Map<String, dynamic>> obtenerHistorialRemisionesSurtidor({int registros = 50}) async {
    try {
      final uri = Uri.parse('$_baseUrl/surtidores/historial-remisiones?registros=$registros');
      final response = await http.get(uri).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      return {'exito': false, 'mensaje': 'Error HTTP ${response.statusCode}'};
    } catch (e) {
      debugPrint('[ApiConsultas] Error obtenerHistorialRemisionesSurtidor: $e');
      return {'exito': false, 'mensaje': e.toString()};
    }
  }

  /// Verifica si una remisión es válida en SAP (Entrada de Combustible)
  Future<Map<String, dynamic>> validarRemisionSAP({required String delivery}) async {
    try {
      final uri = Uri.parse('$_baseUrl/surtidores/remision/validar?delivery=$delivery');
      final response = await http.get(uri).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      return {'exito': false, 'mensaje': 'Error HTTP ${response.statusCode}'};
    } catch (e) {
      debugPrint('[ApiConsultas] Error validarRemisionSAP: $e');
      return {'exito': false, 'mensaje': e.toString()};
    }
  }

  /// Obtiene los tanques autorizados y productos de un número de remisión
  Future<Map<String, dynamic>> obtenerTanquesRemision({required String delivery}) async {
    try {
      final uri = Uri.parse('$_baseUrl/surtidores/remision/$delivery/tanques');
      final response = await http.get(uri).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      return {'exito': false, 'mensaje': 'Error HTTP ${response.statusCode}'};
    } catch (e) {
      debugPrint('[ApiConsultas] Error obtenerTanquesRemision: $e');
      return {'exito': false, 'mensaje': e.toString()};
    }
  }

  /// Obtiene los tanques y productos disponibles para MODO OFFLINE (Entrada Manual)
  Future<Map<String, dynamic>> getTanquesYProductosManual() async {
    try {
      final uri = Uri.parse('$_baseUrl/surtidores/tanques-y-productos');
      final response = await http.get(uri).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      return {'exito': false, 'mensaje': 'Error HTTP ${response.statusCode}'};
    } catch (e) {
      debugPrint('[ApiConsultas] Error getTanquesYProductosManual: $e');
      return {'exito': false, 'mensaje': e.toString()};
    }
  }

  /// Consulta el aforo de un tanque específico para una altura dada
  Future<Map<String, dynamic>> getAforoTanque(int tanqueId, double altura) async {
    try {
      final uri = Uri.parse('$_baseUrl/surtidores/aforo/$tanqueId?altura=$altura');
      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      return {'exito': false, 'volumen': 0.0, 'mensaje': 'Error HTTP ${response.statusCode}'};
    } catch (e) {
      debugPrint('[ApiConsultas] Error getAforoTanque: $e');
      return {'exito': false, 'volumen': 0.0, 'mensaje': e.toString()};
    }
  }

  Future<Map<String, dynamic>> registrarReceptorCombustible({required Map<String, dynamic> datos}) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/surtidores/recepcion-combustible'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(datos),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      return {'exito': false, 'mensaje': 'Error HTTP ${response.statusCode}'};
    } catch (e) {
      debugPrint('[ApiConsultas] Error registrarReceptorCombustible: $e');
      return {'exito': false, 'mensaje': e.toString()};
    }
  }

  /// Obtiene los registros pendientes de Recepción Combustible
  Future<Map<String, dynamic>> getRecepcionesPendientes() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/surtidores/recepciones/pendientes')).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      return {'exito': false, 'data': [], 'mensaje': 'Error HTTP ${response.statusCode}'};
    } catch (e) {
      debugPrint('[ApiConsultas] Error getRecepcionesPendientes: $e');
      return {'exito': false, 'data': [], 'mensaje': e.toString()};
    }
  }

  /// Obtener historial de ventas canastilla
  Future<Map<String, dynamic>> obtenerHistorialCanastilla({
    required String fechaInicio,
    required String fechaFin,
    String? promotor,
  }) async {
    try {
      final params = <String, String>{
        'fecha_inicio': fechaInicio,
        'fecha_fin': fechaFin,
      };
      if (promotor != null && promotor.isNotEmpty) {
        params['promotor'] = promotor;
      }

      final uri = Uri.parse('$_baseUrl/canastilla/historial')
          .replace(queryParameters: params);
      final response = await http.get(uri).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      return {'total': 0, 'ventas': []};
    } catch (e) {
      debugPrint('[ApiConsultas] Error obtenerHistorialCanastilla: $e');
      return {'total': 0, 'ventas': []};
    }
  }

  /// Imprimir venta canastilla
  /// Java: StoreConfirmarViewController.impresionVenta() → flow_type: CONFIRMAR_STORE
  Future<Map<String, dynamic>> imprimirCanastilla(int movimientoId,
      {String reportType = 'VENTA', Map<String, dynamic>? cliente}) async {
    try {
      final body = {
        'movimiento_id': movimientoId,
        'report_type': reportType,
        if (cliente != null) 'cliente': cliente,
      };
      final response = await http
          .post(
            Uri.parse('$_baseUrl/canastilla/imprimir'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(body),
          )
          .timeout(const Duration(seconds: 15));

      return json.decode(response.body) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[ApiConsultas] Error imprimirCanastilla: $e');
      return {'exito': false, 'mensaje': 'Error: $e'};
    }
  }

  /// Obtener configuración de facturación POS + isDefaultFe
  /// Java: Main.getParametroCoreBoolean("FACTURACION", false) + FacturacionElectronicaDao.isDefaultFe()
  Future<Map<String, bool>> obtenerConfigFacturacion() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/canastilla/config-facturacion'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return {
          'facturacion_pos': data['facturacion_pos'] == true,
          'is_default_fe': data['is_default_fe'] == true,
        };
      }
      return {'facturacion_pos': false, 'is_default_fe': false};
    } catch (e) {
      debugPrint('[ApiConsultas] Error obtenerConfigFacturacion: $e');
      return {'facturacion_pos': false, 'is_default_fe': false};
    }
  }

  // ============================================================
  //  MARKET (KCO / Kiosco)
  // ============================================================

  /// Obtener productos de Market (paginado, con búsqueda y filtro)
  Future<Map<String, dynamic>> obtenerProductosMarket({
    int page = 1,
    int pageSize = 50,
    String? buscar,
    int? categoriaId,
  }) async {
    try {
      final params = <String, String>{
        'page': page.toString(),
        'page_size': pageSize.toString(),
      };
      if (buscar != null && buscar.isNotEmpty) params['buscar'] = buscar;
      if (categoriaId != null && categoriaId > 0) {
        params['categoria_id'] = categoriaId.toString();
      }

      final uri = Uri.parse('$_baseUrl/market/productos')
          .replace(queryParameters: params);
      final response = await http.get(uri).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      return {'total': 0, 'productos': []};
    } catch (e) {
      debugPrint('[ApiConsultas] Error obtenerProductosMarket: $e');
      return {'total': 0, 'productos': []};
    }
  }

  /// Obtener categorías de Market
  Future<List<CategoriaCanastilla>> obtenerCategoriasMarket() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/market/categorias'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final list = data['categorias'] as List? ?? [];
        return list
            .map((e) =>
                CategoriaCanastilla.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('[ApiConsultas] Error obtenerCategoriasMarket: $e');
      return [];
    }
  }

  /// Obtener medios de pago para Market
  Future<List<MedioPagoCanastilla>> obtenerMediosPagoMarket() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/market/medios-pago'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final list = data['medios_pago'] as List? ?? [];
        return list
            .map((e) =>
                MedioPagoCanastilla.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('[ApiConsultas] Error obtenerMediosPagoMarket: $e');
      return [];
    }
  }

  /// Procesar venta de Market (KCO)
  Future<Map<String, dynamic>> procesarVentaMarket(
      Map<String, dynamic> body) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/market/procesar-venta'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(body),
          )
          .timeout(const Duration(seconds: 30));

      return json.decode(response.body) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[ApiConsultas] Error procesarVentaMarket: $e');
      return {'exito': false, 'mensaje': 'Error: $e'};
    }
  }

  /// Obtener historial de ventas Market
  Future<Map<String, dynamic>> obtenerHistorialMarket({
    required String fechaInicio,
    required String fechaFin,
    String? promotor,
  }) async {
    try {
      final params = <String, String>{
        'fecha_inicio': fechaInicio,
        'fecha_fin': fechaFin,
      };
      if (promotor != null && promotor.isNotEmpty) {
        params['promotor'] = promotor;
      }

      final uri = Uri.parse('$_baseUrl/market/historial')
          .replace(queryParameters: params);
      final response = await http.get(uri).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      return {'total': 0, 'ventas': []};
    } catch (e) {
      debugPrint('[ApiConsultas] Error obtenerHistorialMarket: $e');
      return {'total': 0, 'ventas': []};
    }
  }

  /// Imprimir venta Market
  Future<Map<String, dynamic>> imprimirMarket(int movimientoId,
      {String reportType = 'VENTA', Map<String, dynamic>? cliente}) async {
    try {
      final body = {
        'movimiento_id': movimientoId,
        'report_type': reportType,
        if (cliente != null) 'cliente': cliente,
      };
      final response = await http
          .post(
            Uri.parse('$_baseUrl/market/imprimir'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(body),
          )
          .timeout(const Duration(seconds: 15));

      return json.decode(response.body) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[ApiConsultas] Error imprimirMarket: $e');
      return {'exito': false, 'mensaje': 'Error: $e'};
    }
  }

  /// Obtener configuración de facturación para Market
  Future<Map<String, bool>> obtenerConfigFacturacionMarket() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/market/config-facturacion'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return {
          'facturacion_pos': data['facturacion_pos'] == true,
          'is_default_fe': data['is_default_fe'] == true,
        };
      }
      return {'facturacion_pos': false, 'is_default_fe': false};
    } catch (e) {
      debugPrint('[ApiConsultas] Error obtenerConfigFacturacionMarket: $e');
      return {'facturacion_pos': false, 'is_default_fe': false};
    }
  }

  // ══════════════════════════════════════════════════════════
  //  PLACA — Pre-Autorización de Venta
  // ══════════════════════════════════════════════════════════

  /// Obtener mangueras disponibles para pre-autorización
  /// tipo: 'normal' (excluye GLP) o 'glp' (solo GLP)
  Future<List<Map<String, dynamic>>> getManguerasPlaca({String tipo = 'normal'}) async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/placa/mangueras?tipo=$tipo'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List;
        return data.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      debugPrint('[ApiConsultas] Error getManguerasPlaca: $e');
      return [];
    }
  }

  /// Verificar si una cara tiene pre-autorización activa
  Future<Map<String, dynamic>> verificarCaraUsada(int cara) async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/placa/caras-usadas?cara=$cara'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      return {'cara': cara, 'tiene_preautorizacion': false};
    } catch (e) {
      debugPrint('[ApiConsultas] Error verificarCaraUsada: $e');
      return {'cara': cara, 'tiene_preautorizacion': false};
    }
  }

  /// Crear pre-autorización de venta por placa
  Future<Map<String, dynamic>> preAutorizarPlaca({
    required int surtidor,
    required int cara,
    required int manguera,
    required int grado,
    required String placa,
    required String odometro,
    int? promotorId,
    // ── Clientes Propios (iButton) ──
    double? saldo,
    String? tipoCupo,
    String? documentoCliente,
    String? nombreCliente,
    String? medioAutorizacion,
    String? serialDispositivo,
    double? productoPrecio,
  }) async {
    try {
      final body = {
        'surtidor': surtidor,
        'cara': cara,
        'manguera': manguera,
        'grado': grado,
        'placa': placa,
        'odometro': odometro,
        if (promotorId != null) 'promotor_id': promotorId,
        // Clientes Propios fields
        if (saldo != null) 'saldo': saldo,
        if (tipoCupo != null) 'tipo_cupo': tipoCupo,
        if (documentoCliente != null) 'documento_cliente': documentoCliente,
        if (nombreCliente != null) 'nombre_cliente': nombreCliente,
        if (medioAutorizacion != null) 'medio_autorizacion': medioAutorizacion,
        if (serialDispositivo != null) 'serial_dispositivo': serialDispositivo,
        if (productoPrecio != null) 'producto_precio': productoPrecio,
      };
      final response = await http
          .post(
            Uri.parse('$_baseUrl/placa/pre-autorizar'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(body),
          )
          .timeout(const Duration(seconds: 15));

      return json.decode(response.body) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[ApiConsultas] Error preAutorizarPlaca: $e');
      return {'exito': false, 'mensaje': 'Error: $e'};
    }
  }

  /// Validar placa en SICOM para GLP
  /// Replica ClienteFacade.consultaVehiculoSicom()
  /// GET /placa/validar-sicom/{placa}
  Future<Map<String, dynamic>> validarPlacaSicom(String placa) async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/placa/validar-sicom/${Uri.encodeComponent(placa.trim().toUpperCase())}'))
          .timeout(const Duration(seconds: 15));
      return json.decode(response.body) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[ApiConsultas] Error validarPlacaSicom: $e');
      return {'exito': false, 'mensaje': 'Error consultando SICOM: $e'};
    }
  }

  /// Validar cupo de cliente propio vía iButton (Clientes Propios)
  /// Llama al proxy que consulta :7001/api/cupos/validar-cupo/v1
  Future<Map<String, dynamic>> validarCupoIButton({
    required String serial,
    required int cara,
    int? promotorId,
  }) async {
    try {
      final body = {
        'serial': serial,
        'cara': cara,
        if (promotorId != null) 'promotor_id': promotorId,
      };
      final response = await http
          .post(
            Uri.parse('$_baseUrl/placa/validar-cupo-ibutton'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(body),
          )
          .timeout(const Duration(seconds: 20));

      return json.decode(response.body) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[ApiConsultas] Error validarCupoIButton: $e');
      return {'exito': false, 'mensaje': 'Error: $e', 'data': null};
    }
  }

  /// Polling: obtener última notificación iButton del hardware
  /// Retorna {exito, mensaje, data} o {exito: false} si no hay notificación
  Future<Map<String, dynamic>> getUltimaNotificacionIButton() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/placa/ultima-notificacion-ibutton'))
          .timeout(const Duration(seconds: 5));
      return json.decode(response.body) as Map<String, dynamic>;
    } catch (e) {
      return {'exito': false, 'mensaje': null, 'data': null};
    }
  }

  /// Consumir/limpiar la notificación iButton después de procesarla
  Future<void> consumirNotificacionIButton() async {
    try {
      await http
          .delete(Uri.parse('$_baseUrl/placa/ultima-notificacion-ibutton'))
          .timeout(const Duration(seconds: 5));
    } catch (_) {}
  }

  /// Obtener ventas del turno actual que aún no han sido fidelizadas
  Future<Map<String, dynamic>> obtenerVentasPendientesFidelizacion() async {
    try {
      // Obtener ventas del turno actual y filtrar las no fidelizadas
      final response = await http
          .get(Uri.parse('$_baseUrl/ventas/historial?limite=50'))
          .timeout(const Duration(seconds: 15));
      final data = json.decode(response.body) as Map<String, dynamic>;
      final ventas = List<Map<String, dynamic>>.from(data['ventas'] ?? []);

      // Filtrar solo las no fidelizadas
      final pendientes = ventas.where((v) {
        return v['fidelizada'] != true && v['fidelizada'] != 'S';
      }).toList();

      return {'exito': true, 'ventas': pendientes};
    } catch (e) {
      return {'exito': false, 'ventas': [], 'mensaje': 'Error: $e'};
    }
  }

  // ─── Fidelizaciones Retenidas ───
  Future<Map<String, dynamic>> obtenerFidelizacionesRetenidas() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/fidelizacion/retenidas'))
          .timeout(const Duration(seconds: 15));
      return json.decode(response.body) as Map<String, dynamic>;
    } catch (e) {
      return {'exito': false, 'retenidas': [], 'error': 'Error: $e'};
    }
  }

  // ─── Validación Bono / Voucher ───
  Future<Map<String, dynamic>> validarBono({
    required String codigoBono,
    int valorBono = 0,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/fidelizacion/validar-bono'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'codigo_bono': codigoBono,
              'valor_bono': valorBono,
            }),
          )
          .timeout(const Duration(seconds: 15));
      return json.decode(response.body) as Map<String, dynamic>;
    } catch (e) {
      return {'exito': false, 'mensaje': 'Error: $e'};
    }
  }

  // ============================================================
  // CONFIGURACIÓN - DISPOSITIVOS
  // ============================================================

  /// Obtener todos los dispositivos configurados
  Future<List<Map<String, dynamic>>> getDispositivos() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/configuracion/dispositivos'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final items = data['dispositivos'] as List<dynamic>;
        return items.map((d) => Map<String, dynamic>.from(d)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('[ApiConsultas] Error getDispositivos: $e');
      return [];
    }
  }

  /// Crear un nuevo dispositivo
  Future<bool> crearDispositivo({
    required String tipos,
    required String conector,
    required String interfaz,
    String estado = 'A',
    Map<String, dynamic>? atributos,
  }) async {
    try {
      final body = {
        'tipos': tipos,
        'conector': conector,
        'interfaz': interfaz,
        'estado': estado,
        if (atributos != null) 'atributos': atributos,
      };

      final response = await http.post(
        Uri.parse('$_baseUrl/configuracion/dispositivos'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      ).timeout(const Duration(seconds: 10));

      final data = json.decode(response.body);
      return data['success'] == true;
    } catch (e) {
      debugPrint('[ApiConsultas] Error crearDispositivo: $e');
      return false;
    }
  }

  /// Editar un dispositivo existente
  Future<bool> editarDispositivo({
    required int id,
    String? tipos,
    String? conector,
    String? interfaz,
    String? estado,
    Map<String, dynamic>? atributos,
  }) async {
    try {
      final body = <String, dynamic>{
        if (tipos != null) 'tipos': tipos,
        if (conector != null) 'conector': conector,
        if (interfaz != null) 'interfaz': interfaz,
        if (estado != null) 'estado': estado,
        if (atributos != null) 'atributos': atributos,
      };

      final response = await http.put(
        Uri.parse('$_baseUrl/configuracion/dispositivos/$id'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      ).timeout(const Duration(seconds: 10));

      final data = json.decode(response.body);
      return data['success'] == true;
    } catch (e) {
      debugPrint('[ApiConsultas] Error editarDispositivo: $e');
      return false;
    }
  }

  /// Eliminar un dispositivo por ID
  Future<bool> eliminarDispositivo(int id) async {
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/configuracion/dispositivos/$id'),
      ).timeout(const Duration(seconds: 10));

      final data = json.decode(response.body);
      return data['success'] == true;
    } catch (e) {
      debugPrint('[ApiConsultas] Error eliminarDispositivo: $e');
      return false;
    }
  }

  // ============================================================
  // CONFIGURACIÓN - TAG RFID
  // ============================================================

  /// Obtener lista de usuarios con su tag RFID
  Future<List<Map<String, dynamic>>> getUsuariosTag() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/configuracion/usuarios-tag'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final items = data['usuarios'] as List<dynamic>;
        return items.map((u) => Map<String, dynamic>.from(u)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('[ApiConsultas] Error getUsuariosTag: $e');
      return [];
    }
  }

  /// Registrar (asignar) un tag RFID a un usuario
  Future<Map<String, dynamic>> registrarTag({
    required String identificacion,
    required String tag,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/configuracion/registrar-tag'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'identificacion': identificacion,
          'tag': tag,
        }),
      ).timeout(const Duration(seconds: 10));

      return json.decode(response.body) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[ApiConsultas] Error registrarTag: $e');
      return {'success': false, 'message': 'Error de conexión: $e'};
    }
  }

  /// Obtener lectura pendiente del tag RFID del hardware
  Future<String?> getLecturaTag() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/configuracion/lectura-tag'),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['disponible'] == true) {
          return data['lectura']?.toString();
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ============================================================
  // CONFIGURACIÓN - PARAMETRIZACIONES
  // ============================================================

  /// Obtener parámetros del POS (tipo_autorizacion, placa obligatoria, etc.)
  Future<Map<String, dynamic>> getParametrizaciones() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/configuracion/parametrizaciones'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      return {};
    } catch (e) {
      debugPrint('[ApiConsultas] Error getParametrizaciones: $e');
      return {};
    }
  }

  /// Actualizar parámetros del POS
  Future<bool> updateParametrizaciones(Map<String, String> params) async {
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/configuracion/parametrizaciones'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(params),
      ).timeout(const Duration(seconds: 10));

      final data = json.decode(response.body);
      return data['success'] == true;
    } catch (e) {
      debugPrint('[ApiConsultas] Error updateParametrizaciones: $e');
      return false;
    }
  }

  // ============================================================
  // SINCRONIZACIÓN
  // ============================================================

  /// Ejecutar sincronización (total o por módulo)
  Future<Map<String, dynamic>> ejecutarSincronizacion(
    String tipo, {
    int? tipoNotificacion,
  }) async {
    try {
      final body = <String, dynamic>{'tipo': tipo};
      if (tipoNotificacion != null) {
        body['tipo_notificacion'] = tipoNotificacion;
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/configuracion/sincronizacion/ejecutar'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      ).timeout(const Duration(seconds: 120));

      return json.decode(response.body) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[ApiConsultas] Error ejecutarSincronizacion: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Obtener historial de sincronizaciones
  Future<List<Map<String, dynamic>>> getHistorialSincronizacion() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/configuracion/sincronizacion/historial'),
      ).timeout(const Duration(seconds: 10));

      final data = json.decode(response.body);
      if (data['success'] == true && data['historial'] != null) {
        return (data['historial'] as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('[ApiConsultas] Error getHistorialSincronizacion: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════
  // IMPRESORA
  // ═══════════════════════════════════════

  /// Obtener IP de la impresora configurada
  Future<String?> getIpImpresora() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/configuracion/impresora'),
      ).timeout(const Duration(seconds: 5));

      final data = json.decode(response.body);
      if (data['success'] == true) {
        return data['ip'];
      }
      return null;
    } catch (e) {
      debugPrint('[ApiConsultas] Error getIpImpresora: $e');
      return null;
    }
  }

  /// Guardar IP de la impresora
  Future<bool> guardarIpImpresora(String ip) async {
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/configuracion/impresora'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'ip': ip}),
      ).timeout(const Duration(seconds: 5));

      final data = json.decode(response.body);
      return data['success'] == true;
    } catch (e) {
      debugPrint('[ApiConsultas] Error guardarIpImpresora: $e');
      return false;
    }
  }

  // LICENCIAS ─────────────────────────────────────────────────────────────────

  // EDS ────────────────────────────────────────────────────────────────────────

  /// Obtiene la configuración de la EDS (Estación de Servicio) desde el backend.
  /// Endpoint: GET /configuracion/eds
  Future<Map<String, dynamic>?> getConfiguracionEds() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/configuracion/eds'))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      debugPrint('[ApiConsultas] getConfiguracionEds status: ${response.statusCode}');
      return null;
    } catch (e) {
      debugPrint('[ApiConsultas] getConfiguracionEds error: $e');
      return null;
    }
  }

  // LICENCIAS ─────────────────────────────────────────────────────────────────

  /// Consulta el estado de licencia del equipo (puede llamarse antes del login).
  Future<Map<String, dynamic>> getLicenciaStatus() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/configuracion/licencia'))
          .timeout(const Duration(seconds: 10));
      return json.decode(response.body) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[License] getLicenciaStatus error: $e');
      return {'licenciado': false, 'mensaje': 'Error: $e'};
    }
  }

  /// Activa la licencia con el codigo numerico de la HO.
  Future<Map<String, dynamic>> activarLicencia(String code) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/configuracion/activar-licencia'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'code': code}),
          )
          .timeout(const Duration(seconds: 15));
      return json.decode(response.body) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[License] activarLicencia error: $e');
      return {'exito': false, 'mensaje': 'Error de conexion: $e'};
    }
  }

  /// Restaura la licencia del equipo (autorizado=N) para re-activar.
  Future<void> restaurarLicencia() async {
    try {
      await http
          .post(Uri.parse('$_baseUrl/configuracion/restaurar-licencia'))
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('[License] restaurarLicencia error: $e');
    }
  }
}