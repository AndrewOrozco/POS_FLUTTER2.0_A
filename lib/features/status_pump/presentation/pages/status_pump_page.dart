import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/status_pump_provider.dart';
import '../widgets/surtidor_card_widget.dart';
import '../../domain/entities/surtidor_estado.dart';
import '../../../home/presentation/widgets/medios_pago_bottom_sheet.dart';
import 'gestionar_venta_page.dart';

/// Página principal que muestra todos los surtidores activos
/// Similar a la vista de StatusPump en la UI Java
class StatusPumpPage extends StatefulWidget {
  const StatusPumpPage({super.key});

  @override
  State<StatusPumpPage> createState() => _StatusPumpPageState();
}

class _StatusPumpPageState extends State<StatusPumpPage> {
  /// Caras gestionadas → monto al momento de guardar.
  /// Cuando el monto baja (venta nueva), se limpia automáticamente.
  final Map<int, double> _carasGestionadasMonto = {};

  @override
  void initState() {
    super.initState();
    // Inicializar conexión al entrar a la página
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<StatusPumpProvider>();
      if (!provider.isConnected) {
        provider.initialize();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'ESTADO SURTIDORES',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppTheme.terpeRed,
        foregroundColor: Colors.white,
        actions: [
          // Botón de reconexión
          Consumer<StatusPumpProvider>(
            builder: (context, provider, _) {
              return IconButton(
                icon: Icon(
                  provider.isConnected ? Icons.wifi : Icons.wifi_off,
                  color: provider.isConnected ? Colors.green : Colors.white,
                ),
                onPressed: () => provider.reconnect(),
                tooltip: provider.isConnected ? 'Conectado' : 'Reconectar',
              );
            },
          ),
        ],
      ),
      body: Consumer<StatusPumpProvider>(
        builder: (context, provider, child) {
          // Estado de conexión
          if (!provider.isConnected) {
            return _buildNoConnection(provider);
          }

          final surtidores = provider.surtidoresActivos;

          // Sin surtidores activos
          if (surtidores.isEmpty) {
            return _buildNoSurtidores();
          }

          // Lista de surtidores
          return _buildSurtidoresList(surtidores);
        },
      ),
    );
  }

  Widget _buildNoConnection(StatusPumpProvider provider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.wifi_off,
            size: 80,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          const Text(
            'Sin conexión con Flask',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            provider.connectionError.isNotEmpty
                ? provider.connectionError
                : 'Intentando conectar...',
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => provider.reconnect(),
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.terpeRed,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoSurtidores() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.local_gas_station_outlined,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          const Text(
            'No hay surtidores activos',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Los surtidores aparecerán aquí cuando\nse detecte una venta en progreso',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildSurtidoresList(List surtidores) {
    // Determinar caras que siguen siendo válidas (misma venta activa)
    final carasValidas = <int>{};
    for (final entry in _carasGestionadasMonto.entries) {
      final surtidor = surtidores.cast<SurtidorEstado>().where((s) => s.cara == entry.key).firstOrNull;
      if (surtidor != null && surtidor.monto >= entry.value && surtidor.estado.estaActivo) {
        carasValidas.add(entry.key);
      }
    }
    // Limpiar flags de ventas que ya terminaron o reiniciaron
    _carasGestionadasMonto.removeWhere((cara, _) => !carasValidas.contains(cara));

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        children: surtidores.map<Widget>((surtidor) {
          final gestionada = carasValidas.contains(surtidor.cara);
          return SurtidorCardWidget(
            surtidor: surtidor,
            onGestionarVenta: gestionada ? null : () => _onGestionarVenta(surtidor.cara),
            ventaGestionada: gestionada,
            onMediosPago: () => _onMediosPago(surtidor.cara),
          );
        }).toList(),
      ),
    );
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

  void _onMediosPago(int cara) {
    final provider = context.read<StatusPumpProvider>();
    final surtidor = provider.surtidoresActivos.firstWhere(
      (s) => s.cara == cara,
      orElse: () => SurtidorEstado(surtidorId: 0, cara: cara, manguera: 0, estado: EstadoSurtidor.unknown),
    );
    
    // Reutilizar el bottom sheet del home
    showMediosPagoBottomSheet(context, surtidor);
  }
}
