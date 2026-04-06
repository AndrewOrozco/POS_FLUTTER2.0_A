import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import 'dispositivos_page.dart';
import 'impresora_page.dart';
import 'parametrizaciones_page.dart';
import 'registro_tag_page.dart';
import 'sincronizacion_page.dart';

/// Menú principal de Configuración.
/// Replica: Java ConfiguracionMenuPanelController
/// Opciones: Dispositivos, Registro Tag RFID
class ConfiguracionPage extends StatelessWidget {
  const ConfiguracionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: Row(
                children: [
                  // ── Menú lateral izquierdo ──
                  Expanded(
                    flex: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          _buildMenuOption(
                            context,
                            numero: '1',
                            titulo: 'DISPOSITIVOS',
                            subtitulo: 'Gestionar dispositivos del sistema',
                            icono: Icons.devices_other_rounded,
                            onTap: () => _abrirDispositivos(context),
                          ),
                          const SizedBox(height: 12),
                          _buildMenuOption(
                            context,
                            numero: '2',
                            titulo: 'REGISTRO TAG RFID',
                            subtitulo: 'Asignar tag RFID a usuarios',
                            icono: Icons.nfc_rounded,
                            onTap: () => _abrirRegistroTag(context),
                          ),
                          const SizedBox(height: 12),
                          _buildMenuOption(
                            context,
                            numero: '3',
                            titulo: 'PARAMETRIZACIONES',
                            subtitulo: 'Configuración de parámetros globales',
                            icono: Icons.tune_rounded,
                            onTap: () => _abrirParametrizaciones(context),
                          ),
                          const SizedBox(height: 12),
                          _buildMenuOption(
                            context,
                            numero: '4',
                            titulo: 'SINCRONIZACIÓN',
                            subtitulo: 'Sincronizar datos con el servidor central',
                            icono: Icons.sync_rounded,
                            onTap: () => _abrirSincronizacion(context),
                          ),
                          const SizedBox(height: 12),
                          _buildMenuOption(
                            context,
                            numero: '5',
                            titulo: 'IMPRESORA',
                            subtitulo: 'Configurar IP de la impresora',
                            icono: Icons.print_rounded,
                            onTap: () => _abrirImpresora(context),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // ── Ilustración derecha ──
                  Expanded(
                    flex: 3,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              color: AppTheme.terpeRed.withValues(alpha: 0.08),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.settings_rounded,
                              size: 72,
                              color: AppTheme.terpeRed.withValues(alpha: 0.7),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Configuración del Sistema',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.terpelGray5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Dispositivos, Tags y Parámetros',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.terpelGray3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          InkWell(
            onTap: () => Navigator.of(context).pop(),
            borderRadius: BorderRadius.circular(8),
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Icon(Icons.arrow_back_rounded, color: Color(0xFF333333), size: 24),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.terpeRed.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.settings_rounded, color: AppTheme.terpeRed, size: 22),
          ),
          const SizedBox(width: 12),
          const Text(
            'Configuración',
            style: TextStyle(
              color: Color(0xFF333333),
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildMenuOption(
    BuildContext context, {
    required String numero,
    required String titulo,
    required String subtitulo,
    required IconData icono,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              // Número estilo Terpel
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.terpeRed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    numero,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.terpeRed,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Título y subtítulo
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A1A),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitulo,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              // Ícono
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.lightGray,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icono, color: AppTheme.terpelGray5, size: 24),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400, size: 24),
            ],
          ),
        ),
      ),
    );
  }

  void _abrirDispositivos(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DispositivosPage()),
    );
  }

  void _abrirRegistroTag(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RegistroTagPage()),
    );
  }

  void _abrirParametrizaciones(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ParametrizacionesPage()),
    );
  }

  void _abrirSincronizacion(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SincronizacionPage()),
    );
  }

  void _abrirImpresora(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ImpresoraPage()),
    );
  }
}