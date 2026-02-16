import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/api_consultas_service.dart';
import '../../../../core/services/payment_websocket_service.dart';
import '../../../status_pump/presentation/providers/status_pump_provider.dart';
import '../../../status_pump/domain/entities/surtidor_estado.dart';

/// Función reutilizable para mostrar el bottom sheet de medios de pago.
/// Se puede llamar desde HomePage o desde StatusPumpPage.
void showMediosPagoBottomSheet(BuildContext context, SurtidorEstado surtidor) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => MediosPagoBottomSheet(surtidor: surtidor),
  );
}

// ============================================================
// BOTTOM SHEET COMPACTO DE MEDIOS DE PAGO
// ============================================================
// Maneja: EFECTIVO, TARJETA, GOPASS (con placas), APP TERPEL (con QR),
// y cualquier otro medio de pago configurado en la BD.
// ============================================================

class MediosPagoBottomSheet extends StatefulWidget {
  final SurtidorEstado surtidor;

  const MediosPagoBottomSheet({super.key, required this.surtidor});

  @override
  State<MediosPagoBottomSheet> createState() => _MediosPagoBottomSheetState();
}

class _MediosPagoBottomSheetState extends State<MediosPagoBottomSheet> {
  final ApiConsultasService _apiService = ApiConsultasService();
  List<MedioPagoConsulta> _medios = [];
  bool _isLoading = true;
  MedioPagoConsulta? _seleccionado;
  bool _guardando = false;

  // GOPASS - Estado de placas
  bool _esGopass = false;
  bool _cargandoPlacas = false;
  List<PlacaGopass> _placas = [];
  PlacaGopass? _placaSeleccionada;
  String? _errorPlacas;
  
  // APP TERPEL
  bool _esAppTerpel = false;

  @override
  void initState() {
    super.initState();
    _cargarMedios();
  }

  Future<void> _cargarMedios() async {
    final medios = await _apiService.getMediosPago(traerEfectivo: true);
    setState(() {
      _medios = medios;
      _seleccionado = medios.firstWhere(
        (m) => m.nombre.toUpperCase().contains('EFECTIVO'),
        orElse: () => medios.isNotEmpty ? medios.first : MedioPagoConsulta(id: 1, codigo: '01', nombre: 'EFECTIVO', codigoDian: 10, requiereVoucher: false),
      );
      _isLoading = false;
    });
  }

  // ============================================================
  // Selección de medio de pago
  // ============================================================

  /// Seleccionar un medio de pago. Si es GOPASS, iniciar consulta de placas.
  /// Si es APP TERPEL, mostrar sección con instrucciones QR.
  void _seleccionarMedio(MedioPagoConsulta medio) {
    final nombre = medio.nombre.toUpperCase();
    final esGopass = nombre.contains('GOPASS');
    final esAppTerpel = nombre.contains('APP TERPEL') || nombre.contains('APPTERPEL');
    
    setState(() {
      _seleccionado = medio;
      _esGopass = esGopass;
      _esAppTerpel = esAppTerpel;
      
      if (!esGopass) {
        _placas = [];
        _placaSeleccionada = null;
        _errorPlacas = null;
        _cargandoPlacas = false;
      }
    });
    
    if (esGopass && _placas.isEmpty && !_cargandoPlacas) {
      _consultarPlacas();
    }
  }

  // ============================================================
  // GOPASS - Consulta de placas
  // ============================================================

  Future<void> _consultarPlacas() async {
    setState(() {
      _cargandoPlacas = true;
      _errorPlacas = null;
      _placaSeleccionada = null;
    });
    
    final response = await _apiService.consultarPlacasGoPass(
      cara: widget.surtidor.cara,
    );
    
    if (!mounted) return;
    
    setState(() {
      _cargandoPlacas = false;
      if (response.success) {
        _placas = response.placas;
        if (_placas.isEmpty) {
          _errorPlacas = 'No se encontraron placas para esta cara';
        }
      } else {
        _errorPlacas = response.message;
        _placas = [];
      }
    });
  }

