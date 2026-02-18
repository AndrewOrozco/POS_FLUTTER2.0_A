import 'package:flutter/material.dart';
import '../../../../core/services/api_consultas_service.dart';
import '../../../../core/models/api_models.dart';
import '../../../../core/widgets/teclado_tactil.dart';

/// Página Enviar Pago GoPass - Wizard multi-paso
///
/// Paso 1: Seleccionar venta
/// Paso 2: Seleccionar placa + validar 3 dígitos
/// Paso 3: Confirmar y procesar pago
/// Paso 4: Resultado
class GopassEnviarPagoPage extends StatefulWidget {
  const GopassEnviarPagoPage({super.key});

  @override
  State<GopassEnviarPagoPage> createState() => _GopassEnviarPagoPageState();
}

class _GopassEnviarPagoPageState extends State<GopassEnviarPagoPage> {
  final ApiConsultasService _apiService = ApiConsultasService();
  final TextEditingController _digitosController = TextEditingController();

  int _paso = 0;
  bool _cargando = false;
  String? _error;

  // Paso 1: Ventas
  List<VentaGopass> _ventas = [];
  VentaGopass? _ventaSeleccionada;

  // Paso 2: Placas
  List<PlacaGopass> _placas = [];
  PlacaGopass? _placaSeleccionada;
  bool _placaValidada = false;
  String? _errorValidacion;

  // Paso 3-4: Pago
  bool _procesando = false;
  Map<String, dynamic>? _resultadoPago;

  @override
  void initState() {
    super.initState();
    _digitosController.addListener(() => setState(() {}));
    _cargarVentas();
  }

  @override
  void dispose() {
    _digitosController.dispose();
    super.dispose();
  }

  Future<void> _cargarVentas() async {
    setState(() { _cargando = true; _error = null; });
    try {
      _ventas = await _apiService.obtenerVentasGopass();
      setState(() => _cargando = false);
    } catch (e) {
      setState(() { _error = 'Error: $e'; _cargando = false; });
    }
  }

  Future<void> _consultarPlacas() async {
    if (_ventaSeleccionada == null) return;
    setState(() { _cargando = true; _error = null; _paso = 1; });
    try {
      _placas = await _apiService.consultarPlacasGopass(_ventaSeleccionada!.id);
      if (_placas.isEmpty) {
        setState(() { _error = 'No se encontraron placas GoPass para esta venta'; _cargando = false; });
      } else {
        setState(() => _cargando = false);
      }
    } catch (e) {
      setState(() { _error = 'Error consultando placas: $e'; _cargando = false; });
    }
  }

  void _seleccionarPlaca(PlacaGopass placa) {
    setState(() {
      _placaSeleccionada = placa;
      _placaValidada = false;
      _errorValidacion = null;
      _digitosController.clear();
    });
  }

  void _validarPlaca() {
    if (_placaSeleccionada == null) return;
    final digitos = _digitosController.text.trim();
    if (digitos.length < 3) {
      setState(() => _errorValidacion = 'Ingrese al menos 3 dígitos');
      return;
    }
    if (_placaSeleccionada!.validarDigitos(digitos)) {
      setState(() {
        _placaValidada = true;
        _errorValidacion = null;
        _paso = 2;
      });
    } else {
      setState(() => _errorValidacion = 'Los dígitos no coinciden con la placa');
    }
  }

  Future<void> _procesarPago() async {
    if (_ventaSeleccionada == null || _placaSeleccionada == null) return;
    setState(() { _procesando = true; _paso = 3; });
    try {
      final resultado = await _apiService.procesarPagoGopass(
        ventaId: _ventaSeleccionada!.id,
        placa: _placaSeleccionada!.placa,
        tagGopass: _placaSeleccionada!.tagGopass,
        nombreUsuario: _placaSeleccionada!.nombreUsuario,
      );
      setState(() { _resultadoPago = resultado; _procesando = false; });
    } catch (e) {
      setState(() {
        _resultadoPago = {'exito': false, 'mensaje': 'Error: $e'};
        _procesando = false;
      });
    }
  }

