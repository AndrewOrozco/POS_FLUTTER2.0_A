import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/header_widget.dart';
import '../widgets/sidebar_widget.dart';
import '../widgets/center_content_widget.dart';
import '../widgets/menu_grid_widget.dart';
import '../widgets/status_bubbles_widget.dart';
import '../widgets/ventas_fe_banner_widget.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/api_consultas_service.dart';
import '../../../../core/services/payment_websocket_service.dart';
import '../../../../core/services/notification_websocket_service.dart';
import '../../../../core/widgets/top_notification.dart';
import '../../../../core/providers/session_provider.dart';
import '../../../status_pump/status_pump.dart';
import '../../../status_pump/presentation/providers/status_pump_provider.dart';
import '../../../status_pump/domain/entities/surtidor_estado.dart';
import '../widgets/medios_pago_bottom_sheet.dart';
import '../../../status_pump/presentation/pages/gestionar_venta_page.dart';
import '../../../turnos/presentation/pages/turnos_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  StreamSubscription<AppTerpelVentaTerminada>? _appTerpelSubscription;
  StreamSubscription<PaymentNotification>? _paymentWsSubscription;
  StreamSubscription<VentaTerminada>? _ventaTerminadaSubscription;
  StreamSubscription<BackendNotification>? _backendNotifSubscription;
  final ApiConsultasService _apiService = ApiConsultasService();
  /// Caras gestionadas → monto al momento de guardar.
  /// Cuando el monto baja (venta nueva), se limpia automáticamente.
  final Map<int, double> _carasGestionadasMonto = {};
  /// Caras que ya están en proceso de impresión (evitar duplicados)
  final Set<int> _carasImprimiendo = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Escuchar cuando un surtidor con APP TERPEL termina de despachar
      final provider = context.read<StatusPumpProvider>();
      _appTerpelSubscription = provider.appTerpelTerminadaStream.listen((evento) {
        _onAppTerpelVentaTerminada(evento);
      });

      // Escuchar cuando CUALQUIER venta termina → impresión automática
      _ventaTerminadaSubscription = provider.ventaTerminadaStream.listen((evento) {
        _onVentaTerminada(evento);
      });

      // Escuchar notificaciones de pago del orquestador via WebSocket
      _paymentWsSubscription = PaymentWebSocketService().notificationStream.listen((notification) {
        _onPaymentNotification(notification);
      });

      // Escuchar notificaciones del backend Python (errores 7011, impresión, etc.)
      final notifService = NotificationWebSocketService();
      notifService.connect();
      _backendNotifSubscription = notifService.notificationStream.listen((notif) {
        _onBackendNotification(notif);
      });
    });
  }

  @override
  void dispose() {
    _appTerpelSubscription?.cancel();
    _paymentWsSubscription?.cancel();
    _ventaTerminadaSubscription?.cancel();
    _backendNotifSubscription?.cancel();
    super.dispose();
  }

  // Evitar mostrar diálogos duplicados (el orquestador a veces manda 2 callbacks)
  DateTime? _lastPaymentNotificationTime;

  /// Mostrar alerta cuando el orquestador notifica un pago aprobado/rechazado
  void _onPaymentNotification(PaymentNotification notification) {
    if (!mounted) return;

    // Notificación "pendiente" de APP TERPEL: mostrar diálogo de countdown para escanear QR
    if (notification.isAppTerpel && notification.isPendiente) {
      if (PaymentWebSocketService().countdownDialogActive) {
        print('[HomePage] Notificación pendiente APP TERPEL ignorada (CountdownDialog activo)');
        return;
      }
      _mostrarDialogoEscaneoQR(notification);
      return;
    }

    // Si el CountdownDialog está activo, él ya maneja las notificaciones APP TERPEL
    if (PaymentWebSocketService().countdownDialogActive && notification.isAppTerpel) {
      print('[HomePage] Notificación APP TERPEL ignorada (CountdownDialog activo)');
      return;
    }

    // Ignorar notificaciones seguidas dentro de 15 segundos
    // (pueden llegar múltiples callbacks de diferentes ventas casi al mismo tiempo)
    final now = DateTime.now();
    if (_lastPaymentNotificationTime != null &&
        now.difference(_lastPaymentNotificationTime!).inSeconds < 15) {
      print('[HomePage] Notificación ignorada (dentro de ventana 15s)');
      return;
    }
    _lastPaymentNotificationTime = now;

    final bool aprobado = notification.isAprobado;
    final Color color = aprobado ? Colors.green : Colors.red;
    final IconData icono = aprobado ? Icons.check_circle : Icons.cancel;
    final String estado = aprobado ? 'APROBADO' : 'RECHAZADO';

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: EdgeInsets.zero,
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.phone_iphone, color: Colors.white, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        notification.titulo,
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              // Contenido
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: color.withAlpha(25),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icono, size: 48, color: color),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Pago $estado',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      notification.mensaje,
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                      textAlign: TextAlign.center,
                    ),
                    if (!aprobado) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.orange.withAlpha(20),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.withAlpha(80)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.orange, size: 18),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Debe gestionar la venta con otro medio de pago',
                                style: TextStyle(fontSize: 12, color: Colors.orange),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Botón cerrar
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      aprobado ? 'CERRAR' : 'CERRAR - ASIGNAR OTRO MEDIO',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Manejar notificaciones del backend Python (errores 7011, impresión, etc.)
  /// Se muestra como notificación tipo Steam (no bloqueante, arriba derecha)
  void _onBackendNotification(BackendNotification notif) {
    if (!mounted) return;

    print('[HomePage] Backend notificación: [${notif.type}] ${notif.title} - ${notif.message}');

    // Mapear severity a tipo de notificación
    NotificationType type;
    switch (notif.severity) {
      case 'success':
        type = NotificationType.success;
        break;
      case 'warning':
        type = NotificationType.warning;
        break;
      case 'error':
        type = NotificationType.error;
        break;
      default:
        type = NotificationType.info;
    }

    // Duración: errores/warnings duran más para que el promotor los vea
    final duration = notif.isError
        ? const Duration(seconds: 10)
        : const Duration(seconds: 5);

    TopNotification.show(
      context,
      message: notif.title,
      subtitle: notif.message,
      type: type,
      duration: duration,
    );
  }

  /// Cuando la venta con APP TERPEL termina de despachar (flujo Status Pump).
  /// NO envía al orquestador: ms-lazoexpress/lazoexpress ya lo hace automáticamente.
  /// Solo limpia el flag de ventas_curso y muestra notificación informativa.
  /// El resultado (aprobado/rechazado) llegará por WebSocket → _onPaymentNotification.
  void _onAppTerpelVentaTerminada(AppTerpelVentaTerminada evento) async {
    print('[HomePage] Venta APP TERPEL terminada en cara ${evento.cara}');
    print('[HomePage] LazoExpress se encarga de enviar al orquestador. Flutter solo escucha WS.');
    
    // IMPORTANTE: Limpiar isAppTerpel de ventas_curso INMEDIATAMENTE
    // para que la siguiente venta en la misma cara NO herede el flag
    _apiService.limpiarAppTerpelVentasCurso(evento.cara);
    
    if (!mounted) return;
    
    // Solo informar al promotor que el pago se está procesando
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.phone_iphone, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(child: Text('APP TERPEL cara ${evento.cara} - Pago en proceso, esperando respuesta...')),
        ]),
        backgroundColor: const Color(0xFF6A1B9A),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  /// Cuando CUALQUIER venta termina de despachar (PEOT/FEOT).
  /// Dispara impresión automática: espera a que el backend cree el movimiento
  /// en ct_movimientos, obtiene el movimiento_id, y envía a imprimir.
  /// Replica el comportamiento de Java: ControlImpresion.java
  void _onVentaTerminada(VentaTerminada evento) async {
    print('[HomePage] Venta terminada en cara ${evento.cara}, monto: ${evento.monto}');
    
    // Evitar impresión duplicada si la misma cara ya está en proceso
    if (_carasImprimiendo.contains(evento.cara)) {
      print('[HomePage] Cara ${evento.cara} ya está en proceso de impresión, ignorando');
      return;
    }
    _carasImprimiendo.add(evento.cara);
    
    try {
      await _intentarImprimirVenta(evento.cara);
    } finally {
      _carasImprimiendo.remove(evento.cara);
    }
  }

  /// Cuando la venta termina, verificamos el estado pero NO imprimimos.
  /// LazoExpress se encarga de toda la impresión:
  ///   - statusPump=true  → LazoExpress envía a enviar-fe-pump (FE 7011 + impresión)
  ///   - statusPump=false → LazoExpress imprime localmente
  ///
  /// Flutter NO debe intentar imprimir porque venta-activa-cara puede devolver
  /// un movimiento anterior (ej: 488 en vez de 489 — el nuevo aún no tiene cara
  /// en atributos cuando Flutter consulta).
  Future<void> _intentarImprimirVenta(int cara) async {
    // Esperar un poco para que LazoExpress cree el movimiento
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;

    try {
      final ventaActiva = await _apiService.getVentaActivaPorCara(cara);
      if (ventaActiva.found && ventaActiva.movimientoId != null) {
        if (ventaActiva.statusPump) {
          print('[HomePage] statusPump=true cara $cara → LazoExpress envía a enviar-fe-pump');
        } else {
          print('[HomePage] statusPump=false cara $cara → LazoExpress imprime localmente');
        }
      } else {
        print('[HomePage] No se encontró movimiento para cara $cara (LazoExpress aún lo procesa)');
      }
    } catch (e) {
      print('[HomePage] Error consultando venta para cara $cara: $e');
    }
  }

  /// Mostrar diálogo de countdown para escanear QR de App Terpel
  void _mostrarDialogoEscaneoQR(PaymentNotification notification) {
    print('[HomePage] Mostrando diálogo de escaneo QR App Terpel');
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ScanQRCountdownDialog(
        mensaje: notification.mensaje,
      ),
    );
  }

  void _onMediosPago(int cara) {
    final provider = context.read<StatusPumpProvider>();
    final surtidor = provider.surtidoresActivos.firstWhere(
      (s) => s.cara == cara,
      orElse: () => SurtidorEstado(surtidorId: 0, cara: cara, manguera: 0, estado: EstadoSurtidor.unknown),
    );
    
    showMediosPagoBottomSheet(context, surtidor);
  }

  void _onGestionarVenta(int cara) {
    final provider = context.read<StatusPumpProvider>();
    final surtidor = provider.surtidoresActivos.firstWhere(
      (s) => s.cara == cara,
      orElse: () => SurtidorEstado(surtidorId: 0, cara: cara, manguera: 0, estado: EstadoSurtidor.unknown),
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GestionarVentaPage(surtidor: surtidor),
      ),
    ).then((resultado) {
      if (resultado == true && mounted) {
        // Guardar el monto actual para detectar venta nueva
        final montoActual = provider.surtidoresActivos
            .where((s) => s.cara == cara)
            .map((s) => s.monto)
            .firstOrNull ?? 0.0;
        setState(() => _carasGestionadasMonto[cara] = montoActual);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('Datos de factura guardados'),
              ],
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    });
  }

  Widget _buildSinTurnoOverlay(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.55),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(Icons.local_gas_station_rounded, size: 64, color: Colors.grey.shade400),
                  Positioned(
                    right: -6,
                    bottom: -6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.red.shade700,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2.5),
                      ),
                      child: const Icon(Icons.lock_rounded, size: 20, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'SURTIDORES BLOQUEADOS',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Inicie turno para operar los surtidores',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const TurnosPage()),
                      );
                    },
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('INICIAR TURNO', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Header
          const HeaderWidget(),
          // Contenido principal
          Expanded(
            child: Container(
              color: AppTheme.mediumGray,
              child: Stack(
                children: [
                  Row(
                    children: [
                      // Barra lateral izquierda
                      const SidebarWidget(),
                      // Contenido central: logo FIJO + surtidores flotando encima
                      Expanded(
                        flex: 2,
                        child: Consumer<SessionProvider>(
                          builder: (context, session, _) {
                            final sinTurno = session.promotoresActivos.isEmpty;
                            return Stack(
                              children: [
                                // Logo Terpel siempre centrado (fijo, no se mueve)
                                const Positioned.fill(
                                  child: Align(
                                    alignment: Alignment.center,
                                    child: CenterContentWidget(),
                                  ),
                                ),
                                // Surtidores activos flotan arriba (no empujan el logo)
                                if (!sinTurno)
                                  Positioned(
                                    top: 0,
                                    left: 0,
                                    right: 0,
                                    child: Builder(
                                      builder: (context) {
                                        // Limpiar caras gestionadas cuando el monto baja (venta nueva)
                                        final provider = context.watch<StatusPumpProvider>();
                                        final carasValidas = <int>{};
                                        for (final entry in _carasGestionadasMonto.entries) {
                                          final surtidor = provider.surtidoresActivos
                                              .where((s) => s.cara == entry.key)
                                              .firstOrNull;
                                          if (surtidor != null && surtidor.monto >= entry.value && surtidor.estado.estaActivo) {
                                            carasValidas.add(entry.key);
                                          }
                                        }
                                        // Limpiar flags de ventas que ya terminaron
                                        _carasGestionadasMonto.removeWhere((cara, _) => !carasValidas.contains(cara));
                                        return SurtidorListWidget(
                                          onGestionarVenta: _onGestionarVenta,
                                          onMediosPago: _onMediosPago,
                                          carasGestionadas: carasValidas,
                                        );
                                      },
                                    ),
                                  ),
                                // Overlay de bloqueo cuando no hay turno activo
                                if (sinTurno)
                                  Positioned.fill(
                                    child: _buildSinTurnoOverlay(context),
                                  ),
                              ],
                            );
                          },
                        ),
                      ),
                      // Panel derecho con botones en grid
                      const MenuGridWidget(),
                    ],
                  ),
                  // Iconos de estado posicionados independientemente
                  const StatusBubblesWidget(),
                ],
              ),
            ),
          ),
          // Banner de ventas en proceso (F.E + Datafono)
          const VentasFEBannerWidget(),
        ],
      ),
    );
  }
}

