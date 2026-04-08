import 'package:flutter/material.dart';
import '../../../../core/services/api_consultas_service.dart';

class SurtidoresHistorialRemisionesView extends StatefulWidget {
  const SurtidoresHistorialRemisionesView({Key? key}) : super(key: key);

  @override
  State<SurtidoresHistorialRemisionesView> createState() => _SurtidoresHistorialRemisionesViewState();
}

class _SurtidoresHistorialRemisionesViewState extends State<SurtidoresHistorialRemisionesView> {
  final ApiConsultasService _apiService = ApiConsultasService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _remisiones = [];

  @override
  void initState() {
    super.initState();
    _cargarHistorial();
  }

  Future<void> _cargarHistorial() async {
    setState(() => _isLoading = true);
    final res = await _apiService.obtenerHistorialRemisionesSurtidor(registros: 100);
    
    if (res['exito'] == true) {
      if (mounted) {
        setState(() {
          _remisiones = List<Map<String, dynamic>>.from(res['data'] ?? []);
          _isLoading = false;
        });
      }
    } else {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar historial: ${res['mensaje']}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Cabecera top
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Historial de Remisiones SAP',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF333333)),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Registro de operaciones de descarga y validación.',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _cargarHistorial,
                icon: const Icon(Icons.refresh, color: Colors.white),
                label: const Text('Actualizar', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFBA0C2F),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),
        
        // Contenido Principal
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(left: 24, right: 24, bottom: 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : _remisiones.isEmpty
                    ? _buildEmptyState()
                    : _buildDataTable(),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_toggle_off, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'No hay remisiones registradas.',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildDataTable() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SingleChildScrollView(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: MediaQuery.of(context).size.width - 320, // Aproximadamente el ancho sin el drawer
            ),
            child: DataTable(
              headingRowColor: MaterialStateProperty.all(const Color(0xFFBA0C2F)),
              headingTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              dataRowMinHeight: 60,
              dataRowMaxHeight: 60,
              columnSpacing: 24,
              columns: const [
                DataColumn(label: Text('REMISIÓN')),
                DataColumn(label: Text('PRODUCTO')),
                DataColumn(label: Text('CANTIDAD')),
                DataColumn(label: Text('UNIDAD')),
                DataColumn(label: Text('CREADO')),
                DataColumn(label: Text('MODIFICADO')),
                DataColumn(label: Text('ESTADO')),
              ],
              rows: _remisiones.map((remision) {
                final String estadoStr = remision['status'] ?? 'DESCONOCIDO';
                Color chipColor = Colors.grey;
                if (estadoStr.toUpperCase().contains('CONFIRMADO')) {
                  chipColor = Colors.green;
                } else if (estadoStr.toUpperCase().contains('CARGADO')) {
                  chipColor = Colors.orange;
                } else if (estadoStr.toUpperCase().contains('SAP')) {
                  chipColor = Colors.blue;
                }

                return DataRow(
                  cells: [
                    DataCell(Text(remision['delivery']?.toString() ?? '-', style: const TextStyle(fontWeight: FontWeight.bold))),
                    DataCell(Text(remision['product']?.toString() ?? '-')),
                    DataCell(Text(remision['quantity']?.toString() ?? '-')),
                    DataCell(Text(remision['unit']?.toString() ?? '-')),
                    DataCell(Text('${remision['creation_date']} ${remision['creation_hour']}')),
                    DataCell(Text('${remision['modification_date']} ${remision['modification_hour']}')),
                    DataCell(
                      Chip(
                        label: Text(estadoStr, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                        backgroundColor: chipColor,
                      )
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}
