import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/services/api_consultas_service.dart';
import '../../../../core/services/lazo_express_api_service.dart';
import '../../../../core/services/payment_websocket_service.dart';
import '../../../../core/widgets/teclado_tactil.dart';
import '../widgets/asignar_datos_wizard.dart';
import '../widgets/medio_pago_dialog.dart';

/// Página de Ventas Sin Resolver
/// 
/// Muestra una tabla con las ventas pendientes de resolver.
/// Usa fnc_consultar_ventas_pendientes() igual que Java.
class VentasSinResolverPage extends StatefulWidget {
  const VentasSinResolverPage({super.key});

  @override
  State<VentasSinResolverPage> createState() => _VentasSinResolverPageState();
}

class _VentasSinResolverPageState extends State<VentasSinResolverPage> {
  final ApiConsultasService _apiService = ApiConsultasService();
  final LazoExpressApiService _lazoService = LazoExpressApiService();
  
  List<VentaSinResolver> _ventas = [];
  bool _isLoading = true;
  String? _error;
  VentaSinResolver? _ventaSeleccionada;
  
  // APP TERPEL: estado del pago (se consulta al seleccionar venta APP TERPEL)
  bool _appTerpelPuedeGestionar = false;
  bool _consultandoAppTerpel = false;
  
  // Paginación
  int _paginaActual = 1;
  int _totalPaginas = 1;
  int _totalVentas = 0;
  int? _jornadaId;
  static const int _porPagina = 20;
  
  // ID del equipo para operaciones
  int? _identificadorEquipo;

  // Suscripción al WebSocket para auto-refrescar al recibir notificaciones de pago
  StreamSubscription<PaymentNotification>? _paymentWsSubscription;

  @override
  void initState() {
    super.initState();
    _inicializar();
    _escucharNotificacionesPago();
  }
  
  @override
  void dispose() {
    _paymentWsSubscription?.cancel();
    super.dispose();
  }

  /// Escuchar notificaciones de pago para auto-refrescar la tabla
  void _escucharNotificacionesPago() {
    _paymentWsSubscription = PaymentWebSocketService().notificationStream.listen((notification) {
      if (!mounted) return;
      
      debugPrint('[VentasSinResolver] Notificación de pago recibida: '
          '${notification.titulo} - ${notification.estado ? "APROBADO" : "RECHAZADO"}');
      
      // Refrescar la tabla automáticamente al recibir cualquier notificación de pago
      // (puede ser aprobado o rechazado, en ambos casos la tabla puede cambiar)
      _cargarVentas(pagina: _paginaActual);
    });
  }
  
  Future<void> _inicializar() async {
    _identificadorEquipo = await _lazoService.getIdentificadorEquipo();
    _cargarVentas();
  }

  Future<void> _cargarVentas({int pagina = 1}) async {
    setState(() {
      _isLoading = true;
      _error = null;
      _ventaSeleccionada = null;
    });

    try {
      final response = await _apiService.getVentasSinResolver(
        limite: _porPagina,
        pagina: pagina,
      );
      setState(() {
        _ventas = response.ventas;
        _paginaActual = response.pagina;
        _totalPaginas = response.totalPaginas;
        _totalVentas = response.total;
        _jornadaId = response.jornadaId;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error cargando ventas: $e';
        _isLoading = false;
      });
    }
  }
  
  void _paginaAnterior() {
    if (_paginaActual > 1) _cargarVentas(pagina: _paginaActual - 1);
  }
  
  void _paginaSiguiente() {
    if (_paginaActual < _totalPaginas) _cargarVentas(pagina: _paginaActual + 1);
  }

