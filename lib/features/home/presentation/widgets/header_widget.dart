import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/session_provider.dart';
import '../../../turnos/presentation/pages/turnos_page.dart';

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
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SessionProvider>(
      builder: (context, session, child) {
        // Determinar turno activo
        final tienePromotor = session.promotoresActivos.isNotEmpty;
        final turnoTexto = tienePromotor ? 'Turno: Activo' : 'Sin Turno';

        return Container(
          width: double.infinity,
          height: 56,
          decoration: const BoxDecoration(
            color: AppTheme.terpeRed,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                // ── Logo Terpel ──
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/images/Logo.png',
                      width: 32,
                      height: 32,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // ── "terpel" text ──
                const Text(
                  'terpel',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 20),

                // ── Separador ──
                Container(
                  width: 1,
                  height: 28,
                  color: Colors.white24,
                ),
                const SizedBox(width: 20),

                // ── POS Name ──
                Text(
                  session.nombreEDS,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(width: 16),

                // ── Separador ──
                Container(
                  width: 1,
                  height: 28,
                  color: Colors.white24,
                ),
                const SizedBox(width: 16),

                // ── Turno info ──
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: tienePromotor
                        ? Colors.white
                        : AppTheme.terpelYellow,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Punto indicador
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: tienePromotor ? Colors.green : AppTheme.terpeRed,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        turnoTexto,
                        style: TextStyle(
                          color: tienePromotor
                              ? const Color(0xFF333333)
                              : AppTheme.terpelDarkRed,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // ── Nombre usuario ──
                Text(
                  session.promotoresActivos.isNotEmpty
                      ? session.promotoresActivos.map((p) => p.primerNombre.toUpperCase()).join(' / ')
                      : 'SIN PROMOTOR',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 16),

                // ── Logo Terpel pequeño ──
                Container(
                  width: 30,
                  height: 30,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/images/Logo.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // ── Hora ──
                Text(
                  _formatTime(_currentTime),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),

                // ── Sync icon ──
                Icon(
                  Icons.sync,
                  color: Colors.white70,
                  size: 18,
                ),
                const SizedBox(width: 12),

                // ── Avatar con menú rápido ──
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'turnos') {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const TurnosPage()));
                    } else if (value == 'iniciar') {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const TurnosPage(autoIniciar: true)));
                    } else if (value == 'cerrar') {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const TurnosPage(autoCerrar: true)));
                    }
                  },
                  offset: const Offset(0, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  color: Colors.white,
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'turnos',
                      child: Row(
                        children: [
                          Icon(Icons.schedule_rounded, color: Colors.grey.shade700, size: 20),
                          const SizedBox(width: 10),
                          const Text('Gestionar Turnos', style: TextStyle(fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(height: 1),
                    PopupMenuItem(
                      value: 'iniciar',
                      child: Row(
                        children: [
                          Icon(Icons.play_arrow_rounded, color: Colors.green.shade600, size: 20),
                          const SizedBox(width: 10),
                          const Text('Iniciar Turno', style: TextStyle(fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                    if (tienePromotor)
                      PopupMenuItem(
                        value: 'cerrar',
                        child: Row(
                          children: [
                            Icon(Icons.stop_rounded, color: AppTheme.terpeRed, size: 20),
                            const SizedBox(width: 10),
                            const Text('Cerrar Turno', style: TextStyle(fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                  ],
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [AppTheme.terpeRed, AppTheme.terpelDarkRed],
                          ),
                        ),
                        child: const Center(
                          child: Icon(Icons.person, color: Colors.white, size: 20),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.keyboard_arrow_down,
                        color: Colors.white54,
                        size: 20,
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
