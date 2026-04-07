import 'package:flutter/material.dart';
import '../../../../core/services/api_consultas_service.dart';
import '../../../../core/services/lazo_express_api_service.dart';
import '../../../../core/widgets/teclado_tactil.dart';
import '../../../home/presentation/widgets/medios_pago_bottom_sheet.dart' show AppTerpelCountdownDialog;
import 'medio_pago_item.dart';

// ============================================================
// WIZARD ASIGNAR DATOS
// ============================================================
// Widget con 4 pasos para asignar datos a una venta sin resolver:
//   1. Vehículo (placa, odómetro, orden)
//   2. Cliente (tipo doc, identificación, nombre, crédito)
//   3. Medio de Pago (agregar medios, teclado táctil)
//   4. Confirmar (resumen de todos los datos)
//
// Si el medio viene pre-asignado como GOPASS/APP TERPEL,
// el paso 3 se salta automáticamente.
// ============================================================

class AsignarDatosWizard extends StatefulWidget {
  final VentaSinResolver venta;
  final LazoExpressApiService lazoService;
  final int identificadorEquipo;
  final VoidCallback onComplete;

  const AsignarDatosWizard({
    super.key,
    required this.venta,
    required this.lazoService,
    required this.identificadorEquipo,
    required this.onComplete,
  });

  @override
  State<AsignarDatosWizard> createState() => _AsignarDatosWizardState();
}

class _AsignarDatosWizardState extends State<AsignarDatosWizard> {
  int _currentStep = 0;
  bool _isLoading = false;
  bool _consultandoCliente = false;
  bool _yaGuardado = false;
  bool _clientePrecargado = false;
  
  // Controladores
  final _placaController = TextEditingController();
  final _odometroController = TextEditingController();
  final _nombreController = TextEditingController();
  final _identificacionController = TextEditingController();
  final _ordenController = TextEditingController();
  
  // Opciones
  bool _imprimirFactura = true;
  
  // Cliente
  final ApiConsultasService _apiService = ApiConsultasService();
  List<TipoIdentificacion> _tiposIdentificacion = [];
  TipoIdentificacion? _tipoSeleccionado;
  ClienteConsulta? _clienteConsultado;
  
  // Medio de Pago
  final _valorPagoController = TextEditingController();
  final _voucherController = TextEditingController();
  List<MedioPagoConsulta> _mediosPago = [];
  MedioPagoConsulta? _medioSeleccionado;
  final List<MedioPagoItemConsulta> _mediosAgregados = [];

  // ============================================================
  // Getters y validaciones
  // ============================================================

  /// Solo se salta el paso de Pago para medios especiales (GOPASS, APP TERPEL)
  ///  /// EXCEPTO si GoPass o AppTerpel fueron rechazados.
  bool get _saltarPasoPago {
    if (_mediosAgregados.isEmpty || _pendientePago > 0) return false;
    if (_gopassRechazado || _appTerpelRechazado) return false;
    return _mediosAgregados.every((m) {
      final nombre = m.medio.nombre.toUpperCase();
      return _esGoPass(nombre) || nombre.contains('APP TERPEL') || nombre.contains('APPTERPEL');
    });
  }
  
  double get _totalVenta => widget.venta.total.toDouble();
  
  double get _totalRecibido {
    double total = 0;
    for (var item in _mediosAgregados) {
      total += item.valor;
    }
    return total;
  }
  
  double get _pendientePago => _totalVenta - _totalRecibido;
  
  bool _puedeAvanzar() {
    switch (_currentStep) {
      case 0: return true;
      case 1: return _clienteConsultado != null;
      case 2: return true;
      default: return true;
    }
  }
  
  String _getMensajeBotonSiguiente() {
    if (_currentStep == 1 && _clienteConsultado == null) return 'Consulte cliente primero';
    return 'Siguiente';
  }

  // ============================================================
  // Lifecycle
  // ============================================================

  @override
  void initState() {
    super.initState();
    _placaController.text = widget.venta.placa ?? '';
    _valorPagoController.text = widget.venta.total.toString();
    _cargarTiposIdentificacion();
    _inicializarMediosPago();
  }

  /// Primero verifica si APP TERPEL o GOPASS fue rechazado, luego carga medios
  Future<void> _inicializarMediosPago() async {
    await _verificarGoPassRechazado();
    await _verificarAppTerpelRechazado();
    await _cargarMediosPago();
    await _cargarMediosPagoExistentes();
  }
  
  @override
  void dispose() {
    _placaController.dispose();
    _odometroController.dispose();
    _nombreController.dispose();
    _identificacionController.dispose();
    _ordenController.dispose();
    _valorPagoController.dispose();
    _voucherController.dispose();
    super.dispose();
  }

  // ============================================================
  // Carga de datos
  // ============================================================

  bool _appTerpelRechazado = false;
  bool _gopassRechazado = false;

