import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/connectivity_service.dart';
import '../../../../core/providers/session_provider.dart';
import '../../../status_pump/presentation/providers/status_pump_provider.dart';

class StatusBubblesWidget extends StatefulWidget {
  const StatusBubblesWidget({super.key});

  @override
  State<StatusBubblesWidget> createState() => _StatusBubblesWidgetState();
}

class _StatusBubblesWidgetState extends State<StatusBubblesWidget> {
  final ConnectivityService _connectivityService = ConnectivityService();
  bool _hasInternet = true;

  @override
  void initState() {
    super.initState();
    _connectivityService.initialize();
    _connectivityService.connectionStatusController.stream.listen((
      hasConnection,
    ) {
      setState(() {
        _hasInternet = hasConnection;
      });
    });
  }

  @override
  void dispose() {
    _connectivityService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 30,
      left: 130,
      child: Row(
        children: [
          // Burbuja 0: Número de POS
          _buildPosNumberBubble(),
          const SizedBox(width: 15),
          // Burbuja 1: Money + Check combinados
          _buildMoneyCheckBubble(),
          const SizedBox(width: 15),
          // Burbuja 2: WiFi + Check combinados
          _buildWifiCheckBubble(),
          const SizedBox(width: 15),
          // Burbuja 3: Flask Socket.IO status
          _buildFlaskStatusBubble(),
        ],
      ),
    );
  }

  Widget _buildPosNumberBubble() {
    return Consumer<SessionProvider>(
      builder: (context, session, child) {
        return Container(
          padding: const EdgeInsets.all(AppConstants.smallPadding),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.desktop_windows_outlined,
                size: 20,
                color: Colors.grey,
              ),
              const SizedBox(width: 6),
              Text(
                session.numeroIsla.toString(),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWifiCheckBubble() {
    return Container(
      padding: const EdgeInsets.all(AppConstants.smallPadding),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icono WiFi que cambia según la conectividad
          Icon(
            Icons.wifi,
            size: 20,
            color: _hasInternet ? AppTheme.success : Colors.grey,
          ),
          const SizedBox(width: 6),
          // Check o X según la conectividad
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: _hasInternet ? AppTheme.success : Colors.red,
              shape: BoxShape.circle,
            ),
            child: Icon(
              _hasInternet ? Icons.check : Icons.close,
              size: 12,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoneyCheckBubble() {
    return Consumer<SessionProvider>(
      builder: (context, session, _) {
        final ventasPendientes = session.ventasPendientes.numeroVentas;
        final hayPendientes = ventasPendientes > 0;
        
        return Container(
          padding: const EdgeInsets.all(AppConstants.smallPadding),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: hayPendientes ? Colors.red : Colors.grey.shade300,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.payments_outlined,
                size: 20,
                color: hayPendientes ? Colors.red : Colors.grey,
              ),
              const SizedBox(width: 6),
              if (hayPendientes) ...[
                // Mostrar número de ventas pendientes (como Java)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    ventasPendientes > 9 ? '9+' : '$ventasPendientes',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, size: 12, color: Colors.white),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: AppTheme.success,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, size: 12, color: Colors.white),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildFlaskStatusBubble() {
    return Consumer<StatusPumpProvider>(
      builder: (context, provider, _) {
        final isConnected = provider.isConnected;
        final surtidoresActivos = provider.surtidoresActivos.length;
        
        return Container(
          padding: const EdgeInsets.all(AppConstants.smallPadding),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isConnected ? Colors.green : Colors.red,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.local_gas_station,
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
              if (surtidoresActivos > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.terpeRed,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$surtidoresActivos',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}