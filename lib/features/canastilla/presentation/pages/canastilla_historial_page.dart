import 'package:flutter/material.dart';
import '../../../../core/services/api_consultas_service.dart';

/// Historial de ventas de canastilla.
/// Filtros: rango de fechas, promotor (opcional).
/// Tabla/lista con: NRO, FECHA, PROMOTOR, CANT PRODUCTOS, MEDIO PAGO, IMPUESTO, TOTAL.
/// Acción por venta: IMPRIMIR.
class CanastillaHistorialPage extends StatefulWidget {
  const CanastillaHistorialPage({super.key});

  @override
  State<CanastillaHistorialPage> createState() =>
      _CanastillaHistorialPageState();
}

class _CanastillaHistorialPageState extends State<CanastillaHistorialPage> {
  final ApiConsultasService _api = ApiConsultasService();

  DateTime _fechaInicio = DateTime.now();
  DateTime _fechaFin = DateTime.now();
  bool _cargando = false;
  List<Map<String, dynamic>> _ventas = [];
  int? _imprimiendoId;

  @override
  void initState() {
    super.initState();
    _cargarHistorial();
  }

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _cargarHistorial() async {
    setState(() => _cargando = true);
    final data = await _api.obtenerHistorialCanastilla(
      fechaInicio: _formatDate(_fechaInicio),
      fechaFin: _formatDate(_fechaFin),
    );
    if (!mounted) return;
    setState(() {
      _ventas = (data['ventas'] as List?)
              ?.map((e) => e is Map<String, dynamic> ? e : <String, dynamic>{})
              .toList() ??
          [];
      _cargando = false;
    });
  }

  Future<void> _imprimir(int movimientoId) async {
    setState(() => _imprimiendoId = movimientoId);
    final result = await _api.imprimirCanastilla(movimientoId);
    if (mounted) {
      setState(() => _imprimiendoId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['mensaje']?.toString() ?? 'OK'),
          backgroundColor:
              result['exito'] == true ? Colors.green.shade600 : Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _seleccionarFecha(bool esInicio) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: esInicio ? _fechaInicio : _fechaFin,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFFFF8F00),
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (esInicio) {
          _fechaInicio = picked;
        } else {
          _fechaFin = picked;
        }
      });
      _cargarHistorial();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFF8F00),
        foregroundColor: Colors.white,
        title: const Row(
          children: [
            Icon(Icons.history, size: 26),
            SizedBox(width: 10),
            Text('Historial Canastilla',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
          ],
        ),
        elevation: 2,
      ),
      body: Column(
        children: [
          _buildFilters(),
          _buildStats(),
          Expanded(child: _buildTable()),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Fecha inicio
          _buildDateButton('Desde', _fechaInicio, () => _seleccionarFecha(true)),
          const SizedBox(width: 12),
          _buildDateButton('Hasta', _fechaFin, () => _seleccionarFecha(false)),
          const SizedBox(width: 16),
          ElevatedButton.icon(
            onPressed: _cargando ? null : _cargarHistorial,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF8F00),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            icon: _cargando
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.search, size: 20),
            label: const Text('BUSCAR',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildDateButton(String label, DateTime date, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_today,
                size: 18, color: Colors.grey.shade600),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade500)),
                Text(
                  _formatDate(date),
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStats() {
    final totalVentas = _ventas.length;
    final totalMonto = _ventas.fold<double>(
      0,
      (sum, v) =>
          sum +
          (double.tryParse(v['venta_total']?.toString() ?? '0') ?? 0),
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          _buildStatCard(
              'Total Ventas', '$totalVentas', Icons.receipt, const Color(0xFF1976D2)),
          const SizedBox(width: 12),
          _buildStatCard(
              'Total \$', '\$${totalMonto.toStringAsFixed(0)}', Icons.attach_money, const Color(0xFF388E3C)),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      color: color,
                      fontWeight: FontWeight.w500)),
              Text(value,
                  style: TextStyle(
                      fontSize: 18,
                      color: color,
                      fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTable() {
    if (_cargando) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Color(0xFFFF8F00)),
            SizedBox(height: 16),
            Text('Cargando historial...'),
          ],
        ),
      );
    }

    if (_ventas.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined,
                size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'No hay ventas en este rango',
              style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.grey.shade200, blurRadius: 8),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SingleChildScrollView(
          child: DataTable(
            headingRowColor:
                WidgetStateProperty.all(const Color(0xFFFFF3E0)),
            columnSpacing: 16,
            columns: const [
              DataColumn(label: Text('#', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('FECHA', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('PREFIJO', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('CONSECUTIVO', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('PROMOTOR', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('PRODUCTOS', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
              DataColumn(label: Text('MEDIO PAGO', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('IMPUESTO', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
              DataColumn(label: Text('TOTAL', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
              DataColumn(label: Text('', style: TextStyle(fontWeight: FontWeight.bold))),
            ],
            rows: List.generate(_ventas.length, (idx) {
              final v = _ventas[idx];
              final id = v['id'] ?? v['movimiento_id'] ?? idx;
              final movId = int.tryParse(id.toString()) ?? 0;
              return DataRow(
                color: WidgetStateProperty.resolveWith(
                    (s) => idx.isEven ? Colors.grey.shade50 : null),
                cells: [
                  DataCell(Text('${idx + 1}')),
                  DataCell(Text(
                    v['fecha']?.toString().substring(0, 10) ?? '---',
                    style: const TextStyle(fontSize: 13),
                  )),
                  DataCell(Text(v['prefijo']?.toString() ?? '')),
                  DataCell(Text(v['consecutivo']?.toString() ?? '')),
                  DataCell(
                    SizedBox(
                      width: 120,
                      child: Text(
                        v['promotor']?.toString() ?? v['nombres_promotor']?.toString() ?? '---',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ),
                  DataCell(Text(v['cant_productos']?.toString() ??
                      v['cantidad_productos']?.toString() ??
                      '-')),
                  DataCell(
                    SizedBox(
                      width: 100,
                      child: Text(
                        v['medio_pago']?.toString() ?? v['descripcion_medio']?.toString() ?? '-',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ),
                  DataCell(Text(
                    '\$${(double.tryParse(v['impuesto_total']?.toString() ?? '0') ?? 0).toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 13),
                  )),
                  DataCell(Text(
                    '\$${(double.tryParse(v['venta_total']?.toString() ?? '0') ?? 0).toStringAsFixed(0)}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Color(0xFFE65100)),
                  )),
                  DataCell(
                    movId > 0
                        ? IconButton(
                            onPressed: _imprimiendoId != null
                                ? null
                                : () => _imprimir(movId),
                            icon: _imprimiendoId == movId
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2))
                                : Icon(Icons.print,
                                    color: Colors.blue.shade700, size: 22),
                            tooltip: 'Imprimir',
                          )
                        : const SizedBox(),
                  ),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }
}