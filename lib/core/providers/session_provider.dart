import 'dart:async';
import 'package:flutter/material.dart';
import '../services/lazo_express_service.dart';
import '../services/lazo_express_socket_service.dart';

/// Provider para manejar la información de sesión:
/// - Información de la EDS
/// - Información del equipo/POS (isla)
/// - Promotores con turno activo
/// - Ventas pendientes de sincronizar (via Socket.IO desde ms-lazo-express → LazoExpress)
/// Modelo para ventas de Facturación Electrónica en proceso
class VentasFE {
  final int facturaElectronica;
  final int datafono;

  VentasFE({required this.facturaElectronica, required this.datafono});
  
  factory VentasFE.empty() => VentasFE(facturaElectronica: 0, datafono: 0);
  
  bool get tieneVentas => facturaElectronica > 0 || datafono > 0;
  
  String get mensaje {
    final fe = facturaElectronica > 9 ? '9+' : '$facturaElectronica';
    final dat = datafono > 9 ? '9+' : '$datafono';
    return 'Ventas en proceso F.E $fe, DAT $dat';
  }
}

class SessionProvider extends ChangeNotifier {
  final LazoExpressService _lazoService = LazoExpressService();
  final LazoExpressSocketService _lazoSocketService = LazoExpressSocketService();
  StreamSubscription<Map<String, dynamic>>? _ventasPendientesSub;
  StreamSubscription<Map<String, dynamic>>? _ventasFESub;
  StreamSubscription<bool>? _connectionStatusSub;
  Timer? _turnosRefreshTimer;

  EstacionInfo? _estacion;
  EquipoInfo? _equipo;
  List<PromotorTurno> _promotoresActivos = [];
  VentasPendientes _ventasPendientes = VentasPendientes.empty();
  VentasFE _ventasFE = VentasFE.empty();
  bool _isLoading = false;
  bool _isConnected = false;

  // Getters
  EstacionInfo? get estacion => _estacion;
  EquipoInfo? get equipo => _equipo;
  List<PromotorTurno> get promotoresActivos => _promotoresActivos;
  VentasPendientes get ventasPendientes => _ventasPendientes;
  VentasFE get ventasFE => _ventasFE;
  bool get isLoading => _isLoading;
  bool get isConnected => _isConnected;

  /// Nombre de la EDS para mostrar
  String get nombreEDS => _estacion?.nombreMostrar.toUpperCase() ?? 'EDS';

  /// Número de isla/POS
  int get numeroIsla => _equipo?.numeroIsla ?? 1;

  /// Saludo al promotor activo
  String get saludoPromotor {
    if (_promotoresActivos.isEmpty) {
      return 'SIN TURNOS ACTIVOS';
    }
    
    // Mostrar primer nombre de cada promotor activo
    final nombres = _promotoresActivos
        .map((p) => p.primerNombre)
        .toList();
    
    if (nombres.length == 1) {
      return 'Hola ${nombres[0]} 👋';
    }
    return 'Hola ${nombres.join(", ")} 👋';
  }

  /// Inicializar la sesión - obtener info de EDS, equipo y turnos
  Future<void> inicializar() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Obtener info de la EDS
      final estacionInfo = await _lazoService.getInformacionEstacion();
      if (estacionInfo != null) {
        _estacion = estacionInfo;
        _isConnected = true;
        print('[SessionProvider] EDS: ${estacionInfo.alias}');
      }

      // Obtener info del equipo/POS
      final equipoInfo = await _lazoService.getEquipoInfo();
      if (equipoInfo != null) {
        _equipo = equipoInfo;
        print('[SessionProvider] Equipo ID: ${equipoInfo.id}, Isla: ${equipoInfo.numeroIsla}');
      }

      // Obtener promotores activos
      final promotores = await _lazoService.getTurnosActivos();
      _promotoresActivos = promotores;
      print('[SessionProvider] Promotores activos: ${promotores.length}');

      // Obtener ventas pendientes iniciales via REST
      await refrescarVentasPendientes();
      
      // Conectar Socket.IO a LazoExpress para ventas pendientes en tiempo real
      _lazoSocketService.connect();
      
      // Escuchar estado de conexión para reintentar si falla la info inicial
      _iniciarListenerConexion();
      
      // Escuchar ventas pendientes via Socket.IO (real-time desde ms-lazo-express)
      _iniciarListenerVentasPendientes();
      
      // Escuchar ventas FE (Facturación Electrónica + Datafono)
      _iniciarListenerVentasFE();

