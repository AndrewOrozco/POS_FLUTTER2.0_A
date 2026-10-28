import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
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
import '../../../surtidores/presentation/pages/surtidores_page.dart';
import '../../../placa/presentation/pages/placa_page.dart';

/// Drawer móvil elegante y completo para acceder a todos los módulos del POS
class MobileMenuDrawer extends StatelessWidget {
  const MobileMenuDrawer({super.key});

  static const _modulosRequierenTurno = {'Rumbo', 'Canastilla', 'Market', 'Placa'};

  void _verificarTurnoYNavegar(BuildContext context, String modulo, VoidCallback navegar) {
    Navigator.of(context).pop(); // Cerrar drawer
    final session = Provider.of<SessionProvider>(context, listen: false);
    if (_modulosRequierenTurno.contains(modulo) && session.promotoresActivos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(child: Text('Debe abrir un turno para ingresar a $modulo')),
            ],
          ),
          backgroundColor: AppTheme.terpelDarkRed,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }
    navegar();
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    final tienePromotor = session.promotoresActivos.isNotEmpty;
    final promotorNombre = tienePromotor
        ? session.promotoresActivos.map((p) => p.primerNombre).join(' / ')
        : 'Sin Promotor';

    return Drawer(
      backgroundColor: const Color(0xFF1E2228),
      child: SafeArea(
        child: Column(
          children: [
            // ── Header del Drawer ──
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.terpeRed,
                    AppTheme.terpelDarkRed,
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/images/Logo.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'TERPEL POS',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                                letterSpacing: 1.2,
                              ),
                            ),
                            Text(
                              session.nombreEDS,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Píldora de estado del turno
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: tienePromotor ? Colors.greenAccent.withValues(alpha: 0.5) : Colors.orangeAccent.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: tienePromotor ? Colors.greenAccent : Colors.orangeAccent,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          tienePromotor ? 'Turno: $promotorNombre' : 'Sin turno activo',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Lista de Módulos con scroll ──
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                children: [
                  _buildSectionHeader('Operación'),
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.schedule_rounded,
                    color: AppTheme.terpeRed,
                    title: 'Turnos',
                    subtitle: 'Abrir, cerrar y gestionar turnos',
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const TurnosPage()));
                    },
                  ),
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.shopping_bag_rounded,
                    color: const Color(0xFFE91E63),
                    title: 'Ventas',
                    subtitle: 'Consultar y reimprimir transacciones',
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const ConsultaVentasPage()));
                    },
                  ),
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.local_gas_station_rounded,
                    color: Colors.orange.shade700,
                    title: 'Surtidores',
                    subtitle: 'Control y configuración de caras',
                    onTap: () => _verificarTurnoYNavegar(context, 'Surtidores', () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const SurtidoresPage()));
                    }),
                  ),
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.directions_car_rounded,
                    color: Colors.amber.shade700,
                    title: 'Pre-autorización Placa',
                    subtitle: 'Asignar placa antes del despacho',
                    onTap: () => _verificarTurnoYNavegar(context, 'Placa', () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const PlacaPage()));
                    }),
                  ),
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.alt_route_rounded,
                    color: const Color(0xFF9C27B0),
                    title: 'Rumbo',
                    subtitle: 'Control de flotas y transporte',
                    onTap: () => _verificarTurnoYNavegar(context, 'Rumbo', () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const RumboPage()));
                    }),
                  ),
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.toll_rounded,
                    color: const Color(0xFF00897B),
                    title: 'GoPass (Estado)',
                    subtitle: 'Verificar estado de tags GoPass',
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const GopassEstadoPagoPage()));
                    },
                  ),
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.contactless_rounded,
                    color: const Color(0xFF00ACC1),
                    title: 'GoPass (Enviar)',
                    subtitle: 'Procesar cobros directos GoPass',
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const GopassEnviarPagoPage()));
                    },
                  ),

                  _buildSectionHeader('Fidelización & Tienda'),
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.card_giftcard_rounded,
                    color: const Color(0xFFD81B60),
                    title: 'Club Terpel',
                    subtitle: 'Acumular y redimir puntos',
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const FidelizacionPage()));
                    },
                  ),
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.shopping_basket_rounded,
                    color: const Color(0xFF43A047),
                    title: 'Canastilla',
                    subtitle: 'Venta de aceites y aditivos',
                    onTap: () => _verificarTurnoYNavegar(context, 'Canastilla', () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const CanastillaPage()));
                    }),
                  ),
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.storefront_rounded,
                    color: const Color(0xFFFB8C00),
                    title: 'Market / Tienda',
                    subtitle: 'Venta de artículos de conveniencia',
                    onTap: () => _verificarTurnoYNavegar(context, 'Market', () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const MarketPage()));
                    }),
                  ),

                  _buildSectionHeader('Sistema'),
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.bar_chart_rounded,
                    color: const Color(0xFF1E88E5),
                    title: 'Reportes y Cierres',
                    subtitle: 'Cierres de turno y reportes de isla',
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportesSincronizacionPage()));
                    },
                  ),
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.settings_rounded,
                    color: const Color(0xFF78909C),
                    title: 'Configuración',
                    subtitle: 'Parámetros, red y licencias',
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const ConfiguracionPage()));
                    },
                  ),
                ],
              ),
            ),

            // ── Footer ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFF2C323D))),
              ),
              child: Row(
                children: [
                  Icon(Icons.security_rounded, size: 16, color: Colors.white.withValues(alpha: 0.4)),
                  const SizedBox(width: 8),
                  Text(
                    'ISO 27001 • v2.0 Mobile',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 11,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 6),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.4),
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required BuildContext context,
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF262C36),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 11,
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios_rounded,
          size: 12,
          color: Colors.white.withValues(alpha: 0.3),
        ),
        onTap: onTap,
      ),
    );
  }
}