  /// Helper para verificar si un nombre es GoPass (con o sin espacio)
  bool _esGoPass(String nombre) {
    final upper = nombre.toUpperCase();
    return upper.contains('GOPASS') || upper.contains('GO PASS');
  }

  /// Verifica si GoPass fue rechazado revisando si tiene medio GOPASS pre-asignado.
  /// Si la venta aparece en 'sin resolver' con medio GOPASS, fue rechazado.
  Future<void> _verificarGoPassRechazado() async {
    try {
      final mediosExistentes = await _apiService.getMediosPagoVenta(widget.venta.id);
      final tieneGopass = mediosExistentes.any((m) => _esGoPass(m.nombre));
      if (tieneGopass) {
        _gopassRechazado = true;
        debugPrint('[AsignarDatos] GOPASS fue rechazado para venta ${widget.venta.id}');
      }
    } catch (e) {
      debugPrint('[AsignarDatos] Error verificando GoPass: $e');
    }
  }

  Future<void> _verificarAppTerpelRechazado() async {
    try {
      // Verificar si la venta tiene medio APP TERPEL pre-asignado
      final mediosExistentes = await _apiService.getMediosPagoVenta(widget.venta.id);
      final tieneAppTerpel = mediosExistentes.any((m) {
        final nombre = m.nombre.toUpperCase();
        return nombre.contains('APP TERPEL') || nombre.contains('APPTERPEL');
      });

      if (!tieneAppTerpel) return;

      // Si tiene APP TERPEL y está en "sin resolver" → fue rechazado.
      // Una venta aprobada se gestiona automáticamente y sale de esta lista.
      // El sincronizado=4 (pendiente) NO cambia en la BD después de rechazo,
      // por lo que NO podemos confiar en fnc_validar_botones_ventas_appterpel.
      _appTerpelRechazado = true;
      debugPrint('[AsignarDatos] APP TERPEL en venta sin resolver ${widget.venta.id} → rechazado, permitir cambio de medio');
    } catch (e) {
      debugPrint('[AsignarDatos] Error verificando estado AppTerpel: $e');
    }
  }

  Future<void> _cargarMediosPago() async {
    try {
      final medios = await _apiService.getMediosPago(traerEfectivo: false);

      // Filtrar GOPASS/GO PASS (solo desde Status Pump) y APP TERPEL/GOPASS si fueron rechazados
      final mediosFiltrados = medios.where((m) {
        final nombre = m.nombre.toUpperCase();
        if (_esGoPass(nombre)) return false;
        if (_appTerpelRechazado && (nombre.contains('APP TERPEL') || nombre.contains('APPTERPEL'))) return false;
        return true;
      }).toList();
      
      setState(() {
        _mediosPago = mediosFiltrados;
        _medioSeleccionado = mediosFiltrados.isNotEmpty ? mediosFiltrados.first : null;
      });
    } catch (e) {
      debugPrint('[AsignarDatos] Error cargando medios: $e');
    }
  }
  
  Future<void> _cargarMediosPagoExistentes() async {
    try {
      final mediosExistentes = await _apiService.getMediosPagoVenta(widget.venta.id);
      
      if (mediosExistentes.isNotEmpty) {
        setState(() {
          for (var medio in mediosExistentes) {
            // Si APP TERPEL o GOPASS fue rechazado, no agregar ese medio pre-asignado
            final nombreUpper = medio.nombre.toUpperCase();
            if (_appTerpelRechazado && 
                (nombreUpper.contains('APP TERPEL') || nombreUpper.contains('APPTERPEL'))) {
              debugPrint('[AsignarDatos] Omitiendo medio rechazado: ${medio.nombre}');
              continue;
            }
            if (_gopassRechazado && _esGoPass(nombreUpper)) {
              debugPrint('[AsignarDatos] Omitiendo medio GOPASS rechazado: ${medio.nombre}');
              continue;
            }

            final medioPagoConsulta = _mediosPago.firstWhere(
              (m) => m.id == medio.medioPagoId,
              orElse: () => MedioPagoConsulta(
                id: medio.medioPagoId,
                codigo: '',
                nombre: medio.nombre,
                codigoDian: medio.codigoDian ?? 0,
                requiereVoucher: medio.voucher.isNotEmpty,
              ),
            );
            
            _mediosAgregados.add(MedioPagoItemConsulta(
              medio: medioPagoConsulta,
              valor: medio.valor,
              voucher: medio.voucher,
            ));
          }
          _valorPagoController.text = _pendientePago > 0 ? _pendientePago.toStringAsFixed(0) : '0';
        });
        debugPrint('[AsignarDatos] Medios existentes cargados: ${_mediosAgregados.length}');
      }
    } catch (e) {
      debugPrint('[AsignarDatos] Error cargando medios existentes: $e');
    }

    // Si GoPass fue rechazado y no hay medios cargados, pre-seleccionar EFECTIVO
    if (_gopassRechazado && _mediosAgregados.isEmpty) {
      try {
        final mediosConEfectivo = await _apiService.getMediosPago(traerEfectivo: true);
        final efectivo = mediosConEfectivo.firstWhere(
          (m) => m.nombre.toUpperCase().contains('EFECTIVO'),
          orElse: () => MedioPagoConsulta(id: 1, codigo: '01', nombre: 'EFECTIVO', codigoDian: 10, requiereVoucher: false),
        );
        setState(() {
          _mediosAgregados.add(MedioPagoItemConsulta(
            medio: efectivo,
            valor: _totalVenta,
            voucher: '',
          ));
          _valorPagoController.text = '0';
        });
        debugPrint('[AsignarDatos] EFECTIVO pre-seleccionado por GoPass rechazado: \$$_totalVenta');
      } catch (e) {
        debugPrint('[AsignarDatos] Error pre-seleccionando EFECTIVO: $e');
      }
    }
  }
  