  /// Consulta el estado del pago APP TERPEL para una venta.
  /// Si el pago falló, habilita los botones de gestión.
  Future<void> _verificarEstadoAppTerpel(VentaSinResolver venta) async {
    final procesoUpper = venta.proceso.toUpperCase();
    final esAppTerpel = procesoUpper.contains('APP TERPEL') || procesoUpper.contains('APPTERPEL');
    
    if (!esAppTerpel) return;
    
    setState(() => _consultandoAppTerpel = true);
    
    final estado = await _apiService.getAppTerpelEstado(venta.id);
    
    if (!mounted) return;
    setState(() {
      _consultandoAppTerpel = false;
      _appTerpelPuedeGestionar = estado.puedeGestionar;
    });
    
    if (estado.puedeGestionar) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.warning_amber, color: Colors.white),
              SizedBox(width: 12),
              Expanded(child: Text('Pago APP TERPEL falló - puede asignar otro medio')),
            ],
          ),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFBA0C2F), Color(0xFF8B0A24)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withAlpha(51), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: Column(
                    children: [
                      _buildAccionesBar(),
                      Expanded(child: _buildContenido()),
                      if (_totalVentas > 0) _buildPaginacion(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // Header
  // ============================================================

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          InkWell(
            onTap: () => Navigator.pop(context),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.white.withAlpha(51), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(child: Text('VENTAS SIN RESOLVER', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(color: Colors.white.withAlpha(51), borderRadius: BorderRadius.circular(20)),
            child: Text('$_totalVentas ventas', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
          ),
          if (_jornadaId != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: Colors.green.withAlpha(150), borderRadius: BorderRadius.circular(20)),
              child: Text('Jornada: $_jornadaId', style: const TextStyle(color: Colors.white, fontSize: 12)),
            ),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // Barra de acciones
  // ============================================================

  Widget _buildAccionesBar() {
    final bool haySeleccion = _ventaSeleccionada != null;
    final procesoUpper = _ventaSeleccionada?.proceso.toUpperCase() ?? '';
    final bool esRumbo = procesoUpper.contains('RUMBO') || procesoUpper.contains('UREA');
    final bool esUrea = procesoUpper.contains('UREA');
    final bool esAppTerpel = procesoUpper.contains('APP TERPEL') || procesoUpper.contains('APPTERPEL');
    final bool puedeGestionar = haySeleccion && !esUrea && (!esAppTerpel || _appTerpelPuedeGestionar);
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildBotonAccion(icon: Icons.refresh, label: 'Refrescar', onTap: _cargarVentas, activo: true),
            const SizedBox(width: 10),
            _buildBotonAccion(icon: Icons.person_add, label: 'Asignar Datos', onTap: puedeGestionar ? _mostrarDialogoAsignarDatos : null, activo: puedeGestionar),
            const SizedBox(width: 10),
            _buildBotonAccion(icon: Icons.send, label: 'Enviar Venta', onTap: puedeGestionar ? _enviarVenta : null, activo: puedeGestionar, color: Colors.blue),
            const SizedBox(width: 10),
            _buildBotonAccion(icon: Icons.local_gas_station, label: 'RUMBO/UREA', onTap: haySeleccion && esRumbo ? _mostrarDialogoFinalizarRumbo : null, activo: haySeleccion && esRumbo, color: Colors.purple),
            // Badge de estado APP TERPEL
            if (haySeleccion && esAppTerpel) ...[
              const SizedBox(width: 10),
              _buildAppTerpelBadge(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAppTerpelBadge() {
    if (_consultandoAppTerpel) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8)),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: 8),
          Text('Consultando estado...', style: TextStyle(fontSize: 12)),
        ]),
      );
    }
    
    if (_appTerpelPuedeGestionar) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(color: Colors.orange.withAlpha(20), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.orange.withAlpha(80))),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.warning_amber, color: Colors.orange, size: 18),
          SizedBox(width: 6),
          Text('Pago APP TERPEL falló - Puede asignar otro medio', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.w600, fontSize: 12)),
        ]),
      );
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: const Color(0xFF6A1B9A).withAlpha(20), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF6A1B9A).withAlpha(80))),
      child: const Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.phone_iphone, color: Color(0xFF6A1B9A), size: 18),
        SizedBox(width: 6),
        Text('Pago en proceso por orquestador', style: TextStyle(color: Color(0xFF6A1B9A), fontWeight: FontWeight.w600, fontSize: 12)),
      ]),
    );
  }

  Widget _buildBotonAccion({required IconData icon, required String label, VoidCallback? onTap, required bool activo, Color? color}) {
    final Color colorFondo = activo ? (color ?? const Color(0xFFBA0C2F)) : Colors.grey.shade400;
    return InkWell(
      onTap: activo ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(color: colorFondo, borderRadius: BorderRadius.circular(8)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
        ]),
      ),
    );
  }

  // ============================================================
  // Acciones: Medio de Pago, Asignar Datos, Enviar Venta, Rumbo
  // ============================================================
  
  void _mostrarDialogoMedioPago() async {
    if (_ventaSeleccionada == null) return;
    
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => MedioPagoDialog(
        venta: _ventaSeleccionada!,
        lazoService: _lazoService,
        apiService: _apiService,
      ),
    );
    
    if (result == true) _cargarVentas();
  }

  void _mostrarDialogoAsignarDatos() {
    if (_ventaSeleccionada == null) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AsignarDatosWizard(
        venta: _ventaSeleccionada!,
        lazoService: _lazoService,
        identificadorEquipo: _identificadorEquipo ?? 1,
        onComplete: () => _cargarVentas(pagina: _paginaActual),
      ),
    );
  }

  Future<void> _enviarVenta() async {
    if (_ventaSeleccionada == null) return;
    
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [Icon(Icons.send, color: Colors.blue), SizedBox(width: 12), Text('ENVIAR VENTA')]),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('¿Desea enviar la venta #${_ventaSeleccionada!.id}?'),
          const SizedBox(height: 8),
          Text('Total: ${_ventaSeleccionada!.totalFormateado}', style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.blue.withAlpha(20), borderRadius: BorderRadius.circular(8)),
            child: const Row(children: [
              Icon(Icons.info_outline, color: Colors.blue, size: 18),
              SizedBox(width: 8),
              Expanded(child: Text('Se enviará la venta al sistema para su procesamiento.', style: TextStyle(fontSize: 12))),
            ]),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
    
    if (confirmar != true) return;
    
    _mostrarLoading('Enviando venta...');
    
    final ventaData = {'identificadorMovimiento': _ventaSeleccionada!.id};
    final response = await _lazoService.enviarVenta(ventaData: ventaData);

    if (!mounted) return;
    Navigator.pop(context);
    
    if (response.success) {
      _mostrarExito(response.message);
      _cargarVentas(pagina: _paginaActual);
    } else {
      _mostrarError(response.message);
    }
  }

  void _mostrarDialogoFinalizarRumbo() {
    if (_ventaSeleccionada == null) return;
    
    final venta = _ventaSeleccionada!;
    final esUrea = venta.proceso.toUpperCase().contains('UREA');
    
    if (esUrea) {
      _mostrarDialogoFinalizarUrea(venta);
    } else {
      _mostrarDialogoRumboGenerico(venta);
    }
  }

  void _mostrarDialogoFinalizarUrea(VentaSinResolver venta) async {
    // Obtener detalles UREA del backend (precio, litros, placa)
    final detalles = await _apiService.getDetallesUreaVenta(venta.id);
    
    if (!mounted) return;
    
    final placa = detalles['placa'] ?? venta.placa ?? '-';
    final precioUrea = (detalles['precio'] as num?)?.toDouble() ?? 0;
    final litrosAutorizados = (detalles['litros_autorizados'] as num?)?.toDouble() ?? 0;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _UreaFinalizarDialog(
        ventaId: venta.id,
        placa: placa,
        precioUrea: precioUrea,
        litrosAutorizados: litrosAutorizados,
        onFinalizar: (cantidad) async {
          Navigator.pop(ctx);
          _mostrarLoading('Finalizando venta UREA...');
          
          final resultado = await _apiService.finalizarUreaSinResolver(
            movimientoId: venta.id,
            cantidadSuministrada: cantidad,
            precioUrea: precioUrea,
          );
          
          if (!mounted) return;
          Navigator.pop(context); // loading
          
          if (resultado['exito'] == true) {
            _mostrarExito(resultado['mensaje'] ?? 'Venta UREA finalizada');
            _cargarVentas(pagina: _paginaActual);
          } else {
            _mostrarError(resultado['mensaje'] ?? 'Error al finalizar');
          }
        },
      ),
    );
  }
  
  void _mostrarDialogoRumboGenerico(VentaSinResolver venta) {
    final documentoController = TextEditingController();
    final nombreController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.local_gas_station, color: Colors.purple),
          SizedBox(width: 12),
          Expanded(child: Text('DATOS RUMBO', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
        ]),
        content: SizedBox(
          width: 400,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.purple.withAlpha(20), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.purple.withAlpha(100))),
              child: Row(children: [
                const Icon(Icons.receipt_long, color: Colors.purple),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Venta #${venta.id}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(venta.totalFormateado, style: const TextStyle(color: Colors.purple, fontWeight: FontWeight.bold)),
                ])),
              ]),
            ),
            const SizedBox(height: 20),
            TextField(controller: documentoController, decoration: const InputDecoration(labelText: 'Documento del cliente *', prefixIcon: Icon(Icons.badge), border: OutlineInputBorder()), keyboardType: TextInputType.number, autofocus: true),
            const SizedBox(height: 16),
            TextField(controller: nombreController, decoration: const InputDecoration(labelText: 'Nombre del cliente *', prefixIcon: Icon(Icons.person), border: OutlineInputBorder()), textCapitalization: TextCapitalization.characters),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              final doc = documentoController.text.trim();
              final nombre = nombreController.text.trim();
              if (doc.isEmpty || nombre.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Complete todos los campos'), backgroundColor: Colors.orange));
                return;
              }
              _procesarDatosRumbo(documento: doc, nombre: nombre);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, foregroundColor: Colors.white),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }
  
  Future<void> _procesarDatosRumbo({required String documento, required String nombre}) async {
    Navigator.pop(context);
    _mostrarLoading('Guardando datos RUMBO...');
    
    final response = await _lazoService.actualizarDatosRumbo(
      identificadorMovimiento: _ventaSeleccionada!.id,
      identificadorEquipo: _identificadorEquipo ?? 1,
      documentoCliente: documento,
      nombreCliente: nombre,
    );

    if (!mounted) return;
    Navigator.pop(context);
    if (response.success) {
      _mostrarExito(response.message);
      _cargarVentas(pagina: _paginaActual);
    } else {
      _mostrarError(response.message);
    }
  }

  Future<void> _procesarMedioPago(MedioPago medio, double total) async {
    Navigator.pop(context);
    _mostrarLoading('Procesando medio de pago...');
    
    final medioPagoVenta = MedioPagoVenta(
      ctMediosPagosId: medio.id,
      valorTotal: total,
      valorRecibido: total,
      valorCambio: 0,
      codigoDian: medio.codigoDian,
    );
    
    final response = await _lazoService.actualizarMediosPago(
      identificadorMovimiento: _ventaSeleccionada!.id,
      mediosPagos: [medioPagoVenta],
      identificadorEquipo: _identificadorEquipo ?? 1,
    );
    
    Navigator.pop(context);
    if (response.success) {
      _mostrarExito(response.message);
      _cargarVentas(pagina: _paginaActual);
    } else {
      _mostrarError(response.message);
    }
  }

  // ============================================================
  // Helpers UI
  // ============================================================
  
  void _mostrarLoading(String mensaje) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        content: Row(children: [const CircularProgressIndicator(color: Color(0xFFBA0C2F)), const SizedBox(width: 20), Text(mensaje)]),
      ),
    );
  }
  
  void _mostrarExito(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [const Icon(Icons.check_circle, color: Colors.white), const SizedBox(width: 12), Expanded(child: Text(mensaje))]),
      backgroundColor: Colors.green,
      duration: const Duration(seconds: 3),
    ));
  }
  
  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [const Icon(Icons.error, color: Colors.white), const SizedBox(width: 12), Expanded(child: Text(mensaje))]),
      backgroundColor: Colors.red,
      duration: const Duration(seconds: 4),
    ));
  }

  // ============================================================
  // Contenido: Loading / Error / Vacío / Tabla
  // ============================================================

  Widget _buildContenido() {
    if (_isLoading) {
      return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        CircularProgressIndicator(color: Color(0xFFBA0C2F)),
        SizedBox(height: 16),
        Text('Cargando ventas...'),
      ]));
    }

    if (_error != null) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
        const SizedBox(height: 16),
        Text(_error!, style: const TextStyle(color: Colors.red)),
        const SizedBox(height: 16),
        ElevatedButton.icon(onPressed: _cargarVentas, icon: const Icon(Icons.refresh), label: const Text('Reintentar')),
      ]));
    }

    if (_ventas.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.check_circle_outline, size: 64, color: Colors.green.shade300),
        const SizedBox(height: 16),
        const Text('¡No hay ventas pendientes!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text('Todas las ventas están resueltas', style: TextStyle(color: Colors.grey.shade600)),
      ]));
    }

    return _buildTabla();
  }

  // ============================================================
  // Tabla de ventas
  // ============================================================

  Widget _buildTabla() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(const Color(0xFFBA0C2F).withAlpha(25)),
                dataRowMinHeight: 52,
                dataRowMaxHeight: 60,
                columnSpacing: 24,
                horizontalMargin: 20,
                columns: const [
                  DataColumn(label: Text('PREFIJO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                  DataColumn(label: Text('# VENTA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                  DataColumn(label: Text('FECHA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                  DataColumn(label: Text('PRODUCTO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                  DataColumn(label: Text('CANTIDAD', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                  DataColumn(label: Text('TOTAL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)), numeric: true),
                  DataColumn(label: Text('PROCESO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                  DataColumn(label: Text('PLACA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                ],
                rows: _ventas.map((venta) {
                  final isSelected = _ventaSeleccionada?.id == venta.id;
                  return DataRow(
                    selected: isSelected,
                    color: WidgetStateProperty.resolveWith<Color?>((states) => isSelected ? const Color(0xFFBA0C2F).withAlpha(30) : null),
                    onSelectChanged: (selected) {
                      setState(() {
                        _ventaSeleccionada = selected == true ? venta : null;
                        _appTerpelPuedeGestionar = false;
                      });
                      if (selected == true) _verificarEstadoAppTerpel(venta);
                    },
                    cells: [
                      DataCell(Text(venta.prefijo, style: const TextStyle(fontSize: 13))),
                      DataCell(Text('${venta.id}', style: const TextStyle(fontSize: 13))),
                      DataCell(Text(_formatFecha(venta.fecha), style: const TextStyle(fontSize: 13))),
                      DataCell(ConstrainedBox(constraints: const BoxConstraints(maxWidth: 180), child: Text(venta.producto, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)))),
                      DataCell(Text(venta.cantidadFormateada, style: const TextStyle(fontSize: 13))),
                      DataCell(Text(venta.totalFormateado, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                      DataCell(_buildProcesoChip(venta.proceso)),
                      DataCell(Text(venta.placa ?? '-', style: const TextStyle(fontSize: 13))),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProcesoChip(String proceso) {
    Color color;
    switch (proceso.toUpperCase()) {
      case 'FE': color = Colors.orange; break;
      case 'DATAFONO': color = Colors.blue; break;
      case 'UREA': case 'RUMBO': color = Colors.purple; break;
      default: color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withAlpha(30), borderRadius: BorderRadius.circular(12), border: Border.all(color: color)),
      child: Text(proceso, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }

  String _formatFecha(String fecha) {
    try {
      if (fecha.length >= 16) return '${fecha.substring(8, 10)}/${fecha.substring(5, 7)} ${fecha.substring(11, 16)}';
      return fecha;
    } catch (e) {
      return fecha;
    }
  }

  // ============================================================
  // Paginación
  // ============================================================

  Widget _buildPaginacion() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(onPressed: _paginaActual > 1 ? _paginaAnterior : null, icon: const Icon(Icons.chevron_left), color: const Color(0xFFBA0C2F), disabledColor: Colors.grey.shade400),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(color: const Color(0xFFBA0C2F).withAlpha(20), borderRadius: BorderRadius.circular(20)),
            child: Text('Página $_paginaActual de $_totalPaginas', style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFFBA0C2F))),
          ),
          IconButton(onPressed: _paginaActual < _totalPaginas ? _paginaSiguiente : null, icon: const Icon(Icons.chevron_right), color: const Color(0xFFBA0C2F), disabledColor: Colors.grey.shade400),
          const SizedBox(width: 20),
          Text('Mostrando ${_ventas.length} de $_totalVentas', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
        ],
      ),
    );
  }
}


/// Diálogo fullscreen para finalizar venta UREA en "Ventas sin resolver"
/// Replica la pantalla Java de VentasHistorialView con:
/// Placa, Precio, Litros autorizados, Total venta (calculado), Cantidad suministrada + teclado táctil
class _UreaFinalizarDialog extends StatefulWidget {
  final int ventaId;
  final String placa;
  final double precioUrea;
  final double litrosAutorizados;
  final Future<void> Function(double cantidad) onFinalizar;

  const _UreaFinalizarDialog({
    required this.ventaId,
    required this.placa,
    required this.precioUrea,
    required this.litrosAutorizados,
    required this.onFinalizar,
  });

  @override
  State<_UreaFinalizarDialog> createState() => _UreaFinalizarDialogState();
}

class _UreaFinalizarDialogState extends State<_UreaFinalizarDialog> {
  final TextEditingController _cantidadCtrl = TextEditingController();
  bool _procesando = false;

  double get _cantidad => double.tryParse(_cantidadCtrl.text.trim()) ?? 0;
  double get _totalVenta => _cantidad * widget.precioUrea;
  bool get _cantidadValida => _cantidad > 0 && _cantidad <= widget.litrosAutorizados;

  @override
  void initState() {
    super.initState();
    _cantidadCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _cantidadCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 750,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.purple.shade700,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(children: [
              const Icon(Icons.local_gas_station, color: Colors.white, size: 24),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('FINALIZAR RUMBO UREA', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              InkWell(
                onTap: _procesando ? null : () => Navigator.pop(context),
                child: const Icon(Icons.close, color: Colors.white),
              ),
            ]),
          ),
          // Contenido: datos + teclado
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Panel izquierdo: datos de la venta
              Expanded(
                flex: 3,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _buildRow('Placa', widget.placa),
                    const Divider(height: 16),
                    _buildRow('Precio', '\$ ${_formatNumber(widget.precioUrea)}'),
                    const Divider(height: 16),
                    _buildRow('Litros autorizados', widget.litrosAutorizados.toStringAsFixed(1)),
                    const Divider(height: 16),
                    _buildRow('Total venta', '\$ ${_formatNumber(_totalVenta)}',
                        valorColor: const Color(0xFFBA0C2F)),
                    const Divider(height: 16),
                    // Campo cantidad suministrada
                    const Text('Cantidad suministrada urea',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF494951)),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _cantidadCtrl,
                      readOnly: true, // Solo se escribe con TecladoTactil
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: _cantidadCtrl.text.isNotEmpty && !_cantidadValida ? Colors.red : const Color(0xFFBA0C2F),
                            width: 2,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: _cantidadCtrl.text.isNotEmpty && !_cantidadValida ? Colors.red : const Color(0xFFBA0C2F),
                            width: 2,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    if (_cantidadCtrl.text.isNotEmpty && _cantidad > widget.litrosAutorizados) ...[
                      const SizedBox(height: 6),
                      Text('Supera el máximo autorizado (${widget.litrosAutorizados.toStringAsFixed(1)})',
                        style: TextStyle(color: Colors.red.shade700, fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ]),
                ),
              ),
              const SizedBox(width: 16),
              // Panel derecho: teclado numérico
              SizedBox(
                width: 250,
                child: Column(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    alignment: Alignment.center,
                    child: Text('Cantidad suministrada',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                    ),
                  ),
                  TecladoTactil(
                    controller: _cantidadCtrl,
                    soloNumeros: true,
                    height: 300,
                    onAceptar: (_cantidadValida && !_procesando) ? () async {
                      setState(() => _procesando = true);
                      await widget.onFinalizar(_cantidad);
                    } : null,
                  ),
                ]),
              ),
            ]),
          ),
          // Botón finalizar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: (_cantidadValida && !_procesando) ? () async {
                  setState(() => _procesando = true);
                  await widget.onFinalizar(_cantidad);
                } : null,
                icon: _procesando
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.check_circle, size: 22),
                label: Text(
                  _procesando ? 'FINALIZANDO...' : 'FINALIZAR RUMBO UREA',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple.shade700,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade400,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildRow(String label, String value, {Color? valorColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        Expanded(flex: 3, child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF494951)))),
        Expanded(flex: 2, child: Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: valorColor ?? const Color(0xFFBA0C2F)))),
      ]),
    );
  }

  String _formatNumber(double value) {
    if (value == value.truncateToDouble()) {
      return value.toInt().toString().replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');
    }
    return value.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');
  }
}
