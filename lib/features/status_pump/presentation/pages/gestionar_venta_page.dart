import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/api_consultas_service.dart';
import '../../../../core/services/lazo_express_api_service.dart';
import '../../../../core/widgets/teclado_tactil.dart';
import '../../domain/entities/surtidor_estado.dart';

/// Pantalla "DATOS FACTURA" para gestionar una venta activa desde la bomba.
///
/// Layout:
///   ┌─────────────────────────────────────────────┐
///   │  HEADER (DATOS FACTURA + info venta)         │
///   ├─────────────────────────────────────────────┤
///   │  Identificación  |  Tipo doc dropdown        │
///   │  Placa           |  Kilometraje     | ▶      │
///   │  [Nombre cliente resultado]                  │
///   │  [Fidelización]  |  [Facturación Electrónica]│
///   ├─────────────────────────────────────────────┤
///   │  TECLADO COMPLETO (abajo, ancho completo)    │
///   ├─────────────────────────────────────────────┤
///   │  CANCELAR    CONSULTAR    GUARDAR             │
///   └─────────────────────────────────────────────┘
class GestionarVentaPage extends StatefulWidget {
  final SurtidorEstado surtidor;

  const GestionarVentaPage({super.key, required this.surtidor});

  @override
  State<GestionarVentaPage> createState() => _GestionarVentaPageState();
}

class _GestionarVentaPageState extends State<GestionarVentaPage> {
  final ApiConsultasService _apiService = ApiConsultasService();
  final LazoExpressApiService _lazoService = LazoExpressApiService();

  // Estado
  bool _cargando = true;
  bool _guardando = false;
  bool _consultandoCliente = false;
  String? _error;

  // Venta activa
  VentaActivaCara? _ventaActiva;
  int? _identificadorEquipo;

  // Controllers
  final _identificacionController = TextEditingController();
  final _placaController = TextEditingController();
  final _kilometrajeController = TextEditingController();

  // Campo activo para el teclado
  _CampoInfo _campoActivo = _CampoInfo.identificacion;

  // Cliente
  List<TipoIdentificacion> _tiposIdentificacion = [];
  TipoIdentificacion? _tipoSeleccionado;
  ClienteConsulta? _clienteConsultado;
  String _nombreCliente = '';

  // Opciones
  bool _fidelizar = false;
  bool _facturacionElectronica = false;
  String _nombreAcumulador = '';
  String _nombreFE = '';

  /// Controller activo según campo seleccionado
  TextEditingController get _controllerActivo {
    switch (_campoActivo) {
      case _CampoInfo.identificacion:
        return _identificacionController;
      case _CampoInfo.placa:
        return _placaController;
      case _CampoInfo.kilometraje:
        return _kilometrajeController;
    }
  }

  /// Si el campo activo solo acepta números
  bool get _campoActivoSoloNumeros {
    switch (_campoActivo) {
      case _CampoInfo.identificacion:
        // Solo números para CC, NIT. Alfanumérico para cédula extranjería
        return _tipoSeleccionado?.caracteresPermitidos.contains('A') != true;
      case _CampoInfo.placa:
        return false; // Placa es alfanumérica
      case _CampoInfo.kilometraje:
        return true; // Kilometraje solo números
    }
  }

