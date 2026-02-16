import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/session_provider.dart';
import '../../../consulta_ventas/consulta_ventas.dart';
import '../../../rumbo/presentation/pages/rumbo_page.dart';
import '../../../turnos/presentation/pages/turnos_page.dart';

class MenuGridWidget extends StatelessWidget {
  const MenuGridWidget({super.key});

  /// Módulos que requieren turno activo para poder acceder
  static const _modulosRequierenTurno = {'Rumbo', 'Canastilla'};

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppConstants.rightPanelWidth,
      padding: const EdgeInsets.all(AppConstants.defaultPadding),
      color: AppTheme.darkGray,
      child: Column(
        children: [
          // Botones del menú
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.0,
              children: [
                _buildMenuButton(
                  context: context,
                  icon: Icons.schedule_outlined,
                  title: 'Turnos',
                  color: const Color(0xFFE3F2FD),
                  iconColor: const Color(0xFF1976D2),
                  onTap: () => _navegarTurnos(context),
                ),
                _buildMenuButton(
                  context: context,
                  icon: Icons.point_of_sale_outlined,
                  title: 'Ventas',
                  color: const Color(0xFFFCE4EC),
                  iconColor: const Color(0xFFE91E63),
                  onTap: () => _navegarConsultaVentas(context),
                ),
                _buildMenuButton(
                  context: context,
                  icon: Icons.shopping_cart_outlined,
                  title: 'Canastilla',
                  color: const Color(0xFFFFF8E1),
                  iconColor: const Color(0xFFFF8F00),
                  onTap: () => _verificarTurnoYNavegar(context, 'Canastilla', () {
                    print('Navegar a Canastilla');
                  }),
                ),
                _buildMenuButton(
                  context: context,
                  icon: Icons.location_on_outlined,
                  title: 'Rumbo',
                  color: const Color(0xFFFFEBEE),
                  iconColor: AppTheme.terpeRed,
                  onTap: () => _verificarTurnoYNavegar(context, 'Rumbo', () {
                    _navegarRumbo(context);
                  }),
                ),
                _buildMenuButton(
                  context: context,
                  icon: Icons.storefront_outlined,
                  title: 'Market',
                  color: const Color(0xFFE0F2F1),
                  iconColor: const Color(0xFF00897B),
                  onTap: () => _verificarTurnoYNavegar(context, 'Market', () {
                    print('Navegar a Market');
                  }),
                ),
                _buildMenuButton(
                  context: context,
                  icon: Icons.settings_outlined,
                  title: 'Configuración',
                  color: const Color(0xFFF3E5F5),
                  iconColor: const Color(0xFF7B1FA2),
                ),
                _buildMenuButton(
                  context: context,
                  icon: Icons.card_giftcard_outlined,
                  title: 'Fidelización',
                  color: const Color(0xFFE8F5E8),
                  iconColor: const Color(0xFF388E3C),
                ),
                _buildMenuButton(
                  context: context,
                  icon: Icons.local_gas_station_outlined,
                  title: 'Surtidor',
                  color: const Color(0xFFFFEBEE),
                  iconColor: AppTheme.terpeRed,
                ),
                _buildMenuButton(
                  context: context,
                  icon: Icons.assessment_outlined,
                  title: 'Reportes',
                  color: const Color(0xFFF5F5F5),
                  iconColor: const Color(0xFF424242),
                ),
                _buildMenuButton(
                  context: context,
                  icon: Icons.group_outlined,
                  title: 'Usuarios',
                  color: const Color(0xFFE1F5FE),
                  iconColor: const Color(0xFF0277BD),
                ),
                _buildMenuButton(
                  context: context,
                  icon: Icons.credit_card_outlined,
                  title: 'Gopass',
                  color: const Color(0xFFE8F5E8),
                  iconColor: const Color(0xFF2E7D32),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

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

  Widget _buildMenuButton({
    required BuildContext context,
    required IconData icon,
    required String title,
    required Color color,
    required Color iconColor,
    VoidCallback? onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: onTap ?? () {
            print('Botón $title presionado');
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Área del ícono más grande y colorida
                Expanded(
                  flex: 3,
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Center(child: _buildCustomIcon(title, iconColor)),
                  ),
                ),
                const SizedBox(height: 12),
                // Texto
                Expanded(
                  flex: 1,
                  child: Center(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomIcon(String title, Color iconColor) {
    switch (title) {
      case 'Turnos':
        return Icon(Icons.schedule, size: 50, color: iconColor);
      case 'Ventas':
        return Icon(Icons.shopping_bag, size: 50, color: iconColor);
      case 'Canastilla':
        return Icon(Icons.shopping_cart, size: 50, color: iconColor);
      case 'Rumbo':
        return Icon(Icons.location_on, size: 50, color: iconColor);
      case 'Market':
        return Icon(Icons.storefront, size: 50, color: iconColor);
      case 'Configuración':
        return Icon(Icons.settings, size: 50, color: iconColor);
      case 'Fidelización':
        return Icon(Icons.favorite, size: 50, color: iconColor);
      case 'Surtidor':
        return Icon(Icons.local_gas_station, size: 50, color: iconColor);
      case 'Reportes':
        return Icon(Icons.assessment, size: 50, color: iconColor);
      case 'Usuarios':
        return Icon(Icons.people, size: 50, color: iconColor);
      case 'Gopass':
        return Icon(Icons.credit_card, size: 50, color: iconColor);
      default:
        return Icon(Icons.help_outline, size: 50, color: iconColor);
    }
  }
}
