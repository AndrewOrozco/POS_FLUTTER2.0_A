import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

/// Servicio para interactuar con LazoExpress API (puerto 8010)
/// 
/// Maneja operaciones de negocio como:
/// - Medios de pago
/// - Asignar datos de cliente
/// - Enviar venta
/// - Finalizar RUMBO
class LazoExpressApiService {
  static const String _baseUrl = 'http://127.0.0.1:8010';
  
  /// Headers comunes para las peticiones
  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };
  
  // ============================================================
  // MEDIOS DE PAGO
  // ============================================================
  
  /// Obtiene los medios de pago disponibles
  /// GET /api/buscarMediosPagos
  Future<List<MedioPago>> getMediosPago() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/buscarMediosPagos'),
        headers: _headers,
      );
      
      debugPrint('[LazoExpressAPI] getMediosPago response: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // La respuesta viene como { data: [...] } o directamente como array
        List<dynamic>? mediosList;
        if (data is List) {
          mediosList = data;
        } else if (data['data'] != null && data['data'] is List) {
          mediosList = data['data'];
        }
        
        if (mediosList != null) {
          return mediosList
              .map((e) => MedioPago.fromJson(e))
              .where((m) => m.activo)
              .toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('[LazoExpressAPI] Error getMediosPago: $e');
      return [];
    }
  }
  
  /// Actualiza los medios de pago de una venta
  /// PUT /api/venta/medios-de-pagos
  Future<ApiResponse> actualizarMediosPago({
    required int identificadorMovimiento,
    required List<MedioPagoVenta> mediosPagos,
    required int identificadorEquipo,
  }) async {
    try {
      final body = {
        'identificadorMovimiento': identificadorMovimiento,
        'mediosDePagos': mediosPagos.map((m) => m.toJson()).toList(),
        'identificadorEquipo': identificadorEquipo,
        'validarTurno': true,
      };
      
      debugPrint('[LazoExpressAPI] PUT medios-de-pagos: $body');
      
      final response = await http.put(
        Uri.parse('$_baseUrl/api/venta/medios-de-pagos'),
        headers: _headers,
        body: json.encode(body),
      );
      
      debugPrint('[LazoExpressAPI] Response ${response.statusCode}: ${response.body}');
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        return ApiResponse(
          success: true,
          message: 'Medios de pago actualizados correctamente',
        );
      } else {
        final data = json.decode(response.body);
        return ApiResponse(
          success: false,
          message: data['message'] ?? 'Error actualizando medios de pago',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      debugPrint('[LazoExpressAPI] Error actualizarMediosPago: $e');
      return ApiResponse(
        success: false,
        message: 'Error de conexión: $e',
      );
    }
  }
  
  // ============================================================
  // ASIGNAR DATOS
  // ============================================================
  
  /// Actualiza los datos de una venta (placa, odómetro, cliente)
  /// PUT /api/venta/actualizar-datos-ventas
  Future<ApiResponse> actualizarDatosVenta({
    required int identificadorMovimiento,
    required int identificadorEquipo,
    String? placa,
    int? odometro,
    String? numero,
    String? orden,
    String? nombrePersona,
    String? identificacionPersona,
    bool? isCredito,
    String? tipoVenta,
  }) async {
    try {
      final body = {
        'identificadorMovimiento': identificadorMovimiento,
        'identificadorEquipo': identificadorEquipo,
        if (placa != null) 'placa': placa,
        if (odometro != null) 'odometro': odometro,
        if (numero != null) 'numero': numero,
        if (orden != null) 'orden': orden,
        if (nombrePersona != null) 'nombrePersona': nombrePersona,
        if (identificacionPersona != null) 'identificacionPersona': identificacionPersona,
        if (isCredito != null) 'isCredito': isCredito,
        if (tipoVenta != null) 'tipoVenta': tipoVenta,
      };
      
      debugPrint('[LazoExpressAPI] PUT actualizar-datos-ventas: $body');
      
      final response = await http.put(
        Uri.parse('$_baseUrl/api/venta/actualizar-datos-ventas'),
        headers: _headers,
        body: json.encode(body),
      );
      
      debugPrint('[LazoExpressAPI] Response ${response.statusCode}: ${response.body}');
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        return ApiResponse(
          success: true,
          message: 'Datos actualizados correctamente',
        );
      } else {
        final data = json.decode(response.body);
        return ApiResponse(
          success: false,
          message: data['message'] ?? 'Error actualizando datos',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      debugPrint('[LazoExpressAPI] Error actualizarDatosVenta: $e');
      return ApiResponse(
        success: false,
        message: 'Error de conexión: $e',
      );
    }
  }
  
  // ============================================================
  // ENVIAR VENTA
  // ============================================================
  
  /// Envía/registra una venta
  /// POST /api/venta/subir
  Future<ApiResponse> enviarVenta({
    required Map<String, dynamic> ventaData,
  }) async {
    try {
      debugPrint('[LazoExpressAPI] POST /api/venta/subir: $ventaData');
      
      final response = await http.post(
        Uri.parse('$_baseUrl/api/venta/subir'),
        headers: _headers,
        body: json.encode(ventaData),
      );
      
      debugPrint('[LazoExpressAPI] Response ${response.statusCode}: ${response.body}');
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        return ApiResponse(
          success: true,
          message: 'Venta enviada correctamente',
        );
      } else {
        final data = json.decode(response.body);
        return ApiResponse(
          success: false,
          message: data['mensaje'] ?? data['message'] ?? 'Error enviando venta',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      debugPrint('[LazoExpressAPI] Error enviarVenta: $e');
      return ApiResponse(
        success: false,
        message: 'Error de conexión: $e',
      );
    }
  }
  
  // ============================================================
  // ASIGNAR DATOS RUMBO/UREA
  // ============================================================
  
  /// Actualiza datos de venta con información RUMBO/UREA
  /// Usa el mismo endpoint de actualizar datos pero con campos específicos
  Future<ApiResponse> actualizarDatosRumbo({
    required int identificadorMovimiento,
    required int identificadorEquipo,
    required String documentoCliente,
    required String nombreCliente,
  }) async {
    try {
      final body = {
        'identificadorMovimiento': identificadorMovimiento,
        'identificadorEquipo': identificadorEquipo,
        'identificacionPersona': documentoCliente,
        'nombrePersona': nombreCliente.toUpperCase(),
      };
      
      debugPrint('[LazoExpressAPI] PUT actualizar-datos-ventas (RUMBO): $body');
      
      final response = await http.put(
        Uri.parse('$_baseUrl/api/venta/actualizar-datos-ventas'),
        headers: _headers,
        body: json.encode(body),
      );
      
      debugPrint('[LazoExpressAPI] Response ${response.statusCode}: ${response.body}');
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        return ApiResponse(
          success: true,
          message: 'Datos RUMBO actualizados correctamente',
        );
      } else {
        final data = json.decode(response.body);
        return ApiResponse(
          success: false,
          message: data['mensaje'] ?? data['message'] ?? 'Error actualizando datos RUMBO',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      debugPrint('[LazoExpressAPI] Error actualizarDatosRumbo: $e');
      return ApiResponse(
        success: false,
        message: 'Error de conexión: $e',
      );
    }
  }
  
  // ============================================================
  // OBTENER INFORMACIÓN EQUIPO
  // ============================================================
  
  /// Obtiene el identificador del equipo actual
  Future<int?> getIdentificadorEquipo() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/configuracion/equipo'),
        headers: _headers,
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data']?['id'] ?? data['id'];
      }
      return null;
    } catch (e) {
      debugPrint('[LazoExpressAPI] Error getIdentificadorEquipo: $e');
      return null;
    }
  }
}

