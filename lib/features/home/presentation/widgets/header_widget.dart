import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/session_provider.dart';

class HeaderWidget extends StatefulWidget {
  const HeaderWidget({super.key});

  @override
  State<HeaderWidget> createState() => _HeaderWidgetState();
}

class _HeaderWidgetState extends State<HeaderWidget> {
  late Timer _timer;
  DateTime _currentTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    // Actualizar la hora cada segundo
    _timer = Timer.periodic(AppConstants.timerInterval, (timer) {
      setState(() {
        _currentTime = DateTime.now();
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';
  }

  String _formatDate(DateTime time) {
    return '${time.day.toString().padLeft(2, '0')}-${time.month.toString().padLeft(2, '0')}-${time.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SessionProvider>(
      builder: (context, session, child) {
        return Container(
          width: double.infinity,
          height: AppConstants.headerHeight,
          decoration: const BoxDecoration(color: AppTheme.terpeRed),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: [
                // Logo y texto izquierda
                Flexible(
                  flex: 2,
                  child: Row(
                    children: [
                      // Logo personalizado
                      Container(
                        width: 45,
                        height: 45,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/images/Logo.png',
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(width: 15),
                      // Texto terpel
                      const Text(
                        'terpel',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(width: 40),
                      // EDS y saludo al promotor (desde SessionProvider)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Nombre de la EDS (desde LazoExpress)
                            Text(
                              session.nombreEDS,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: MediaQuery.of(context).size.width < 600 ? 12 : 16,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.0,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            // Saludo al promotor activo
                            Text(
                              session.saludoPromotor,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: MediaQuery.of(context).size.width < 600 ? 18 : 24,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Información derecha (versión y fecha/hora)
                Flexible(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          const Text(
                            'Versión',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            AppConstants.version,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            _formatDate(_currentTime),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatTime(_currentTime),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
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
