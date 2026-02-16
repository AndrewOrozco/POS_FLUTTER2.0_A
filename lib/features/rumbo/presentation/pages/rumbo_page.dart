import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/providers/session_provider.dart';
import '../../../../core/services/api_consultas_service.dart';
import '../../../../core/services/socket_io_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/teclado_tactil.dart';
import '../../../status_pump/presentation/providers/status_pump_provider.dart';

/// Pantalla RUMBO optimizada - Flujo en una sola pantalla
///
/// Java tiene 6+ pantallas: Medios → Mangueras → Km → Identificador → Datos → Venta
/// Flutter lo reduce a 1 pantalla con 4 secciones visibles simultáneamente:
///   1. Seleccionar manguera
///   2. Ingresar kilometraje
///   3. Seleccionar medio de identificación
///   4. Ingresar/esperar identificador
///   → Botón AUTORIZAR
///   → Pantalla AUTORIZADO con countdown timer
class RumboPage extends StatefulWidget {
  const RumboPage({super.key});

  @override
  State<RumboPage> createState() => _RumboPageState();
}

class _RumboPageState extends State<RumboPage> {
  final ApiConsultasService _apiService = ApiConsultasService();
  final TextEditingController _kmController = TextEditingController();
  final TextEditingController _serialController = TextEditingController();
  final TextEditingController _passController = TextEditingController();

  // Estado general
  List<MangueraRumbo> _mangueras = [];
  List<MedioIdentificacionRumbo> _medios = [];
  MangueraRumbo? _mangueraSeleccionada;
  MedioIdentificacionRumbo? _medioSeleccionado;
  bool _cargando = true;
  String? _campoActivo; // 'km', 'serial', 'pass'

  // Estado de autorización
  bool _autorizando = false;
  bool _autorizado = false;
  AutorizarRumboResponse? _respuestaAutorizacion;
  String? _mensajeError;

  // Estado de lector/polling
  bool _esperandoLector = false;
  bool _pollingActivo = false;

  // Estado del countdown timer
  Timer? _countdownTimer;
  int _segundosRestantes = 0;
  int _segundosTotales = 0;

  // WebSocket: detección de venta en curso
  final SocketIOService _socketService = SocketIOService();
  StreamSubscription<Map<String, dynamic>>? _wsSubscription;
  bool _ventaEnCurso = false;
  double _montoVenta = 0;
  double _volumenVenta = 0;