  Color get _productoColor {
    final producto = widget.surtidor.producto.toUpperCase();
    // Extra / Premium → Azul (check BEFORE oxigenada!)
    if (producto.contains('EXTRA') || producto.contains('PREMIUM') || producto.contains('SUPER')) {
      return const Color(0xFF1E88E5);
    }
    // Corriente / Regular → Rojo
    if (producto.contains('CORRIENTE') || producto.contains('REGULAR') || producto.contains('OXIGENADA')) {
      return const Color(0xFFE53935);
    }
    if (producto.contains('DIESEL') || producto.contains('ACPM') || producto.contains('BIODIESEL')) {
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

  @override
  void initState() {
    super.initState();
    // Listeners para actualizar UI en tiempo real cuando el teclado modifica el controller
    _identificacionController.addListener(_onControllerChanged);
    _placaController.addListener(_onControllerChanged);
    _kilometrajeController.addListener(_onControllerChanged);
    _cargarDatos();
  }

  void _onControllerChanged() {
    // Rebuild para que los TextField muestren el texto en tiempo real
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _identificacionController.removeListener(_onControllerChanged);
    _placaController.removeListener(_onControllerChanged);
    _kilometrajeController.removeListener(_onControllerChanged);
    _identificacionController.dispose();
    _placaController.dispose();
    _kilometrajeController.dispose();
    super.dispose();
  }

  // ============================================================
  // CARGA INICIAL
  // ============================================================

  Future<void> _cargarDatos() async {
    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _apiService.getVentaActivaPorCara(widget.surtidor.cara),
        _apiService.getTiposIdentificacion(),
        _lazoService.getIdentificadorEquipo(),
      ]);

      final ventaActiva = results[0] as VentaActivaCara;
      final tipos = results[1] as List<TipoIdentificacion>;
      final equipoId = results[2] as int?;

      if (!ventaActiva.found || ventaActiva.movimientoId == null) {
        setState(() {
          _cargando = false;
          _error = 'No se encontró una venta activa para la cara ${widget.surtidor.cara}.\n'
              'Es posible que la venta aún no se haya registrado en el sistema.';
        });
        return;
      }

      final tipoDefault = tipos.firstWhere(
        (t) => t.esConsumidorFinal,
        orElse: () => tipos.firstWhere(
          (t) => t.nombre.toLowerCase().contains('cedula'),
          orElse: () => tipos.first,
        ),
      );

      setState(() {
        _ventaActiva = ventaActiva;
        _tiposIdentificacion = tipos;
        _tipoSeleccionado = tipoDefault;
        _identificadorEquipo = equipoId;
        _cargando = false;

        if (tipoDefault.esConsumidorFinal) {
          _identificacionController.text = tipoDefault.identificacionDefecto;
          _nombreCliente = 'CONSUMIDOR FINAL';
        }

        if (widget.surtidor.placa != null && widget.surtidor.placa!.isNotEmpty) {
          _placaController.text = widget.surtidor.placa!;
        }
      });
    } catch (e) {
      setState(() {
        _cargando = false;
        _error = 'Error cargando datos: $e';
      });
    }
  }

  // ============================================================
  // ACCIONES
  // ============================================================

  void _onTipoDocumentoChanged(TipoIdentificacion? tipo) {
    setState(() {
      _tipoSeleccionado = tipo;
      _clienteConsultado = null;
      _nombreAcumulador = '';
      _nombreFE = '';
      _fidelizar = false;
      _facturacionElectronica = false;
      if (tipo?.esConsumidorFinal == true) {
        _identificacionController.text = tipo!.identificacionDefecto;
        _nombreCliente = 'CONSUMIDOR FINAL';
      } else {
        _identificacionController.clear();
        _nombreCliente = '';
      }
    });
  }

  Future<void> _consultarCliente() async {
    final identificacion = _identificacionController.text.trim();
    if (identificacion.isEmpty) {
      _mostrarSnackBar('Ingrese una identificación', Colors.orange);
      return;
    }

    setState(() => _consultandoCliente = true);

    try {
      final tipoDoc = _tipoSeleccionado?.codigo ?? 13;
      final cliente = await _apiService.consultarCliente(identificacion, tipoDocumento: tipoDoc);

      setState(() {
        _consultandoCliente = false;
        _clienteConsultado = cliente;
        _nombreCliente = cliente.nombre;
        if (cliente.encontrado && !cliente.esConsumidorFinal) {
          _fidelizar = true;
          _facturacionElectronica = true;
          _nombreAcumulador = cliente.nombre;
          _nombreFE = cliente.nombre;
        } else {
          _fidelizar = false;
          _facturacionElectronica = false;
          _nombreAcumulador = '';
          _nombreFE = '';
        }
      });
    } catch (e) {
      setState(() => _consultandoCliente = false);
      _mostrarSnackBar('Error consultando cliente: $e', Colors.red);
    }
  }

  Future<void> _guardarDatos() async {
    setState(() => _guardando = true);

    try {
      // Construir factura_electronica con datos completos de Terpel
      // Java: SurtidorDao.updateVentasEncurso(recibo, datos, FACTURA_ELECTRONICA)
      Map<String, dynamic>? facturaElectronica;

      if (_clienteConsultado?.rawResponse != null) {
        // Usar la respuesta COMPLETA del servicio Terpel (incluye extraData)
        facturaElectronica = Map<String, dynamic>.from(_clienteConsultado!.rawResponse!);
      } else if (_facturacionElectronica || _fidelizar) {
        // Sin datos Terpel, construir objeto mínimo
        facturaElectronica = {
          'numeroDocumento': _identificacionController.text.trim().isNotEmpty
              ? _identificacionController.text.trim()
              : '222222222222',
          'nombreComercial': _nombreCliente.isNotEmpty ? _nombreCliente : 'CONSUMIDOR FINAL',
          'nombreRazonSocial': _nombreCliente.isNotEmpty ? _nombreCliente : 'CONSUMIDOR FINAL',
        };
      }

      // Guardar en ventas_curso (NO en ct_movimientos)
      // Esto replica el flujo de Java: SurtidorDao.generarDatosSurtidorVentasCurso
      final response = await _apiService.guardarDatosFacturaVentasCurso(
        cara: widget.surtidor.cara,
        facturaElectronica: facturaElectronica,
        tipoDocumento: _tipoSeleccionado?.codigo,
        identificacionCliente: _identificacionController.text.trim().isNotEmpty
            ? _identificacionController.text.trim()
            : null,
        nombreCliente: _nombreCliente.isNotEmpty ? _nombreCliente : null,
        placa: _placaController.text.trim().isNotEmpty ? _placaController.text.trim().toUpperCase() : null,
        odometro: _kilometrajeController.text.trim().isNotEmpty ? _kilometrajeController.text.trim() : null,
        fidelizar: _fidelizar,
        facturacionElectronica: _facturacionElectronica,
      );

      if (!mounted) return;

      if (response.success) {
        _mostrarSnackBar('Datos guardados correctamente', Colors.green);
        Navigator.pop(context, true);
      } else {
        setState(() => _guardando = false);
        _mostrarSnackBar(response.message, Colors.red);
      }
    } catch (e) {
      setState(() => _guardando = false);
      _mostrarSnackBar('Error guardando datos: $e', Colors.red);
    }
  }

  void _mostrarSnackBar(String mensaje, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: color),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : Column(
                  children: [
                    _buildHeader(),
                    Expanded(child: _buildFormulario()),
                    _buildTeclado(),
                    _buildFooter(),
                  ],
                ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      color: _productoColor,
      child: Row(
        children: [
          InkWell(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 16),
          const Text(
            'DATOS FACTURA',
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(30),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Cara ${widget.surtidor.cara} · ${widget.surtidor.producto.isNotEmpty ? widget.surtidor.producto : "COMBUSTIBLE"} · \$ ${_formatNumber(widget.surtidor.monto)}',
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // FORMULARIO (parte superior, scrollable)
  // ============================================================

  Widget _buildFormulario() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fila 1: Identificación + Tipo documento
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: _buildCampoTexto(
                  label: 'NÚMERO IDENTIFICACIÓN CLIENTE',
                  controller: _identificacionController,
                  hint: 'Número de documento',
                  campo: _CampoInfo.identificacion,
                  enabled: _tipoSeleccionado?.esConsumidorFinal != true,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('TIPOS DE DOCUMENTO',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _productoColor)),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      height: 52,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade400),
                      ),
                      child: DropdownButton<TipoIdentificacion>(
                        value: _tipoSeleccionado,
                        isExpanded: true,
                        underline: const SizedBox(),
                        style: const TextStyle(fontSize: 15, color: Colors.black),
                        items: _tiposIdentificacion.map((tipo) {
                          return DropdownMenuItem(
                            value: tipo,
                            child: Text(tipo.nombre.toUpperCase(), overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                        onChanged: _onTipoDocumentoChanged,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Fila 2: Placa + Kilometraje + Botón consultar
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                flex: 2,
                child: _buildCampoTexto(
                  label: 'INGRESE PLACA',
                  controller: _placaController,
                  hint: 'Ingrese placa',
                  campo: _CampoInfo.placa,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                flex: 2,
                child: _buildCampoTexto(
                  label: 'KILOMETRAJE',
                  controller: _kilometrajeController,
                  hint: 'Kilometraje',
                  campo: _CampoInfo.kilometraje,
                ),
              ),
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: SizedBox(
                  height: 52,
                  width: 52,
                  child: ElevatedButton(
                    onPressed: _consultandoCliente ? null : _consultarCliente,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _productoColor,
                      foregroundColor: Colors.white,
                      shape: const CircleBorder(),
                      padding: EdgeInsets.zero,
                    ),
                    child: _consultandoCliente
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.play_arrow, size: 30),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Nombre del cliente (resultado)
          if (_nombreCliente.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _clienteConsultado != null && _clienteConsultado!.encontrado
                    ? Colors.green.shade50
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _clienteConsultado != null && _clienteConsultado!.encontrado
                      ? Colors.green.shade300
                      : Colors.grey.shade300,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _clienteConsultado != null && _clienteConsultado!.encontrado ? Icons.check_circle : Icons.person,
                    color: _clienteConsultado != null && _clienteConsultado!.encontrado ? Colors.green : Colors.grey,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _nombreCliente,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: _clienteConsultado != null && _clienteConsultado!.encontrado
                            ? Colors.green.shade800
                            : Colors.grey.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),

          // Opciones: Fidelización + FE
          Row(
            children: [
              Expanded(
                child: _buildOpcionCheck(
                  titulo: 'FIDELIZACIÓN',
                  subtitulo: _nombreAcumulador.isNotEmpty ? _nombreAcumulador : 'Club Terpel',
                  icon: Icons.card_giftcard,
                  valor: _fidelizar,
                  color: Colors.orange,
                  onChanged: (val) => setState(() => _fidelizar = val ?? false),
                  habilitado: _clienteConsultado != null &&
                      _clienteConsultado!.encontrado &&
                      !_clienteConsultado!.esConsumidorFinal,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildOpcionCheck(
                  titulo: 'FACTURACIÓN ELECTRÓNICA',
                  subtitulo: _nombreFE.isNotEmpty ? _nombreFE : (_nombreCliente.isNotEmpty ? _nombreCliente : 'Sin asignar'),
                  icon: Icons.receipt_long,
                  valor: _facturacionElectronica,
                  color: Colors.blue,
                  onChanged: (val) {
                    if (val == true) {
                      // Mostrar diálogo de confirmación al activar FE
                      showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          icon: const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 48),
                          title: const Text('¿Activar Facturación Electrónica?', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                          content: const Text(
                            'Al guardar con Facturación Electrónica, los datos del cliente y la venta no podrán ser modificados.\n\n¿Está seguro que desea continuar?',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 15),
                          ),
                          actionsAlignment: MainAxisAlignment.center,
                          actions: [
                            OutlinedButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.grey.shade700,
                                side: BorderSide(color: Colors.grey.shade400),
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              ),
                              child: const Text('Cancelar'),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              ),
                              child: const Text('Sí, activar FE'),
                            ),
                          ],
                        ),
                      ).then((confirmed) {
                        if (confirmed == true) {
                          setState(() => _facturacionElectronica = true);
                        }
                      });
                    } else {
                      setState(() => _facturacionElectronica = false);
                    }
                  },
                  habilitado: true, // FE siempre disponible, incluso para consumidor final
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CAMPO DE TEXTO con indicador de campo activo
  // ============================================================

  Widget _buildCampoTexto({
    required String label,
    required TextEditingController controller,
    required _CampoInfo campo,
    String hint = '',
    bool enabled = true,
  }) {
    final isActivo = _campoActivo == campo && enabled;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _productoColor)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: enabled ? () => setState(() => _campoActivo = campo) : null,
          child: AbsorbPointer(
            child: TextField(
              controller: controller,
              readOnly: true,
              style: const TextStyle(fontSize: 16),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(color: Colors.grey.shade400),
                filled: true,
                fillColor: enabled ? Colors.white : Colors.grey.shade200,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: isActivo ? _productoColor : Colors.grey.shade400, width: isActivo ? 2 : 1),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: isActivo ? _productoColor : Colors.grey.shade400, width: isActivo ? 2 : 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: _productoColor, width: 2),
                ),
                suffixIcon: isActivo ? Icon(Icons.keyboard, size: 18, color: _productoColor) : null,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // OPCIÓN CHECK (Fidelización / FE)
  // ============================================================

  Widget _buildOpcionCheck({
    required String titulo,
    required String subtitulo,
    required IconData icon,
    required bool valor,
    required Color color,
    required ValueChanged<bool?> onChanged,
    bool habilitado = true,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: valor && habilitado ? color.withAlpha(15) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: valor && habilitado ? color.withAlpha(100) : Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Icon(icon, color: habilitado ? (valor ? color : Colors.grey) : Colors.grey.shade400, size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: habilitado ? Colors.black : Colors.grey.shade500)),
                Text(subtitulo, style: TextStyle(fontSize: 11, color: Colors.grey.shade600), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Checkbox(
            value: valor && habilitado,
            onChanged: habilitado ? onChanged : null,
            activeColor: color,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TECLADO (abajo, ancho completo)
  // ============================================================

  Widget _buildTeclado() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: TecladoTactil(
        controller: _controllerActivo,
        soloNumeros: _campoActivoSoloNumeros,
        height: _campoActivoSoloNumeros ? 200 : 220,
        onAceptar: _consultarCliente,
      ),
    );
  }

  // ============================================================
  // FOOTER
  // ============================================================

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        children: [
          if (_ventaActiva != null) ...[
            Icon(Icons.receipt_long, size: 14, color: Colors.grey.shade500),
            const SizedBox(width: 4),
            Text('Mov. #${_ventaActiva!.movimientoId}', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
          ],
          const Spacer(),
          // CANCELAR
          SizedBox(
            height: 44,
            child: OutlinedButton(
              onPressed: _guardando ? null : () => Navigator.pop(context, false),
              style: OutlinedButton.styleFrom(
                foregroundColor: _productoColor,
                side: BorderSide(color: _productoColor),
                padding: const EdgeInsets.symmetric(horizontal: 28),
              ),
              child: const Text('CANCELAR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ),
          const SizedBox(width: 12),
          // CONSULTAR
          SizedBox(
            height: 44,
            child: ElevatedButton.icon(
              onPressed: _consultandoCliente ? null : _consultarCliente,
              icon: _consultandoCliente
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.search, size: 20),
              label: const Text('CONSULTAR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _productoColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 28),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // GUARDAR
          SizedBox(
            height: 44,
            child: ElevatedButton.icon(
              onPressed: _guardando ? null : _guardarDatos,
              icon: _guardando
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save, size: 20),
              label: Text(_guardando ? 'GUARDANDO...' : 'GUARDAR', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 28),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ERROR
  // ============================================================

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.orange.shade700),
            const SizedBox(height: 16),
            Text(_error!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, color: Colors.grey)),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('VOLVER'),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: _cargarDatos,
                  icon: const Icon(Icons.refresh),
                  label: const Text('REINTENTAR'),
                  style: ElevatedButton.styleFrom(backgroundColor: _productoColor, foregroundColor: Colors.white),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatNumber(double number) {
    final intVal = number.toInt();
    return intVal.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]}.',
    );
  }
}

/// Enum para identificar qué campo está activo
enum _CampoInfo {
  identificacion,
  placa,
  kilometraje,
}
