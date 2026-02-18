import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../../core/services/api_consultas_service.dart';
import '../../../../core/models/api_models.dart';
import '../../../../core/providers/session_provider.dart';

/// Página de checkout / confirmación de venta de canastilla.
/// Muestra resumen, selección de medio de pago, campo recibido y cambio.
class CanastillaCheckoutPage extends StatefulWidget {
  final List<ItemCarrito> carrito;
  final VoidCallback onVentaExitosa;

  const CanastillaCheckoutPage({
    super.key,
    required this.carrito,
    required this.onVentaExitosa,
  });

  @override
  State<CanastillaCheckoutPage> createState() => _CanastillaCheckoutPageState();
}

class _CanastillaCheckoutPageState extends State<CanastillaCheckoutPage> {
  final ApiConsultasService _api = ApiConsultasService();

  List<MedioPagoCanastilla> _mediosPago = [];
  bool _cargando = false;
  bool _procesando = false;
  bool _ventaExitosa = false;
  int? _movimientoId;
  bool _facturacionPOS = false;
  bool _isDefaultFe = false;
  bool _esUltimaVentaFE = false;
  ClienteConsulta? _clienteFE;

  // Medio de pago seleccionado
  MedioPagoCanastilla? _medioPagoSeleccionado;
  final TextEditingController _recibidoCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargarMediosPago();
    _cargarConfigFacturacion();
  }

  @override
  void dispose() {
    _recibidoCtrl.dispose();
    super.dispose();
  }

  double get _subtotal =>
      widget.carrito.fold(0.0, (s, i) => s + i.subtotal);

  double get _impuestos =>
      widget.carrito.fold(0.0, (s, i) => s + i.impuestoTotal);

  double get _total => _subtotal;

  double get _recibido {
    final text = _recibidoCtrl.text.replaceAll(RegExp(r'[^\d.]'), '');
    return double.tryParse(text) ?? 0;
  }

  double get _cambio => (_recibido - _total).clamp(0, double.infinity);

  Future<void> _cargarMediosPago() async {
    setState(() => _cargando = true);
    final medios = await _api.obtenerMediosPagoCanastilla();
    if (mounted) {
      setState(() {
        _mediosPago = medios;
        _cargando = false;
        // Seleccionar EFECTIVO por defecto si existe
        final efectivoIdx = medios.indexWhere(
            (m) => m.descripcion.toUpperCase().contains('EFECTIVO'));
        _medioPagoSeleccionado = efectivoIdx >= 0 ? medios[efectivoIdx] : (medios.isNotEmpty ? medios.first : null);
      });
    }
  }

  Future<void> _cargarConfigFacturacion() async {
    try {
      final config = await _api.obtenerConfigFacturacion();
      if (mounted) {
        setState(() {
          _facturacionPOS = config['facturacion_pos'] ?? false;
          _isDefaultFe = config['is_default_fe'] ?? false;
        });
      }
    } catch (_) {
      // Si falla, dejamos false
    }
  }

  /// Abre diálogo compacto de Facturación Electrónica para buscar cliente.
  /// Si el usuario confirma, procede con la venta FE.
  Future<void> _mostrarDialogoFE() async {
    if (_medioPagoSeleccionado == null) {
      _showMsg('Seleccione un medio de pago', error: true);
      return;
    }

    final esEfectivo = _medioPagoSeleccionado!.descripcion
            .toUpperCase()
            .contains('EFECTIVO') ||
        _medioPagoSeleccionado!.tipo.toUpperCase().contains('EFECTIVO');

    if (esEfectivo && _recibido < _total) {
      _showMsg('El valor recibido debe ser mayor o igual al total',
          error: true);
      return;
    }

    final resultado = await showDialog<ClienteConsulta?>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _DialogoFacturacionElectronica(),
    );

    if (resultado != null && mounted) {
      setState(() => _clienteFE = resultado);
      _confirmarVenta(esFacturacionElectronica: true);
    }
  }

  Future<void> _confirmarVenta({bool esFacturacionElectronica = false}) async {
    if (_medioPagoSeleccionado == null) {
      _showMsg('Seleccione un medio de pago', error: true);
      return;
    }

    final esEfectivo = _medioPagoSeleccionado!.descripcion
            .toUpperCase()
            .contains('EFECTIVO') ||
        _medioPagoSeleccionado!.tipo.toUpperCase().contains('EFECTIVO');

    if (esEfectivo && _recibido < _total) {
      _showMsg('El valor recibido debe ser mayor o igual al total', error: true);
      return;
    }

    setState(() => _procesando = true);

    try {
      final session = Provider.of<SessionProvider>(context, listen: false);
      final promotor = session.promotoresActivos.isNotEmpty
          ? session.promotoresActivos.first
          : null;

      final costoTotal = widget.carrito
          .fold(0.0, (s, i) => s + (i.producto.costo * i.cantidad));

      final body = {
        'identificador_promotor': promotor?.id ?? 0,
        'nombres_promotor': promotor?.nombre ?? '',
        'apellidos_promotor': '',
        'identificacion_promotor': promotor?.identificacion ?? '',
        'identificador_jornada': promotor?.jornadaId ?? 0,
        'venta_total': _total,
        'impuesto_total': _impuestos,
        'costo_total': costoTotal,
        'descuento_total': 0.0,
        'es_facturacion_electronica': esFacturacionElectronica,
        'detalles': widget.carrito.map((i) => i.toDetalleJson()).toList(),
        'medios_pago': [
          {
            'identificacion_medios_pagos': _medioPagoSeleccionado!.id,
            'descripcion_medio': _medioPagoSeleccionado!.descripcion,
            'recibido_medio_pago': esEfectivo ? _recibido : _total,
            'total_medio_pago': _total,
            'vuelto_medio_pago': esEfectivo ? _cambio : 0.0,
            'identificacion_comprobante': '',
          },
        ],
        if (esFacturacionElectronica && _clienteFE != null)
          'factura_electronica': {
            'identificacion_cliente': _clienteFE!.identificacion,
            'nombre_cliente': _clienteFE!.nombre,
            'email_cliente': _clienteFE!.email ?? '',
            'telefono_cliente': _clienteFE!.telefono ?? '',
            'direccion_cliente': _clienteFE!.direccion ?? '',
            'tipo_identificacion': _clienteFE!.tipoIdentificacion,
            if (_clienteFE!.rawResponse != null)
              'raw_response': _clienteFE!.rawResponse,
          },
      };

      final result = await _api.procesarVentaCanastilla(body);

      if (!mounted) return;

      if (result['exito'] == true) {
        _movimientoId =
            parseInt(result['movimiento_id'] ?? result['data']?['id']);
        setState(() {
          _ventaExitosa = true;
          _procesando = false;
          _esUltimaVentaFE = esFacturacionElectronica;
        });
        widget.onVentaExitosa();
      } else {
        setState(() => _procesando = false);
        _showMsg(result['mensaje']?.toString() ?? 'Error procesando venta',
            error: true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _procesando = false);
        _showMsg('Error: $e', error: true);
      }
    }
  }

  Future<void> _imprimir() async {
    if (_movimientoId == null || _movimientoId == 0) return;
    // Java:
    //   Factura Electrónica → /api/imprimir/factura-electronica (FACTURA-ELECTRONICA)
    //   Factura POS         → /api/imprimir/factura            (FACTURA)
    //   Venta simple        → /api/imprimir/venta              (VENTA)
    String reportType;
    if (_esUltimaVentaFE) {
      reportType = 'FACTURA-ELECTRONICA';
    } else if (_facturacionPOS) {
      reportType = 'FACTURA';
    } else {
      reportType = 'VENTA';
    }

    // Datos del cliente para el recibo
    // Enviar siempre que haya datos de cliente, incluso si encontrado=false
    // (ej: "Consumidor Final" con C.C. 222222 necesita aparecer en el ticket)
    Map<String, dynamic>? clienteData;
    if (_clienteFE != null) {
      clienteData = {
        'tipoDocumento': _clienteFE!.tipoIdentificacion,
        'numeroDocumento': _clienteFE!.identificacion,
        'identificadorTipoPersona': 1,
        'nombreComercial': _clienteFE!.nombre.isNotEmpty
            ? _clienteFE!.nombre
            : 'CONSUMIDOR FINAL',
        'nombreRazonSocial': _clienteFE!.nombre.isNotEmpty
            ? _clienteFE!.nombre
            : 'CONSUMIDOR FINAL',
        'direccionTicket': _clienteFE!.direccion ?? '',
        'correoElectronico': _clienteFE!.email ?? '',
        'telefonoTicket': _clienteFE!.telefono ?? '',
      };
    }

    final result = await _api.imprimirCanastilla(
      _movimientoId!,
      reportType: reportType,
      cliente: clienteData,
    );
    if (mounted) {
      _showMsg(result['mensaje']?.toString() ?? 'OK',
          error: result['exito'] != true);
    }
  }

  void _showMsg(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? Colors.red.shade600 : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_ventaExitosa) return _buildExitoScreen();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFF8F00),
        foregroundColor: Colors.white,
        title: const Text('Confirmar Venta',
            style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 2,
      ),
      body: _cargando
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFFF8F00)))
          : Row(
              children: [
                // Panel izquierdo: resumen de productos
                Expanded(flex: 5, child: _buildResumenProductos()),
                // Panel derecho: pago
                SizedBox(width: 420, child: _buildPanelPago()),
              ],
            ),
    );
  }

  Widget _buildResumenProductos() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.grey.shade200, blurRadius: 8),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3E0),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                const Icon(Icons.receipt_long, color: Color(0xFFE65100)),
                const SizedBox(width: 10),
                Text(
                  'Resumen de Productos (${widget.carrito.length})',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Color(0xFFE65100)),
                ),
              ],
            ),
          ),
          // Tabla de productos
          Expanded(
            child: SingleChildScrollView(
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(
                    const Color(0xFFFAFAFA)),
                columnSpacing: 20,
                columns: const [
                  DataColumn(label: Text('#', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Producto', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Precio', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                  DataColumn(label: Text('Cant.', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                  DataColumn(label: Text('Subtotal', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                ],
                rows: List.generate(widget.carrito.length, (idx) {
                  final item = widget.carrito[idx];
                  return DataRow(cells: [
                    DataCell(Text('${idx + 1}')),
                    DataCell(
                      SizedBox(
                        width: 200,
                        child: Text(
                          item.producto.descripcion,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ),
                    DataCell(Text('\$${item.producto.precio.toStringAsFixed(0)}')),
                    DataCell(Text('${item.cantidad}')),
                    DataCell(Text(
                      '\$${item.subtotal.toStringAsFixed(0)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    )),
                  ]);
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPanelPago() {
    final esEfectivo = _medioPagoSeleccionado?.descripcion
            .toUpperCase()
            .contains('EFECTIVO') ==
        true;

    return Container(
      margin: const EdgeInsets.fromLTRB(0, 16, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.grey.shade200, blurRadius: 8),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF8F00), Color(0xFFE65100)],
              ),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: const Column(
              children: [
                Icon(Icons.payment, size: 40, color: Colors.white),
                SizedBox(height: 8),
                Text('MEDIO DE PAGO',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          // Totales
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _totalRow('Subtotal', _subtotal),
                _totalRow('Impuestos', _impuestos),
                const Divider(),
                _totalRow('TOTAL', _total, bold: true, big: true),
              ],
            ),
          ),
          // Selector de medio de pago
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Seleccione medio de pago:',
                    style:
                        TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 140,
                  child: ListView.builder(
                    itemCount: _mediosPago.length,
                    itemBuilder: (ctx, idx) {
                      final mp = _mediosPago[idx];
                      final sel =
                          _medioPagoSeleccionado?.id == mp.id;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Material(
                          color: sel
                              ? const Color(0xFFFF8F00).withOpacity(0.12)
                              : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(10),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () =>
                                setState(() => _medioPagoSeleccionado = mp),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: sel
                                      ? const Color(0xFFFF8F00)
                                      : Colors.grey.shade300,
                                  width: sel ? 2 : 1,
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _iconForMedio(mp.descripcion),
                                    color: sel
                                        ? const Color(0xFFFF8F00)
                                        : Colors.grey.shade600,
                                    size: 22,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      mp.descripcion,
                                      style: TextStyle(
                                        fontWeight: sel
                                            ? FontWeight.bold
                                            : FontWeight.w500,
                                        color: sel
                                            ? const Color(0xFFE65100)
                                            : Colors.black87,
                                      ),
                                    ),
                                  ),
                                  if (sel)
                                    const Icon(Icons.check_circle,
                                        color: Color(0xFFFF8F00), size: 22),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          // Valor recibido (solo para efectivo)
          if (esEfectivo) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: TextField(
                controller: _recibidoCtrl,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Valor Recibido',
                  prefixText: '\$ ',
                  prefixStyle: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 18),
                  filled: true,
                  fillColor: const Color(0xFFF5F5F5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ),
            // Cambio
            Container(
              margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _cambio > 0
                    ? Colors.green.shade50
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color:
                      _cambio > 0 ? Colors.green.shade300 : Colors.grey.shade300,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('CAMBIO:',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(
                    '\$${_cambio.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: _cambio > 0
                          ? Colors.green.shade700
                          : Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const Spacer(),
          // ── Botones de venta (Java: StoreConfirmarViewController) ──
          // Botón 1: F. ELECTRONICA / FACTURA POS
          // Botón 2: GUARDAR VENTA
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed:
                    _procesando || _medioPagoSeleccionado == null
                        ? null
                        : _mostrarDialogoFE,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isDefaultFe
                      ? const Color(0xFF1565C0)
                      : const Color(0xFF388E3C),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 3,
                ),
                icon: _procesando
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5))
                    : Icon(
                        _isDefaultFe
                            ? Icons.receipt_long
                            : Icons.description_outlined,
                        size: 24),
                label: Text(
                  _procesando
                      ? 'PROCESANDO...'
                      : (_isDefaultFe
                          ? 'FACTURA POS'
                          : 'F. ELECTRONICA'),
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
          // Botón 2: GUARDAR VENTA
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed:
                    _procesando || _medioPagoSeleccionado == null
                        ? null
                        : () => _confirmarVenta(esFacturacionElectronica: false),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF8F00),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 3,
                ),
                icon: _procesando
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5))
                    : const Icon(Icons.save_outlined, size: 24),
                label: Text(
                  _procesando ? 'PROCESANDO...' : 'GUARDAR VENTA',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExitoScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Center(
        child: Container(
          width: 500,
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(color: Colors.grey.shade300, blurRadius: 20),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check_circle,
                    size: 70, color: Colors.green.shade600),
              ),
              const SizedBox(height: 24),
              const Text(
                '¡VENTA EXITOSA!',
                style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF388E3C)),
              ),
              const SizedBox(height: 12),
              Text(
                'Movimiento #${_movimientoId ?? '---'}',
                style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: _esUltimaVentaFE
                      ? Colors.blue.shade50
                      : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _esUltimaVentaFE
                      ? (_isDefaultFe ? 'FACTURA POS' : 'F. ELECTRONICA')
                      : 'VENTA GUARDADA',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _esUltimaVentaFE
                        ? Colors.blue.shade700
                        : Colors.orange.shade800,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _totalRow('Total', _total, bold: true, big: true),
                    if (_medioPagoSeleccionado != null)
                      _totalRow(
                          'Medio de pago', 0,
                          label2: _medioPagoSeleccionado!.descripcion),
                    _totalRow('Productos',
                        widget.carrito.fold(0.0, (s, i) => s + i.cantidad),
                        label2: '${widget.carrito.fold<int>(0, (s, i) => s + i.cantidad)} items'),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: _imprimir,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1976D2),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.print),
                    label: const Text('IMPRIMIR',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF8F00),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('VOLVER',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _totalRow(String label, double value,
      {bool bold = false, bool big = false, String? label2}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                fontSize: big ? 20 : 14,
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              )),
          Text(
            label2 ?? '\$${value.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: big ? 22 : 14,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              color: big ? const Color(0xFFE65100) : null,
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconForMedio(String desc) {
    final d = desc.toUpperCase();
    if (d.contains('EFECTIVO')) return Icons.attach_money;
    if (d.contains('TARJETA') || d.contains('DEBITO') || d.contains('CREDITO')) {
      return Icons.credit_card;
    }
    if (d.contains('NEQUI') || d.contains('DAVIPLATA') || d.contains('TRANSFER')) {
      return Icons.phone_android;
    }
    if (d.contains('BONO') || d.contains('VALE')) return Icons.card_giftcard;
    return Icons.payment;
  }
}

// ============================================================
// Diálogo compacto de Facturación Electrónica
// ============================================================

class _DialogoFacturacionElectronica extends StatefulWidget {
  const _DialogoFacturacionElectronica();

  @override
  State<_DialogoFacturacionElectronica> createState() =>
      _DialogoFacturacionElectronicaState();
}

class _DialogoFacturacionElectronicaState
    extends State<_DialogoFacturacionElectronica> {
  final ApiConsultasService _api = ApiConsultasService();
  final TextEditingController _idCtrl = TextEditingController();
  final FocusNode _idFocus = FocusNode();

  List<TipoIdentificacion> _tipos = [];
  TipoIdentificacion? _tipoSeleccionado;
  ClienteConsulta? _clienteEncontrado;
  bool _buscando = false;
  bool _cargandoTipos = true;
  bool _fidelizar = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarTipos();
  }

  @override
  void dispose() {
    _idCtrl.dispose();
    _idFocus.dispose();
    super.dispose();
  }

  Future<void> _cargarTipos() async {
    final tipos = await _api.getTiposIdentificacion();
    if (mounted) {
      setState(() {
        _tipos = tipos.where((t) => !t.esConsumidorFinal).toList();
        _tipoSeleccionado = _tipos.isNotEmpty ? _tipos.first : null;
        _cargandoTipos = false;
      });
    }
  }

  Future<void> _buscarCliente() async {
    final id = _idCtrl.text.trim();
    if (id.isEmpty) {
      setState(() => _error = 'Ingrese un número de identificación');
      return;
    }
    if (_tipoSeleccionado == null) return;

    setState(() {
      _buscando = true;
      _error = null;
      _clienteEncontrado = null;
    });

    try {
      final cliente = await _api.consultarCliente(
        id,
        tipoDocumento: _tipoSeleccionado!.codigo,
      );
      if (mounted) {
        setState(() {
          _clienteEncontrado = cliente;
          _buscando = false;
          if (!cliente.encontrado) {
            _error = 'Cliente no registrado. Se facturará como CONSUMIDOR FINAL.';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _buscando = false;
          _error = 'Error consultando: $e';
        });
      }
    }
  }

  void _teclaNumero(String digito) {
    if (_tipoSeleccionado != null &&
        _idCtrl.text.length >= _tipoSeleccionado!.limiteCaracteres) return;
    _idCtrl.text += digito;
    _idCtrl.selection =
        TextSelection.collapsed(offset: _idCtrl.text.length);
  }

  void _borrar() {
    if (_idCtrl.text.isNotEmpty) {
      _idCtrl.text = _idCtrl.text.substring(0, _idCtrl.text.length - 1);
      _idCtrl.selection =
          TextSelection.collapsed(offset: _idCtrl.text.length);
    }
  }

  void _limpiar() {
    _idCtrl.clear();
    setState(() {
      _clienteEncontrado = null;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 520,
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header ──
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.receipt_long,
                        color: Colors.blue.shade700, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'FACTURA ELECTRÓNICA',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    tooltip: 'Cancelar',
                    iconSize: 22,
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // ── Check fidelizar ──
              Container(
                decoration: BoxDecoration(
                  color: _fidelizar ? Colors.purple.shade50 : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _fidelizar
                        ? Colors.purple.shade200
                        : Colors.grey.shade200,
                  ),
                ),
                child: CheckboxListTile(
                  value: _fidelizar,
                  onChanged: (v) => setState(() {
                    _fidelizar = v ?? false;
                    if (!_fidelizar) {
                      _clienteEncontrado = null;
                      _error = null;
                    }
                  }),
                  title: const Text('FIDELIZAR CLIENTE',
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    _fidelizar
                        ? 'Se consultará el cliente para fidelización'
                        : 'Sin fidelización - Consumidor final',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                  secondary: Icon(
                    _fidelizar ? Icons.loyalty : Icons.person_outline,
                    color: _fidelizar
                        ? Colors.purple.shade600
                        : Colors.grey.shade500,
                  ),
                  activeColor: Colors.purple.shade600,
                  dense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),

              // ── Formulario cliente (visible si fidelizar) ──
              if (_fidelizar) ...[
                const SizedBox(height: 14),

                if (_cargandoTipos)
                  const Center(
                      child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  ))
                else ...[
                  // Tipo de identificación
                  const Text('TIPO DE IDENTIFICACIÓN:',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey)),
                  const SizedBox(height: 4),
                  Container(
                    height: 42,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<TipoIdentificacion>(
                        isExpanded: true,
                        value: _tipoSeleccionado,
                        items: _tipos
                            .map((t) => DropdownMenuItem(
                                  value: t,
                                  child: Text(t.nombre.toUpperCase(),
                                      style: const TextStyle(fontSize: 13)),
                                ))
                            .toList(),
                        onChanged: (v) => setState(() {
                          _tipoSeleccionado = v;
                          _clienteEncontrado = null;
                          _error = null;
                          _idCtrl.clear();
                        }),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Identificación + consultar
                  const Text('IDENTIFICACIÓN:',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 42,
                          child: TextField(
                            controller: _idCtrl,
                            focusNode: _idFocus,
                            readOnly: true,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600),
                            decoration: InputDecoration(
                              hintText: 'Número de documento',
                              hintStyle: const TextStyle(fontSize: 13),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 10),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8)),
                              suffixIcon: _idCtrl.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 18),
                                      onPressed: _limpiar,
                                      padding: EdgeInsets.zero,
                                    )
                                  : null,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 42,
                        child: ElevatedButton(
                          onPressed: _buscando ? null : _buscarCliente,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1976D2),
                            foregroundColor: Colors.white,
                            padding:
                                const EdgeInsets.symmetric(horizontal: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          child: _buscando
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2))
                              : const Text('CONSULTAR',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // ── Teclado numérico ──
                  _buildTecladoNumerico(),

                  // ── Resultado cliente ──
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _clienteEncontrado != null &&
                                !_clienteEncontrado!.encontrado
                            ? Colors.orange.shade50
                            : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _clienteEncontrado != null &&
                                    !_clienteEncontrado!.encontrado
                                ? Icons.info_outline
                                : Icons.error_outline,
                            color: _clienteEncontrado != null &&
                                    !_clienteEncontrado!.encontrado
                                ? Colors.orange.shade700
                                : Colors.red.shade700,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(_error!,
                                style: TextStyle(
                                  color: _clienteEncontrado != null &&
                                          !_clienteEncontrado!.encontrado
                                      ? Colors.orange.shade800
                                      : Colors.red.shade800,
                                  fontSize: 12,
                                )),
                          ),
                        ],
                      ),
                    ),
                  ],

                  if (_clienteEncontrado != null &&
                      _clienteEncontrado!.encontrado) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.check_circle,
                                  color: Colors.green.shade700, size: 18),
                              const SizedBox(width: 6),
                              const Text('CLIENTE ENCONTRADO',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: Color(0xFF2E7D32))),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _infoRow('Nombre', _clienteEncontrado!.nombre),
                          _infoRow(
                              'Documento', _clienteEncontrado!.identificacion),
                          if (_clienteEncontrado!.email != null &&
                              _clienteEncontrado!.email!.isNotEmpty)
                            _infoRow('Email', _clienteEncontrado!.email!),
                          if (_clienteEncontrado!.telefono != null &&
                              _clienteEncontrado!.telefono!.isNotEmpty)
                            _infoRow(
                                'Teléfono', _clienteEncontrado!.telefono!),
                        ],
                      ),
                    ),
                  ],
                ],
              ],

              const SizedBox(height: 16),

              // ── Botones ──
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('CANCELAR',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _puedeFacturar
                          ? () => _onFacturar()
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF388E3C),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey.shade300,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('FACTURAR',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onFacturar() async {
    if (_fidelizar) {
      // Con fidelización → retornar cliente directamente
      Navigator.pop(context, _clienteEncontrado);
      return;
    }

    // Sin fidelización → mostrar advertencia animada
    final confirmar = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Cerrar',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 350),
      transitionBuilder: (ctx, anim, _, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim, curve: Curves.elasticOut),
          child: FadeTransition(opacity: anim, child: child),
        );
      },
      pageBuilder: (ctx, _, __) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 380,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black26,
                      blurRadius: 20,
                      offset: const Offset(0, 8)),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Ícono animado
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.bounceOut,
                    builder: (_, v, child) => Transform.scale(
                        scale: v, child: child),
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.warning_amber_rounded,
                          size: 42, color: Colors.orange.shade700),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'SIN FIDELIZACIÓN',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFE65100)),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'La factura se generará como\nCONSUMIDOR FINAL\n\n'
                    'El cliente NO acumulará puntos.\n¿Desea continuar?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 14, color: Colors.grey.shade700, height: 1.4),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          style: OutlinedButton.styleFrom(
                            padding:
                                const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('VOLVER',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange.shade700,
                            foregroundColor: Colors.white,
                            padding:
                                const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('SÍ, CONTINUAR',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (confirmar == true && mounted) {
      Navigator.pop(context, ClienteConsulta.consumidorFinal(''));
    }
  }

  /// Se puede facturar si:
  /// - No fideliza (consumidor final) → siempre
  /// - Fideliza → debe haber consultado al cliente
  bool get _puedeFacturar {
    if (!_fidelizar) return true;
    return _clienteEncontrado != null;
  }

  Widget _buildTecladoNumerico() {
    const teclas = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['C', '0', '<'],
    ];

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: teclas.map((fila) {
          return Row(
            children: fila.map((tecla) {
              final esAccion = tecla == 'C' || tecla == '<';
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: SizedBox(
                    height: 44,
                    child: ElevatedButton(
                      onPressed: () {
                        if (tecla == 'C') {
                          _limpiar();
                        } else if (tecla == '<') {
                          _borrar();
                          setState(() {});
                        } else {
                          _teclaNumero(tecla);
                          setState(() {});
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: esAccion
                            ? (tecla == 'C'
                                ? Colors.red.shade400
                                : Colors.orange.shade400)
                            : Colors.white,
                        foregroundColor:
                            esAccion ? Colors.white : Colors.black87,
                        elevation: 1,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: tecla == '<'
                          ? const Icon(Icons.backspace_outlined, size: 20)
                          : Text(tecla,
                              style: TextStyle(
                                  fontSize: esAccion ? 14 : 18,
                                  fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              );
            }).toList(),
          );
        }).toList(),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text('$label:',
                style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
