import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../widgets/surtidores_bloqueo_view.dart';
import '../widgets/surtidores_salto_lectura_view.dart';
import '../widgets/surtidores_placeholder_view.dart';
import '../widgets/surtidores_calibracion_view.dart';
import '../widgets/surtidores_cambio_precio_view.dart';
import '../widgets/surtidores_historial_remisiones_view.dart';
import '../widgets/surtidores_recepcion_combustible_view.dart';

class SurtidoresPage extends StatefulWidget {
  const SurtidoresPage({Key? key}) : super(key: key);

  @override
  State<SurtidoresPage> createState() => _SurtidoresPageState();
}

class _SurtidoresPageState extends State<SurtidoresPage> with SingleTickerProviderStateMixin {
  int _selectedIndex = 2; // Inicia en Bloqueo por defecto según el caso de uso
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    // Configurar sistema fullscreen si aplica
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
      width: 300,
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
                Icon(Icons.local_gas_station, color: Colors.white, size: 36),
                SizedBox(width: 12),
                Text(
                  'SURTIDORES',
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
                  numero: '1',
                  titulo: 'CALIBRACIONES',
                  icono: Icons.settings_suggest,
                  isSelected: _selectedIndex == 0,
                  onTap: () => _onMenuItemSelected(0),
                ),
                const SizedBox(height: 16),
                _ModuloSidebarItem(
                  numero: '2',
                  titulo: 'CAMBIO PRECIO',
                  icono: Icons.attach_money,
                  isSelected: _selectedIndex == 1,
                  onTap: () => _onMenuItemSelected(1),
                ),
                const SizedBox(height: 16),
                _ModuloSidebarItem(
                  numero: '3',
                  titulo: 'BLOQUEO',
                  icono: Icons.block,
                  isSelected: _selectedIndex == 2,
                  onTap: () => _onMenuItemSelected(2),
                ),
                const SizedBox(height: 16),
                _ModuloSidebarItem(
                  numero: '4',
                  titulo: 'SALTOS LECTURAS',
                  icono: Icons.skip_next,
                  isSelected: _selectedIndex == 3,
                  onTap: () => _onMenuItemSelected(3),
                ),
                const SizedBox(height: 16),
                _ModuloSidebarItem(
                  numero: '5',
                  titulo: 'ENTRADA COMBUSTIBLE',
                  icono: Icons.input,
                  isSelected: _selectedIndex == 4,
                  onTap: () => _onMenuItemSelected(4),
                ),
                const SizedBox(height: 16),
                _ModuloSidebarItem(
                  numero: '6',
                  titulo: 'HISTORIAL REMISIONES',
                  icono: Icons.history,
                  isSelected: _selectedIndex == 5,
                  onTap: () => _onMenuItemSelected(5),
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
        return const SurtidoresCalibracionesView();
      case 1:
        return const SurtidoresCambioPrecioView();
      case 2:
        return const SurtidoresBloqueoView();
      case 3:
        return const SurtidoresSaltoLecturaView();
      case 4:
        return const SurtidoresRecepcionCombustibleView();
      case 5:
        return const SurtidoresHistorialRemisionesView();
      default:
        return const Center(child: Text('Seleccione una opción'));
    }
  }
}


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
        height: 65,
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
            // Badge del número (triangulito en legacy, pero aquí será un cuadro redondeado pro)
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
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: isSelected ? Colors.white : const Color(0xFFBA0C2F),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Icon(
              icono,
              color: isSelected ? Colors.white : Colors.grey.shade600,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                titulo,
                style: TextStyle(
                  fontSize: 14,
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
