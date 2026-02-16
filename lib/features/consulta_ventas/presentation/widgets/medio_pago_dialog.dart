import 'package:flutter/material.dart';
import '../../../../core/services/api_consultas_service.dart';
import '../../../../core/services/lazo_express_api_service.dart';
import '../../../../core/widgets/teclado_tactil.dart';
import 'medio_pago_item.dart';

// ============================================================
// DIÁLOGO DE MEDIO DE PAGO
// ============================================================
// Permite agregar uno o más medios de pago (pagos mixtos) a una
// venta sin resolver. Incluye teclado táctil, dropdown de medios,
// tabla de medios agregados y campo de voucher.
// ============================================================

class MedioPagoDialog extends StatefulWidget {
  final VentaSinResolver venta;
  final LazoExpressApiService lazoService;
  final ApiConsultasService apiService;

  const MedioPagoDialog({
    super.key,
    required this.venta,
    required this.lazoService,
    required this.apiService,
  });

  @override
  State<MedioPagoDialog> createState() => _MedioPagoDialogState();
}

class _MedioPagoDialogState extends State<MedioPagoDialog> {
  List<MedioPagoConsulta> _mediosPago = [];
  MedioPagoConsulta? _medioSeleccionado;
  bool _isLoading = true;
  bool _guardando = false;
  int? _identificadorEquipo;
  
  final TextEditingController _valorController = TextEditingController();
  final TextEditingController _voucherController = TextEditingController();
  
  final List<MedioPagoItemConsulta> _mediosAgregados = [];
  
  double get _totalVenta => widget.venta.total.toDouble();
  
  double get _totalRecibido {
    double total = 0;
    for (var item in _mediosAgregados) {
      total += item.valor;
    }
    return total;
  }
  
