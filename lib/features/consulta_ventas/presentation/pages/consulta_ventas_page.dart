import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/opcion_consulta_card.dart';
import '../widgets/ventas_placeholder_view.dart';
import 'historial_ventas_page.dart';
import 'ventas_sin_resolver_page.dart';
import '../../../venta_manual/presentation/venta_manual_view.dart';
import '../../../anulaciones/presentation/anulaciones_view.dart';

/// Página Principal del menú de Ventas con layout Sidebar
class ConsultaVentasPage extends StatefulWidget {
  const ConsultaVentasPage({Key? key}) : super(key: key);

  @override
  State<ConsultaVentasPage> createState() => _ConsultaVentasPageState();
}

class _ConsultaVentasPageState extends State<ConsultaVentasPage> with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeIn));
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onMenuItemSelected(int index) {
    if (_selectedIndex != index) {
      setState(() => _selectedIndex = index);
      _animationController.reset();
      _animationController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Row(
        children: [
          // Sidebar Menu
          _buildSidebar(),
          
          // Main Content Area
          Expanded(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: _buildMainContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(2, 0),
          )
        ],
      ),
      child: Column(
        children: [
          // Header del Sidebar
          Container(
            height: 100,
            width: double.infinity,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0xFFBA0C2F), // Rojo Terpel
              borderRadius: BorderRadius.only(bottomRight: Radius.circular(30)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.shopping_bag, color: Colors.white, size: 36),
                SizedBox(width: 12),
                Text(
                  'VENTAS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          
          // Opciones del menú
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              children: [
                _ModuloSidebarItem(
                  numero: '1', titulo: 'CONSULTA VENTAS', icono: Icons.search,
                  isSelected: _selectedIndex == 0, onTap: () => _onMenuItemSelected(0),
                ),
                const SizedBox(height: 12),
                _ModuloSidebarItem(
                  numero: '2', titulo: 'PREDETERMINAR', icono: Icons.settings_backup_restore,
                  isSelected: _selectedIndex == 1, onTap: () => _onMenuItemSelected(1),
                ),
                const SizedBox(height: 12),
                _ModuloSidebarItem(
                  numero: '3', titulo: 'CONSUMO PROPIO', icono: Icons.local_gas_station,
                  isSelected: _selectedIndex == 2, onTap: () => _onMenuItemSelected(2),
                ),
                const SizedBox(height: 12),
                _ModuloSidebarItem(
                  numero: '4', titulo: 'FAC. ELECTRÓNICA', icono: Icons.receipt,
                  isSelected: _selectedIndex == 3, onTap: () => _onMenuItemSelected(3),
                ),
                const SizedBox(height: 12),
                _ModuloSidebarItem(
                  numero: '5', titulo: 'VENTAS APP TERPEL', icono: Icons.phone_android,
                  isSelected: _selectedIndex == 4, onTap: () => _onMenuItemSelected(4),
                ),
                const SizedBox(height: 12),
                _ModuloSidebarItem(
                  numero: '6', titulo: 'HISTÓRICA', icono: Icons.history,
                  isSelected: _selectedIndex == 5, onTap: () => _onMenuItemSelected(5),
                ),
                const SizedBox(height: 12),
                _ModuloSidebarItem(
                  numero: '7', titulo: 'VENTA MANUAL', icono: Icons.edit_note,
                  isSelected: _selectedIndex == 6, onTap: () => _onMenuItemSelected(6),
                ),
                const SizedBox(height: 12),
                _ModuloSidebarItem(
                  numero: '8', titulo: 'ANULACIONES', icono: Icons.cancel_presentation,
                  isSelected: _selectedIndex == 7, onTap: () => _onMenuItemSelected(7),
                ),
              ],
            ),
          ),
          
          // Botón Regresar
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              label: const Text('VOLVER AL INICIO', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: Colors.grey.shade800,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    switch (_selectedIndex) {
      case 0:
        return const _ConsultaVentasVista();
      case 1:
        return const VentasPlaceholderView(title: 'PREDETERMINAR');
      case 2:
        return const VentasPlaceholderView(title: 'CONSUMO PROPIO');
      case 3:
        return const VentasPlaceholderView(title: 'FACTURACIÓN ELECTRÓNICA');
      case 4:
        return const VentasPlaceholderView(title: 'VENTAS APP TERPEL');
      case 5:
        return const VentasPlaceholderView(title: 'HISTÓRICA');
      case 6:
        return const VentaManualView();
      case 7:
        return const AnulacionesView();
      default:
        return const Center(child: Text('Seleccione una opción'));
    }
  }
}

// -------------------------------------------------------------
// Componente Sidebar Item
// -------------------------------------------------------------
class _ModuloSidebarItem extends StatelessWidget {
  final String numero;
  final String titulo;
  final IconData icono;
  final bool isSelected;
  final VoidCallback onTap;

  const _ModuloSidebarItem({
    Key? key,
    required this.numero,
    required this.titulo,
    required this.icono,
    required this.isSelected,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        height: 60,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFBA0C2F) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFFBA0C2F) : Colors.grey.shade300,
            width: isSelected ? 0 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFFBA0C2F).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: double.infinity,
              decoration: BoxDecoration(
                color: isSelected ? Colors.white.withOpacity(0.15) : Colors.grey.shade100,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                numero,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: isSelected ? Colors.white : const Color(0xFFBA0C2F),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Icon(
              icono,
              color: isSelected ? Colors.white : Colors.grey.shade600,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                titulo,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : Colors.grey.shade800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// Vista Interna: Consulta Ventas (Historial / Sin Resolver)
// -------------------------------------------------------------
class _ConsultaVentasVista extends StatelessWidget {
  const _ConsultaVentasVista({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            // Header Minimalista Superior
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.receipt_long_rounded,
                      color: Colors.red.shade700,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Centro de Consultas',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF333333),
                        ),
                      ),
                      Text(
                        'Consulte el historial o las ventas pendientes',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Opciones de consulta
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Row(
                  children: [
                    // Historial de Ventas
                    Expanded(
                      child: OpcionConsultaCard(
                        titulo: 'Historial de Ventas',
                        subtitulo: 'Consulta todas las ventas realizadas',
                        icono: Icons.history_rounded,
                        color: Colors.blue.shade600,
                        onTap: () => _navegarHistorial(context),
                      ),
                    ),
                    const SizedBox(width: 40),
                    // Ventas sin Resolver
                    Expanded(
                      child: OpcionConsultaCard(
                        titulo: 'Ventas sin Resolver',
                        subtitulo: 'Ventas pendientes de procesar',
                        icono: Icons.pending_actions_rounded,
                        color: Colors.orange.shade600,
                        onTap: () => _navegarSinResolver(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navegarHistorial(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const HistorialVentasPage()),
    );
  }

  void _navegarSinResolver(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const VentasSinResolverPage()),
    );
  }
}