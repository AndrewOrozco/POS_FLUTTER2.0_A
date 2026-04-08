import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/app_constants.dart';
import 'package:flutter/foundation.dart';

/// Servicio para comunicarse con LazoExpress (Node.js)
class LazoExpressService {
  static final LazoExpressService _instance = LazoExpressService._internal();
  factory LazoExpressService() => _instance;
  LazoExpressService._internal();

  String get _baseUrl => 'http://${AppConstants.lazoExpressHost}:${AppConstants.lazoExpressPort}';

  /// Obtener información de la estación (EDS)
  Future<EstacionInfo?> getInformacionEstacion() async {
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.apiConsultasUrl}/configuracion/eds'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        // La respuesta puede venir como { estacion: {...} } o directamente el objeto
        if (json['estacion'] != null) {
          return EstacionInfo.fromJson(json['estacion']);
        } else if (json['data'] != null && json['data']['estacion'] != null) {
          return EstacionInfo.fromJson(json['data']['estacion']);
        } else if (json['alias'] != null) {
          // La respuesta es directamente la estación
          return EstacionInfo.fromJson(json);
        }
      }
      debugPrint('[LazoExpress] Error obteniendo estación: ${response.statusCode}');
      return null;
    } catch (e) {
      debugPrint('[LazoExpress] Error de conexión estación: $e');
      return null;
    }
  }

  /// Obtener información del equipo/POS (isla)
  Future<EquipoInfo?> getEquipoInfo() async {
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.apiConsultasUrl}/configuracion/equipo/info'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        // Puede venir como { equipo: {...} } o directamente
        if (json['equipo'] != null) {
          return EquipoInfo.fromJson(json['equipo']);
        } else if (json['id'] != null) {
          return EquipoInfo.fromJson(json);
        }
      }
      debugPrint('[LazoExpress] Error obteniendo equipo: ${response.statusCode}');
      return null;
    } catch (e) {
      debugPrint('[LazoExpress] Error de conexión equipo: $e');
      return null;
    }
  }

  /// Obtener conteo de ventas pendientes de sincronizar
  Future<VentasPendientes> getVentasPendientes() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/servicios/ventasPendientes'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['data'] != null) {
          return VentasPendientes.fromJson(json['data']);
        }
      }
      return VentasPendientes.empty();
    } catch (e) {
      debugPrint('[LazoExpress] Error obteniendo ventas pendientes: $e');
      return VentasPendientes.empty();
    }
  }

  /// Obtener promotores con turno activo
  Future<List<PromotorTurno>> getTurnosActivos() async {
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.apiConsultasUrl}/turnos/activos'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['turnos'] != null && json['turnos'] is List) {
          return (json['turnos'] as List)
              .map((item) => PromotorTurno.fromJson(item))
              .toList();
        } else if (json['data'] != null && json['data'] is List) {
          return (json['data'] as List)
              .map((item) => PromotorTurno.fromJson(item))
              .toList();
        }
      }
      debugPrint('[LazoExpress] Error obteniendo turnos: ${response.statusCode}');
      return [];
    } catch (e) {
      debugPrint('[LazoExpress] Error de conexión turnos: $e');
      return [];
    }
  }
}

/// Modelo para información del equipo/POS (isla)
class EquipoInfo {
  final int id;
  final String? serialEquipo;
  final String? ip;
  final String? referencia;
  final int numeroIsla;

  EquipoInfo({
    required this.id,
    this.serialEquipo,
    this.ip,
    this.referencia,
    required this.numeroIsla,
  });

  factory EquipoInfo.fromJson(Map<String, dynamic> json) {
    return EquipoInfo(
      id: _parseInt(json['id']),
      serialEquipo: json['serial_equipo']?.toString(),
      ip: json['ip']?.toString(),
      referencia: json['referencia']?.toString(),
      // El numeroIsla viene directo del endpoint, obtenido de surtidores.islas_id
      numeroIsla: _parseInt(json['numeroIsla']),
    );
  }
}

/// Modelo para información de la estación (EDS)
class EstacionInfo {
  final int id;
  final String alias;
  final String razonSocial;
  final String? nit;
  final String? codigo;
  final String? direccion;
  final String? telefono;

  EstacionInfo({
    required this.id,
    required this.alias,
    required this.razonSocial,
    this.nit,
    this.codigo,
    this.direccion,
    this.telefono,
  });

  factory EstacionInfo.fromJson(Map<String, dynamic> json) {
    return EstacionInfo(
      id: _parseInt(json['id']),
      alias: json['alias']?.toString() ?? 'EDS',
      razonSocial: json['razon_social']?.toString() ?? json['razonSocial']?.toString() ?? '',
      nit: json['nit']?.toString(),
      codigo: json['codigo']?.toString(),
      direccion: json['direccion']?.toString(),
      telefono: json['telefono']?.toString(),
    );
  }

  /// Nombre para mostrar (alias o razón social)
  String get nombreMostrar => alias.isNotEmpty ? alias : razonSocial;
}

/// Helper para parsear int de forma segura
int _parseInt(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is String) return int.tryParse(value) ?? 0;
  if (value is double) return value.toInt();
  return 0;
}

/// Modelo para ventas pendientes de sincronizar
class VentasPendientes {
  final int numeroVentas;
  final int ventasCombustible;
  final int ventasCanastilla;
  final bool sincronizado;

  VentasPendientes({
    required this.numeroVentas,
    required this.ventasCombustible,
    required this.ventasCanastilla,
    required this.sincronizado,
  });

  factory VentasPendientes.fromJson(Map<String, dynamic> json) {
    return VentasPendientes(
      numeroVentas: _parseInt(json['numeroVentas']),
      ventasCombustible: _parseInt(json['ventasCombustible']),
      ventasCanastilla: _parseInt(json['ventasCanastilla']),
      sincronizado: json['sincronizado'] == true,
    );
  }

  factory VentasPendientes.empty() {
    return VentasPendientes(
      numeroVentas: 0,
      ventasCombustible: 0,
      ventasCanastilla: 0,
      sincronizado: true,
    );
  }

  bool get hayPendientes => numeroVentas > 0;
}

/// Modelo para promotor con turno activo
class PromotorTurno {
  final int id;
  final String nombre;
  final String? identificacion;
  final DateTime? fechaInicio;
  final int? jornadaId;

  PromotorTurno({
    required this.id,
    required this.nombre,
    this.identificacion,
    this.fechaInicio,
    this.jornadaId,
  });

  factory PromotorTurno.fromJson(Map<String, dynamic> json) {
    return PromotorTurno(
      id: _parseInt(json['id'] ?? json['promotor_id'] ?? json['personas_id']),
      nombre: json['nombre']?.toString() ?? json['nombrePromotor']?.toString() ?? json['promotor_nombre']?.toString() ?? 'Sin nombre',
      identificacion: json['identificacion']?.toString() ?? json['promotor_identificacion']?.toString(),
      fechaInicio: json['fecha_inicio'] != null 
          ? DateTime.tryParse(json['fecha_inicio'].toString())
          : null,
      jornadaId: _parseInt(json['jornada_id'] ?? json['jornadaId']),
    );
  }

  /// Primer nombre del promotor
  String get primerNombre {
    final partes = nombre.split(' ');
    return partes.isNotEmpty ? partes[0] : nombre;
  }
}