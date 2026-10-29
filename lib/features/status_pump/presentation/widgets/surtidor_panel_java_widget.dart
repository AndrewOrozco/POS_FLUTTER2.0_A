import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../domain/entities/surtidor_estado.dart';
import '../../domain/entities/combustible_color.dart';
import '../providers/status_pump_provider.dart';

/// Panel de estado de surtidores para Terpel POS.
///
/// Arquitectura UX/UI Profesional y Responsiva:
/// - Zona A: Selector de caras (01, 02, 03, 04) con franja azul #001333 e indicador activo.
/// - Zona B: Identificación del combustible, manguera, placa y badge de estado.
/// - Zona C: Tres métricas alineadas (PRECIO, IMPORTE, CANTIDAD GL).
///          Durante DESPACHANDO: PRECIO visible, IMPORTE y CANTIDAD muestran spinners.
///          En FIN DESPACHO: Valores finales visibles en las tres tarjetas.
/// - Zona D: Acciones (Gestionar venta / Medios de Pago en despacho, Asignar datos al terminar).
///
/// Diseñado con LayoutBuilder para adaptación fluida en vertical y horizontal
/// sin superponerse a los indicadores inferiores ni deformar el contenido de HomePage.
class SurtidorPanelJavaWidget extends StatefulWidget {
  final Function(int cara)? onGestionarVenta;
  final Function(int cara)? onMediosPago;
  final Set<int> carasGestionadas;
  final bool ocultarSiNoHayActivos;

  const SurtidorPanelJavaWidget({
    super.key,
    this.onGestionarVenta,
    this.onMediosPago,
    this.carasGestionadas = const {},
    this.ocultarSiNoHayActivos = true,
  });

  @override
  State<SurtidorPanelJavaWidget> createState() => _SurtidorPanelJavaWidgetState();
}

class _SurtidorPanelJavaWidgetState extends State<SurtidorPanelJavaWidget> {
  List<int> _todasLasCaras = [];

  @override
  void initState() {
    super.initState();
    _todasLasCaras = [1, 2, 3, 4];
  }

  String _formatMiles(num valor) {
    final entero = valor.toInt();
    return entero.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }

