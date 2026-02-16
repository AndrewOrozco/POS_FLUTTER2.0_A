import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/status_pump_provider.dart';
import 'surtidor_card_widget.dart';
import 'animated_surtidor_card.dart';

/// Widget que muestra la lista horizontal de surtidores activos
/// Se actualiza automáticamente cuando llegan eventos de Socket.IO
class SurtidorListWidget extends StatefulWidget {
  final Function(int cara)? onGestionarVenta;
  final Function(int cara)? onMediosPago;
  /// Caras que ya tienen datos de factura guardados.
  final Set<int> carasGestionadas;

  const SurtidorListWidget({
    super.key,
    this.onGestionarVenta,
    this.onMediosPago,
    this.carasGestionadas = const {},
  });

  @override
  State<SurtidorListWidget> createState() => _SurtidorListWidgetState();
}

class _SurtidorListWidgetState extends State<SurtidorListWidget> {
  // Mantiene registro de surtidores que ya fueron animados
  final Set<int> _animatedSurtidores = {};

  @override
  Widget build(BuildContext context) {
    return Consumer<StatusPumpProvider>(
      builder: (context, provider, child) {
        final surtidores = provider.surtidoresActivos;
        
        // Debug: siempre mostrar algo para verificar que funciona
        print('[SurtidorListWidget] isConnected: ${provider.isConnected}, surtidores: ${surtidores.length}');
        
        if (surtidores.isEmpty) {
          // Limpiar los animados si no hay surtidores
          _animatedSurtidores.clear();
          return const SizedBox.shrink();
        }

        // Ajustar altura si algún surtidor tiene placa o medio especial asignado
        final tieneExtra = surtidores.any((s) => 
          (s.placa != null && s.placa!.isNotEmpty) ||
          (s.medioPagoEspecial != null && s.medioPagoEspecial!.isNotEmpty));
        return Container(
          height: tieneExtra ? 405 : 360,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemCount: surtidores.length,
            itemBuilder: (context, index) {
              final surtidor = surtidores[index];
              final isNew = !_animatedSurtidores.contains(surtidor.cara);
              
              // Si es nuevo, marcarlo como animado
              final gestionada = widget.carasGestionadas.contains(surtidor.cara);
              
              if (isNew) {
                _animatedSurtidores.add(surtidor.cara);
                return AnimatedSurtidorCard(
                  key: ValueKey('animated_${surtidor.cara}'),
                  surtidor: surtidor,
                  index: index,
                  onGestionarVenta: gestionada ? null : () => widget.onGestionarVenta?.call(surtidor.cara),
                  ventaGestionada: gestionada,
                  onMediosPago: () => widget.onMediosPago?.call(surtidor.cara),
                );
              }
              
              return SurtidorCardWidget(
                key: ValueKey('card_${surtidor.cara}'),
                surtidor: surtidor,
                onGestionarVenta: gestionada ? null : () => widget.onGestionarVenta?.call(surtidor.cara),
                ventaGestionada: gestionada,
                onMediosPago: () => widget.onMediosPago?.call(surtidor.cara),
              );
            },
          ),
        );
      },
    );
  }
}

/// Widget compacto que muestra solo indicadores de surtidores activos
/// Para usar en la barra de estado o header
class SurtidorIndicatorsWidget extends StatelessWidget {
  const SurtidorIndicatorsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<StatusPumpProvider>(
      builder: (context, provider, child) {
        final surtidores = provider.surtidoresActivos;
        
        if (surtidores.isEmpty) {
          return const SizedBox.shrink();
        }

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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.local_gas_station, size: 16, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            'C$cara',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

/// Widget de estado de conexión Socket.IO
class SocketConnectionStatusWidget extends StatelessWidget {
  const SocketConnectionStatusWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<StatusPumpProvider>(
      builder: (context, provider, child) {
        final isConnected = provider.isConnected;
        
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isConnected ? Colors.green : Colors.red,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.wifi,
                size: 20,
                color: isConnected ? Colors.green : Colors.grey,
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: isConnected ? Colors.green : Colors.red,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isConnected ? Icons.check : Icons.close,
                  size: 12,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                isConnected ? 'Flask' : 'Sin conexión',
                style: TextStyle(
                  fontSize: 12,
                  color: isConnected ? Colors.green : Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
