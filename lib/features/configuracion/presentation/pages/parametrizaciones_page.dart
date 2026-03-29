import 'package:flutter/material.dart';
import '../../../../core/services/api_consultas_service.dart';
import '../../../../core/theme/app_theme.dart';

/// Parametrizaciones del POS.
/// Replica: Java ParametrizacionesViewController (tab PARAMETRIZACION)
/// Parámetros almacenados en wacher_parametros:
///   - tipo_autorizacion (1=POR JORNADA, 2=GLOBAL, 3=POR CARA)
///   - solicitar_placa_impresion (S/N)
///   - IMPRIMIR_VENTA_FINALIZADA (S/N)
///   - solicitar_lecturas_tanques (S/N)
///   - imprimir_sobres (S/N)
class ParametrizacionesPage extends StatefulWidget {
  const ParametrizacionesPage({super.key});

  @override
  State<ParametrizacionesPage> createState() => _ParametrizacionesPageState();
}

class _ParametrizacionesPageState extends State<ParametrizacionesPage> {
  final ApiConsultasService _apiService = ApiConsultasService();

  bool _cargando = true;
  bool _guardando = false;
  String? _mensaje;
  bool _mensajeExito = false;

  // Parámetros
  String _tipoAutorizacion = '1';  // 1, 2, 3
  bool _placaObligatoria = false;
  bool _impresionAutomatica = true;
  bool _medidasTanques = false;
  bool _imprimirSobres = false;

  // Tracking cambios
  bool _hayCambios = false;

  static const Map<String, String> _tipoAutorizacionOptions = {
    '1': 'POR JORNADA',
    '2': 'GLOBAL',
    '3': 'POR CARA',
  };

  @override
  void initState() {
    super.initState();
    _cargarParametros();
  }

