import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/session_provider.dart';
import '../../../consulta_ventas/consulta_ventas.dart';
import '../../../rumbo/presentation/pages/rumbo_page.dart';
import '../../../turnos/presentation/pages/turnos_page.dart';
import '../../../gopass/presentation/pages/gopass_estado_pago_page.dart';
import '../../../gopass/presentation/pages/gopass_enviar_pago_page.dart';
import '../../../canastilla/presentation/pages/canastilla_page.dart';
import '../../../market/presentation/pages/market_page.dart';
import '../../../fidelizacion/presentation/pages/fidelizacion_page.dart';
import '../../../configuracion/presentation/pages/configuracion_page.dart';
import '../../../reportes/presentation/pages/reportes_sincronizacion_page.dart';

class MenuGridWidget extends StatelessWidget {
  const MenuGridWidget({super.key});

  /// Módulos que requieren turno activo para poder acceder
  static const _modulosRequierenTurno = {'Rumbo', 'Canastilla', 'Market'};

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppConstants.rightPanelWidth,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F3F5),
        border: Border(
          left: BorderSide(color: Colors.grey.shade300, width: 1),
        ),
      ),
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                // ══════ OPERACIÓN ══════
                _buildSectionHeader('Operación'),
                _buildMenuItem(
                  context: context,
                  icon: Icons.schedule,
                  title: 'Turnos',
                  iconBgColor: AppTheme.terpeRed,
                  onTap: () => _navegarTurnos(context),
                ),
                _buildMenuItem(
                  context: context,
                  icon: Icons.shopping_bag,
                  title: 'Ventas',
                  iconBgColor: const Color(0xFFE91E63),
                  onTap: () => _navegarConsultaVentas(context),
                ),
                _buildMenuItem(
                  context: context,
                  icon: Icons.local_gas_station,
                  title: 'Surtidor',
                  iconBgColor: AppTheme.terpeRed,
                ),
                _buildMenuItem(
                  context: context,
                  icon: Icons.location_on,
                  title: 'Rumbo',
                  iconBgColor: AppTheme.terpeRed,
                  onTap: () => _verificarTurnoYNavegar(context, 'Rumbo', () {
                    _navegarRumbo(context);
                  }),
                ),
                const SizedBox(height: 12),

                // ══════ ADMINISTRACIÓN ══════
                _buildSectionHeader('Administración'),
                _buildMenuItem(
                  context: context,
                  icon: Icons.assessment,
                  title: 'Reportes',
                  iconBgColor: const Color(0xFF424242),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ReportesSincronizacionPage()),
                  ),
                ),
                _buildMenuItem(
                  context: context,
                  icon: Icons.people,
                  title: 'Usuarios',
                  iconBgColor: const Color(0xFF0277BD),
                ),
                const SizedBox(height: 12),

                // ══════ CLIENTE ══════
                _buildSectionHeader('Cliente'),
                _buildMenuItem(
                  context: context,
                  icon: Icons.favorite,
                  title: 'Fidelización',
                  iconBgColor: const Color(0xFF388E3C),
                  onTap: () => _navegarFidelizacion(context),
                ),
                _buildMenuItem(
                  context: context,
                  title: 'Market',
                  iconBgColor: const Color(0xFFE84868),
                  assetIcon: 'assets/icons/terpel/Recurso 1672@2x.png',
                  onTap: () => _verificarTurnoYNavegar(context, 'Market', () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const MarketPage()),
                    );
                  }),
                ),
                _buildMenuItem(
                  context: context,
                  title: 'Canastilla',
                  iconBgColor: const Color(0xFFFF8F00),
                  assetIcon: 'assets/icons/terpel/location_pin.png',
                  onTap: () => _verificarTurnoYNavegar(context, 'Canastilla', () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CanastillaPage()),
                    );
                  }),
                ),
                _buildMenuItem(
                  context: context,
                  icon: Icons.credit_card,
                  title: 'Gopass',
                  iconBgColor: const Color(0xFF2E7D32),
                  onTap: () => _mostrarMenuGopass(context),
                ),
              ],
            ),
          ),
          // ══════ CONFIGURACIÓN (fijada al fondo) ══════
          const Divider(height: 1),
          _buildMenuItem(
            context: context,
            icon: Icons.settings,
            title: 'Configuración',
            iconBgColor: const Color(0xFF7B1FA2),
            showChevron: true,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ConfiguracionPage()),
            ),
          ),
        ],
      ),
    );
  }

  // ── Section header ──
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, top: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade500,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  // ── Menu item ──
  Widget _buildMenuItem({
    required BuildContext context,
    IconData? icon,
    String? assetIcon,
    required String title,
    required Color iconBgColor,
    VoidCallback? onTap,
    bool showChevron = true,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap ?? () {
            debugPrint('Botón $title presionado');
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                // Ícono circular
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: assetIcon != null
                        ? Padding(
                            padding: const EdgeInsets.all(6),
                            child: Image.asset(
                              assetIcon,
                              width: 22,
                              height: 22,
                              color: Colors.white,
                              colorBlendMode: BlendMode.srcIn,
                            ),
                          )
                        : Icon(icon, color: Colors.white, size: 20),
                  ),
                ),
                const SizedBox(width: 12),
                // Título
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                ),
                // Chevron
                if (showChevron)
                  Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: Colors.grey.shade400,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  NAVEGACIÓN (sin cambios respecto al original)
  // ══════════════════════════════════════════════════════════

  void _navegarTurnos(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const TurnosPage()),
    );
  }

  void _navegarConsultaVentas(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ConsultaVentasPage()),
    );
  }

  void _navegarRumbo(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const RumboPage()),
    );
  }

  void _navegarFidelizacion(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const FidelizacionPage()),
    );
  }

  /// Verifica si hay turno activo antes de navegar a un módulo
  void _verificarTurnoYNavegar(BuildContext context, String modulo, VoidCallback navegar) {
    final session = Provider.of<SessionProvider>(context, listen: false);
    if (session.promotoresActivos.isEmpty) {
      _mostrarAlertaSinTurno(context, modulo);
    } else {
      navegar();
    }
  }

  /// Muestra alerta indicando que se necesita turno activo
  void _mostrarAlertaSinTurno(BuildContext context, String modulo) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: Icon(Icons.warning_amber_rounded, size: 56, color: Colors.orange.shade700),
        title: const Text(
          'TURNO REQUERIDO',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        content: Text(
          'Debe iniciar turno antes de acceder al módulo $modulo.\n\nVaya a Turnos > Iniciar Turno.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 15, color: Color(0xFF555555)),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(ctx).pop();
              _navegarTurnos(context);
            },
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('IR A TURNOS', style: TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(width: 12),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('CERRAR', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  /// Muestra las opciones de GoPass: Enviar Pago y Estado Pago
  void _mostrarMenuGopass(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        title: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.credit_card, color: Color(0xFF2E7D32), size: 28),
            ),
            const SizedBox(width: 14),
            const Text('GoPass', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
          ],
        ),
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Opcion 1: Enviar Pago
            _buildGopassOpcion(
              icon: Icons.send_rounded,
              titulo: 'ENVIAR PAGO',
              subtitulo: 'Enviar pago de venta a GoPass',
              color: const Color(0xFFB71C1C),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const GopassEnviarPagoPage()),
                );
              },
            ),
            const SizedBox(height: 12),
            // Opcion 2: Estado Pago
            _buildGopassOpcion(
              icon: Icons.fact_check_rounded,
              titulo: 'ESTADO PAGO',
              subtitulo: 'Consultar estado de pagos GoPass',
              color: const Color(0xFF2E7D32),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const GopassEstadoPagoPage()),
                );
              },
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('CERRAR', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildGopassOpcion({
    required IconData icon,
    required String titulo,
    required String subtitulo,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
            borderRadius: BorderRadius.circular(14),
            color: color.withValues(alpha: 0.05),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitulo,
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 18, color: color.withValues(alpha: 0.5)),
            ],
          ),
        ),
      ),
    );
  }
}