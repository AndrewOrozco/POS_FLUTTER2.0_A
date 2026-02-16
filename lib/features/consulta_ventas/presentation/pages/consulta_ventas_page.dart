import 'package:flutter/material.dart';
import '../widgets/opcion_consulta_card.dart';
import 'historial_ventas_page.dart';
import 'ventas_sin_resolver_page.dart';

/// Página de Consulta de Ventas
/// Permite navegar a Historial de Ventas o Ventas sin Resolver
class ConsultaVentasPage extends StatelessWidget {
  const ConsultaVentasPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.red.shade700,
              Colors.red.shade900,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header con botón de regreso
              _buildHeader(context),
              // Contenido principal
              Expanded(
                child: Container(
                  margin: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Título
                      _buildTitle(),
                      const Divider(height: 1),
                      // Opciones de consulta
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
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
                              const SizedBox(width: 24),
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
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Botón de regreso
          Material(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: () => Navigator.of(context).pop(),
              borderRadius: BorderRadius.circular(12),
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Icon(
                  Icons.arrow_back_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Título del header
          const Text(
            'Consulta de Ventas',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          // Icono Terpel
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.local_gas_station,
              color: Colors.red.shade700,
              size: 40,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitle() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 32),
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
                'Seleccione una opción',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF333333),
                ),
              ),
              Text(
                'Consulte el historial o las ventas pendientes',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ],
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