// El bottom sheet de medios de pago fue extraído a:
// ../widgets/medios_pago_bottom_sheet.dart

// ============================================================
// DIÁLOGO COUNTDOWN ESCANEO QR - APP TERPEL
// ============================================================
// Se muestra cuando el orquestador envía el pago al servicio
// appTerpelPaymentIntegration y notifica que el cliente
// ya puede escanear el código QR (tipo: "pendiente").
// Se auto-cierra al recibir la notificación de resultado.
// ============================================================

class ScanQRCountdownDialog extends StatefulWidget {
  final String mensaje;

  const ScanQRCountdownDialog({
    super.key,
    required this.mensaje,
  });

  @override
  State<ScanQRCountdownDialog> createState() => _ScanQRCountdownDialogState();
}

class _ScanQRCountdownDialogState extends State<ScanQRCountdownDialog>
    with SingleTickerProviderStateMixin {
  
  static const int _tiempoTotal = 90;
  late AnimationController _countdownController;
  int _segundosRestantes = _tiempoTotal;
  StreamSubscription<PaymentNotification>? _wsSubscription;
  bool _resultadoRecibido = false;
  bool _aprobado = false;
  String _mensajeResultado = '';

  @override
  void initState() {
    super.initState();
    PaymentWebSocketService().countdownDialogActive = true;
    _countdownController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: _tiempoTotal),
    );

    _countdownController.addListener(() {
      if (!mounted) return;
      final remaining = (_tiempoTotal * (1 - _countdownController.value)).ceil();
      if (remaining != _segundosRestantes) {
        setState(() => _segundosRestantes = remaining);
      }
    });

    _countdownController.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted && !_resultadoRecibido) {
        setState(() {
          _mensajeResultado = 'El tiempo para escanear el QR ha finalizado';
        });
      }
    });

    _countdownController.forward();
    _escucharResultado();
  }

  @override
  void dispose() {
    PaymentWebSocketService().countdownDialogActive = false;
    _wsSubscription?.cancel();
    _countdownController.dispose();
    super.dispose();
  }

  void _escucharResultado() {
    _wsSubscription = PaymentWebSocketService().notificationStream.listen((notification) {
      if (!mounted) return;
      if (!notification.isAppTerpel) return;
      // Ignorar notificaciones pendientes duplicadas
      if (notification.isPendiente) return;

      print('[ScanQRDialog] Resultado recibido: ${notification.titulo} - ${notification.estado}');

      setState(() {
        _resultadoRecibido = true;
        _aprobado = notification.isAprobado;
        _mensajeResultado = notification.mensaje;
        _countdownController.stop();
      });

      // Auto cerrar después de 3 segundos si fue aprobado
      if (notification.isAprobado) {
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) Navigator.of(context).pop();
        });
      }
    });
  }

  Color get _colorProgreso {
    if (_resultadoRecibido) return _aprobado ? Colors.green : Colors.red;
    if (_segundosRestantes > 30) return const Color(0xFF6A1B9A);
    if (_segundosRestantes > 10) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      contentPadding: EdgeInsets.zero,
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header púrpura
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _resultadoRecibido
                    ? (_aprobado ? Colors.green : Colors.red)
                    : const Color(0xFF6A1B9A),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Icon(
                    _resultadoRecibido
                        ? (_aprobado ? Icons.check_circle : Icons.cancel)
                        : Icons.qr_code_scanner,
                    color: Colors.white, size: 32,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _resultadoRecibido
                              ? (_aprobado ? 'PAGO APROBADO' : 'PAGO RECHAZADO')
                              : 'ESCANEE CÓDIGO QR',
                          style: const TextStyle(
                            color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'APP TERPEL',
                          style: TextStyle(color: Colors.white.withAlpha(200), fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Contenido
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Countdown circular (solo si no hay resultado)
                  if (!_resultadoRecibido) ...[
                    SizedBox(
                      width: 120,
                      height: 120,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 120,
                            height: 120,
                            child: CircularProgressIndicator(
                              value: 1 - _countdownController.value,
                              strokeWidth: 8,
                              color: _colorProgreso,
                              backgroundColor: Colors.grey.shade200,
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '$_segundosRestantes',
                                style: TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                  color: _colorProgreso,
                                ),
                              ),
                              Text('seg',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Icono de resultado
                  if (_resultadoRecibido) ...[
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: (_aprobado ? Colors.green : Colors.red).withAlpha(25),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _aprobado ? Icons.check_circle : Icons.cancel,
                        size: 56,
                        color: _aprobado ? Colors.green : Colors.red,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Mensaje principal
                  Text(
                    _resultadoRecibido
                        ? _mensajeResultado
                        : widget.mensaje,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: _resultadoRecibido ? _colorProgreso : Colors.grey.shade800,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  // Instrucciones QR (solo cuando pendiente)
                  if (!_resultadoRecibido) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6A1B9A).withAlpha(12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF6A1B9A).withAlpha(40)),
                      ),
                      child: Column(
                        children: [
                          _buildInstruccion(Icons.qr_code_2, 'Escanee el código QR con la App Terpel'),
                          const Divider(height: 16),
                          _buildInstruccion(Icons.keyboard, 'O ingrese el código manualmente'),
                          const Divider(height: 16),
                          _buildInstruccion(Icons.timer, 'Tiene aproximadamente 90 segundos'),
                        ],
                      ),
                    ),
                  ],

                  // Sugerencia cuando rechazado
                  if (_resultadoRecibido && !_aprobado) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.orange.withAlpha(20),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.withAlpha(80)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.orange, size: 18),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Debe gestionar la venta con otro medio de pago',
                              style: TextStyle(fontSize: 12, color: Colors.orange),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Botón cerrar
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _resultadoRecibido
                        ? (_aprobado ? Colors.green : Colors.red)
                        : const Color(0xFF6A1B9A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    _resultadoRecibido
                        ? (_aprobado ? 'CERRAR' : 'CERRAR - ASIGNAR OTRO MEDIO')
                        : 'ACEPTAR',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstruccion(IconData icono, String texto) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF6A1B9A).withAlpha(20),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icono, color: const Color(0xFF6A1B9A), size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(texto,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
        ),
      ],
    );
  }
}
