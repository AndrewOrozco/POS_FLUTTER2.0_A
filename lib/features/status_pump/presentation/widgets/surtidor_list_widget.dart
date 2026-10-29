import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/status_pump_provider.dart';
import 'surtidor_panel_java_widget.dart';

/// Widget que representa la lista y monitoreo de surtidores activos.
/// Redirige directamente al nuevo componente StatusPump NEW unificado
/// para garantizar consistencia absoluta en toda la aplicación.
class SurtidorListWidget extends StatelessWidget {
  final Function(int cara)? onGestionarVenta;
  final Function(int cara)? onMediosPago;
  final Set<int> carasGestionadas;

  const SurtidorListWidget({
    super.key,
    this.onGestionarVenta,
    this.onMediosPago,
    this.carasGestionadas = const {},
  });

  @override
  Widget build(BuildContext context) {
    debugPrint('[STATUS_PUMP_AUDIT] Renderizando SurtidorListWidget delegando a SurtidorPanelJavaWidget');
    return SurtidorPanelJavaWidget(
      onGestionarVenta: onGestionarVenta,
      onMediosPago: onMediosPago,
      carasGestionadas: carasGestionadas,
    );
  }
}

/// Widget compacto para indicadores rápidos
class SurtidorIndicatorsWidget extends StatelessWidget {
  const SurtidorIndicatorsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<StatusPumpProvider>(
      builder: (context, provider, child) {
        final surtidores = provider.surtidoresActivos;
        if (surtidores.isEmpty) return const SizedBox.shrink();

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: surtidores.map((s) => _buildIndicator(s.cara, s.estado.nombre)).toList(),
        );
      },
    );
  }

  Widget _buildIndicator(int cara, String estado) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.green,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'C$cara: $estado',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}