// ============================================================
// MODELOS
// ============================================================

/// Respuesta genérica de la API
class ApiResponse {
  final bool success;
  final String message;
  final int? statusCode;
  final dynamic data;
  
  ApiResponse({
    required this.success,
    required this.message,
    this.statusCode,
    this.data,
  });
}

/// Medio de pago disponible
class MedioPago {
  final int id;
  final String nombre;
  final String? codigo;
  final int? codigoDian;
  final bool activo;
  final bool requiereVoucher;
  
  MedioPago({
    required this.id,
    required this.nombre,
    this.codigo,
    this.codigoDian,
    this.activo = true,
    this.requiereVoucher = false,
  });
  
  factory MedioPago.fromJson(Map<String, dynamic> json) {
    final nombre = json['nombre']?.toString() ?? '';
    // Determinar si requiere voucher basado en el nombre o campo específico
    final requiereVoucher = json['requiere_voucher'] == true ||
        json['requiereVoucher'] == true ||
        nombre.toLowerCase().contains('tarjeta') ||
        nombre.toLowerCase().contains('app') ||
        nombre.toLowerCase().contains('datafono');
    
    return MedioPago(
      id: _parseInt(json['id']) ?? 0,
      nombre: nombre,
      codigo: json['codigo']?.toString(),
      codigoDian: _parseInt(json['codigo_dian']),
      activo: json['activo'] == true || json['estado'] == 'A',
      requiereVoucher: requiereVoucher,
    );
  }
  
  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}

/// Medio de pago para registrar en una venta
class MedioPagoVenta {
  final int ctMediosPagosId;
  final double valorTotal;
  final double valorRecibido;
  final double valorCambio;
  final int? codigoDian;
  
  MedioPagoVenta({
    required this.ctMediosPagosId,
    required this.valorTotal,
    this.valorRecibido = 0,
    this.valorCambio = 0,
    this.codigoDian,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'ct_medios_pagos_id': ctMediosPagosId,
      'valor_total': valorTotal,
      'valor_recibido': valorRecibido,
      'valor_cambio': valorCambio,
      if (codigoDian != null) 'codigoDian': codigoDian,
    };
  }
}