  // ============================================================
  // Validaciones y texto del botón
  // ============================================================

  bool get _puedeGuardar {
    if (_guardando || _seleccionado == null) return false;
    if (_esGopass && _placaSeleccionada == null) return false;
    return true;
  }

  String get _textoBotonGuardar {
    if (_guardando) return 'GUARDANDO...';
    if (_seleccionado == null) return 'SELECCIONE UN MEDIO';
    if (_esGopass) {
      if (_placaSeleccionada != null) {
        return 'GUARDAR GOPASS - ${_placaSeleccionada!.placa}';
      }
      return 'SELECCIONE UNA PLACA';
    }
    if (_esAppTerpel) {
      return 'CONFIRMAR APP TERPEL';
    }
    return 'GUARDAR ${_seleccionado!.nombre}';
  }

  // ============================================================
  // Guardar medio de pago
  // ============================================================

  Future<void> _guardar() async {
    if (!_puedeGuardar) return;
    
    // Confirmación GOPASS
    if (_esGopass && _placaSeleccionada != null) {
      final confirmar = await _confirmarGopass();
      if (confirmar != true) return;
    }
    
    // Confirmación APP TERPEL
    if (_esAppTerpel) {
      final confirmar = await _confirmarAppTerpel();
      if (confirmar != true) return;
    }
    
    setState(() => _guardando = true);
    
    // Guardar en ventas_curso (igual que Java desde Status Pump)
    final response = await _apiService.guardarMedioVentaCurso(
      cara: widget.surtidor.cara,
      medioPagoId: _seleccionado!.id,
      descripcion: _seleccionado!.nombre,
      placa: _esGopass ? _placaSeleccionada?.placa : null,
      esGopass: _esGopass,
      esAppTerpel: _esAppTerpel,
    );
    
    if (!mounted) return;
    
    // Actualizar provider para que la tarjeta del surtidor refleje el cambio
    if (_esGopass && response.success && _placaSeleccionada != null) {
      context.read<StatusPumpProvider>().asignarPlaca(
        widget.surtidor.cara,
        _placaSeleccionada!.placa,
        clienteNombre: _placaSeleccionada!.nombreUsuario.isNotEmpty
            ? _placaSeleccionada!.nombreUsuario
            : null,
      );
    }
    
    if (_esAppTerpel && response.success) {
      context.read<StatusPumpProvider>().asignarMedioPagoEspecial(
        widget.surtidor.cara,
        'APP TERPEL',
      );
      
      // Solo guardar el medio y cerrar. El envío al orquestador se hace cuando
      // la venta termina de despachar (StatusPumpProvider emite appTerpelTerminadaStream)
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(children: [
            Icon(Icons.phone_iphone, color: Colors.white),
            SizedBox(width: 12),
            Text('APP TERPEL asignado - Se enviará al finalizar despacho'),
          ]),
          backgroundColor: Color(0xFF6A1B9A),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }
    
    Navigator.pop(context);
    
    // Mensaje de éxito personalizado
    String mensajeExito;
    if (_esGopass && response.success) {
      mensajeExito = 'GOPASS asignado - Placa: ${_placaSeleccionada?.placa}';
    } else {
      mensajeExito = response.message;
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(response.success ? Icons.check_circle : Icons.error, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(mensajeExito)),
          ],
        ),
        backgroundColor: response.success ? Colors.green : Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }
  
  // ============================================================
  // APP TERPEL - Enviar al orquestador (puerto 5555) y countdown
  // ============================================================
  // Java: EnviandoMedioPago.java → POST http://localhost:5555/v1/payments/
  // Muestra diálogo con countdown mientras se espera respuesta
  
  Future<void> _enviarPagoOrquestadorYMostrarCountdown() async {
    // Obtener movimiento_id de la venta activa
    final ventaActiva = await _apiService.getVentaActivaPorCara(widget.surtidor.cara);
    
    if (!ventaActiva.found || ventaActiva.movimientoId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('APP TERPEL asignado, pero no se encontró movimiento activo para enviar al orquestador'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    if (!mounted) return;
    
    // Mostrar diálogo de countdown y enviar al orquestador en paralelo
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AppTerpelCountdownDialog(
        apiService: _apiService,
        movimientoId: ventaActiva.movimientoId!,
        cara: widget.surtidor.cara,
        monto: widget.surtidor.monto,
      ),
    );
  }

  // ============================================================
  // Diálogos de confirmación
  // ============================================================

  Future<bool?> _confirmarGopass() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.directions_car, color: AppTheme.terpeRed),
            const SizedBox(width: 8),
            const Text('Confirmar GOPASS'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('¿Confirma que la placa seleccionada es:'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.terpeRed.withAlpha(15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.terpeRed, width: 2),
              ),
              child: Text(
                _placaSeleccionada!.placa,
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppTheme.terpeRed, letterSpacing: 3),
              ),
            ),
            if (_placaSeleccionada!.nombreUsuario.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(_placaSeleccionada!.nombreUsuario, style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCELAR', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.terpeRed, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: const Text('SI, CONFIRMAR'),
          ),
        ],
      ),
    );
  }

  Future<bool?> _confirmarAppTerpel() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: const Color(0xFF6A1B9A).withAlpha(20), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.phone_iphone, color: Color(0xFF6A1B9A), size: 24),
            ),
            const SizedBox(width: 10),
            const Text('Confirmar APP TERPEL'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [const Color(0xFF6A1B9A).withAlpha(15), const Color(0xFF6A1B9A).withAlpha(5)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF6A1B9A).withAlpha(50)),
              ),
              child: Column(
                children: [
                  const Icon(Icons.qr_code_2, size: 48, color: Color(0xFF6A1B9A)),
                  const SizedBox(height: 12),
                  const Text('¿Asignar APP TERPEL como medio de pago?', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  const SizedBox(height: 8),
                  Text('Cara ${widget.surtidor.cara} - \$${_formatNumber(widget.surtidor.monto)}', style: TextStyle(color: Colors.grey.shade600)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.amber.withAlpha(20), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.amber.withAlpha(80))),
              child: Row(
                children: [
                  const Icon(Icons.timer, color: Colors.amber, size: 22),
                  const SizedBox(width: 10),
                  Expanded(child: Text('Una vez cuelgue manguera, indique al cliente que tiene 90 segundos para leer el código QR.', style: TextStyle(fontSize: 12, color: Colors.grey.shade700))),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCELAR', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6A1B9A), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: const Text('SI, CONFIRMAR'),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.7;
    
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
            ),
            
            // Header
            _buildHeader(),
            const Divider(height: 1),
            
            // Contenido scrollable
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Chips de medios de pago
                    _isLoading
                        ? const Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: AppTheme.terpeRed))
                        : Padding(
                            padding: const EdgeInsets.all(16),
                            child: Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: _medios.map((medio) => _buildMedioChip(medio)).toList(),
                            ),
                          ),
                    if (_esGopass) _buildGopassSection(),
                    if (_esAppTerpel) _buildAppTerpelSection(),
                  ],
                ),
              ),
            ),
            
            // Botón guardar
            _buildBotonGuardar(),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // Sub-widgets del build
  // ============================================================

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppTheme.terpeRed.withAlpha(20), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.payments, color: AppTheme.terpeRed, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('MEDIO DE PAGO', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text('Cara ${widget.surtidor.cara} - ${widget.surtidor.producto}', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(color: AppTheme.terpeRed, borderRadius: BorderRadius.circular(10)),
            child: Text('\$ ${_formatNumber(widget.surtidor.monto)}', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildBotonGuardar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton.icon(
          onPressed: _puedeGuardar ? _guardar : null,
          icon: _guardando
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Icon(_esGopass ? Icons.directions_car : _esAppTerpel ? Icons.phone_iphone : Icons.check),
          label: Text(_textoBotonGuardar, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.terpeRed,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // GOPASS - Sección de placas
  // ============================================================

  Widget _buildGopassSection() {
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.terpeRed.withAlpha(40)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
              decoration: BoxDecoration(color: AppTheme.terpeRed.withAlpha(15), borderRadius: const BorderRadius.vertical(top: Radius.circular(13))),
              child: Row(
                children: [
                  const Icon(Icons.directions_car, color: AppTheme.terpeRed, size: 20),
                  const SizedBox(width: 8),
                  const Text('SELECCIONE PLACA GOPASS', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.terpeRed)),
                  const Spacer(),
                  if (!_cargandoPlacas)
                    GestureDetector(
                      onTap: _consultarPlacas,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)),
                        child: const Icon(Icons.refresh, size: 18, color: AppTheme.terpeRed),
                      ),
                    ),
                ],
              ),
            ),
            Padding(padding: const EdgeInsets.all(12), child: _buildGopassContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildGopassContent() {
    if (_cargandoPlacas) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: Column(children: [
          SizedBox(width: 36, height: 36, child: CircularProgressIndicator(strokeWidth: 3, color: AppTheme.terpeRed)),
          SizedBox(height: 10),
          Text('Consultando placas...', style: TextStyle(fontSize: 13, color: Colors.grey)),
        ])),
      );
    }
    
    if (_errorPlacas != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(10)),
        child: Row(children: [
          Icon(Icons.error_outline, color: Colors.red.shade400, size: 24),
          const SizedBox(width: 10),
          Expanded(child: Text(_errorPlacas!, style: TextStyle(fontSize: 12, color: Colors.red.shade700))),
          TextButton(onPressed: _consultarPlacas, child: const Text('REINTENTAR', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
        ]),
      );
    }
    
    if (_placas.isEmpty) {
      return const Center(child: Padding(padding: EdgeInsets.all(16), child: Text('No hay placas disponibles', style: TextStyle(color: Colors.grey))));
    }
    
    return Wrap(spacing: 8, runSpacing: 8, children: _placas.map((placa) => _buildPlacaChip(placa)).toList());
  }

  Widget _buildPlacaChip(PlacaGopass placa) {
    final isSelected = _placaSeleccionada?.placa == placa.placa;
    return GestureDetector(
      onTap: () => setState(() => _placaSeleccionada = placa),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.terpeRed : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? AppTheme.terpeRed : Colors.grey.shade300, width: isSelected ? 2 : 1),
          boxShadow: isSelected
              ? [BoxShadow(color: AppTheme.terpeRed.withAlpha(50), blurRadius: 8, offset: const Offset(0, 2))]
              : [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 4)],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.directions_car, size: 18, color: isSelected ? Colors.white : Colors.grey.shade600),
            const SizedBox(width: 6),
            Text(placa.placa, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.black87, letterSpacing: 1.5)),
            if (isSelected) ...[const SizedBox(width: 6), const Icon(Icons.check_circle, size: 16, color: Colors.white)],
          ]),
          if (placa.nombreUsuario.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(placa.nombreUsuario, style: TextStyle(fontSize: 10, color: isSelected ? Colors.white70 : Colors.grey.shade500), overflow: TextOverflow.ellipsis),
          ],
        ]),
      ),
    );
  }

  // ============================================================
  // APP TERPEL - Sección de información QR
  // ============================================================

  Widget _buildAppTerpelSection() {
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [const Color(0xFF6A1B9A).withAlpha(12), const Color(0xFF6A1B9A).withAlpha(5)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF6A1B9A).withAlpha(50)),
        ),
        child: Column(children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFF6A1B9A).withAlpha(25), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.phone_iphone, color: Color(0xFF6A1B9A), size: 28),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('APP TERPEL', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF6A1B9A))),
              Text('Pago mediante aplicación móvil', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ])),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), boxShadow: [BoxShadow(color: const Color(0xFF6A1B9A).withAlpha(30), blurRadius: 6)]),
              child: const Icon(Icons.qr_code_2, color: Color(0xFF6A1B9A), size: 32),
            ),
          ]),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
            child: Column(children: [
              _buildInstruccionItem('1', 'El cliente abre la App Terpel en su celular', Icons.phone_android),
              const SizedBox(height: 8),
              _buildInstruccionItem('2', 'Al colgar manguera, tiene 90 segundos para escanear el código QR', Icons.timer),
              const SizedBox(height: 8),
              _buildInstruccionItem('3', 'El pago se procesa automáticamente desde la app', Icons.check_circle_outline),
            ]),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: Colors.amber.withAlpha(25), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.amber.withAlpha(80))),
            child: Row(children: [
              const Icon(Icons.info_outline, color: Colors.amber, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text('Recuerde indicar al cliente sobre los 90 segundos al colgar la manguera', style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.w500))),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _buildInstruccionItem(String numero, String texto, IconData icono) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 24, height: 24,
        decoration: const BoxDecoration(color: Color(0xFF6A1B9A), shape: BoxShape.circle),
        child: Center(child: Text(numero, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
      ),
      const SizedBox(width: 10),
      Icon(icono, size: 18, color: const Color(0xFF6A1B9A)),
      const SizedBox(width: 8),
      Expanded(child: Text(texto, style: TextStyle(fontSize: 12, color: Colors.grey.shade700))),
    ]);
  }

  // ============================================================
  // Chips de medios de pago
  // ============================================================

  Widget _buildMedioChip(MedioPagoConsulta medio) {
    final isSelected = _seleccionado?.id == medio.id;
    return GestureDetector(
      onTap: () => _seleccionarMedio(medio),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.terpeRed : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? AppTheme.terpeRed : Colors.grey.shade300, width: isSelected ? 2 : 1),
          boxShadow: isSelected ? [BoxShadow(color: AppTheme.terpeRed.withAlpha(40), blurRadius: 8, offset: const Offset(0, 2))] : null,
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(_getIconoMedio(medio.nombre), size: 20, color: isSelected ? Colors.white : Colors.grey.shade700),
          const SizedBox(width: 8),
          Text(medio.nombre, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isSelected ? Colors.white : Colors.black87)),
          if (isSelected) ...[const SizedBox(width: 6), const Icon(Icons.check_circle, size: 18, color: Colors.white)],
        ]),
      ),
    );
  }

  // ============================================================
  // Utilidades
  // ============================================================

  IconData _getIconoMedio(String nombre) {
    final n = nombre.toUpperCase();
    if (n.contains('EFECTIVO')) return Icons.money;
    if (n.contains('TARJETA') || n.contains('DEBITO') || n.contains('CREDITO')) return Icons.credit_card;
    if (n.contains('TRANSFER') || n.contains('NEQUI') || n.contains('DAVIPLATA')) return Icons.phone_android;
    if (n.contains('APP') || n.contains('TERPEL')) return Icons.phone_iphone;
    if (n.contains('RAPPI')) return Icons.delivery_dining;
    if (n.contains('BONO') || n.contains('SODEXO') || n.contains('BIGPASS')) return Icons.card_giftcard;
    if (n.contains('GOPASS')) return Icons.directions_car;
    if (n.contains('MI EMPRESA') || n.contains('FLOTA')) return Icons.business;
    if (n.contains('DATAFONO')) return Icons.point_of_sale;
    return Icons.payment;
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

// ============================================================
// DIÁLOGO COUNTDOWN APP TERPEL
// ============================================================
// Réplica del comportamiento Java:
// - Envía POST a localhost:5555/v1/payments/ (vía backend proxy)
// - Muestra countdown configurable (default 30s desde BD)
// - Muestra estado del pago (enviando, esperando, aprobado, rechazado)
// ============================================================

class AppTerpelCountdownDialog extends StatefulWidget {
  final ApiConsultasService apiService;
  final int movimientoId;
  final int cara;
  final double monto;

  const AppTerpelCountdownDialog({
    super.key,
    required this.apiService,
    required this.movimientoId,
    required this.cara,
    required this.monto,
  });

  @override
  State<AppTerpelCountdownDialog> createState() => _AppTerpelCountdownDialogState();
}

class _AppTerpelCountdownDialogState extends State<AppTerpelCountdownDialog>
    with TickerProviderStateMixin {
  
  late AnimationController _countdownController;
  int _tiempoTotal = 30; // Default, se carga desde BD
  int _segundosRestantes = 30;
  
  // Estados del proceso
  bool _enviandoOrquestador = true;
  bool _pagoEnviado = false;
  bool _pagoAprobado = false;
  bool _pagoRechazado = false;
  String _mensajeEstado = 'Enviando pago al orquestador...';
  String _mensajeDetalle = '';
  AppTerpelPagoResponse? _respuestaOrquestador;

  // Suscripción al WebSocket del orquestador
  StreamSubscription<PaymentNotification>? _wsSubscription;

  @override
  void initState() {
    super.initState();
    _countdownController = AnimationController(vsync: this);
    PaymentWebSocketService().countdownDialogActive = true;
    _escucharWebSocket();
    _iniciarProceso();
  }

  @override
  void dispose() {
    PaymentWebSocketService().countdownDialogActive = false;
    _wsSubscription?.cancel();
    _countdownController.dispose();
    super.dispose();
  }

  /// Escuchar notificaciones del orquestador en tiempo real via WebSocket
  void _escucharWebSocket() {
    _wsSubscription = PaymentWebSocketService().notificationStream.listen((notification) {
      if (!mounted) return;
      
      // Solo procesar notificaciones de APP TERPEL (codigo "4")
      if (!notification.isAppTerpel) return;
      
      print('[CountdownDialog] Notificación WS recibida: ${notification.titulo} - ${notification.estado}');
      
      setState(() {
        if (notification.isAprobado) {
          _pagoAprobado = true;
          _pagoRechazado = false;
          _mensajeEstado = 'Pago APROBADO';
          _mensajeDetalle = notification.mensaje;
          _countdownController.stop();
        } else {
          _pagoRechazado = true;
          _pagoAprobado = false;
          _mensajeEstado = 'Pago RECHAZADO';
          _mensajeDetalle = notification.mensaje;
          _countdownController.stop();
        }
      });
    });
  }

  Future<void> _iniciarProceso() async {
    // 1. Cargar tiempo de countdown desde BD (en paralelo con envío)
    final tiempoFuture = widget.apiService.getTiempoMensajeAppTerpel();
    
    // 2. Enviar pago al orquestador
    final response = await widget.apiService.enviarPagoAppTerpel(
      movimientoId: widget.movimientoId,
    );
    
    final tiempo = await tiempoFuture;
    
    if (!mounted) return;
    
    setState(() {
      _tiempoTotal = tiempo;
      _segundosRestantes = tiempo;
      _enviandoOrquestador = false;
      _respuestaOrquestador = response;
      
      if (response.success) {
        _pagoEnviado = true;
        _mensajeEstado = 'Pago enviado correctamente';
        _mensajeDetalle = response.mensajeOrquestador.isNotEmpty 
            ? response.mensajeOrquestador 
            : 'Indique al cliente que escanee el código QR';
        
        if (response.estadoPago.toUpperCase() == 'APROBADO') {
          _pagoAprobado = true;
          _mensajeEstado = 'Pago APROBADO';
        }
      } else {
        _pagoRechazado = true;
        _mensajeEstado = 'Error al enviar pago';
        _mensajeDetalle = response.message;
      }
    });
    
    // 3. Iniciar countdown si fue exitoso
    if (response.success && !_pagoAprobado) {
      _iniciarCountdown();
    }
  }
  
  void _iniciarCountdown() {
    _countdownController.duration = Duration(seconds: _tiempoTotal);
    _countdownController.forward();
    
    _countdownController.addListener(() {
      if (!mounted) return;
      final remaining = (_tiempoTotal * (1 - _countdownController.value)).ceil();
      if (remaining != _segundosRestantes) {
        setState(() => _segundosRestantes = remaining);
      }
    });
    
    _countdownController.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() {
          _mensajeEstado = 'Tiempo agotado';
          _mensajeDetalle = 'El tiempo para escanear el QR ha finalizado';
        });
      }
    });
  }

  Color get _colorEstado {
    if (_pagoAprobado) return Colors.green;
    if (_pagoRechazado) return Colors.red;
    if (_pagoEnviado) return const Color(0xFF6A1B9A);
    return Colors.grey;
  }
  
  IconData get _iconoEstado {
    if (_pagoAprobado) return Icons.check_circle;
    if (_pagoRechazado) return Icons.error;
    if (_enviandoOrquestador) return Icons.cloud_upload;
    if (_pagoEnviado) return Icons.qr_code_2;
    return Icons.hourglass_empty;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      contentPadding: EdgeInsets.zero,
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header púrpura
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFF6A1B9A),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.phone_iphone, color: Colors.white, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('APP TERPEL', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        Text('Cara ${widget.cara}', style: TextStyle(color: Colors.white.withAlpha(200), fontSize: 13)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: Colors.white.withAlpha(40), borderRadius: BorderRadius.circular(8)),
                    child: Text('\$ ${_formatMonto(widget.monto)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            
            // Contenido
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Countdown circular
                  if (_pagoEnviado && !_pagoAprobado && !_pagoRechazado)
                    _buildCountdownCircle(),
                  
                  // Icono de estado
                  if (!_pagoEnviado || _pagoAprobado || _pagoRechazado)
                    _buildIconoEstado(),
                  
                  const SizedBox(height: 16),
                  
                  // Mensaje de estado
                  Text(
                    _mensajeEstado,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _colorEstado,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  if (_mensajeDetalle.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      _mensajeDetalle,
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  
                  // Info de seguimiento
                  if (_respuestaOrquestador != null && _respuestaOrquestador!.idSeguimiento.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.receipt_long, size: 16, color: Colors.grey.shade500),
                          const SizedBox(width: 6),
                          Text(
                            'Seguimiento: ${_respuestaOrquestador!.idSeguimiento}',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                  ],
                  
                  // Instrucciones QR
                  if (_pagoEnviado && !_pagoAprobado && !_pagoRechazado) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.withAlpha(20),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.amber.withAlpha(80)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: Colors.amber, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Indique al cliente que escanee el código QR con la APP Terpel',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            
            // Botón cerrar
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _pagoAprobado 
                        ? Colors.green 
                        : (_pagoRechazado ? Colors.red : const Color(0xFF6A1B9A)),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    _pagoAprobado ? 'CERRAR - PAGO APROBADO' 
                        : (_pagoRechazado ? 'CERRAR' : 'ACEPTAR'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildCountdownCircle() {
    return SizedBox(
      width: 100,
      height: 100,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 100,
            height: 100,
            child: CircularProgressIndicator(
              value: 1 - _countdownController.value,
              strokeWidth: 6,
              color: _segundosRestantes > 10 
                  ? const Color(0xFF6A1B9A) 
                  : (_segundosRestantes > 5 ? Colors.orange : Colors.red),
              backgroundColor: Colors.grey.shade200,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$_segundosRestantes',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: _segundosRestantes > 10 
                      ? const Color(0xFF6A1B9A) 
                      : (_segundosRestantes > 5 ? Colors.orange : Colors.red),
                ),
              ),
              Text('seg', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildIconoEstado() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _colorEstado.withAlpha(20),
        shape: BoxShape.circle,
      ),
      child: _enviandoOrquestador
          ? SizedBox(
              width: 40, height: 40,
              child: CircularProgressIndicator(strokeWidth: 3, color: _colorEstado),
            )
          : Icon(_iconoEstado, size: 40, color: _colorEstado),
    );
  }
  
  String _formatMonto(double number) {
    if (number >= 1000) {
      return number.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (Match m) => '${m[1]},',
      );
    }
    return number.toStringAsFixed(0);
  }
}