  Future<void> _cargarTiposIdentificacion() async {
    final tipos = await _apiService.getTiposIdentificacion();
    
    // Verificar si hay datos del cliente pre-cargados desde statusPump
    final identPrecargada = widget.venta.clienteIdentificacion ?? '';
    final tipoDocPrecargado = widget.venta.clienteTipoDocumento;
    final esClienteReal = identPrecargada.isNotEmpty 
        && identPrecargada != '222222222222'
        && identPrecargada != '0';
    
    setState(() {
      _tiposIdentificacion = tipos;
      
      if (esClienteReal && tipoDocPrecargado != null) {
        // Pre-seleccionar el tipo de documento del cliente existente
        _tipoSeleccionado = tipos.firstWhere(
          (t) => t.codigo == tipoDocPrecargado,
          orElse: () => tipos.firstWhere(
            (t) => t.nombre.toLowerCase().contains('cedula'),
            orElse: () => tipos.first,
          ),
        );
        _identificacionController.text = identPrecargada;
        _clientePrecargado = true;
      } else {
        // Default: CONSUMIDOR FINAL
        _tipoSeleccionado = tipos.firstWhere(
          (t) => t.esConsumidorFinal,
          orElse: () => tipos.firstWhere(
            (t) => t.nombre.toLowerCase().contains('cedula'),
            orElse: () => tipos.first,
          ),
        );
        if (_tipoSeleccionado?.esConsumidorFinal == true) {
          _identificacionController.text = _tipoSeleccionado!.identificacionDefecto;
          _nombreController.text = 'CONSUMIDOR FINAL (Presione CONSULTAR)';
        }
      }
    });
    
    // Auto-consultar si hay datos del cliente pre-cargados
    if (esClienteReal && identPrecargada.isNotEmpty) {
      debugPrint('[AsignarDatos] Cliente pre-cargado: $identPrecargada — auto-consultando...');
      await _consultarCliente();
    }
  }

  // ============================================================
  // Acciones del cliente
  // ============================================================

  void _onTipoIdentificacionChanged(TipoIdentificacion? tipo) {
    setState(() {
      _tipoSeleccionado = tipo;
      _clienteConsultado = null;
      if (tipo?.esConsumidorFinal == true) {
        _identificacionController.text = tipo!.identificacionDefecto;
        _nombreController.text = 'CONSUMIDOR FINAL (Presione CONSULTAR)';
      } else {
        _identificacionController.text = '';
        _nombreController.text = '';
      }
    });
  }
  
  Future<void> _consultarCliente() async {
    final identificacion = _identificacionController.text.trim();
    if (identificacion.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingrese una identificación'), backgroundColor: Colors.orange),
      );
      return;
    }
    
    setState(() => _consultandoCliente = true);
    
    final tipoDocumento = _tipoSeleccionado?.codigo ?? 13;
    final cliente = await _apiService.consultarCliente(identificacion, tipoDocumento: tipoDocumento);
    