  void _reiniciar() {
    setState(() {
      _paso = 0;
      _ventaSeleccionada = null;
      _placaSeleccionada = null;
      _placaValidada = false;
      _placas = [];
      _resultadoPago = null;
      _digitosController.clear();
      _error = null;
      _errorValidacion = null;
    });
    _cargarVentas();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titulosPaso[_paso.clamp(0, 3)]),
        backgroundColor: const Color(0xFFB71C1C),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_paso > 0 && _paso < 3) {
              setState(() {
                _paso = _paso == 2 ? 1 : 0;
                if (_paso == 0) { _placas = []; _placaSeleccionada = null; }
              });
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _buildPasoActual(),
    );
  }

  static const _titulosPaso = [
    'GoPass - Seleccionar Venta',
    'GoPass - Seleccionar Placa',
    'GoPass - Confirmar Pago',
    'GoPass - Resultado',
  ];

  Widget _buildPasoActual() {
    if (_error != null && _paso < 3) {
      return _buildError();
    }
    switch (_paso) {
      case 0: return _buildPaso1Ventas();
      case 1: return _buildPaso2Placas();
      case 2: return _buildPaso3Confirmar();
      case 3: return _buildPaso4Resultado();
      default: return _buildPaso1Ventas();
    }
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(_error!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _paso == 0 ? _cargarVentas : () => setState(() { _error = null; _paso = 0; }),
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // PASO 1: Seleccionar Venta
  // ============================================================
  Widget _buildPaso1Ventas() {
    if (_ventas.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text('Sin ventas disponibles', style: TextStyle(fontSize: 18, color: Colors.grey.shade600)),
            const SizedBox(height: 8),
            Text('No hay ventas elegibles para GoPass', style: TextStyle(fontSize: 14, color: Colors.grey.shade400)),
            const SizedBox(height: 20),
            ElevatedButton.icon(onPressed: _cargarVentas, icon: const Icon(Icons.refresh), label: const Text('Actualizar')),
          ],
        ),
      );
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          color: const Color(0xFFF5F5F5),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: Color(0xFFB71C1C), size: 20),
              const SizedBox(width: 8),
              Text('${_ventas.length} ventas disponibles - Seleccione una', style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: _ventas.length,
            itemBuilder: (_, i) => _buildVentaCard(_ventas[i]),
          ),
        ),
      ],
    );
  }

  Widget _buildVentaCard(VentaGopass venta) {
    final sel = _ventaSeleccionada?.id == venta.id;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: sel ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: sel ? const Color(0xFFB71C1C) : Colors.grey.shade300, width: sel ? 2.5 : 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          setState(() => _ventaSeleccionada = venta);
          _consultarPlacas();
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 50, height: 50,
                decoration: BoxDecoration(color: const Color(0xFFFFEBEE), borderRadius: BorderRadius.circular(12)),
                child: Center(child: Text('C${venta.cara}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFFB71C1C)))),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(venta.descripcion, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15), overflow: TextOverflow.ellipsis)),
                        Text(venta.ventaTotalFormateada, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF2E7D32))),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('${venta.cantidad.toStringAsFixed(3)} GL × \$${venta.precioProducto.toInt()}', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                    Text(venta.fecha, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // PASO 2: Seleccionar Placa + Validar
  // ============================================================
  Widget _buildPaso2Placas() {
    return Column(
      children: [
        // Info de la venta seleccionada
        if (_ventaSeleccionada != null)
          Container(
            padding: const EdgeInsets.all(12),
            color: const Color(0xFFE8F5E9),
            child: Row(
              children: [
                const Icon(Icons.local_gas_station, color: Color(0xFF2E7D32)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Cara ${_ventaSeleccionada!.cara} - ${_ventaSeleccionada!.descripcion} - ${_ventaSeleccionada!.ventaTotalFormateada}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        // Lista de placas o validación
        if (_placaSeleccionada == null)
          Expanded(
            child: _placas.isEmpty
                ? const Center(child: Text('Sin placas GoPass', style: TextStyle(fontSize: 16, color: Colors.grey)))
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: _placas.length,
                    itemBuilder: (_, i) => _buildPlacaCard(_placas[i]),
                  ),
          )
        else
          Expanded(child: _buildValidacionPlaca()),
      ],
    );
  }

  Widget _buildPlacaCard(PlacaGopass placa) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.blue.shade200)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _seleccionarPlaca(placa),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 50, height: 50,
                decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.directions_car, color: Colors.blue, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(placa.placa, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    if (placa.nombreUsuario.isNotEmpty)
                      Text(placa.nombreUsuario, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildValidacionPlaca() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Placa seleccionada
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                children: [
                  const Icon(Icons.directions_car, size: 40, color: Colors.blue),
                  const SizedBox(height: 8),
                  Text(_placaSeleccionada!.placa, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 3)),
                  if (_placaSeleccionada!.nombreUsuario.isNotEmpty)
                    Text(_placaSeleccionada!.nombreUsuario, style: TextStyle(color: Colors.grey.shade600)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text('Ingrese los últimos 3 dígitos de la placa', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            // Campo de dígitos
            Container(
              width: 200,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _errorValidacion != null ? Colors.red : Colors.grey.shade300, width: 2),
              ),
              child: Center(
                child: Text(
                  _digitosController.text.isEmpty ? '_ _ _' : _digitosController.text,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 8,
                    color: _digitosController.text.isEmpty ? Colors.grey.shade300 : Colors.black,
                  ),
                ),
              ),
            ),
            if (_errorValidacion != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_errorValidacion!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
              ),
            const SizedBox(height: 12),
            // Botones
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: () => setState(() { _placaSeleccionada = null; _digitosController.clear(); }),
                  child: const Text('Cambiar placa'),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _digitosController.text.length >= 3 ? _validarPlaca : null,
                  icon: const Icon(Icons.check),
                  label: const Text('VALIDAR'),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32), foregroundColor: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: 350,
              child: TecladoTactil(
                controller: _digitosController,
                soloNumeros: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // PASO 3: Confirmar Pago
  // ============================================================
  Widget _buildPaso3Confirmar() {
    if (_procesando) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: 80, height: 80, child: CircularProgressIndicator(strokeWidth: 6, color: Color(0xFFB71C1C))),
            const SizedBox(height: 24),
            const Text('Procesando pago GoPass...', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Esto puede tomar unos segundos', style: TextStyle(color: Colors.grey.shade600)),
          ],
        ),
      );
    }

    // Si ya hay resultado, ir a paso 4
    if (_resultadoPago != null) return _buildPaso4Resultado();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Resumen
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 10, offset: const Offset(0, 4))],
              border: Border.all(color: const Color(0xFFB71C1C), width: 2),
            ),
            child: Column(
              children: [
                const Icon(Icons.credit_card, size: 48, color: Color(0xFF2E7D32)),
                const SizedBox(height: 16),
                const Text('Confirmar Pago GoPass', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const Divider(height: 32),
                _resumenRow('Producto', _ventaSeleccionada?.descripcion ?? ''),
                _resumenRow('Cara', _ventaSeleccionada?.cara ?? ''),
                _resumenRow('Total', _ventaSeleccionada?.ventaTotalFormateada ?? ''),
                _resumenRow('Placa', _placaSeleccionada?.placa ?? ''),
                if (_placaSeleccionada?.nombreUsuario.isNotEmpty == true)
                  _resumenRow('Cliente', _placaSeleccionada!.nombreUsuario),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => setState(() { _paso = 1; _placaValidada = false; }),
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('VOLVER'),
                        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: _procesarPago,
                        icon: const Icon(Icons.send),
                        label: const Text('ENVIAR PAGO', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFB71C1C),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _resumenRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 100, child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15))),
        ],
      ),
    );
  }

  // ============================================================
  // PASO 4: Resultado
  // ============================================================
  Widget _buildPaso4Resultado() {
    if (_resultadoPago == null) return const SizedBox();

    final exito = _resultadoPago!['exito'] == true;
    final estado = _resultadoPago!['estado']?.toString() ?? '';
    final mensaje = _resultadoPago!['mensaje']?.toString() ?? '';

    final Color color;
    final IconData icon;
    if (exito && estado == 'APROBADO') {
      color = Colors.green;
      icon = Icons.check_circle;
    } else if (estado == 'PENDIENTE') {
      color = Colors.orange;
      icon = Icons.hourglass_top;
    } else {
      color = Colors.red;
      icon = Icons.cancel;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 100, color: color),
            const SizedBox(height: 20),
            Text(
              estado.isNotEmpty ? estado : (exito ? 'ÉXITO' : 'ERROR'),
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(mensaje, textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: color.shade700)),
            ),
            const SizedBox(height: 32),
            if (exito && estado == 'APROBADO')
              ElevatedButton.icon(
                onPressed: () {
                  _apiService.imprimirGopass(movimientoId: _ventaSeleccionada!.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Impresión enviada'), backgroundColor: Colors.green),
                  );
                },
                icon: const Icon(Icons.print),
                label: const Text('IMPRIMIR'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFB71C1C),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                ),
              ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _reiniciar,
              icon: const Icon(Icons.refresh),
              label: const Text('NUEVA OPERACIÓN'),
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14)),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('VOLVER AL MENÚ'),
            ),
          ],
        ),
      ),
    );
  }
}

extension on Color {
  Color get shade700 {
    final hsl = HSLColor.fromColor(this);
    return hsl.withLightness((hsl.lightness * 0.7).clamp(0.0, 1.0)).toColor();
  }
}
