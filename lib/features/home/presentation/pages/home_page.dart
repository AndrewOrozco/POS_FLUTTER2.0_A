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
  final ApiConsultasService _apiService = ApiConsultasService();
  /// Caras gestionadas → monto al momento de guardar.
  /// Cuando el monto baja (venta nueva), se limpia automáticamente.
  final Map<int, double> _carasGestionadasMonto = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Escuchar cuando un surtidor con APP TERPEL termina de despachar
      final provider = context.read<StatusPumpProvider>();
      _appTerpelSubscription = provider.appTerpelTerminadaStream.listen((evento) {
        _onAppTerpelVentaTerminada(evento);
      });

      // Escuchar notificaciones de pago del orquestador via WebSocket
      _paymentWsSubscription = PaymentWebSocketService().notificationStream.listen((notification) {
        _onPaymentNotification(notification);
      });
    });
  }

  @override
  void dispose() {
    _appTerpelSubscription?.cancel();
    _paymentWsSubscription?.cancel();
    super.dispose();
  }

  // Evitar mostrar diálogos duplicados (el orquestador a veces manda 2 callbacks)
  DateTime? _lastPaymentNotificationTime;

  /// Mostrar alerta cuando el orquestador notifica un pago aprobado/rechazado
  void _onPaymentNotification(PaymentNotification notification) {
    if (!mounted) return;

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
