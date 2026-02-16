import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/providers/session_provider.dart';
import '../../../consulta_ventas/consulta_ventas.dart';

/// Banner de notificación para ventas en proceso (Facturación Electrónica + Datafono)
/// Similar al banner rojo de la UI de Java
class VentasFEBannerWidget extends StatelessWidget {
  const VentasFEBannerWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SessionProvider>(
      builder: (context, session, child) {
        final ventasFE = session.ventasFE;
        
        // Solo mostrar si hay ventas en proceso
        if (!ventasFE.tieneVentas) {
          return const SizedBox.shrink();
        }

        return GestureDetector(
          onTap: () {
            // Navegar a la página de Consulta de Ventas
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const ConsultaVentasPage(),
              ),
            );
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.red.shade700,
                  Colors.red.shade600,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.shade900.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Logo Terpel POS
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.local_gas_station,
                    color: Colors.red,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                // Texto de ventas en proceso
                Expanded(
                  child: Text(
                    ventasFE.mensaje,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                // Icono de advertencia
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade400,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.warning_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
