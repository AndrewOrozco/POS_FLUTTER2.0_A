import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/widgets/supervisor_authorization_dialog.dart';
import '../../../../core/services/api_consultas_service.dart';

class AnulacionesView extends StatefulWidget {
  const AnulacionesView({Key? key}) : super(key: key);

  @override
  State<AnulacionesView> createState() => _AnulacionesViewState();
}

class _AnulacionesViewState extends State<AnulacionesView> {
  final _apiService = ApiConsultasService();
  
  DateTime _fechaInicio = DateTime.now().subtract(const Duration(days: 1));
  DateTime _fechaFin = DateTime.now();

  bool _isLoading = false;
  List<dynamic> _ventas = [];
  List<dynamic> _motivos = [];
  int? _selectedIndex;

  @override
  void initState() {
    super.initState();
    _cargarMotivos();
    _consultarVentas();
  }

  Future<void> _cargarMotivos() async {
    final res = await _apiService.getMotivosAnulacion();
    if (mounted) setState(() => _motivos = res);
  }

  Future<void> _consultarVentas() async {
    setState(() {
      _isLoading = true;
      _selectedIndex = null;
    });
    
    final fIniStr = DateFormat('yyyy-MM-dd').format(_fechaInicio);
    final fFinStr = DateFormat('yyyy-MM-dd').format(_fechaFin);
    
    final res = await _apiService.consultarVentasAnulables(fIniStr, fFinStr);
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (res['exito'] == true) {
          _ventas = res['data'] ?? [];
        } else {
          _ventas = [];
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${res['error']}'), backgroundColor: Colors.red),
          );
        }
      });
    }
  }

  Future<void> _seleccionarFecha(BuildContext context, bool isInicio) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isInicio ? _fechaInicio : _fechaFin,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: const Color(0xFFBA0C2F),
            colorScheme: const ColorScheme.light(primary: Color(0xFFBA0C2F)),
            buttonTheme: const ButtonThemeData(textTheme: ButtonTextTheme.primary),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isInicio) {
          _fechaInicio = picked;
        } else {
          _fechaFin = picked;
        }
      });
      _consultarVentas();
    }
  }

  Future<void> _abrirSelectorMotivo(int ventaId) async {
    if (_motivos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cargando motivos...'), backgroundColor: Colors.orange));
      await _cargarMotivos();
      if (_motivos.isEmpty) return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('Seleccione el Motivo de Anulación', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          const Divider(),
          Expanded(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _motivos.length,
              itemBuilder: (ctx, i) {
                final m = _motivos[i];
                return ListTile(
                  title: Center(child: Text(m['descripcion'].toString(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                  onTap: () {
                    Navigator.pop(ctx);
                    _confirmarYEjecutarAnulacion(ventaId, int.parse(m['codigo'].toString()));
                  },
                );
              },
            ),
          )
        ],
      )
    );
  }

  Future<void> _confirmarYEjecutarAnulacion(int ventaId, int motivoCod) async {
    final autorizado = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => SupervisorAuthorizationDialog(
        onAuthorize: (username, password) async {
          await Future.delayed(const Duration(seconds: 1)); // Simula validación red auth
          return username == 'admin' && password == '1234';
        },
      ),
    );

    if (autorizado == true && mounted) {
      // 1 = supervisor local harcodeado, 1 = promotor auth id
      final res = await _apiService.ejecutarAnulacion(ventaId: ventaId, supervisorId: 1, motivoCodigo: motivoCod, promotorId: 1);
      
      if (res['exito'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['mensaje'] ?? 'Guardado exitosamente'), backgroundColor: Colors.green));
        _consultarVentas();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${res['mensaje']}'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.grey.shade50, Colors.grey.shade100],
        ),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // HEADER PREMIUM
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFBA0C2F), Color(0xFF8A001A)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: const Color(0xFFBA0C2F).withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 4))]
                ),
                child: const Icon(Icons.cancel_presentation, size: 28, color: Colors.white),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Consulta de Anulaciones', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF1A1A1A), letterSpacing: -0.5)),
                    Text('Selector de reversiones y devoluciones pre-facturadas', style: TextStyle(fontSize: 14, color: Colors.grey)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // FILTROS DATE PICKER
          Row(
            children: [
              _buildDateWidget('Fecha Inicial', _fechaInicio, () => _seleccionarFecha(context, true)),
              const SizedBox(width: 16),
              _buildDateWidget('Fecha Final', _fechaFin, () => _seleccionarFecha(context, false)),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _consultarVentas,
                icon: const Icon(Icons.refresh),
                label: const Text('ACTUALIZAR'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFBA0C2F),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              )
            ],
          ),
          const SizedBox(height: 24),

          // TABLA RESULTADOS Y DETALLES
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // PANEL IZQUIERDO: TABLA
                Expanded(
                  flex: 3,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 24, offset: const Offset(0, 12))
                      ]
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: _isLoading 
                        ? const Center(child: CircularProgressIndicator(color: Color(0xFFBA0C2F)))
                        : _ventas.isEmpty
                          ? const Center(child: Text('No se encontraron ventas para este rango.', style: TextStyle(fontSize: 18, color: Colors.grey)))
                          : SingleChildScrollView(
                              child: SizedBox(
                                width: double.infinity,
                                child: DataTable(
                                  showCheckboxColumn: false,
                                  headingRowColor: MaterialStateProperty.all(const Color(0xFFBA0C2F)),
                                  headingTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                  dataRowMaxHeight: 60,
                                  dataRowMinHeight: 60,
                                  columns: const [
                                    DataColumn(label: Text('PREFIJO')),
                                    DataColumn(label: Text('NRO')),
                                    DataColumn(label: Text('FECHA')),
                                    DataColumn(label: Text('PROMOTOR')),
                                    DataColumn(label: Text('VALOR')),
                                  ],
                                  rows: List.generate(_ventas.length, (i) {
                                    final venta = _ventas[i];
                                    final isSelected = _selectedIndex == i;
                                    return DataRow(
                                      selected: isSelected,
                                      onSelectChanged: (b) => setState(() => _selectedIndex = i),
                                      color: MaterialStateProperty.resolveWith<Color?>((Set<MaterialState> states) {
                                        if (states.contains(MaterialState.selected)) return const Color(0xFFFFB600).withOpacity(0.3); // Yellow Terpel
                                        return i.isEven ? Colors.grey.shade50 : Colors.white;
                                      }),
                                      cells: [
                                        DataCell(Text(venta['prefijo'].toString(), style: const TextStyle(fontWeight: FontWeight.bold))),
                                        DataCell(Text(venta['nro'].toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                                        DataCell(Text(venta['fecha'].toString())),
                                        DataCell(Text(venta['promotor'].toString())),
                                        DataCell(Text('\$ ${NumberFormat("#,##0", "es_CO").format(venta['valor'])}', style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFBA0C2F)))),
                                      ],
                                    );
                                  }),
                                ),
                              ),
                            ),
                    )
                  ),
                ),
                
                const SizedBox(width: 24),
                
                // PANEL DERECHO: DETALLE FACTURA
                Expanded(
                  flex: 2,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey.shade200, width: 2),
                    ),
                    child: _selectedIndex == null 
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.touch_app, size: 60, color: Colors.grey.shade300),
                            const SizedBox(height: 16),
                            Text('Seleccione una venta para\nver el detalle y anular', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
                          ],
                        )
                      : _buildDetalleVenta(_ventas[_selectedIndex!]),
                  )
                )
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          // FOOTER / ACCIONES
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton.icon(
                onPressed: _selectedIndex == null ? null : () {
                  final venta = _ventas[_selectedIndex!];
                  _abrirSelectorMotivo(int.parse(venta['movimiento_id'].toString()));
                },
                icon: const Icon(Icons.block),
                label: const Text('ANULAR SELECCIONADA'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E1E1E),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              )
            ],
          )
        ],
      ),
    );
  }

  Widget _buildDateWidget(String title, DateTime date, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey.shade200, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade500, fontSize: 11)),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 16, color: Color(0xFFBA0C2F)),
                const SizedBox(width: 8),
                Text(DateFormat('yyyy-MM-dd').format(date), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Color(0xFF1A1A1A))),
              ],
            ),
          ],
        ),
      ),
    );
  }
  // Detalle visual de la venta seleccionada simulando un ticket
  Widget _buildDetalleVenta(Map<String, dynamic> venta) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.red.shade50, shape: BoxShape.circle),
                child: const Icon(Icons.receipt_long, color: Color(0xFFBA0C2F), size: 32),
              ),
              const SizedBox(width: 16),
              const Text('Resumen de\nTransacción', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, height: 1.2)),
            ],
          ),
          const SizedBox(height: 32),
          _buildDetailRow('Nro. Recibo', venta['nro'].toString(), isBold: true),
          const Divider(height: 24),
          _buildDetailRow('Prefijo', venta['prefijo'].toString()),
          const Divider(height: 24),
          _buildDetailRow('Fecha y Hora', venta['fecha'].toString()),
          const Divider(height: 24),
          _buildDetailRow('Responsable', venta['promotor'].toString()),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200)
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('TOTAL', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
                Text('\$ ${NumberFormat("#,##0", "es_CO").format(venta['valor'])}', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Color(0xFFBA0C2F))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
        Text(value, style: TextStyle(fontWeight: isBold ? FontWeight.w900 : FontWeight.w600, fontSize: isBold ? 18 : 16, color: const Color(0xFF1A1A1A))),
      ],
    );
  }
}