  double get _pendiente => _totalVenta - _totalRecibido;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
    _valorController.text = _totalVenta.toStringAsFixed(0);
  }
  
  Future<void> _cargarDatos() async {
    await Future.wait([
      _cargarMediosPago(),
      _cargarIdentificadorEquipo(),
    ]);
  }
  
  Future<void> _cargarIdentificadorEquipo() async {
    _identificadorEquipo = await widget.lazoService.getIdentificadorEquipo();
    debugPrint('[MedioPago] Identificador equipo: $_identificadorEquipo');
  }
  
  @override
  void dispose() {
    _valorController.dispose();
    _voucherController.dispose();
    super.dispose();
  }

  // ============================================================
  // Carga de medios de pago
  // ============================================================

  Future<void> _cargarMediosPago() async {
    try {
      final medios = await widget.apiService.getMediosPago(traerEfectivo: false);
      
      // Filtrar GOPASS y APP TERPEL de este diálogo rápido.
      // - GOPASS: solo desde Status Pump
      // - APP TERPEL: usar "Asignar Datos" (wizard) que tiene flujo especial
      //   (marca pendiente + envía al orquestador, sin gestionar la venta)
      final mediosFiltrados = medios.where((m) {
        final nombre = m.nombre.toUpperCase();
        return !nombre.contains('GOPASS') && !nombre.contains('APP TERPEL') && !nombre.contains('APPTERPEL');
      }).toList();
      
      setState(() {
        _mediosPago = mediosFiltrados;
        _medioSeleccionado = mediosFiltrados.isNotEmpty ? mediosFiltrados.first : null;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('[MedioPago] Error cargando medios: $e');
      setState(() => _isLoading = false);
    }
  }

  // ============================================================
  // Agregar / quitar medios
  // ============================================================

  void _agregarMedio() {
    if (_medioSeleccionado == null) return;
    
    final valor = double.tryParse(_valorController.text) ?? 0;
    if (valor <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingrese un valor válido'), backgroundColor: Colors.orange),
      );
      return;
    }
    
    setState(() {
      _mediosAgregados.add(MedioPagoItemConsulta(
        medio: _medioSeleccionado!,
        valor: valor,
        voucher: _voucherController.text,
      ));
      _voucherController.clear();
      _valorController.text = _pendiente > 0 ? _pendiente.toStringAsFixed(0) : '0';
    });
  }
  
  void _quitarMedio(int index) {
    setState(() {
      _mediosAgregados.removeAt(index);
      _valorController.text = _pendiente > 0 ? _pendiente.toStringAsFixed(0) : '0';
    });
  }
  
  void _quitarTodos() {
    setState(() {
      _mediosAgregados.clear();
      _valorController.text = _totalVenta.toStringAsFixed(0);
    });
  }

  // ============================================================
  // Guardar
  // ============================================================

  Future<void> _guardarMediosPago() async {
    if (_mediosAgregados.isEmpty) {
      _agregarMedio();
      if (_mediosAgregados.isEmpty) return;
    }
    
    if (_pendiente > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Falta pagar: \$${_pendiente.toStringAsFixed(0)}'), backgroundColor: Colors.orange),
      );
      return;
    }
    
    if (_identificadorEquipo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: No se pudo obtener identificador de equipo'), backgroundColor: Colors.red),
      );
      return;
    }
    
    setState(() => _guardando = true);
    
    try {
      final List<MedioPagoVenta> mediosVenta = _mediosAgregados.map((item) => MedioPagoVenta(
        ctMediosPagosId: item.medio.id,
        valorTotal: item.valor,
        valorRecibido: item.valor,
        valorCambio: 0,
        codigoDian: item.medio.codigoDian,
      )).toList();
      
      final response = await widget.lazoService.actualizarMediosPago(
        identificadorMovimiento: widget.venta.id,
        mediosPagos: mediosVenta,
        identificadorEquipo: _identificadorEquipo!,
      );
      
      if (!mounted) return;
      
      if (response.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(children: [Icon(Icons.check_circle, color: Colors.white), SizedBox(width: 12), Text('Medios de pago guardados')]),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      } else {
        setState(() => _guardando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response.message), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      setState(() => _guardando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        width: 800,
        constraints: const BoxConstraints(maxHeight: 650),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            Flexible(child: _isLoading ? const Center(child: CircularProgressIndicator()) : _buildContent()),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFFBA0C2F),
        borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.payment, color: Colors.white, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('MEDIO DE PAGO', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                Text('Venta #${widget.venta.id} - ${widget.venta.producto}', style: TextStyle(color: Colors.white.withAlpha(200), fontSize: 13)),
              ],
            ),
          ),
          IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context, false)),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTotales(),
                const SizedBox(height: 16),
                _buildTablaMedios(),
              ],
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 320,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDropdownMedio(),
                const SizedBox(height: 12),
                if (_medioSeleccionado?.requiereVoucher == true) ...[_buildCampoVoucher(), const SizedBox(height: 12)],
                _buildCampoValor(),
                const SizedBox(height: 12),
                TecladoTactil(controller: _valorController, soloNumeros: true, height: 320, onAceptar: _agregarMedio),
                const SizedBox(height: 12),
                _buildBotonAgregar(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // Sub-widgets
  // ============================================================

  Widget _buildTotales() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
      child: Column(children: [
        _buildFilaTotal('TOTAL:', _totalVenta, Colors.black),
        const Divider(),
        _buildFilaTotal('RECIBIDO:', _totalRecibido, Colors.green.shade700),
        if (_pendiente > 0) ...[const Divider(), _buildFilaTotal('PENDIENTE:', _pendiente, Colors.orange.shade700)],
        if (_pendiente < 0) ...[const Divider(), _buildFilaTotal('CAMBIO:', _pendiente.abs(), Colors.blue.shade700)],
      ]),
    );
  }
  
  Widget _buildFilaTotal(String label, double valor, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        Text('\$ ${valor.toStringAsFixed(0)}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _buildDropdownMedio() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('MEDIO PAGO:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade400)),
          child: DropdownButton<MedioPagoConsulta>(
            value: _medioSeleccionado,
            isExpanded: true,
            underline: const SizedBox(),
            items: _mediosPago.map((medio) => DropdownMenuItem(
              value: medio,
              child: Row(children: [
                Icon(_getIconoMedioPago(medio.nombre), size: 20, color: Colors.grey.shade700),
                const SizedBox(width: 8),
                Text(medio.nombre),
              ]),
            )).toList(),
            onChanged: (medio) => setState(() => _medioSeleccionado = medio),
          ),
        ),
      ],
    );
  }

  Widget _buildCampoVoucher() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('NÚMERO DE VOUCHER:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        const SizedBox(height: 6),
        TextField(
          controller: _voucherController,
          decoration: InputDecoration(
            hintText: 'Ingrese número de voucher',
            prefixIcon: const Icon(Icons.receipt),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildCampoValor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('VALOR:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        const SizedBox(height: 6),
        TextField(
          controller: _valorController,
          readOnly: true,
          textAlign: TextAlign.right,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            prefixText: '\$ ',
            prefixStyle: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            filled: true,
            fillColor: Colors.grey.shade100,
          ),
        ),
      ],
    );
  }

  Widget _buildBotonAgregar() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _agregarMedio,
        icon: const Icon(Icons.add),
        label: const Text('AGREGAR MEDIO'),
        style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
      ),
    );
  }

  Widget _buildTablaMedios() {
    return Container(
      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: const BoxDecoration(color: Color(0xFFBA0C2F), borderRadius: BorderRadius.vertical(top: Radius.circular(7))),
          child: const Row(children: [
            Expanded(flex: 3, child: Text('MEDIO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
            Expanded(flex: 2, child: Text('VOUCHER', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
            Expanded(flex: 2, child: Text('VALOR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
            SizedBox(width: 40),
          ]),
        ),
        if (_mediosAgregados.isEmpty)
          const Padding(padding: EdgeInsets.all(20), child: Text('No hay medios agregados', style: TextStyle(color: Colors.grey)))
        else
          ..._mediosAgregados.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: index % 2 == 0 ? Colors.white : Colors.grey.shade50),
              child: Row(children: [
                Expanded(flex: 3, child: Text(item.medio.nombre)),
                Expanded(flex: 2, child: Text(item.voucher.isNotEmpty ? item.voucher : '-')),
                Expanded(flex: 2, child: Text('\$ ${item.valor.toStringAsFixed(0)}', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold))),
                SizedBox(width: 40, child: IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 20), onPressed: () => _quitarMedio(index), padding: EdgeInsets.zero)),
              ]),
            );
          }),
      ]),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: const BorderRadius.vertical(bottom: Radius.circular(4))),
      child: Row(children: [
        OutlinedButton.icon(
          onPressed: _mediosAgregados.isNotEmpty ? _quitarTodos : null,
          icon: const Icon(Icons.clear_all),
          label: const Text('QUITAR TODOS'),
          style: OutlinedButton.styleFrom(foregroundColor: Colors.grey.shade700),
        ),
        const Spacer(),
        TextButton(onPressed: _guardando ? null : () => Navigator.pop(context, false), child: const Text('Cancelar')),
        const SizedBox(width: 12),
        ElevatedButton.icon(
          onPressed: _guardando ? null : _guardarMediosPago,
          icon: _guardando
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.save),
          label: Text(_guardando ? 'GUARDANDO...' : 'GUARDAR'),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFBA0C2F), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14)),
        ),
      ]),
    );
  }

  // ============================================================
  // Utilidades
  // ============================================================

  IconData _getIconoMedioPago(String nombre) {
    final nombreLower = nombre.toLowerCase();
    if (nombreLower.contains('efectivo')) return Icons.money;
    if (nombreLower.contains('tarjeta') || nombreLower.contains('debito') || nombreLower.contains('credito')) return Icons.credit_card;
    if (nombreLower.contains('transfer') || nombreLower.contains('nequi') || nombreLower.contains('daviplata')) return Icons.phone_android;
    if (nombreLower.contains('app') || nombreLower.contains('terpel')) return Icons.phone_iphone;
    if (nombreLower.contains('flota')) return Icons.business;
    return Icons.payment;
  }
}
