import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';

class SidebarWidget extends StatelessWidget {
  const SidebarWidget({super.key});

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
          // Icono alerta
          Container(
            margin: const EdgeInsets.symmetric(vertical: 15),
            child: const Icon(
              Icons.local_gas_station_outlined,
              size: 28,
              color: AppTheme.terpeRed,
            ),
          ),
          // Icono configuración avanzada
          Container(
            margin: const EdgeInsets.symmetric(vertical: 15),
            child: const Icon(
              Icons.account_circle,
              size: 28,
              color: AppTheme.terpeRed,
            ),
          ),
        ],
      ),
    );
  }
}