  String _formatGalones(double valor) {
    final str = valor.toStringAsFixed(3);
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
    return Consumer<StatusPumpProvider>(
      builder: (context, provider, _) {
        final surtidores = provider.surtidoresActivos;

        if (widget.ocultarSiNoHayActivos && surtidores.isEmpty) {
          return const SizedBox.shrink();
        }

        final caras = _todasLasCaras.isNotEmpty
            ? _todasLasCaras
            : (surtidores.map((s) => s.cara).toSet().toList()..sort());

        if (caras.isEmpty && surtidores.isEmpty) {
          return const SizedBox.shrink();
        }

        final caraSeleccionada = provider.caraSeleccionada ??
            (surtidores.isNotEmpty ? surtidores.first.cara : caras.firstOrNull ?? 1);

        final surtidorSeleccionado = provider.getSurtidor(caraSeleccionada);

        debugPrint('[STATUS_PUMP_AUDIT] Renderizando SurtidorPanelJavaWidget | Surtidores activos: ${surtidores.length} | Cara enfocada: $caraSeleccionada');

        // SafeArea lateral: en horizontal la barra de navegación del sistema
        // ocupa el lateral derecho; sin esto la tarjeta quedaba debajo de ella.
        return SafeArea(
          top: false,
          bottom: false,
          child: Align(
          alignment: Alignment.topCenter,
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Distribución decidida por el ancho real disponible, no por orientación.
              final isHorizontal = constraints.maxWidth >= 600;

              return ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isHorizontal ? 760 : 500,
                ),
                child: Container(
                  margin: EdgeInsets.fromLTRB(
                    isHorizontal ? 10 : 12,
                    isHorizontal ? 2 : 4,
                    isHorizontal ? 10 : 12,
                    isHorizontal ? 4 : 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x18000000),
                        blurRadius: 8,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(9),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // ── ZONA A: SELECTOR DE CARAS SUPERIOR ──
                        _buildZonaSelectorCaras(
                          caras,
                          caraSeleccionada,
                          provider,
                          surtidorSeleccionado,
                          isHorizontal: isHorizontal,
                        ),

                        // ── ZONAS B, C y D: DETALLE DE LA CARA ──
                        if (surtidorSeleccionado != null && surtidorSeleccionado.estaActivo)
                          (isHorizontal
                              ? _buildDetalleHorizontal(surtidorSeleccionado, provider)
                              : _buildDetalleVertical(surtidorSeleccionado, provider))
                        else
                          _buildCaraEnReposo(caraSeleccionada, isHorizontal: isHorizontal),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          ),
        );
      },
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // ZONA A: SELECTOR DE CARAS (01, 02, 03, 04)
  // ═════════════════════════════════════════════════════════════════════════

  Widget _buildZonaSelectorCaras(
    List<int> caras,
    int caraSeleccionada,
    StatusPumpProvider provider,
    SurtidorEstado? surtidorSeleccionado, {
    required bool isHorizontal,
  }) {
    if (isHorizontal && surtidorSeleccionado != null && surtidorSeleccionado.estaActivo) {
      // Franja horizontal elegante: Selector (izq), Combustible (centro), Badge (der)
      final colorProducto = surtidorSeleccionado.colorProducto;
      return Container(
        width: double.infinity,
        color: CombustibleColor.headerDark,
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
        child: Row(
          children: [
            const Text(
              'CARA',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(width: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: caras.map((c) {
                return _buildCaraChip(
                  c,
                  c == caraSeleccionada,
                  provider,
                  isHorizontal: false, // Usa dimensiones confortables
                );
              }).toList(),
            ),
            const SizedBox(width: 12),
            // Centro: Identificación del combustible (flexible, nunca desborda la fila)
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
            Icon(Icons.local_gas_station_rounded, size: 18, color: colorProducto),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                surtidorSeleccionado.producto.isNotEmpty
                    ? '${surtidorSeleccionado.producto.toUpperCase()} • MANGUERA ${surtidorSeleccionado.manguera}'
                    : 'MANGUERA ${surtidorSeleccionado.manguera}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 0.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (surtidorSeleccionado.placa != null && surtidorSeleccionado.placa!.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  surtidorSeleccionado.placa!,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Derecha: Badge de estado
            _buildBadgeEstado(surtidorSeleccionado, compact: false),
          ],
        ),
      );
    }

    // Franja vertical estándar
    return Container(
      width: double.infinity,
      color: CombustibleColor.headerDark,
      padding: EdgeInsets.symmetric(
        vertical: isHorizontal ? 3 : 5,
        horizontal: 8,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'CARA',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(width: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: caras.map((c) {
              return _buildCaraChip(
                c,
                c == caraSeleccionada,
                provider,
                isHorizontal: isHorizontal,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCaraChip(
    int cara,
    bool isSelected,
    StatusPumpProvider provider, {
    required bool isHorizontal,
  }) {
    final surtidor = provider.getSurtidor(cara);
    final esActivo = surtidor != null && surtidor.estaActivo;
    final esFin = surtidor != null && surtidor.esFinDespacho;
    final esDespachando = surtidor != null && surtidor.esDespachando;

    final colorProducto = surtidor != null
        ? surtidor.colorProducto
        : CombustibleColor.diesel;

    final double chipWidth = isHorizontal ? 38 : 44;
    final double chipHeight = isHorizontal ? 26 : 30;
    final double chipFontSize = isHorizontal ? 13 : 15;

    return GestureDetector(
      onTap: () => provider.seleccionarCara(cara),
      child: Container(
        width: chipWidth,
        height: chipHeight,
        margin: const EdgeInsets.symmetric(horizontal: 2.5),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : CombustibleColor.idleBg,
          borderRadius: BorderRadius.circular(6),
          border: isSelected
              ? Border.all(color: colorProducto, width: 2.0)
              : (esActivo
                  ? Border.all(color: colorProducto.withValues(alpha: 0.8), width: 1.2)
                  : null),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  cara.toString().padLeft(2, '0'),
                  style: TextStyle(
                    fontSize: chipFontSize,
                    fontWeight: FontWeight.w900,
                    color: isSelected
                        ? const Color(0xFF001333)
                        : (esActivo ? Colors.white : CombustibleColor.idleNum),
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 1.5),
                Container(
                  height: isSelected ? 2.5 : 1.5,
                  width: isSelected ? (chipWidth * 0.55) : (chipWidth * 0.45),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? colorProducto
                        : (esActivo ? colorProducto : Colors.white30),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ],
            ),
            if (esFin)
              Positioned(
                top: 2,
                right: 2,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: CombustibleColor.finDespachoFg,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1),
                  ),
                ),
              )
            else if (esDespachando)
              Positioned(
                top: 2,
                right: 2,
                child: Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: colorProducto,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 0.8),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // DISTRIBUCIÓN VERTICAL (ZONA B, ZONA C, ZONA D)
  // ═════════════════════════════════════════════════════════════════════════

  Widget _buildDetalleVertical(SurtidorEstado surtidor, StatusPumpProvider provider) {
    final colorProducto = surtidor.colorProducto;
    final esFin = surtidor.esFinDespacho;
    final gestionada = surtidor.gestionaVenta || widget.carasGestionadas.contains(surtidor.cara);
    final habilitarMediosPago = surtidor.permiteMediosPago;

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── ZONA B: IDENTIFICACIÓN DEL SURTIDOR ──
          Row(
            children: [
              Icon(
                Icons.local_gas_station_rounded,
                size: 20,
                color: colorProducto,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  surtidor.producto.isNotEmpty
                      ? '${surtidor.producto.toUpperCase()} • M${surtidor.manguera}'
                      : 'MANGUERA ${surtidor.manguera}',
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF001333),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              _buildBadgeEstado(surtidor, compact: true),
            ],
          ),

          const SizedBox(height: 6),

          // ── ZONA C: TRES MÉTRICAS ALINEADAS (PRECIO, IMPORTE, CANTIDAD GL) ──
          Row(
            children: [
              Expanded(
                child: _buildMetricBox(
                  titulo: 'PRECIO',
                  contenido: Text(
                    '\$ ${_formatMiles(surtidor.precioUnidad)}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF001333),
                    ),
                    maxLines: 1,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildMetricBox(
                  titulo: 'IMPORTE',
                  contenido: esFin
                      ? Text(
                          '\$ ${_formatMiles(surtidor.monto)}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF001333),
                          ),
                          maxLines: 1,
                        )
                      : _buildSpinner(),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildMetricBox(
                  titulo: 'CANTIDAD (GL)',
                  contenido: esFin
                      ? Text(
                          _formatGalones(surtidor.volumen),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF001333),
                          ),
                          maxLines: 1,
                        )
                      : _buildSpinner(),
                ),
              ),
            ],
          ),

          // Placa si aplica
          if (surtidor.placa != null && surtidor.placa!.isNotEmpty) ...[
            const SizedBox(height: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
              decoration: BoxDecoration(
                color: const Color(0xFF0070D5).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF0070D5).withValues(alpha: 0.25)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.directions_car, size: 13, color: Color(0xFF0070D5)),
                  const SizedBox(width: 4),
                  const Text(
                    'PLACA:',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0070D5),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    surtidor.placa!,
                    style: const TextStyle(
                      color: Color(0xFF0070D5),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 6),

          // ── ZONA D: BOTONES DE ACCIÓN ──
          _buildBotonesAccion(surtidor, esFin, gestionada, habilitarMediosPago, isHorizontal: false),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // DISTRIBUCIÓN HORIZONTAL (MÉTRICAS A LA IZQUIERDA, ACCIONES A LA DERECHA)
  // ═════════════════════════════════════════════════════════════════════════

  Widget _buildDetalleHorizontal(SurtidorEstado surtidor, StatusPumpProvider provider) {
    final esFin = surtidor.esFinDespacho;
    final gestionada = surtidor.gestionaVenta || widget.carasGestionadas.contains(surtidor.cara);
    final habilitarMediosPago = surtidor.permiteMediosPago;

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
      child: LayoutBuilder(
        builder: (context, c) {
          // ── ZONA C: TRES MÉTRICAS (misma caja de 50px que en vertical) ──
          final metricas = Row(
              children: [
                Expanded(
                  child: _buildMetricBox(
                    titulo: 'PRECIO',
                    compact: false,
                    contenido: Text(
                      '\$ ${_formatMiles(surtidor.precioUnidad)}',
                      style: const TextStyle(
                        fontSize: 15,
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
                    compact: false,
                    contenido: esFin
                        ? Text(
                            '\$ ${_formatMiles(surtidor.monto)}',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF001333),
                            ),
                            maxLines: 1,
                          )
                        : _buildSpinner(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricBox(
                    titulo: 'CANTIDAD (GL)',
                    compact: false,
                    contenido: esFin
                        ? Text(
                            _formatGalones(surtidor.volumen),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF001333),
                            ),
                            maxLines: 1,
                          )
                        : _buildSpinner(),
                  ),
                ),
              ],
          );

          // ── ZONA D: ACCIONES ──
          final acciones = _buildBotonesAccion(
            surtidor, esFin, gestionada, habilitarMediosPago,
            isHorizontal: true,
          );

          // Ancho natural de las acciones (2 botones en despacho, 1 al finalizar)
          // y ancho mínimo legible de las 3 métricas.
          final anchoAcciones = esFin ? 220.0 : 316.0;
          const anchoMinMetricas = 3 * 110.0 + 2 * 8.0;
          final caben = c.maxWidth >= anchoMinMetricas + 12 + anchoAcciones;

          if (caben) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: metricas),
                const SizedBox(width: 12),
                SizedBox(width: anchoAcciones, child: acciones),
              ],
            );
          }

          // Si no caben con holgura: dos filas, como en vertical.
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              metricas,
              const SizedBox(height: 8),
              acciones,
            ],
          );
        },
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // ZONA C: CAJA INDIVIDUAL DE MÉTRICA
  // ═════════════════════════════════════════════════════════════════════════

  Widget _buildMetricBox({
    required String titulo,
    required Widget contenido,
    bool compact = false,
  }) {
    return Container(
      height: compact ? 44 : 50,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            titulo,
            style: TextStyle(
              color: const Color(0xFF8B0000),
              fontSize: compact ? 9.5 : 10.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
              height: 1.0,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.center,
              child: contenido,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpinner({bool compact = false}) {
    final size = compact ? 15.0 : 17.0;
    return Center(
      child: SizedBox(
        width: size,
        height: size,
        child: const CircularProgressIndicator(
          strokeWidth: 2.0,
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0070D5)),
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // ZONA B: BADGE DE ESTADO
  // ═════════════════════════════════════════════════════════════════════════

  Widget _buildBadgeEstado(SurtidorEstado surtidor, {bool compact = false}) {
    final horizontalPad = compact ? 7.0 : 10.0;
    final verticalPad = compact ? 2.5 : 4.0;
    final fontSz = compact ? 10.5 : 11.5;

    if (surtidor.esFinDespacho) {
      final segs = surtidor.segundosRestantesFin;
      return Container(
        padding: EdgeInsets.symmetric(horizontal: horizontalPad, vertical: verticalPad),
        decoration: BoxDecoration(
          color: CombustibleColor.finDespachoBg,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: CombustibleColor.finDespachoBorder, width: 1.0),
        ),
        child: Text(
          'Fin despacho (${segs}s)',
          style: TextStyle(
            color: CombustibleColor.finDespachoFg,
            fontSize: fontSz,
            fontWeight: FontWeight.w900,
          ),
        ),
      );
    }

    if (surtidor.esDespachando) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: horizontalPad, vertical: verticalPad),
        decoration: BoxDecoration(
          color: const Color(0xFF001B3A),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: Colors.white24, width: 0.8),
        ),
        child: Text(
          'Despachando',
          style: TextStyle(
            color: Colors.white,
            fontSize: fontSz,
            fontWeight: FontWeight.w900,
          ),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: horizontalPad, vertical: verticalPad),
      decoration: BoxDecoration(
        color: CombustibleColor.idleBg,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        surtidor.estado.nombre,
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSz,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // ZONA D: BOTONES DE ACCIÓN
  // ═════════════════════════════════════════════════════════════════════════

  Widget _buildBotonesAccion(
    SurtidorEstado surtidor,
    bool esFin,
    bool gestionada,
    bool habilitarMediosPago, {
    required bool isHorizontal,
  }) {
    final btnHeight = isHorizontal ? 50.0 : 40.0;

    // ── MODO FIN DE DESPACHO ──
    if (esFin) {
      if (gestionada) {
        return SizedBox(
          width: double.infinity,
          height: btnHeight,
          child: ElevatedButton.icon(
            onPressed: null,
            icon: const Icon(Icons.check_circle_outline, size: 17, color: Color(0xFF646E78)),
            label: const Text(
              'Datos guardados',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, color: Color(0xFF646E78)),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: CombustibleColor.botonDisabledBg,
              disabledBackgroundColor: CombustibleColor.botonDisabledBg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
          ),
        );
      }

      // Venta terminada NO gestionada -> Botón activo "Asignar datos"
      return SizedBox(
        width: double.infinity,
        height: btnHeight,
        child: ElevatedButton.icon(
          onPressed: () => widget.onGestionarVenta?.call(surtidor.cara),
          icon: const Icon(Icons.volunteer_activism_outlined, size: 17, color: Color(0xFF1E293B)),
          label: const Text(
            'Asignar datos',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1E293B),
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFE2E8F0),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            elevation: 1,
          ),
        ),
      );
    }

    // ── MODO DESPACHO (Dos botones: Gestionar venta y Medios de Pago) ──
    return Row(
      children: [
        // Botón 1: Gestionar venta
        Expanded(
          child: SizedBox(
            height: btnHeight,
            child: ElevatedButton.icon(
              onPressed: gestionada
                  ? null
                  : () => widget.onGestionarVenta?.call(surtidor.cara),
              icon: Icon(
                gestionada ? Icons.check_circle : Icons.volunteer_activism_outlined,
                size: 16,
                color: Colors.white,
              ),
              label: Text(
                gestionada ? 'Datos guardados' : 'Gestionar venta',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: gestionada ? Colors.green.shade700 : CombustibleColor.botonAccionBg,
                padding: isHorizontal ? const EdgeInsets.symmetric(horizontal: 8) : null,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 1,
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        // Botón 2: Medios de Pago
        Expanded(
          child: SizedBox(
            height: btnHeight,
            child: ElevatedButton.icon(
              onPressed: habilitarMediosPago
                  ? () => widget.onMediosPago?.call(surtidor.cara)
                  : null,
              icon: const Icon(Icons.credit_card_outlined, size: 16, color: Colors.white),
              label: const Text(
                'Medios de Pago',
                style: TextStyle(
                  fontSize: 12,
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
                padding: isHorizontal ? const EdgeInsets.symmetric(horizontal: 8) : null,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: habilitarMediosPago ? 1 : 0,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // CARA EN REPOSO / INACTIVA
  // ═════════════════════════════════════════════════════════════════════════

  Widget _buildCaraEnReposo(int cara, {required bool isHorizontal}) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: 14,
        vertical: isHorizontal ? 5 : 8,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.local_gas_station_outlined,
            size: isHorizontal ? 14 : 16,
            color: Colors.grey.shade400,
          ),
          const SizedBox(width: 6),
          Text(
            'Cara ${cara.toString().padLeft(2, '0')} en reposo • Esperando despacho',
            style: TextStyle(
              fontSize: isHorizontal ? 11 : 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}