  Future<void> _cargarParametros() async {
    setState(() => _cargando = true);
    try {
      final data = await _apiService.getParametrizaciones();
      if (mounted && data.isNotEmpty) {
        setState(() {
          _tipoAutorizacion = data['tipo_autorizacion']?.toString() ?? '1';
          _placaObligatoria = data['solicitar_placa_impresion'] == 'S';
          _impresionAutomatica = data['impresion_factura_automatica'] == 'S';
          _medidasTanques = data['solicitar_lecturas_tanques'] == 'S';
          _imprimirSobres = data['imprimir_sobres'] == 'S';
          _cargando = false;
          _hayCambios = false;
        });
      } else {
        if (mounted) setState(() => _cargando = false);
      }
    } catch (e) {
      print('[Parametrizaciones] Error: $e');
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _guardarParametros() async {
    setState(() => _guardando = true);
    try {
      final ok = await _apiService.updateParametrizaciones({
        'tipo_autorizacion': _tipoAutorizacion,
        'solicitar_placa_impresion': _placaObligatoria ? 'S' : 'N',
        'impresion_factura_automatica': _impresionAutomatica ? 'S' : 'N',
        'solicitar_lecturas_tanques': _medidasTanques ? 'S' : 'N',
        'imprimir_sobres': _imprimirSobres ? 'S' : 'N',
      });

      if (mounted) {
        setState(() {
          _guardando = false;
          _mensajeExito = ok;
          _mensaje = ok
              ? 'PARÁMETROS MODIFICADOS CORRECTAMENTE'
              : 'Error al actualizar parámetros';
          if (ok) _hayCambios = false;
        });

        Future.delayed(const Duration(seconds: 4), () {
          if (mounted) setState(() => _mensaje = null);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _guardando = false;
          _mensaje = 'Error de conexión';
          _mensajeExito = false;
        });
      }
    }
  }

  void _marcarCambio() => setState(() => _hayCambios = true);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: _cargando
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          // ════════════════════════════════════
                          // TIPO AUTORIZACIÓN RFID
                          // ════════════════════════════════════
                          _buildCard(
                            icon: Icons.nfc_rounded,
                            title: 'TIPO AUTORIZACIÓN RFID',
                            subtitle: 'Define cómo se autoriza el acceso al sistema mediante tag RFID',
                            child: _buildDropdownAutorizacion(),
                          ),

                          const SizedBox(height: 16),

                          // ════════════════════════════════════
                          // PARÁMETROS GLOBALES
                          // ════════════════════════════════════
                          _buildCard(
                            icon: Icons.tune_rounded,
                            title: 'PARÁMETROS GLOBALES',
                            subtitle: 'Configuraciones generales del punto de venta',
                            child: Column(
                              children: [
                                _buildToggle(
                                  icon: Icons.directions_car_rounded,
                                  title: 'Placa obligatoria impresión ventas',
                                  subtitle: 'Requiere placa del vehículo para imprimir la factura',
                                  value: _placaObligatoria,
                                  onChanged: (v) {
                                    setState(() => _placaObligatoria = v);
                                    _marcarCambio();
                                  },
                                ),
                                _buildDivider(),
                                _buildToggle(
                                  icon: Icons.print_rounded,
                                  title: 'Impresión factura automática',
                                  subtitle: 'Imprime factura al finalizar venta automáticamente',
                                  value: _impresionAutomatica,
                                  onChanged: (v) {
                                    setState(() => _impresionAutomatica = v);
                                    _marcarCambio();
                                  },
                                  warning: !_impresionAutomatica
                                      ? 'La entrega de factura es obligatoria según la resolución 42 del 05 de Mayo del 2020. Se inactiva bajo su responsabilidad.'
                                      : null,
                                ),
                                _buildDivider(),
                                _buildToggle(
                                  icon: Icons.propane_tank_rounded,
                                  title: 'Ingreso medidas de tanques',
                                  subtitle: 'Solicitar lecturas de tanques al iniciar jornada',
                                  value: _medidasTanques,
                                  onChanged: (v) {
                                    setState(() => _medidasTanques = v);
                                    _marcarCambio();
                                  },
                                ),
                                _buildDivider(),
                                _buildToggle(
                                  icon: Icons.receipt_long_rounded,
                                  title: 'Imprimir consignación de sobres',
                                  subtitle: 'Genera impresión de consignaciones de sobres',
                                  value: _imprimirSobres,
                                  onChanged: (v) {
                                    setState(() => _imprimirSobres = v);
                                    _marcarCambio();
                                  },
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // ════════════════════════════════════
                          // MENSAJE DE ESTADO
                          // ════════════════════════════════════
                          if (_mensaje != null)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: _mensajeExito ? Colors.green.shade50 : Colors.red.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _mensajeExito ? Colors.green.shade300 : Colors.red.shade300,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _mensajeExito ? Icons.check_circle_rounded : Icons.error_rounded,
                                    color: _mensajeExito ? Colors.green.shade600 : Colors.red.shade600,
                                    size: 22,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    _mensaje!,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: _mensajeExito ? Colors.green.shade700 : Colors.red.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          // ════════════════════════════════════
                          // BOTÓN GUARDAR
                          // ════════════════════════════════════
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton.icon(
                              onPressed: (_guardando || !_hayCambios) ? null : _guardarParametros,
                              icon: _guardando
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Icon(Icons.save_rounded, size: 22),
                              label: Text(
                                _guardando
                                    ? 'GUARDANDO...'
                                    : _hayCambios
                                        ? 'GUARDAR CAMBIOS'
                                        : 'SIN CAMBIOS',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.terpeRed,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                elevation: _hayCambios ? 3 : 0,
                                disabledBackgroundColor: Colors.grey.shade300,
                                disabledForegroundColor: Colors.grey.shade500,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════
  //  WIDGETS AUXILIARES
  // ══════════════════════════════════════════════════

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2)),
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
          const Text(
            'Parametrizaciones',
            style: TextStyle(color: Color(0xFF333333), fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          IconButton(
            onPressed: _cargarParametros,
            icon: Icon(Icons.refresh_rounded, color: AppTheme.terpeRed),
            tooltip: 'Refrescar',
          ),
        ],
      ),
    );
  }

  Widget _buildCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: AppTheme.terpeRed,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Icon(icon, color: Colors.white, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(20),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownAutorizacion() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButtonFormField<String>(
        value: _tipoAutorizacion,
        isExpanded: true,
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          prefixIcon: Icon(Icons.security_rounded, color: AppTheme.terpeRed, size: 22),
        ),
        items: _tipoAutorizacionOptions.entries.map((e) {
          return DropdownMenuItem<String>(
            value: e.key,
            child: Text(
              e.value,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          );
        }).toList(),
        onChanged: (v) {
          if (v != null) {
            setState(() => _tipoAutorizacion = v);
            _marcarCambio();
          }
        },
      ),
    );
  }

  Widget _buildToggle({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    String? warning,
  }) {
    return Column(
      children: [
        Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: value
                    ? AppTheme.terpeRed.withOpacity(0.08)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: value ? AppTheme.terpeRed : Colors.grey.shade500,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: value ? const Color(0xFF1A1A1A) : Colors.grey.shade600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Switch(
              value: value,
              onChanged: onChanged,
              activeColor: AppTheme.terpeRed,
              activeTrackColor: AppTheme.terpeRed.withOpacity(0.3),
            ),
          ],
        ),
        // Warning message
        if (warning != null) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded, size: 16, color: Colors.amber.shade800),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    warning,
                    style: TextStyle(fontSize: 11, color: Colors.amber.shade900, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Divider(height: 1, color: Colors.grey.shade200),
    );
  }
}