    setState(() {
      _consultandoCliente = false;
      _clienteConsultado = cliente;
      _nombreController.text = cliente.nombre;
    });
  }

  // ============================================================
  // Acciones de medios de pago
  // ============================================================

  void _agregarMedioPago() {
    if (_medioSeleccionado == null) return;
    
    final valor = double.tryParse(_valorPagoController.text) ?? 0;
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
      _valorPagoController.text = _pendientePago > 0 ? _pendientePago.toStringAsFixed(0) : '0';
    });
  }
  
  void _quitarMedioPago(int index) {
    setState(() {
      _mediosAgregados.removeAt(index);
      _valorPagoController.text = _pendientePago > 0 ? _pendientePago.toStringAsFixed(0) : '0';
    });
  }

  // ============================================================
  // Guardar
  // ============================================================

  Future<void> _guardarDatos() async {
    // Guard: prevenir doble guardado
    if (_yaGuardado) {
      debugPrint('[AsignarDatos] ⚠ Ya se guardó esta venta, ignorando segundo intento');
      return;
    }
    
    if (_mediosAgregados.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debe agregar al menos un medio de pago'), backgroundColor: Colors.orange),
      );
      setState(() => _currentStep = 2);
      return;
    }
    
    if (_pendientePago > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Falta pagar: \$${_pendientePago.toStringAsFixed(0)}'), backgroundColor: Colors.orange),
      );
      setState(() => _currentStep = 2);
      return;
    }
    
    // Detectar si APP TERPEL es uno de los medios
    final medioAppTerpel = _mediosAgregados.where((m) {
      final nombre = m.medio.nombre.toUpperCase();
      return nombre.contains('APP TERPEL') || nombre.contains('APPTERPEL');
    }).toList();
    final esAppTerpel = medioAppTerpel.isNotEmpty;
    
    setState(() => _isLoading = true);
    
    try {
      // 1. Guardar datos de la venta (placa, cliente, etc.)
      final responseDatos = await _apiService.actualizarDatosVenta(
        movimientoId: widget.venta.id,
        placa: _placaController.text.trim().isNotEmpty ? _placaController.text.trim().toUpperCase() : null,
        odometro: int.tryParse(_odometroController.text),
        nombreCliente: _nombreController.text.trim().isNotEmpty ? _nombreController.text.trim() : null,
        identificacionCliente: _identificacionController.text.trim().isNotEmpty ? _identificacionController.text.trim() : null,
        tipoDocumento: _tipoSeleccionado?.codigo,
        orden: _ordenController.text.trim().isNotEmpty ? _ordenController.text.trim() : null,
      );
      
      if (!responseDatos.success) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(responseDatos.message), backgroundColor: Colors.red),
        );
        return;
      }
      
      // ================================================================
      // 2. Guardar medios de pago
      // Si es APP TERPEL: NO llamar fnc_actualizar_medios_de_pagos
      //   → Usar endpoint especial que marca isAppTerpel y estado pendiente
      //   → La venta NO se gestiona, queda en "sin resolver"
      //   → Luego se envia al orquestador (5555)
      // Si NO es APP TERPEL: flujo normal con fnc_actualizar_medios_de_pagos
      // ================================================================
      
      if (esAppTerpel) {
        // Flujo APP TERPEL: marcar pendiente + enviar al orquestador
        final responseAppTerpel = await _apiService.asignarAppTerpelVenta(
          movimientoId: widget.venta.id,
          medioPagoId: medioAppTerpel.first.medio.id,
          medioDescripcion: medioAppTerpel.first.medio.nombre,
          valorTotal: medioAppTerpel.first.valor,
        );
        
        if (!mounted) return;
        setState(() => _isLoading = false);
        
        if (responseAppTerpel.success) {
          // Mostrar countdown dialog que espera aprobación del orquestador
          // y luego envía al 7011 automáticamente
          final result = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AppTerpelCountdownDialog(
              apiService: _apiService,
              movimientoId: widget.venta.id,
              cara: 0, // Sin Resolver no tiene cara específica
              monto: medioAppTerpel.first.valor,
            ),
          );
          
          if (!mounted) return;
          final messenger = ScaffoldMessenger.of(context);
          final onComplete = widget.onComplete;
          Navigator.pop(context);
          
          messenger.showSnackBar(
            SnackBar(
              content: Row(children: [
                Icon(
                  result == true ? Icons.check_circle : Icons.info_outline,
                  color: Colors.white,
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(
                  result == true
                      ? 'APP TERPEL aprobado ✓ Factura enviada'
                      : 'APP TERPEL - Resultado pendiente',
                )),
              ]),
              backgroundColor: result == true ? Colors.teal : Colors.orange,
              duration: const Duration(seconds: 4),
            ),
          );
          onComplete();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(children: [const Icon(Icons.error, color: Colors.white), const SizedBox(width: 12), Expanded(child: Text(responseAppTerpel.message))]),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        // Flujo normal: llamar fnc_actualizar_medios_de_pagos (gestiona la venta)
        final List<MedioPagoParaGuardar> mediosVenta = _mediosAgregados.map((item) => MedioPagoParaGuardar(
          ctMediosPagosId: item.medio.id,
          descripcion: item.medio.nombre,
          valorTotal: item.valor,
          valorRecibido: item.valor,
          valorCambio: 0,
          codigoDian: item.medio.codigoDian,
          numeroComprobante: item.voucher.isNotEmpty ? item.voucher : null,
        )).toList();
        
        final responsePagos = await _apiService.actualizarMediosPago(
          movimientoId: widget.venta.id,
          mediosPagos: mediosVenta,
          identificadorEquipo: widget.identificadorEquipo.toString(),
        );
        
        if (!mounted) return;
        
        if (responsePagos.success) {
          // Marcar como guardado para prevenir doble envío
          _yaGuardado = true;
          
          // ── Enviar a Facturación Electrónica (7011) + transmision ──
          // Se hace ANTES de cerrar el diálogo para que el async no se pierda
          String feMessage = '';
          Color feColor = Colors.green;
          try {
            final payloadFe = {
              'identificadorMovimiento': widget.venta.id,
              'documentoCliente': _identificacionController.text.trim(),
              'tipoDocumentoCliente': _tipoSeleccionado?.codigo ?? 13,
              'nombreRazonSocial': _nombreController.text.trim(),
            };
            final fResult = await _apiService.enviarFEVentaSinResolver(
              movimientoId: widget.venta.id,
              payloadFe: payloadFe,
              imprimirDespues: _imprimirFactura,
            );
            if (fResult['ok'] == true) {
              feMessage = _imprimirFactura
                  ? 'Venta gestionada ✓ Factura electrónica enviada ✓ Impresión disparada'
                  : 'Venta gestionada ✓ Factura electrónica enviada';
              feColor = Colors.teal;
            } else {
              feMessage = 'Venta gestionada ✓ FE pendiente (se reintentará automáticamente)';
              feColor = Colors.orange;
            }
          } catch (feErr) {
            debugPrint('[AsignarDatos] Error enviando FE: $feErr');
            feMessage = 'Venta gestionada ✓ FE se reintentará automáticamente';
            feColor = Colors.orange;
          }

          if (!mounted) return;
          final messenger = ScaffoldMessenger.of(context);
          final onComplete = widget.onComplete;
          Navigator.pop(context);

          messenger.showSnackBar(
            SnackBar(
              content: Row(children: [
                Icon(feColor == Colors.teal ? Icons.print : Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text(feMessage)),
              ]),
              backgroundColor: feColor,
              duration: const Duration(seconds: 4),
            ),
          );

          // Siempre refrescar la lista después de guardar exitosamente
          onComplete();
        } else {
          final messenger = ScaffoldMessenger.of(context);
          Navigator.pop(context);
          messenger.showSnackBar(
            SnackBar(
              content: Row(children: [const Icon(Icons.error, color: Colors.white), const SizedBox(width: 12), Expanded(child: Text(responsePagos.message))]),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        width: 950,
        constraints: const BoxConstraints(maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            _buildStepIndicators(),
            Flexible(child: SingleChildScrollView(padding: const EdgeInsets.all(20), child: _buildStepContent())),
            _buildNavigationButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(color: Color(0xFFBA0C2F), borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      child: Row(children: [
        const Icon(Icons.edit_note, color: Colors.white, size: 28),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('ASIGNAR DATOS', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          Text('Venta #${widget.venta.id} - ${widget.venta.totalFormateado}', style: TextStyle(color: Colors.white.withAlpha(200), fontSize: 13)),
        ])),
        IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: Colors.white)),
      ]),
    );
  }

  Widget _buildStepIndicators() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        _buildStepIndicator(0, 'Vehículo'),
        _buildStepConnector(0),
        _buildStepIndicator(1, 'Cliente'),
        _buildStepConnector(1),
        _buildStepIndicator(2, 'Pago'),
        _buildStepConnector(2),
        _buildStepIndicator(3, 'Confirmar'),
      ]),
    );
  }

  Widget _buildNavigationButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _currentStep > 0
              ? TextButton.icon(
                  onPressed: _isLoading ? null : () {
                    setState(() {
                      _currentStep--;
                      if (_currentStep == 2 && _saltarPasoPago) _currentStep = 1;
                    });
                  },
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Anterior'),
                )
              : TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          _currentStep < 3
              ? ElevatedButton.icon(
                  onPressed: _isLoading || !_puedeAvanzar() ? null : () {
                    setState(() {
                      _currentStep++;
                      if (_currentStep == 2 && _saltarPasoPago) _currentStep = 3;
                    });
                  },
                  icon: const Icon(Icons.arrow_forward),
                  label: Text(_getMensajeBotonSiguiente()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _puedeAvanzar() ? const Color(0xFFBA0C2F) : Colors.grey,
                    foregroundColor: Colors.white,
                  ),
                )
              : ElevatedButton.icon(
                  onPressed: _isLoading ? null : _guardarDatos,
                  icon: _isLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save),
                  label: Text(_isLoading ? 'Guardando...' : 'Guardar'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                ),
        ],
      ),
    );
  }

  // ============================================================
  // Step indicators
  // ============================================================
  
  Widget _buildStepIndicator(int step, String label) {
    final isActive = _currentStep >= step;
    final isCurrent = _currentStep == step;
    final isSkipped = step == 2 && _saltarPasoPago;
    final showCheck = (isActive && !isCurrent) || isSkipped;
    
    return Column(children: [
      Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: (isActive || isSkipped) ? const Color(0xFFBA0C2F) : Colors.grey.shade300,
          border: isCurrent ? Border.all(color: const Color(0xFFBA0C2F), width: 3) : null,
        ),
        child: Center(
          child: showCheck
              ? const Icon(Icons.check, color: Colors.white, size: 20)
              : Text('${step + 1}', style: TextStyle(color: isActive ? Colors.white : Colors.grey, fontWeight: FontWeight.bold)),
        ),
      ),
      const SizedBox(height: 4),
      Text(
        isSkipped ? '$label (${_mediosAgregados.isNotEmpty ? _mediosAgregados.first.medio.nombre : "Asignado"})' : label,
        style: TextStyle(fontSize: 11, color: (isActive || isSkipped) ? const Color(0xFFBA0C2F) : Colors.grey, fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal),
      ),
    ]);
  }
  
  Widget _buildStepConnector(int afterStep) {
    final isActive = _currentStep > afterStep || 
        (afterStep == 1 && _saltarPasoPago && _currentStep >= 3) ||
        (afterStep == 2 && _saltarPasoPago && _currentStep >= 3);
    return Container(width: 60, height: 3, margin: const EdgeInsets.only(bottom: 20), color: isActive ? const Color(0xFFBA0C2F) : Colors.grey.shade300);
  }

  // ============================================================
  // Step content router
  // ============================================================
  
  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0: return _buildPasoVehiculo();
      case 1: return _buildPasoCliente();
      case 2: return _buildPasoMedioPago();
      case 3: return _buildPasoConfirmar();
      default: return const SizedBox();
    }
  }

  // ============================================================
  // PASO 1: Vehículo
  // ============================================================
  
  Widget _buildPasoVehiculo() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Info venta
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: const Color(0xFFBA0C2F).withAlpha(20), borderRadius: BorderRadius.circular(8)),
            child: Column(children: [
              const Text('VALOR:', style: TextStyle(fontSize: 10, color: Colors.grey)),
              Text(widget.venta.totalFormateado, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 4),
              const Text('CANTIDAD:', style: TextStyle(fontSize: 10, color: Colors.grey)),
              Text(widget.venta.cantidadFormateada, style: const TextStyle(fontWeight: FontWeight.bold)),
            ]),
          ),
          const SizedBox(width: 16),
          Expanded(child: Text(widget.venta.producto, style: const TextStyle(fontWeight: FontWeight.w600))),
        ]),
      ),
      const SizedBox(height: 20),
      const Text('Datos del Vehículo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      const SizedBox(height: 16),
      CampoPlaca(controller: _placaController),
      const SizedBox(height: 16),
      CampoConTeclado(label: 'KMS (Odómetro)', controller: _odometroController, icon: Icons.speed, soloNumeros: true, hint: '50000'),
      const SizedBox(height: 16),
      CampoConTeclado(label: 'NO. ORDEN (opcional)', controller: _ordenController, icon: Icons.description),
    ]);
  }

  // ============================================================
  // PASO 2: Cliente
  // ============================================================
  
  Widget _buildPasoCliente() {
    final bool esConsumidorFinal = _tipoSeleccionado?.nombre.contains('CONSUMIDOR') == true;
    
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Datos del Cliente', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      const SizedBox(height: 16),
      
      // Dropdown tipo identificación
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('TIPO DE IDENTIFICACIÓN:', style: TextStyle(fontSize: 12, color: Color(0xFFBA0C2F), fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
          child: DropdownButton<TipoIdentificacion>(
            value: _tipoSeleccionado,
            isExpanded: true,
            underline: const SizedBox(),
            style: const TextStyle(fontSize: 16, color: Colors.black),
            items: _tiposIdentificacion.map((tipo) => DropdownMenuItem(value: tipo, child: Text(tipo.nombre))).toList(),
            onChanged: _clientePrecargado ? null : _onTipoIdentificacionChanged,
          ),
        ),
      ]),
      const SizedBox(height: 16),
      
      // Fila: Identificación + Consultar
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(flex: 3, child: CampoConTeclado(label: 'IDENTIFICACIÓN', controller: _identificacionController, icon: Icons.badge, soloNumeros: true, enabled: !esConsumidorFinal && !_clientePrecargado)),
        const SizedBox(width: 12),
        SizedBox(
          height: 60,
          child: ElevatedButton.icon(
            onPressed: (_consultandoCliente || _clientePrecargado) ? null : _consultarCliente,
            icon: _consultandoCliente
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.search, size: 24),
            label: const Text('CONSULTAR', style: TextStyle(fontSize: 16)),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFBA0C2F), foregroundColor: Colors.white),
          ),
        ),
      ]),
      const SizedBox(height: 16),
      
      // Nombre del cliente (solo lectura)
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('NOMBRE DEL CLIENTE:', style: TextStyle(fontSize: 12, color: Color(0xFFBA0C2F), fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
          child: Row(children: [
            const Icon(Icons.person, color: Colors.grey),
            const SizedBox(width: 12),
            Expanded(child: Text(
              _nombreController.text.isEmpty ? 'Se llenará al consultar' : _nombreController.text,
              style: TextStyle(fontSize: 16, color: _nombreController.text.isEmpty ? Colors.grey : Colors.black),
            )),
          ]),
        ),
      ]),
      
      // Mensaje: cliente no encontrado
      if (_clienteConsultado != null && _clienteConsultado!.esConsumidorFinal && _tipoSeleccionado != null && !_tipoSeleccionado!.esConsumidorFinal) ...[
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.orange.withAlpha(30), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.orange.withAlpha(100))),
          child: Row(children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange),
            const SizedBox(width: 12),
            Expanded(child: Text('Cliente no registrado. Se facturará como CONSUMIDOR FINAL.', style: TextStyle(color: Colors.orange.shade800, fontSize: 13))),
          ]),
        ),
      ],
      
      // Mensaje: consumidor final
      if (_tipoSeleccionado != null && _tipoSeleccionado!.esConsumidorFinal) ...[
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.blue.withAlpha(20), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.blue.withAlpha(100))),
          child: Row(children: [
            const Icon(Icons.info_outline, color: Colors.blue),
            const SizedBox(width: 12),
            Expanded(child: Text('Venta a cliente genérico (Consumidor Final).', style: TextStyle(color: Colors.blue.shade700, fontSize: 13))),
          ]),
        ),
      ],
      
      const SizedBox(height: 20),
      
      // Switch imprimir factura
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _imprimirFactura ? Colors.teal.withAlpha(20) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _imprimirFactura ? Colors.teal : Colors.grey.shade300),
        ),
        child: Row(children: [
          Icon(Icons.print, color: _imprimirFactura ? Colors.teal : Colors.grey),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('¿Imprimir factura?', style: TextStyle(fontWeight: FontWeight.w600)),
            Text('Se imprimirá automáticamente con CUFE', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ])),
          Switch(
            value: _imprimirFactura,
            onChanged: (value) => setState(() => _imprimirFactura = value),
            activeThumbColor: Colors.teal,
          )
        ]),
      ),
    ]);
  }

  // ============================================================
  // PASO 3: Medio de Pago
  // ============================================================
  
  Widget _buildPasoMedioPago() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Medio de Pago', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      const SizedBox(height: 16),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Columna izquierda: Totales y Tabla
        Expanded(flex: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildTotalesPago(),
          const SizedBox(height: 16),
          _buildTablaMediosPago(),
        ])),
        const SizedBox(width: 16),
        // Columna derecha: Dropdown, Valor, Teclado
        SizedBox(width: 280, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildDropdownMedioPago(),
          const SizedBox(height: 12),
          _buildCampoValorPago(),
          const SizedBox(height: 12),
          TecladoTactil(controller: _valorPagoController, soloNumeros: true, height: 280, onAceptar: _agregarMedioPago),
          const SizedBox(height: 12),
          if (_pendientePago <= 0 && _mediosAgregados.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.blue.shade200)),
              child: Row(children: [
                Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text('Para cambiar el pago, elimine los medios existentes primero', style: TextStyle(fontSize: 11, color: Colors.blue.shade700))),
              ]),
            ),
            const SizedBox(height: 8),
          ],
          _buildBotonAgregarPago(),
        ])),
      ]),
    ]);
  }

  Widget _buildTotalesPago() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
      child: Column(children: [
        _buildFilaTotalPago('TOTAL:', _totalVenta, Colors.black),
        const Divider(),
        _buildFilaTotalPago('RECIBIDO:', _totalRecibido, _totalRecibido >= _totalVenta ? Colors.green.shade700 : Colors.grey.shade600),
        const Divider(),
        if (_pendientePago > 0) _buildFilaTotalPago('PENDIENTE:', _pendientePago, Colors.red.shade700)
        else if (_pendientePago < 0) _buildFilaTotalPago('CAMBIO:', _pendientePago.abs(), Colors.blue.shade700)
        else _buildFilaTotalPago('PENDIENTE:', 0, Colors.green.shade700, completo: true),
      ]),
    );
  }
  
  Widget _buildFilaTotalPago(String label, double valor, Color color, {bool completo = false}) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      Row(mainAxisSize: MainAxisSize.min, children: [
        Text('\$ ${valor.toStringAsFixed(0)}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        if (completo) ...[
          const SizedBox(width: 8),
          Icon(Icons.check_circle, color: Colors.green.shade700, size: 20),
          const SizedBox(width: 4),
          Text('Completo', style: TextStyle(color: Colors.green.shade700, fontSize: 12)),
        ],
      ]),
    ]);
  }

  Widget _buildDropdownMedioPago() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('MEDIO PAGO:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
      const SizedBox(height: 6),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade400)),
        child: DropdownButton<MedioPagoConsulta>(
          value: _medioSeleccionado,
          isExpanded: true,
          underline: const SizedBox(),
          items: _mediosPago.map((medio) => DropdownMenuItem(value: medio, child: Text(medio.nombre))).toList(),
          onChanged: (medio) => setState(() => _medioSeleccionado = medio),
        ),
      ),
    ]);
  }

  Widget _buildCampoValorPago() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('VALOR:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
      const SizedBox(height: 6),
      TextField(
        controller: _valorPagoController,
        readOnly: true,
        textAlign: TextAlign.right,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          prefixText: '\$ ',
          prefixStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          filled: true,
          fillColor: Colors.grey.shade100,
        ),
      ),
    ]);
  }

  Widget _buildBotonAgregarPago() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _pendientePago > 0 || _mediosAgregados.isEmpty ? _agregarMedioPago : null,
        icon: const Icon(Icons.add),
        label: Text(_pendientePago <= 0 && _mediosAgregados.isNotEmpty ? 'COMPLETO' : 'AGREGAR'),
        style: ElevatedButton.styleFrom(
          backgroundColor: _pendientePago > 0 || _mediosAgregados.isEmpty ? Colors.green : Colors.grey,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  Widget _buildTablaMediosPago() {
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
                SizedBox(width: 40, child: IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 20), onPressed: () => _quitarMedioPago(index), padding: EdgeInsets.zero)),
              ]),
            );
          }),
      ]),
    );
  }

  // ============================================================
  // PASO 4: Confirmar
  // ============================================================

  Widget _buildPasoConfirmar() {
    final medioPreAsignado = _mediosAgregados.isNotEmpty ? _mediosAgregados.first : null;
    final nombreMedio = medioPreAsignado?.medio.nombre.toUpperCase() ?? '';
    final esGopass = nombreMedio.contains('GOPASS');
    final esAppTerpel = nombreMedio.contains('APP TERPEL') || nombreMedio.contains('APPTERPEL');
    final esMedioEspecial = esGopass || esAppTerpel;
    
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Confirmar Datos', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      Text('Revise los datos antes de guardar', style: TextStyle(color: Colors.grey.shade600)),
      const SizedBox(height: 20),
      
      // Banner medio especial pre-asignado
      if (esMedioEspecial && _saltarPasoPago) ...[
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: (esAppTerpel ? const Color(0xFF6A1B9A) : Colors.green).withAlpha(20),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: (esAppTerpel ? const Color(0xFF6A1B9A) : Colors.green).withAlpha(100)),
          ),
          child: Row(children: [
            Icon(Icons.verified, color: esAppTerpel ? const Color(0xFF6A1B9A) : Colors.green, size: 24),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${medioPreAsignado!.medio.nombre} ya asignado previamente',
                style: TextStyle(fontWeight: FontWeight.bold, color: esAppTerpel ? const Color(0xFF6A1B9A) : Colors.green, fontSize: 14)),
              const SizedBox(height: 2),
              Text('Medio de pago: ${medioPreAsignado.medio.nombre} - \$${medioPreAsignado.valor.toStringAsFixed(0)}',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
            ])),
          ]),
        ),
        const SizedBox(height: 16),
      ],
      
      // Resumen
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFBA0C2F).withAlpha(10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFBA0C2F).withAlpha(50)),
        ),
        child: Column(children: [
          _buildResumenItem('Venta', '#${widget.venta.id}'),
          _buildResumenItem('Producto', widget.venta.producto),
          _buildResumenItem('Total', widget.venta.totalFormateado),
          const Divider(),
          if (_placaController.text.isNotEmpty) _buildResumenItem('Placa', _placaController.text.toUpperCase()),
          if (_odometroController.text.isNotEmpty) _buildResumenItem('Odómetro', '${_odometroController.text} km'),
          if (_ordenController.text.isNotEmpty) _buildResumenItem('Orden', _ordenController.text),
          if (_nombreController.text.isNotEmpty) _buildResumenItem('Cliente', _nombreController.text),
          if (_identificacionController.text.isNotEmpty) _buildResumenItem('Identificación', _identificacionController.text),
          if (_imprimirFactura) _buildResumenItem('Impresión', 'AUTOMÁTICA CON CUFE', isHighlight: true),
          if (_mediosAgregados.isNotEmpty) ...[
            const Divider(),
            for (var medio in _mediosAgregados)
              _buildResumenItem('Pago', '${medio.medio.nombre} - \$${medio.valor.toStringAsFixed(0)}',
                isHighlight: medio.medio.nombre.toUpperCase().contains('GOPASS')),
          ],
        ]),
      ),
      
      const SizedBox(height: 16),
      
      if (_imprimirFactura)
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.teal.withAlpha(20), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.teal)),
          child: const Row(children: [
            Icon(Icons.print, color: Colors.teal),
            SizedBox(width: 12),
            Expanded(child: Text('Se imprimirá automáticamente con CUFE al guardar.', style: TextStyle(fontSize: 13))),
          ]),
        ),
    ]);
  }
  
  Widget _buildResumenItem(String label, String value, {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(color: Colors.grey.shade600)),
        Text(value, style: TextStyle(fontWeight: FontWeight.w600, color: isHighlight ? Colors.orange : null)),
      ]),
    );
  }
}
