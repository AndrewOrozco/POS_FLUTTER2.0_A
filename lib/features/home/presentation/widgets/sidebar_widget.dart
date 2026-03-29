import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/session_provider.dart';
import '../../../placa/presentation/pages/placa_page.dart';
import '../../../configuracion/presentation/pages/configuracion_page.dart';

class SidebarWidget extends StatelessWidget {
  const SidebarWidget({super.key});

  void _abrirPlaca(BuildContext context) {
    final session = Provider.of<SessionProvider>(context, listen: false);
    if (session.promotoresActivos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debe abrir un turno primero'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PlacaPage()),
    );
  }

  void _abrirConfiguracion(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ConfiguracionPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppConstants.sidebarWidth,
      color: AppTheme.lightGray,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          const SizedBox(height: 30),
          // Icono notificaciones
          Container(
            margin: const EdgeInsets.symmetric(vertical: 15),
            child: const Icon(
              Icons.notifications_outlined,
              size: 28,
              color: AppTheme.terpeRed,
            ),
          ),
          // Icono Placa (Pre-autorización)
          GestureDetector(
            onTap: () => _abrirPlaca(context),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 15),
              child: Tooltip(
                message: 'Pre-autorización por placa',
                child: Icon(
                  Icons.directions_car,
                  size: 28,
                  color: AppTheme.terpeRed,
                ),
              ),
            ),
          ),
          // Icono Configuración
          GestureDetector(
            onTap: () => _abrirConfiguracion(context),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 15),
              child: Tooltip(
                message: 'Configuración',
                child: Icon(
                  Icons.settings_rounded,
                  size: 28,
                  color: AppTheme.terpeRed,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