  // UREA: estado de procesamiento
  bool _procesandoUrea = false;
  final TextEditingController _cantidadUreaController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargarDatos();
    _kmController.addListener(() => setState(() {}));
    _serialController.addListener(() => setState(() {}));
    _passController.addListener(() => setState(() {}));
    _cantidadUreaController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _pollingActivo = false;
    _countdownTimer?.cancel();
    _wsSubscription?.cancel();
    _kmController.dispose();
    _serialController.dispose();
    _passController.dispose();
    _cantidadUreaController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    setState(() => _cargando = true);
    try {
      final resultados = await Future.wait([
        _apiService.getManguerasRumbo(),
        _apiService.getMediosIdentificacionRumbo(),
      ]);
      setState(() {
        _mangueras = resultados[0] as List<MangueraRumbo>;
        _medios = resultados[1] as List<MedioIdentificacionRumbo>;
        _cargando = false;
      });
    } catch (e) {
      setState(() {
        _cargando = false;
        _mensajeError = 'Error cargando datos: $e';
      });
    }
  }

  bool get _formularioCompleto {
    if (_mangueraSeleccionada == null) return false;
    if (_kmController.text.trim().isEmpty) return false;
    if (_medioSeleccionado == null) return false;
    if (_serialController.text.trim().isEmpty) return false;
    if (_medioSeleccionado!.id == 1 && _passController.text.trim().isEmpty) {
      return false;
    }
    return true;
  }

  // ============================================================
  // POLLING LECTOR
  // ============================================================

  void _iniciarPollingLector() {
    if (_pollingActivo) return;
    if (_mangueraSeleccionada == null) {
      _mostrarSnackbar('Seleccione una manguera primero para detectar la cara');
      return;
    }

    _pollingActivo = true;
    _esperandoLector = true;
    final cara = _mangueraSeleccionada!.cara;

    () async {
      while (_pollingActivo && mounted) {
        try {
          final lectura = await _apiService.getLecturaIdentificadorRumbo(
            cara: cara,
            segundosEspera: 8,
          );

          if (!_pollingActivo || !mounted) break;

          if (lectura != null) {
            final serial = lectura['serial'] as String? ?? '';
            final medio = lectura['medio'] as String? ?? '';
            final promotorNombre = lectura['promotor_nombre'] as String? ?? '';

            setState(() {
              _serialController.text = serial;
              _esperandoLector = false;
              _pollingActivo = false;
            });

            _mostrarSnackbar(
              'Identificador $medio leído: ${promotorNombre.isNotEmpty ? promotorNombre : serial}',
              color: Colors.green,
            );
            break;
          }
        } catch (e) {
          if (!mounted) break;
          await Future.delayed(const Duration(seconds: 1));
        }
      }
    }();
  }

  void _detenerPollingLector() {
    _pollingActivo = false;
    _esperandoLector = false;
    if (_mangueraSeleccionada != null) {
      _apiService.limpiarLecturaIdentificadorRumbo(_mangueraSeleccionada!.cara);
    }
  }

  // ============================================================
  // AUTORIZACIÓN
  // ============================================================

  Future<void> _autorizar() async {
    if (!_formularioCompleto || _autorizando) return;

    final km = int.tryParse(_kmController.text.trim());
    if (km == null || km <= 0) {
      _mostrarSnackbar('Ingrese un kilometraje válido');
      return;
    }
    if (km > 9999999999) {
      _mostrarSnackbar('Kilometraje debe ser menor a 9999999999');
      return;
    }

    setState(() {
      _autorizando = true;
      _mensajeError = null;
    });

    final m = _mangueraSeleccionada!;
    String serial = _serialController.text.trim();

    // Obtener promotor activo del SessionProvider
    // En Java: Main.persona.getId() y Main.persona.getIdentificacion()
    final session = Provider.of<SessionProvider>(context, listen: false);
    int? idPromotor;
    int? identificadorPromotor;
    if (session.promotoresActivos.isNotEmpty) {
      final promotor = session.promotoresActivos.first;
      idPromotor = promotor.id;
      if (promotor.identificacion != null) {
        identificadorPromotor = int.tryParse(promotor.identificacion!);
      }
      print('[RUMBO] Promotor activo: id=$idPromotor ident=$identificadorPromotor');
    }

    final response = await _apiService.autorizarRumbo(
      surtidor: m.surtidor,
      cara: m.cara,
      manguera: m.manguera,
      grado: m.grado,
      valorOdometro: km,
      codigoFamiliaProducto: m.familiaId,
      precioVentaUnidad: m.productoPrecio,
      medioAutorizacion: _medioSeleccionado!.id,
      serialIdentificador: serial,
      codigoSeguridad: _passController.text.trim(),
      codigoProducto: m.esUrea ? m.productoId : null,
      idPromotor: idPromotor,
      identificadorPromotor: identificadorPromotor,
    );

    if (!mounted) return;

    if (response.autorizado) {
      setState(() {
        _autorizando = false;
        _autorizado = true;
        _respuestaAutorizacion = response;
      });

      if (response.esUrea) {
        // UREA/AdBlue: No tiene countdown ni espera de surtidor
        // El operador acepta y la venta va a "Ventas sin resolver"
        // Java: loadSalePanelAdBlue() muestra litros y mensaje
        print('[RUMBO-UREA] Autorizado - litros: ${response.litrosAutorizados}');
      } else {
        // Combustible normal: countdown + escucha WebSocket
        final timeoutSec = response.timeoutAutorizacion ?? 30;
        setState(() {
          _segundosTotales = timeoutSec;
          _segundosRestantes = timeoutSec;
        });

        // Pre-asignar placa RUMBO al StatusPump para que aparezca cuando el surtidor empiece a despachar
        final placaRumbo = response.placaVehiculo ?? _serialController.text;
        if (placaRumbo.isNotEmpty) {
          final statusProvider = Provider.of<StatusPumpProvider>(context, listen: false);
          statusProvider.asignarPlacaRumbo(
            m.cara,
            placaRumbo,
            clienteNombre: response.nombreCliente,
          );
        }

        _iniciarCountdown();
        _iniciarEscuchaWebSocket();
      }
    } else {
      setState(() {
        _autorizando = false;
        _mensajeError = response.mensaje;
      });
    }
  }

  // ============================================================
  // WEBSOCKET: DETECTAR VENTA EN CURSO
  // ============================================================

  void _iniciarEscuchaWebSocket() {
    if (_mangueraSeleccionada == null) return;
    final caraAutorizada = _mangueraSeleccionada!.cara;

    _wsSubscription?.cancel();
    _wsSubscription = _socketService.estadoSurtidorStream.listen((data) {
      if (!mounted) return;

      final cara = data['numeroCara'] ?? data['cara'] ?? 0;
      if (cara != caraAutorizada) return;

      final codigoEstado = data['codigoEstadoSurtidor'] ??
          data['estado_publico'] ??
          data['estado'] ?? 0;

      print('[RUMBO-WS] Cara $cara → estado $codigoEstado');

      // 103 = DESPACHANDO (fueling)
      if (codigoEstado == 103 || codigoEstado == 104) {
        final monto = (data['monto'] ?? 0).toDouble();
        final volumen = (data['volumen'] ?? 0).toDouble();

        setState(() {
          _ventaEnCurso = true;
          _montoVenta = monto;
          _volumenVenta = volumen;
        });

        _countdownTimer?.cancel();

        // Auto-navegar al home después de 3 segundos
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            Navigator.of(context).pop();
          }
        });
      }
    });
  }

  // ============================================================
  // CONFIRMAR VENTA UREA
  // ============================================================

  Future<void> _confirmarVentaUrea() async {
    if (_procesandoUrea || _respuestaAutorizacion == null || _mangueraSeleccionada == null) return;

    final m = _mangueraSeleccionada!;
    final resp = _respuestaAutorizacion!;

    setState(() => _procesandoUrea = true);

    final dataCompleta = resp.dataCompleta ?? {};

    try {
      // Registrar en ct_movimientos con cantidad=0
      // La cantidad real se ingresa en "Ventas sin resolver"
      final resultado = await _apiService.confirmarVentaUrea(
        surtidor: m.surtidor,
        cara: m.cara,
        valorOdometro: int.tryParse(_kmController.text.trim()) ?? 0,
        codigoFamiliaProducto: m.familiaId,
        precioVentaUnidad: m.productoPrecio,
        serialIdentificador: _serialController.text.trim(),
        medioAutorizacion: _medioSeleccionado?.id ?? 2,
        dataCompleta: dataCompleta,
        codigoSeguridad: _passController.text.trim(),
        cantidadSuministrada: 0, // Se completa en Ventas sin resolver
      );

      if (!mounted) return;

      if (resultado['exito'] == true) {
        _mostrarSnackbar(
          'Venta UREA registrada - Cierre en Ventas sin resolver',
          color: Colors.green,
        );
        Navigator.of(context).pop();
      } else {
        setState(() => _procesandoUrea = false);
        _mostrarSnackbar(
          resultado['mensaje'] ?? 'Error al registrar venta UREA',
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _procesandoUrea = false);
      _mostrarSnackbar('Error: $e');
    }
  }

  // ============================================================
  // COUNTDOWN TIMER
  // ============================================================

  void _iniciarCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _segundosRestantes--;
        if (_segundosRestantes <= 0) {
          _segundosRestantes = 0;
          timer.cancel();
        }
      });
    });
  }

  String get _tiempoFormateado {
    final min = _segundosRestantes ~/ 60;
    final seg = _segundosRestantes % 60;
    return '${min}MIN(S) Y ${seg}SEG(S)';
  }

  double get _progresoTimer {
    if (_segundosTotales <= 0) return 0;
    return _segundosRestantes / _segundosTotales;
  }

  // ============================================================
  // LIMPIAR
  // ============================================================

  void _limpiarFormulario() {
    _detenerPollingLector();
    _countdownTimer?.cancel();
    _wsSubscription?.cancel();
    setState(() {
      _mangueraSeleccionada = null;
      _medioSeleccionado = null;
      _kmController.clear();
      _serialController.clear();
      _passController.clear();
      _cantidadUreaController.clear();
      _autorizado = false;
      _autorizando = false;
      _ventaEnCurso = false;
      _respuestaAutorizacion = null;
      _mensajeError = null;
      _campoActivo = null;
      _esperandoLector = false;
      _segundosRestantes = 0;
      _segundosTotales = 0;
      _montoVenta = 0;
      _volumenVenta = 0;
    });
  }

  // ============================================================
  // UTILIDADES
  // ============================================================

  TextEditingController? get _controllerActivo {
    switch (_campoActivo) {
      case 'km':
        return _kmController;
      case 'serial':
        return _serialController;
      case 'pass':
        return _passController;
      default:
        return null;
    }
  }

  bool get _tecladoNumerico {
    // Numérico para: Kilometraje, PIN/contraseña, Código Numérico (5) y Tarjeta (1)
    return _campoActivo == 'km' || _campoActivo == 'pass' ||
        (_campoActivo == 'serial' && (_medioSeleccionado?.id == 5 || _medioSeleccionado?.id == 1));
  }

  void _mostrarSnackbar(String msg, {Color color = Colors.red}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontSize: 16)),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: AppTheme.terpeRed,
        foregroundColor: Colors.white,
        title: const Text('RUMBO', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (_autorizado || _mensajeError != null)
            TextButton.icon(
              onPressed: _limpiarFormulario,
              icon: const Icon(Icons.refresh, color: Colors.white),
              label: const Text('Nueva', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _ventaEnCurso
              ? _buildPantallaVentaEnCurso()
              : _autorizando
                  ? _buildPantallaAutorizando()
                  : _autorizado
                      ? (_respuestaAutorizacion?.esUrea == true
                          ? _buildPantallaAutorizadoUrea()
                          : _buildPantallaAutorizado())
                      : _buildPantallaFormulario(),
    );
  }

  // ============================================================
  // PANTALLA: VENTA EN CURSO (detectada vía WebSocket)
  // ============================================================

  Widget _buildPantallaVentaEnCurso() {
    final m = _mangueraSeleccionada;
    final resp = _respuestaAutorizacion;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icono animado
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.green.shade50,
              border: Border.all(color: Colors.green, width: 3),
            ),
            child: const Icon(
              Icons.local_gas_station,
              size: 56,
              color: Colors.green,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'VENTA EN CURSO',
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'DESPACHANDO EN CARA ${m?.cara ?? ""}',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 24),
          // Info
          Container(
            width: 450,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade300,
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                if (m != null)
                  _infoRow('PRODUCTO', m.productoDescripcion),
                if (resp?.placaVehiculo?.isNotEmpty == true)
                  _infoRow('PLACA', resp!.placaVehiculo!),
                if (resp?.nombreCliente?.isNotEmpty == true)
                  _infoRow('CLIENTE', resp!.nombreCliente!),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Volviendo al inicio...',
            style: TextStyle(
              fontSize: 16,
              fontStyle: FontStyle.italic,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: 200,
            child: LinearProgressIndicator(
              backgroundColor: Colors.grey.shade200,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.terpeRed,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // PANTALLA: SOLICITANDO AUTORIZACIÓN (loading fullscreen)
  // ============================================================

  Widget _buildPantallaAutorizando() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 80,
            height: 80,
            child: CircularProgressIndicator(
              strokeWidth: 6,
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.terpeRed),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'SOLICITANDO AUTORIZACIÓN',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppTheme.terpeRed,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Manguera ${_mangueraSeleccionada?.manguera ?? ""} - ${_mangueraSeleccionada?.productoDescripcion ?? ""}',
            style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // PANTALLA: AUTORIZADO PARA VENDER (con countdown)
  // ============================================================

  Widget _buildPantallaAutorizado() {
    final resp = _respuestaAutorizacion!;
    final m = _mangueraSeleccionada!;
    final tiempoVencido = _segundosRestantes <= 0;
    final tiempoAdvertencia = _segundosRestantes <= 10 && !tiempoVencido;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Título
            Text(
              'AUTORIZADO PARA VENDER',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: tiempoVencido ? Colors.grey : AppTheme.terpeRed,
              ),
            ),
            const SizedBox(height: 32),

            // Card con info de la venta
            Container(
              width: 500,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: tiempoVencido ? Colors.grey.shade400 : AppTheme.terpeRed,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.shade300,
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Manguera
                  Column(
                    children: [
                      const Text(
                        'MANGUERA',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF666666),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${m.manguera}',
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.terpeRed,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 32),
                  // Info producto y placa
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'PRODUCTO',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF666666),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          m.productoDescripcion,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.terpeRed,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'PLACA',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF666666),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          resp.placaVehiculo?.isNotEmpty == true
                              ? resp.placaVehiculo!
                              : _serialController.text,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.terpeRed,
                          ),
                        ),
                        if (resp.nombreCliente?.isNotEmpty == true) ...[
                          const SizedBox(height: 12),
                          const Text(
                            'CLIENTE',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF666666),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            resp.nombreCliente!,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF333333),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Countdown timer
            Container(
              width: 500,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.shade200,
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Timer text + progress bar
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tiempoVencido
                              ? 'TIEMPO VENCIDO'
                              : 'EL TIEMPO VENCERÁ... EN',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: tiempoVencido
                                ? Colors.red.shade700
                                : Colors.grey.shade700,
                          ),
                        ),
                        if (!tiempoVencido) ...[
                          const SizedBox(height: 4),
                          Text(
                            _tiempoFormateado,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: tiempoAdvertencia
                                  ? Colors.red.shade700
                                  : const Color(0xFF333333),
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: _progresoTimer,
                            minHeight: 12,
                            backgroundColor: Colors.grey.shade200,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              tiempoVencido
                                  ? Colors.grey
                                  : tiempoAdvertencia
                                      ? Colors.red
                                      : AppTheme.terpeRed,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  // Hourglass icon
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: tiempoVencido
                          ? Colors.grey.shade100
                          : Colors.orange.shade50,
                    ),
                    child: Icon(
                      tiempoVencido
                          ? Icons.timer_off
                          : Icons.hourglass_bottom,
                      size: 40,
                      color: tiempoVencido
                          ? Colors.grey
                          : Colors.orange.shade700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Botón nueva autorización
            SizedBox(
              width: 300,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _limpiarFormulario,
                icon: const Icon(Icons.refresh),
                label: const Text(
                  'NUEVA AUTORIZACIÓN',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey.shade700,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // PANTALLA: AUTORIZADO UREA/AdBlue (sin countdown, sin surtidor)
  // ============================================================

  Widget _buildPantallaAutorizadoUrea() {
    final resp = _respuestaAutorizacion!;
    final m = _mangueraSeleccionada!;
    final litros = resp.litrosAutorizados ?? 0;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Título
            Text(
              'AUTORIZADO PARA VENDER',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: AppTheme.terpeRed,
              ),
            ),
            const SizedBox(height: 32),

            // Card con info UREA
            Container(
              width: 500,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.terpeRed, width: 2),
                boxShadow: [
                  BoxShadow(color: Colors.grey.shade300, blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Row(
                children: [
                  // Litros
                  Column(
                    children: [
                      const Text('LITROS', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF666666))),
                      const SizedBox(height: 8),
                      Text(
                        litros.toStringAsFixed(1),
                        style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: AppTheme.terpeRed),
                      ),
                    ],
                  ),
                  const SizedBox(width: 32),
                  // Info producto, placa y cliente
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          m.productoDescripcion,
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.terpeRed),
                        ),
                        const SizedBox(height: 12),
                        const Text('PLACA', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF666666))),
                        const SizedBox(height: 4),
                        Text(
                          resp.placaVehiculo?.isNotEmpty == true ? resp.placaVehiculo! : _serialController.text,
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.terpeRed),
                        ),
                        if (resp.nombreCliente?.isNotEmpty == true) ...[
                          const SizedBox(height: 12),
                          const Text('CLIENTE', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF666666))),
                          const SizedBox(height: 4),
                          Text(
                            resp.nombreCliente!,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF333333)),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Mensaje recordatorio
            Container(
              width: 500,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue.shade700, size: 24),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Recuerde cerrar la venta en la opción Ventas sin resolver',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Color(0xFF333333)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Botón ACEPTAR
            SizedBox(
              width: 300,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _procesandoUrea ? null : _confirmarVentaUrea,
                icon: _procesandoUrea
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                    : const Icon(Icons.check_circle, size: 28),
                label: Text(
                  _procesandoUrea ? 'REGISTRANDO...' : 'ACEPTAR',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.terpeRed,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Botón NUEVA AUTORIZACIÓN
            SizedBox(
              width: 300,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: _limpiarFormulario,
                icon: const Icon(Icons.refresh),
                label: const Text('NUEVA AUTORIZACIÓN', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.grey.shade700,
                  side: BorderSide(color: Colors.grey.shade400),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // PANTALLA: FORMULARIO PRINCIPAL
  // ============================================================

  Widget _buildPantallaFormulario() {
    return Row(
      children: [
        // Panel izquierdo: Formulario
        Expanded(
          flex: 3,
          child: _buildFormulario(),
        ),
        // Panel derecho: Teclado (más amplio para mejor usabilidad)
        SizedBox(
          width: 350,
          child: _buildPanelTeclado(),
        ),
      ],
    );
  }

  Widget _buildFormulario() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSeccionMangueras(),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildSeccionKilometraje()),
              const SizedBox(width: 16),
              Expanded(flex: 2, child: _buildSeccionMedios()),
            ],
          ),
          const SizedBox(height: 16),
          _buildSeccionIdentificador(),
          const SizedBox(height: 20),
          _buildBotonAutorizar(),
          if (_mensajeError != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange),
              ),
              child: Text(
                _mensajeError!,
                style: TextStyle(
                  color: Colors.orange.shade800,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // SECCIONES DEL FORMULARIO
  // ============================================================

  Widget _buildSeccionMangueras() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.grey.shade200, blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_gas_station, color: AppTheme.terpeRed, size: 22),
              const SizedBox(width: 8),
              const Text(
                'MANGUERA',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Color(0xFF333333),
                ),
              ),
              if (_mangueraSeleccionada != null) ...[
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.terpeRed.withAlpha(20),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_mangueraSeleccionada!.productoDescripcion} - \$${_mangueraSeleccionada!.productoPrecio.toStringAsFixed(0)}/gal',
                    style: TextStyle(
                      color: AppTheme.terpeRed,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _mangueras.map((m) {
              final seleccionada = _mangueraSeleccionada?.manguera == m.manguera &&
                  _mangueraSeleccionada?.cara == m.cara;
              final esUrea = m.esUrea;
              return GestureDetector(
                onTap: m.bloqueado
                    ? null
                    : () => setState(() => _mangueraSeleccionada = m),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 75,
                  height: 75,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: m.bloqueado
                        ? Colors.grey.shade300
                        : seleccionada
                            ? (esUrea ? const Color(0xFF2E7D32) : AppTheme.terpeRed)
                            : (esUrea ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE)),
                    border: Border.all(
                      color: seleccionada
                          ? (esUrea ? const Color(0xFF2E7D32) : AppTheme.terpeRed)
                          : Colors.grey.shade300,
                      width: seleccionada ? 3 : 1,
                    ),
                    boxShadow: seleccionada
                        ? [BoxShadow(color: (esUrea ? Colors.green : AppTheme.terpeRed).withAlpha(80), blurRadius: 8)]
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      esUrea ? 'UREA' : '${m.manguera}',
                      style: TextStyle(
                        color: m.bloqueado
                            ? Colors.grey
                            : seleccionada
                                ? Colors.white
                                : (esUrea ? const Color(0xFF2E7D32) : AppTheme.terpeRed),
                        fontWeight: FontWeight.bold,
                        fontSize: esUrea ? 13 : 20,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSeccionKilometraje() {
    final activo = _campoActivo == 'km';
    return GestureDetector(
      onTap: () => setState(() => _campoActivo = 'km'),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: activo ? Border.all(color: AppTheme.terpeRed, width: 2) : null,
          boxShadow: [
            BoxShadow(color: Colors.grey.shade200, blurRadius: 4, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.speed, color: AppTheme.terpeRed, size: 22),
                const SizedBox(width: 8),
                const Text(
                  'KILOMETRAJE',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Color(0xFF333333),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: activo ? Colors.red.shade50 : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: activo ? AppTheme.terpeRed : Colors.grey.shade300,
                  width: activo ? 2 : 1,
                ),
              ),
              child: Text(
                _kmController.text.isEmpty ? 'Ingrese km' : _kmController.text,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: _kmController.text.isEmpty ? Colors.grey : Colors.black87,
                  letterSpacing: 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeccionMedios() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.grey.shade200, blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.fingerprint, color: AppTheme.terpeRed, size: 22),
              const SizedBox(width: 8),
              const Text(
                'MEDIO DE AUTORIZACIÓN',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Color(0xFF333333),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: _medios.map((medio) {
              final seleccionado = _medioSeleccionado?.id == medio.id;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: GestureDetector(
                    onTap: () {
                      _detenerPollingLector();
                      setState(() {
                        _medioSeleccionado = medio;
                        _serialController.clear();
                        _passController.clear();
                        if (!medio.requiereLector) {
                          _campoActivo = 'serial';
                        } else {
                          _campoActivo = null;
                          _iniciarPollingLector();
                        }
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                      decoration: BoxDecoration(
                        color: seleccionado ? AppTheme.terpeRed.withAlpha(20) : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: seleccionado ? AppTheme.terpeRed : Colors.grey.shade300,
                          width: seleccionado ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _iconoMedio(medio.icono),
                            size: 28,
                            color: seleccionado ? AppTheme.terpeRed : Colors.grey.shade600,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            medio.descripcion,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: seleccionado ? FontWeight.bold : FontWeight.w500,
                              color: seleccionado ? AppTheme.terpeRed : Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSeccionIdentificador() {
    if (_medioSeleccionado == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(color: Colors.grey.shade200, blurRadius: 4, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.info_outline, color: Colors.grey.shade400),
            const SizedBox(width: 8),
            Text(
              'Seleccione un medio de autorización',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
            ),
          ],
        ),
      );
    }

    if (_medioSeleccionado!.requiereLector) {
      return _buildEsperaLector();
    }
    return _buildCamposManual();
  }

  Widget _buildEsperaLector() {
    final yaLeido = _serialController.text.isNotEmpty;

    if (yaLeido) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green, width: 2),
          boxShadow: [
            BoxShadow(color: Colors.grey.shade200, blurRadius: 4, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 40),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'IDENTIFICADOR LEÍDO',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_medioSeleccionado!.descripcion}: ${_serialController.text}',
                    style: TextStyle(fontSize: 14, color: Colors.green.shade700),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
        boxShadow: [
          BoxShadow(color: Colors.grey.shade200, blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          Icon(
            _medioSeleccionado!.id == 2 ? Icons.vpn_key : Icons.nfc,
            size: 48,
            color: Colors.blue.shade400,
          ),
          const SizedBox(height: 12),
          Text(
            'PRESENTE POR FAVOR SU IDENTIFICADOR',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _medioSeleccionado!.descripcion,
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 12),
          if (_esperandoLector) ...[
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: Colors.blue.shade400,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _mangueraSeleccionada != null
                  ? 'Escuchando cara ${_mangueraSeleccionada!.cara}...'
                  : 'Seleccione manguera para escuchar',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
            ),
          ] else ...[
            Text(
              'Seleccione una manguera primero',
              style: TextStyle(fontSize: 13, color: Colors.orange.shade700),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCamposManual() {
    final esTarjeta = _medioSeleccionado!.id == 1;
    final esCodigo = _medioSeleccionado!.id == 5;
    final activoSerial = _campoActivo == 'serial';
    final activoPass = _campoActivo == 'pass';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.grey.shade200, blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: GestureDetector(
              onTap: () => setState(() => _campoActivo = 'serial'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    esTarjeta ? 'SERIAL TARJETA' : 'CÓDIGO NUMÉRICO',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFF333333),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      color: activoSerial ? Colors.red.shade50 : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: activoSerial ? AppTheme.terpeRed : Colors.grey.shade300,
                        width: activoSerial ? 2 : 1,
                      ),
                    ),
                    child: Text(
                      _serialController.text.isEmpty
                          ? (esCodigo ? 'Ingrese código' : 'Ingrese serial')
                          : (esTarjeta ? '•' * _serialController.text.length : _serialController.text),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: _serialController.text.isEmpty ? Colors.grey : Colors.black87,
                        letterSpacing: esTarjeta ? 4 : 2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (esTarjeta) ...[
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _campoActivo = 'pass'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'CONTRASEÑA',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Color(0xFF333333),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      decoration: BoxDecoration(
                        color: activoPass ? Colors.red.shade50 : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: activoPass ? AppTheme.terpeRed : Colors.grey.shade300,
                          width: activoPass ? 2 : 1,
                        ),
                      ),
                      child: Text(
                        _passController.text.isEmpty
                            ? 'PIN'
                            : '•' * _passController.text.length,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: _passController.text.isEmpty ? Colors.grey : Colors.black87,
                          letterSpacing: 4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBotonAutorizar() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: _formularioCompleto ? _autorizar : null,
        icon: const Icon(Icons.verified_user, size: 28),
        label: const Text(
          'AUTORIZAR VENTA',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _formularioCompleto ? AppTheme.terpeRed : Colors.grey.shade400,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: _formularioCompleto ? 4 : 0,
        ),
      ),
    );
  }

  // ============================================================
  // PANEL TECLADO
  // ============================================================

  Widget _buildPanelTeclado() {
    return Container(
      color: Colors.grey.shade200,
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _campoActivo == null
                  ? 'Toque un campo'
                  : _campoActivo == 'km'
                      ? 'Kilometraje'
                      : _campoActivo == 'serial'
                          ? (_medioSeleccionado?.id == 5 ? 'Código Numérico' : 'Serial Tarjeta')
                          : 'Contraseña',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: _campoActivo != null ? AppTheme.terpeRed : Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: _controllerActivo != null
                ? TecladoTactil(
                    controller: _controllerActivo!,
                    soloNumeros: _tecladoNumerico,
                    onAceptar: () {
                      if (_campoActivo == 'km') {
                        if (_medioSeleccionado != null && !_medioSeleccionado!.requiereLector) {
                          setState(() => _campoActivo = 'serial');
                        }
                      } else if (_campoActivo == 'serial' && _medioSeleccionado?.id == 1) {
                        setState(() => _campoActivo = 'pass');
                      } else {
                        if (_formularioCompleto) _autorizar();
                      }
                    },
                  )
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.keyboard, size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text(
                          'Toque un campo\npara activar el teclado',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // HELPERS
  // ============================================================

  IconData _iconoMedio(String icono) {
    switch (icono) {
      case 'vpn_key':
        return Icons.vpn_key;
      case 'nfc':
        return Icons.nfc;
      case 'credit_card':
        return Icons.credit_card;
      case 'pin':
        return Icons.pin;
      default:
        return Icons.help_outline;
    }
  }
}