      // Timer para refrescar turnos periódicamente (detectar cambios desde Java u otro lugar)
      _turnosRefreshTimer?.cancel();
      _turnosRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        refrescarTurnos();
      });

    } catch (e) {
      print('[SessionProvider] Error inicializando: $e');
      _isConnected = false;
    }

    _isLoading = false;
    notifyListeners();
  }
  
  /// Escuchar estado de conexión - reintentar info cuando LazoExpress se conecte
  void _iniciarListenerConexion() {
    _connectionStatusSub?.cancel();
    _connectionStatusSub = _lazoSocketService.connectionStatusStream.listen((isConnected) {
      if (isConnected && (_estacion == null || _equipo == null)) {
        print('[SessionProvider] 🔄 LazoExpress conectado, reintentando obtener info...');
        _refrescarInfoFaltante();
      }
    });
  }

  /// Refrescar solo la información que no se pudo obtener
  Future<void> _refrescarInfoFaltante() async {
    try {
      if (_estacion == null) {
        final estacionInfo = await _lazoService.getInformacionEstacion();
        if (estacionInfo != null) {
          _estacion = estacionInfo;
          _isConnected = true;
          print('[SessionProvider] ✅ EDS obtenida: ${estacionInfo.alias}');
        }
      }

      if (_equipo == null) {
        final equipoInfo = await _lazoService.getEquipoInfo();
        if (equipoInfo != null) {
          _equipo = equipoInfo;
          print('[SessionProvider] ✅ Equipo obtenido - ID: ${equipoInfo.id}, Isla: ${equipoInfo.numeroIsla}');
        }
      }

      // También refrescar ventas pendientes
      await refrescarVentasPendientes();
      
      notifyListeners();
    } catch (e) {
      print('[SessionProvider] Error refrescando info faltante: $e');
    }
  }

  /// Escuchar ventas pendientes via Socket.IO (real-time desde LazoExpress)
  void _iniciarListenerVentasPendientes() {
    _ventasPendientesSub?.cancel();
    _ventasPendientesSub = _lazoSocketService.ventasPendientesStream.listen((data) {
      final numeroVentas = data['numeroVentas'] ?? 0;
      final ventasCombustible = data['ventasCombustible'] ?? 0;
      final ventasCanastilla = data['ventasCanastilla'] ?? 0;
      final sincronizado = data['sincronizado'] ?? true;
      
      print('[SessionProvider] 💰 Socket.IO LazoExpress - Ventas pendientes: $numeroVentas');
      
      // Solo actualizar si cambió
      if (numeroVentas != _ventasPendientes.numeroVentas) {
        _ventasPendientes = VentasPendientes(
          numeroVentas: numeroVentas,
          ventasCombustible: ventasCombustible,
          ventasCanastilla: ventasCanastilla,
          sincronizado: sincronizado,
        );
        notifyListeners();
      }
    });
    print('[SessionProvider] Escuchando ventas pendientes via Socket.IO (LazoExpress)');
  }

  /// Escuchar ventas FE via Socket.IO (Facturación Electrónica + Datafono)
  void _iniciarListenerVentasFE() {
    _ventasFESub?.cancel();
    _ventasFESub = _lazoSocketService.ventasFEStream.listen((data) {
      final fe = data['facturaElectronica'] ?? 0;
      final dat = data['datafono'] ?? 0;
      
      print('[SessionProvider] 📋 Socket.IO LazoExpress - Ventas FE: F.E $fe, DAT $dat');
      
      // Solo actualizar si cambió
      if (fe != _ventasFE.facturaElectronica || dat != _ventasFE.datafono) {
        _ventasFE = VentasFE(facturaElectronica: fe, datafono: dat);
        notifyListeners();
      }
    });
    print('[SessionProvider] Escuchando ventas FE via Socket.IO (LazoExpress)');
  }

  /// Refrescar información de turnos
  Future<void> refrescarTurnos() async {
    try {
      final promotores = await _lazoService.getTurnosActivos();
      _promotoresActivos = promotores;
      notifyListeners();
    } catch (e) {
      print('[SessionProvider] Error refrescando turnos: $e');
    }
  }

  /// Refrescar ventas pendientes
  Future<void> refrescarVentasPendientes() async {
    try {
      final ventas = await _lazoService.getVentasPendientes();
      if (ventas.numeroVentas != _ventasPendientes.numeroVentas) {
        _ventasPendientes = ventas;
        print('[SessionProvider] Ventas pendientes: ${ventas.numeroVentas}');
        notifyListeners();
      }
    } catch (e) {
      print('[SessionProvider] Error refrescando ventas pendientes: $e');
    }
  }

  /// Refrescar toda la información
  Future<void> refrescar() async {
    await inicializar();
  }

  @override
  void dispose() {
    _turnosRefreshTimer?.cancel();
    _ventasPendientesSub?.cancel();
    _ventasFESub?.cancel();
    _connectionStatusSub?.cancel();
    _lazoSocketService.disconnect();
    super.dispose();
  }
}
