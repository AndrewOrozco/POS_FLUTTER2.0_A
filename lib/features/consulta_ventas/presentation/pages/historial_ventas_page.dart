import 'package:flutter/material.dart';
import '../../../../core/services/api_consultas_service.dart';
import '../../../fidelizacion/presentation/widgets/fidelizar_dialog.dart';

/// Página de Historial de Ventas
/// 
/// Muestra una tabla con el historial de ventas.
/// Usa fnc_consultar_ventas() igual que Java.
class HistorialVentasPage extends StatefulWidget {
  const HistorialVentasPage({super.key});

  @override
  State<HistorialVentasPage> createState() => _HistorialVentasPageState();
}

class _HistorialVentasPageState extends State<HistorialVentasPage> {
  final ApiConsultasService _apiService = ApiConsultasService();
  
  List<VentaHistorial> _ventas = [];
  bool _isLoading = true;
  String? _error;
  VentaHistorial? _ventaSeleccionada;
  
  // Paginación
  int _paginaActual = 1;
  int _totalPaginas = 1;
  int _totalVentas = 0;
  int? _jornadaId;
  static const int _porPagina = 20;

  @override
  void initState() {
    super.initState();
    _cargarVentas();
  }

  Future<void> _cargarVentas({int pagina = 1}) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await _apiService.getHistorialVentas(
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
        _error = 'Error cargando historial: $e';
        _isLoading = false;
      });
    }
  }
  
  void _paginaAnterior() {
    if (_paginaActual > 1) {
      _cargarVentas(pagina: _paginaActual - 1);
    }
  }
  
  void _paginaSiguiente() {
    if (_paginaActual < _totalPaginas) {
      _cargarVentas(pagina: _paginaActual + 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFBA0C2F), // Rojo Terpel
              Color(0xFF8B0A24),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              _buildHeader(),
              
              // Contenido
              Expanded(
                child: Container(
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(51),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Barra de acciones
                      _buildAccionesBar(),
                      
                      // Tabla de ventas
                      Expanded(
                        child: _buildContenido(),
                      ),
                      
                      // Barra de paginación
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

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Botón volver
          InkWell(
            onTap: () => Navigator.pop(context),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(51),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.arrow_back,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
          
          const SizedBox(width: 16),
          
          // Título
          const Expanded(
            child: Text(
              'HISTORIAL DE VENTAS',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          
          // Total de ventas
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(51),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$_totalVentas ventas',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          
          if (_jornadaId != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green.withAlpha(150),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Jornada: $_jornadaId',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAccionesBar() {
    final bool haySeleccion = _ventaSeleccionada != null;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          // Botón refrescar
          _buildBotonAccion(
            icon: Icons.refresh,
            label: 'Refrescar',
            onTap: _cargarVentas,
            activo: true,
          ),
          
          const SizedBox(width: 12),
          
          // Botón medio de pago
          _buildBotonAccion(
            icon: Icons.payment,
            label: 'Medio Pago',
            onTap: haySeleccion ? () => _mostrarMensaje('Medio de pago') : null,
            activo: haySeleccion,
          ),
          
          const SizedBox(width: 12),
          
          // Botón fidelizar (solo si no fue fidelizada y dentro de 3 min)
          _buildBotonAccion(
            icon: Icons.card_giftcard,
            label: 'Fidelizar',
            onTap: (haySeleccion && _ventaSeleccionada!.puedeFidelizar)
                ? _fidelizar
                : (haySeleccion ? () => _mostrarErrorFidelizacion() : null),
            activo: haySeleccion,
          ),
          
          const SizedBox(width: 12),
          
          // Botón imprimir
          _buildBotonAccion(
            icon: Icons.print,
            label: 'Imprimir',
            onTap: haySeleccion ? _imprimir : null,
            activo: haySeleccion,
          ),
          
          const SizedBox(width: 12),
          
          // Botón facturar
          _buildBotonAccion(
            icon: Icons.receipt_long,
            label: 'Facturar',
            onTap: haySeleccion ? () => _mostrarMensaje('Facturar') : null,
            activo: haySeleccion,
          ),
        ],
      ),
    );
  }

  Widget _buildBotonAccion({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
    required bool activo,
  }) {
    final Color colorFondo = activo 
        ? const Color(0xFFBA0C2F) 
        : Colors.grey.shade400;
    
    return InkWell(
      onTap: activo ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: colorFondo,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContenido() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFFBA0C2F)),
            SizedBox(height: 16),
            Text('Cargando historial...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _cargarVentas,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    if (_ventas.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              'No hay ventas en el historial',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Las ventas aparecerán aquí cuando se registren',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return _buildTabla();
  }

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
                  DataColumn(label: Text('OPERADOR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                  DataColumn(label: Text('PLACA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                ],
                rows: _ventas.map((venta) {
                  final isSelected = _ventaSeleccionada?.id == venta.id;
                  
                  return DataRow(
                    selected: isSelected,
                    color: WidgetStateProperty.resolveWith<Color?>((states) {
                      if (isSelected) {
                        return const Color(0xFFBA0C2F).withAlpha(30);
                      }
                      return null;
                    }),
                    onSelectChanged: (selected) {
                      setState(() {
                        _ventaSeleccionada = selected == true ? venta : null;
                      });
                    },
                    cells: [
                      DataCell(Text(venta.prefijo, style: const TextStyle(fontSize: 13))),
                      DataCell(Text('${venta.id}', style: const TextStyle(fontSize: 13))),
                      DataCell(Text(_formatFecha(venta.fecha), style: const TextStyle(fontSize: 13))),
                      DataCell(
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 180),
                          child: Text(
                            venta.producto,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ),
                      DataCell(Text(venta.cantidadFormateada, style: const TextStyle(fontSize: 13))),
                      DataCell(Text(
                        venta.totalFormateado,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      )),
                      DataCell(
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 140),
                          child: Text(
                            venta.operador,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ),
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

  String _formatFecha(String fecha) {
    try {
      // El formato viene como "2025-02-05 14:30:00"
      if (fecha.length >= 16) {
        return '${fecha.substring(8, 10)}/${fecha.substring(5, 7)} ${fecha.substring(11, 16)}';
      }
      return fecha;
    } catch (e) {
      return fecha;
    }
  }

  Widget _buildPaginacion() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Botón anterior
          IconButton(
            onPressed: _paginaActual > 1 ? _paginaAnterior : null,
            icon: const Icon(Icons.chevron_left),
            color: const Color(0xFFBA0C2F),
            disabledColor: Colors.grey.shade400,
          ),
          
          // Info de página
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFBA0C2F).withAlpha(20),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Página $_paginaActual de $_totalPaginas',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFFBA0C2F),
              ),
            ),
          ),
          
          // Botón siguiente
          IconButton(
            onPressed: _paginaActual < _totalPaginas ? _paginaSiguiente : null,
            icon: const Icon(Icons.chevron_right),
            color: const Color(0xFFBA0C2F),
            disabledColor: Colors.grey.shade400,
          ),
          
          const SizedBox(width: 20),
          
          // Info total
          Text(
            'Mostrando ${_ventas.length} de $_totalVentas',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  void _fidelizar() async {
    if (_ventaSeleccionada == null) return;

    final venta = _ventaSeleccionada!;
    
    // Doble check de seguridad
    if (!venta.puedeFidelizar) {
      _mostrarErrorFidelizacion();
      return;
    }

    final resultado = await mostrarFidelizarDialog(
      context,
      movimientoId: venta.id,
      ventaInfo: 'Venta ${venta.prefijo} - ${venta.producto} - \$${venta.total}',
    );

    if (resultado == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Text('Venta fidelizada correctamente'),
            ],
          ),
          backgroundColor: Colors.green,
        ),
      );
      // Recargar historial para reflejar el cambio
      _cargarVentas(pagina: _paginaActual);
    }
  }

  void _mostrarErrorFidelizacion() {
    if (_ventaSeleccionada == null) return;
    final motivo = _ventaSeleccionada!.motivoNoFidelizar;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(motivo.isNotEmpty ? motivo : 'No se puede fidelizar esta venta')),
          ],
        ),
        backgroundColor: Colors.orange.shade800,
      ),
    );
  }

  void _imprimir() async {
    if (_ventaSeleccionada == null) return;

    final venta = _ventaSeleccionada!;

    // Mostrar indicador de carga
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Text('Imprimiendo venta ${venta.prefijo}...'),
          ],
        ),
        backgroundColor: Colors.blue.shade700,
        duration: const Duration(seconds: 2),
      ),
    );

    final resultado = await _apiService.imprimirVenta(
      movimientoId: venta.id,
    );

    if (!mounted) return;

    // Limpiar snackbar anterior
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    if (resultado['exito'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.print, color: Colors.white),
              SizedBox(width: 12),
              Text('Impresión enviada correctamente'),
            ],
          ),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text(resultado['mensaje'] ?? 'Error al imprimir')),
            ],
          ),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  void _mostrarMensaje(String accion) {
    if (_ventaSeleccionada == null) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$accion - Venta #${_ventaSeleccionada!.id}'),
        backgroundColor: const Color(0xFFBA0C2F),
      ),
    );
  }
}
