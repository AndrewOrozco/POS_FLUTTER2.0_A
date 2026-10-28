import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/api_consultas_service.dart';
import '../providers/status_pump_provider.dart';
import '../../domain/entities/surtidor_estado.dart';

/// Widget estilo Java POS: fila horizontal de caras + detalle del surtidor seleccionado.
/// Se usa en la página Home para reemplazar el SurtidorListWidget antiguo.
class SurtidorPanelJavaWidget extends StatefulWidget {
  final Function(int cara)? onGestionarVenta;
  final Function(int cara)? onMediosPago;
  final Set<int> carasGestionadas;

  const SurtidorPanelJavaWidget({
    super.key,
    this.onGestionarVenta,
    this.onMediosPago,
    this.carasGestionadas = const {},
  });

  @override
  State<SurtidorPanelJavaWidget> createState() => _SurtidorPanelJavaWidgetState();
}

class _SurtidorPanelJavaWidgetState extends State<SurtidorPanelJavaWidget> {
  /// Todas las caras configuradas en BD
  List<int> _todasLasCaras = [];
  bool _cargandoConfig = true;
  int? _caraSeleccionada;

  @override
  void initState() {
    super.initState();
    _cargarCaras();
  }

  Future<void> _cargarCaras() async {
    try {
      final api = ApiConsultasService();
      final result = await api.obtenerManguerasSurtidores();
      final data = result['data'] as List? ?? [];
      final carasSet = <int>{};
      for (final item in data) {
        final cara = item['cara'] as int? ?? 0;
        if (cara > 0) carasSet.add(cara);
      }
      if (mounted) {
        setState(() {
          _todasLasCaras = carasSet.toList()..sort();
          _cargandoConfig = false;
        });
      }
    } catch (e) {
      debugPrint('[SurtidorPanel] Error cargando caras: $e');
      if (mounted) setState(() => _cargandoConfig = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<StatusPumpProvider>(
      builder: (context, provider, _) {
        final surtidores = provider.surtidoresActivos;

        if (_cargandoConfig && surtidores.isEmpty) {
          return const SizedBox.shrink();
        }

        // Si no hay caras configuradas Y no hay surtidores activos, no mostrar nada
        if (_todasLasCaras.isEmpty && surtidores.isEmpty) {
          return const SizedBox.shrink();
        }

        // Determinar caras a mostrar:
        // Si tenemos la config de BD, mostrar todas.
        // Si no, solo las activas (fallback).
        final caras = _todasLasCaras.isNotEmpty
            ? _todasLasCaras
            : surtidores.map((s) => s.cara).toSet().toList()
          ..sort();

        // Auto-seleccionar la primera cara activa si no hay selección
        if (_caraSeleccionada == null && surtidores.isNotEmpty) {
          _caraSeleccionada = surtidores.first.cara;
        }

        final surtidorSeleccionado = _caraSeleccionada != null
            ? provider.getSurtidor(_caraSeleccionada!)
            : null;

        return Container(
          margin: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.red.shade100, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ═══ FILA DE CARAS ═══
              _buildCarasRow(caras, provider),
              // ═══ DETALLE DEL SURTIDOR SELECCIONADO ═══
              if (surtidorSeleccionado != null && surtidorSeleccionado.estado.estaActivo)
                _buildDetalle(surtidorSeleccionado)
              else if (_caraSeleccionada != null)
                _buildCaraInactiva(_caraSeleccionada!)
              else if (surtidores.isNotEmpty)
                _buildDetalle(surtidores.first),
            ],
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  FILA DE CARAS
  // ═══════════════════════════════════════════════════════════

  Widget _buildCarasRow(List<int> caras, StatusPumpProvider provider) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF37474F),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'MANGUERA',
            style: TextStyle(
              color: Colors.white60,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 56,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: caras.map((cara) {
                  return _buildCaraChip(cara, provider);
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCaraChip(int cara, StatusPumpProvider provider) {
    final surtidor = provider.getSurtidor(cara);
    final isActivo = surtidor != null && surtidor.estado.estaActivo;
    final isSelected = _caraSeleccionada == cara;
    final productoColor = surtidor != null
        ? _getProductoColor(surtidor.producto)
        : Colors.grey;

    final bool esDespachando = surtidor?.estado == EstadoSurtidor.fueling;
    final bool esAutorizando = surtidor?.estado == EstadoSurtidor.authorizationInProgress;

    return GestureDetector(
      onTap: () {
        setState(() => _caraSeleccionada = cara);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 52,
        height: 56,
        margin: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white
              : isActivo
                  ? Colors.white.withValues(alpha: 0.92)
                  : const Color(0xFF546E7A),
          borderRadius: BorderRadius.circular(10),
          border: isSelected
              ? Border.all(color: productoColor, width: 2.5)
              : isActivo
                  ? Border.all(color: productoColor.withValues(alpha: 0.7), width: 2)
                  : null,
          boxShadow: isSelected
              ? [BoxShadow(color: productoColor.withValues(alpha: 0.4), blurRadius: 6)]
              : null,
        ),
        child: Stack(
          children: [
            Center(
              child: Text(
                cara.toString().padLeft(2, '0'),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isActivo || isSelected
                      ? const Color(0xFF37474F)
                      : Colors.white38,
                ),
              ),
            ),
            // Punto verde = despachando
            if (esDespachando)
              Positioned(
                top: 3,
                right: 3,
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                ),
              ),
            // Punto naranja = autorizando
            if (esAutorizando)
              Positioned(
                top: 3,
                right: 3,
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                ),
              ),
            // Barra de color del producto
            if (isActivo)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: productoColor,
                    borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(8)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  PANEL DE DETALLE
  // ═══════════════════════════════════════════════════════════

  Widget _buildDetalle(SurtidorEstado surtidor) {
    final productoColor = _getProductoColor(surtidor.producto);
    final gestionada = widget.carasGestionadas.contains(surtidor.cara);
    final habilitarMediosPago = surtidor.authorizationIdentifier == null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Header: Producto + Estado ──
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Row(
            children: [
              Icon(Icons.local_gas_station, size: 26, color: productoColor),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  surtidor.producto.isNotEmpty
                      ? '${surtidor.producto} manguera ${surtidor.manguera}'
                      : 'Manguera ${surtidor.manguera}',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A237E),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A237E),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  surtidor.estado == EstadoSurtidor.fueling
                      ? 'Despachando'
                      : surtidor.estado.nombre,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── Info boxes: Precio, Importe, Cantidad ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Row(
            children: [
              Expanded(child: _buildInfoBox('PRECIO', '\$${_formatNumber(surtidor.precioUnidad)}', productoColor)),
              const SizedBox(width: 10),
              Expanded(child: _buildInfoBox('IMPORTE', '\$${_formatNumber(surtidor.monto)}', productoColor)),
              const SizedBox(width: 10),
              Expanded(child: _buildInfoBox('CANTIDAD', surtidor.volumen.toStringAsFixed(3), productoColor)),
            ],
          ),
        ),

        // ── Placa ──
        if (surtidor.placa != null && surtidor.placa!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1565C0).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF1565C0).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.directions_car, size: 18, color: Color(0xFF1565C0)),
                  const SizedBox(width: 8),
                  const Text('PLACA', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1565C0))),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1565C0),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      surtidor.placa!,
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                    ),
                  ),
                ],
              ),
            ),
          ),

        // ── APP TERPEL ──
        if (surtidor.medioPagoEspecial != null && surtidor.medioPagoEspecial!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF6A1B9A).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF6A1B9A).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.phone_iphone, size: 18, color: Color(0xFF6A1B9A)),
                  const SizedBox(width: 8),
                  Text(
                    surtidor.medioPagoEspecial!,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF6A1B9A)),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6A1B9A),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.qr_code_2, size: 12, color: Colors.white),
                        SizedBox(width: 4),
                        Text('QR 90s', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

        // ── Botones de acción ──
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
          child: Row(
            children: [
              Expanded(
                child: _buildActionBtn(
                  icon: gestionada ? Icons.check_circle : Icons.receipt_long,
                  label: gestionada ? 'Datos guardados' : 'Gestionar venta',
                  color: gestionada ? Colors.green : const Color(0xFF8B1A2B),
                  onTap: gestionada ? null : () => widget.onGestionarVenta?.call(surtidor.cara),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildActionBtn(
                  icon: Icons.payment,
                  label: 'Medios de Pago',
                  color: const Color(0xFF8B1A2B),
                  onTap: habilitarMediosPago
                      ? () => widget.onMediosPago?.call(surtidor.cara)
                      : null,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCaraInactiva(int cara) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.local_gas_station_outlined, size: 40, color: Colors.grey.shade300),
          const SizedBox(height: 8),
          Text(
            'Cara ${cara.toString().padLeft(2, '0')} en espera',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBox(String label, String value, Color accentColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: accentColor,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A237E),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBtn({
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onTap,
  }) {
    final enabled = onTap != null;
    return Material(
      color: enabled ? color : Colors.grey.shade300,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: enabled ? Colors.white : Colors.grey),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: enabled ? Colors.white : Colors.grey,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  UTILIDADES
  // ═══════════════════════════════════════════════════════════

  Color _getProductoColor(String productoRaw) {
    final producto = productoRaw.toUpperCase();
    if (producto.contains('EXTRA') || producto.contains('PREMIUM') || producto.contains('SUPER')) {
      return const Color(0xFF1E88E5);
    }
    if (producto.contains('CORRIENTE') || producto.contains('REGULAR') || producto.contains('OXIGENADA')) {
      return const Color(0xFFE53935);
    }
    if (producto.contains('DIESEL') || producto.contains('ACPM') || producto.contains('BIODIESEL') ||
        producto.contains('BIOACEM') || producto.contains('B10') || producto.contains('B12')) {
      return const Color(0xFFFFA000);
    }
    if (producto.contains('GAS') || producto.contains('GNV') || producto.contains('NATURAL')) {
      return const Color(0xFF43A047);
    }
    if (producto.contains('GLP') || producto.contains('PROPANO')) {
      return const Color(0xFF8E24AA);
    }
    return AppTheme.terpeRed;
  }

  String _formatNumber(double number) {
    if (number >= 1000) {
      return number.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (Match m) => '${m[1]},',
      );
    }
    return number.toStringAsFixed(0);
  }
}
