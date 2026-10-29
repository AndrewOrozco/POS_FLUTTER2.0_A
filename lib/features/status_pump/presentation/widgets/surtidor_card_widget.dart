import 'package:flutter/material.dart';
import '../../domain/entities/surtidor_estado.dart';
import '../../domain/entities/combustible_color.dart';

/// Widget que muestra el estado de un surtidor individual bajo la nueva interfaz StatusPump NEW
/// Totalmente alineado a las especificaciones visuales de Terpel POS (Imágenes 1 y 2).
/// Reemplaza completamente la tarjeta naranja anterior.
class SurtidorCardWidget extends StatelessWidget {
  final SurtidorEstado surtidor;
  final VoidCallback? onTap;
  final VoidCallback? onGestionarVenta;
  final VoidCallback? onMediosPago;
  final bool ventaGestionada;

  const SurtidorCardWidget({
    super.key,
    required this.surtidor,
    this.onTap,
    this.onGestionarVenta,
    this.onMediosPago,
    this.ventaGestionada = false,
  });

  String _formatMiles(double value) {
    if (value <= 0) return '0';
    final parts = value.toStringAsFixed(0);
    final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return parts.replaceAllMapped(reg, (Match m) => '${m[1]}.');
  }

  String _formatGalones(double value) {
    if (value <= 0) return '0,000';
    final str = value.toStringAsFixed(3);
    final parts = str.split('.');
    final entero = parts[0].replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
    final decimal = parts.length > 1 ? parts[1] : '000';
    return '$entero,$decimal';
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('[STATUS_PUMP_AUDIT] Renderizando SurtidorCardWidget para Cara ${surtidor.cara} | Fase: ${surtidor.fase.name} | Monto: \$${surtidor.monto}');

    final colorProducto = surtidor.colorProducto;
    final esFin = surtidor.esFinDespacho;
    final habilitarMediosPago = surtidor.permiteMediosPago;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.black.withValues(alpha: 0.12), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── CABECERA: ÍCONO + PRODUCTO MANGUERA + BADGE ──
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.local_gas_station_rounded,
                      size: 32,
                      color: colorProducto,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        surtidor.producto.isNotEmpty
                            ? '${surtidor.producto.toUpperCase()} MANGUERA ${surtidor.manguera}'
                            : 'MANGUERA ${surtidor.manguera}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF001333),
                          letterSpacing: 0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildBadgeEstado(surtidor),
                  ],
                ),

                const SizedBox(height: 16),

                // ── CAJAS DE MÉTRICAS: PRECIO | IMPORTE | CANTIDAD (GL) ──
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricBox(
                        titulo: 'PRECIO',
                        contenido: Text(
                          '\$ ${_formatMiles(surtidor.precioUnidad)}',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF001333),
                          ),
                          maxLines: 1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildMetricBox(
                        titulo: 'IMPORTE',
                        contenido: esFin
                            ? Text(
                                '\$ ${_formatMiles(surtidor.monto)}',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF001333),
                                ),
                                maxLines: 1,
                              )
                            : const Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0070D5)),
                                  ),
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildMetricBox(
                        titulo: 'CANTIDAD (GL)',
                        contenido: esFin
                            ? Text(
                                _formatGalones(surtidor.volumen),
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF001333),
                                ),
                                maxLines: 1,
                              )
                            : const Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0070D5)),
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ],
                ),

                // ── PLACA / VEHÍCULO ──
                if (surtidor.placa != null && surtidor.placa!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0070D5).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF0070D5).withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.directions_car, size: 18, color: Color(0xFF0070D5)),
                        const SizedBox(width: 8),
                        const Text(
                          'PLACA',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0070D5),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0070D5),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            surtidor.placa!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // ── BOTONES DE ACCIÓN ──
                _buildBotonesAccion(surtidor, esFin, ventaGestionada, habilitarMediosPago),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBadgeEstado(SurtidorEstado surtidor) {
    if (surtidor.esFinDespacho) {
      final segs = surtidor.segundosRestantesFin;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: CombustibleColor.finDespachoBg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: CombustibleColor.finDespachoBorder, width: 1.2),
        ),
        child: Text(
          'Fin despacho (${segs}s)',
          style: const TextStyle(
            color: CombustibleColor.finDespachoFg,
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
      );
    }

    if (surtidor.esDespachando) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFF001B3A),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text(
          'Despachando',
          style: TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: CombustibleColor.idleBg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        surtidor.estado.nombre,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildMetricBox({required String titulo, required Widget contenido}) {
    return Container(
      height: 78,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFD0D7DE), width: 1.2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            titulo,
            style: const TextStyle(
              color: Color(0xFF8B0000),
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
              height: 1.0,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: contenido,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBotonesAccion(
    SurtidorEstado surtidor,
    bool esFin,
    bool gestionada,
    bool habilitarMediosPago,
  ) {
    // ── MODO FIN DE DESPACHO ──
    if (esFin) {
      if (gestionada) {
        return SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton.icon(
            onPressed: null,
            icon: const Icon(Icons.check_circle_outline, size: 22, color: Color(0xFF646E78)),
            label: const Text(
              'Datos guardados',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: Color(0xFF646E78),
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: CombustibleColor.botonDisabledBg,
              disabledBackgroundColor: CombustibleColor.botonDisabledBg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
          ),
        );
      }

      // Venta terminada NO gestionada -> Botón activo "Asignar datos" (Imagen 2)
      return SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton.icon(
          onPressed: onGestionarVenta,
          icon: const Icon(Icons.volunteer_activism_outlined, size: 22, color: Color(0xFF1E293B)),
          label: const Text(
            'Asignar datos',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1E293B),
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFE2E8F0),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 1,
          ),
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 54,
            child: ElevatedButton.icon(
              onPressed: gestionada ? null : onGestionarVenta,
              icon: Icon(
                gestionada ? Icons.check_circle : Icons.volunteer_activism_outlined,
                size: 22,
                color: Colors.white,
              ),
              label: Text(
                gestionada ? 'Datos guardados' : 'Gestionar venta',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: gestionada ? Colors.green.shade700 : CombustibleColor.botonAccionBg,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SizedBox(
            height: 54,
            child: ElevatedButton.icon(
              onPressed: habilitarMediosPago ? onMediosPago : null,
              icon: const Icon(Icons.credit_card_outlined, size: 22, color: Colors.white),
              label: const Text(
                'Medios de Pago',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: habilitarMediosPago
                    ? CombustibleColor.botonAccionBg
                    : CombustibleColor.botonDisabledBg,
                disabledBackgroundColor: CombustibleColor.botonDisabledBg,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: habilitarMediosPago ? 2 : 0,
              ),
            ),
          ),
        ),
      ],
    );
  }
}