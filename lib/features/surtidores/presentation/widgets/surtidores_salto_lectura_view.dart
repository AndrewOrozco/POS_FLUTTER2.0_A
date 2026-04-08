import 'package:flutter/material.dart';
import '../../../../core/services/api_consultas_service.dart';

class SurtidoresSaltoLecturaView extends StatefulWidget {
  const SurtidoresSaltoLecturaView({Key? key}) : super(key: key);

  @override
  State<SurtidoresSaltoLecturaView> createState() => _SurtidoresSaltoLecturaViewState();
}

class _SurtidoresSaltoLecturaViewState extends State<SurtidoresSaltoLecturaView> {
  final ApiConsultasService _apiService = ApiConsultasService();
  bool _isLoading = true;
  bool _isSaving = false;
  
  List<Map<String, dynamic>> _mangueras = [];

  @override
  void initState() {
    super.initState();
    _cargarMangueras();
  }

  Future<void> _cargarMangueras() async {
    setState(() {
      _isLoading = true;
    });

    final res = await _apiService.obtenerManguerasSurtidores();
    
    if (res['exito'] == true) {
      setState(() {
        _mangueras = List<Map<String, dynamic>>.from(res['data'] ?? []);
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar mangueras: ${res['mensaje']}'),
            backgroundColor: Colors.red,
          )
        );
      }
    }
  }

  Future<void> _arreglarSalto(int configuracionId, int surtidor, int cara, int manguera) async {
    // Confirmación
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Corrección'),
        content: Text('¿Está seguro que desea limpiar el salto de lectura de la Manguera $manguera (Cara $cara - Surtidor $surtidor)?\n\nEl surtidor se desbloqueará y permitirá nuevas transacciones.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('CANCELAR', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFBA0C2F)),
            child: const Text('LIMPIAR SALTO', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSaving = true);
    
    final res = await _apiService.arreglarSaltoLecturaSurtidor(configuracionId);

    if (res['exito'] == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Salto de lectura resuelto exitosamente'),
            backgroundColor: Colors.green,
          )
        );
      }
      await _cargarMangueras(); // recargar para estado fresco
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${res['mensaje']}'),
            backgroundColor: Colors.red,
          )
        );
      }
    }
    
    setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Filtrar solo las mangueras que tienen salto de lectura
    final manguerasConSalto = _mangueras.where((m) => m['salto_lectura'] == true).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
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
                    'Saltos de Lectura',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF333333)),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Resolver mangueras bloqueadas por lectura no reportada (Ibutton/RFID)',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _cargarMangueras,
                icon: const Icon(Icons.refresh, color: Colors.white),
                label: const Text('ACTUALIZAR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey.shade700,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              )
            ],
          ),
        ),
        
        const Divider(height: 1),
        
        // Contenido principal
        Expanded(
          child: manguerasConSalto.isEmpty
            ? _buildNoHaySaltos()
            : _buildListaSaltos(manguerasConSalto),
        ),
      ],
    );
  }

  Widget _buildNoHaySaltos() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check_circle, size: 80, color: Colors.green.shade600),
          ),
          const SizedBox(height: 24),
          const Text(
            '¡Todo en orden!',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'No hay mangueras bloqueadas por salto de lectura.',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildListaSaltos(List<Map<String, dynamic>> saltos) {
    return Stack(
      children: [
        ListView.builder(
          padding: const EdgeInsets.all(24),
          itemCount: saltos.length,
          itemBuilder: (context, index) {
            final m = saltos[index];
            final surtidor = m['surtidor'] ?? 0;
            final cara = m['cara'] ?? 0;
            final manguera = m['manguera'] ?? 0;
            final configId = m['configuracion_id'] ?? 0;

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.red.shade200, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                leading: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.warning_rounded, color: Colors.red, size: 32),
                ),
                title: Text(
                  'Surtidor $surtidor - Cara $cara - Manguera $manguera',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                subtitle: const Padding(
                  padding: EdgeInsets.only(top: 8.0),
                  child: Text(
                    'Esta manguera se encuentra bloqueada por un salto de lectura detectado por el Core.',
                    style: TextStyle(fontSize: 14),
                  ),
                ),
                trailing: ElevatedButton.icon(
                  onPressed: _isSaving ? null : () => _arreglarSalto(configId, surtidor, cara, manguera),
                  icon: const Icon(Icons.cleaning_services, size: 18),
                  label: const Text('LIMPIAR SALTO'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFBA0C2F),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            );
          },
        ),
        if (_isSaving)
          Container(
            color: Colors.black.withOpacity(0.1),
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),
      ],
    );
  }
}
