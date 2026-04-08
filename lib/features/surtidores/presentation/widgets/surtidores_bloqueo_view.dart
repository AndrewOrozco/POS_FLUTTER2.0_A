import 'package:flutter/material.dart';
import '../../../../core/services/api_consultas_service.dart';

class SurtidoresBloqueoView extends StatefulWidget {
  const SurtidoresBloqueoView({Key? key}) : super(key: key);

  @override
  State<SurtidoresBloqueoView> createState() => _SurtidoresBloqueoViewState();
}

class _SurtidoresBloqueoViewState extends State<SurtidoresBloqueoView> {
  final ApiConsultasService _apiService = ApiConsultasService();
  bool _isLoading = true;
  bool _isSaving = false;
  
  // Lista original y lista editada para enviar solo los cambios reales.
  List<Map<String, dynamic>> _mangueras = [];
  final Map<int, bool> _cambiosPendientes = {};

  @override
  void initState() {
    super.initState();
    _cargarMangueras();
  }

  Future<void> _cargarMangueras() async {
    setState(() {
      _isLoading = true;
      _cambiosPendientes.clear();
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

  Future<void> _guardarCambios() async {
    if (_cambiosPendientes.isEmpty) return;

    setState(() => _isSaving = true);

    List<Map<String, dynamic>> requestBloqueos = [];
    for (var entry in _cambiosPendientes.entries) {
      requestBloqueos.add({
        "manguera": entry.key,
        "bloqueo": entry.value,
        "motivo": entry.value ? "Bloqueo manual desde POS" : "",
      });
    }

    final res = await _apiService.aplicarBloqueosSurtidores(requestBloqueos);

    if (res['exito'] == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cambios guardados con éxito'),
            backgroundColor: Colors.green,
          )
        );
      }
      await _cargarMangueras(); // recargar para estado fresco
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error guardando cambios: ${res['mensaje']}'),
            backgroundColor: Colors.red,
          )
        );
      }
    }
    
    setState(() => _isSaving = false);
  }

  void _toggleBloqueo(int mangueraId, bool estadoActual) {
    setState(() {
      bool nuevoEstado = !estadoActual;
      // Actualizamos objeto local para visualización instantánea
      var item = _mangueras.firstWhere((element) => element['manguera'] == mangueraId);
      item['bloqueo'] = nuevoEstado;
      
      // Registrar en mapa de cambios pendientes
      _cambiosPendientes[mangueraId] = nuevoEstado;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Agrupar por surtidor para mejor visualización
    final surtidoresMap = <int, List<Map<String, dynamic>>>{};
    for (var m in _mangueras) {
      int s = m['surtidor'] ?? 0;
      if (!surtidoresMap.containsKey(s)) {
        surtidoresMap[s] = [];
      }
      surtidoresMap[s]!.add(m);
    }
    
    var surtidoresList = surtidoresMap.keys.toList()..sort();

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
                    'Bloqueo de Surtidores',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF333333)),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Gestión manual del estado de servicio por manguera',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _cambiosPendientes.isEmpty || _isSaving ? null : _guardarCambios,
                icon: _isSaving 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.save),
                label: const Text('GUARDAR CAMBIOS'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFBA0C2F), // Rojo Terpel
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
              )
            ],
          ),
        ),
        
        const Divider(height: 1),
        
        // Grid de Surtidores
        Expanded(
          child: _mangueras.isEmpty
            ? const Center(child: Text('No se encontraron mangueras configuradas.'))
            : GridView.builder(
                padding: const EdgeInsets.all(24),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 400,
                  mainAxisSpacing: 20,
                  crossAxisSpacing: 20,
                  childAspectRatio: 1.2,
                ),
                itemCount: surtidoresList.length,
                itemBuilder: (context, index) {
                  int numSurtidor = surtidoresList[index];
                  var manguerasSurtidor = surtidoresMap[numSurtidor]!;
                  return _SurtidorCardBuilder(
                    numeroSurtidor: numSurtidor,
                    mangueras: manguerasSurtidor,
                    onToggle: _toggleBloqueo,
                  );
                },
              ),
        ),
      ],
    );
  }
}

class _SurtidorCardBuilder extends StatelessWidget {
  final int numeroSurtidor;
  final List<Map<String, dynamic>> mangueras;
  final Function(int mangueraId, bool estadoActual) onToggle;

  const _SurtidorCardBuilder({
    Key? key,
    required this.numeroSurtidor,
    required this.mangueras,
    required this.onToggle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Si alguna manguera está bloqueada, consideramos el surtidor en alerta parcial/total
    bool allBlocked = mangueras.every((m) => m['bloqueo'] == true);
    bool anyBlocked = mangueras.any((m) => m['bloqueo'] == true);

    Color headerColor = allBlocked 
        ? Colors.red.shade600 
        : (anyBlocked ? Colors.orange.shade500 : Colors.green.shade600);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          // Header del Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: headerColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.local_gas_station, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      'SURTIDOR $numeroSurtidor',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    allBlocked ? 'BLOQUEADO' : (anyBlocked ? 'PARCIAL' : 'ACTIVO'),
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                )
              ],
            ),
          ),
          // Lista de Mangueras
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: mangueras.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, idx) {
                var mang = mangueras[idx];
                bool isBloqueada = mang['bloqueo'] == true;
                int cara = mang['cara'] ?? 0;
                int mangueraId = mang['manguera'] ?? 0;

                return ListTile(
                  title: Text('Cara $cara - Manguera $mangueraId', style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(isBloqueada ? 'Deshabilitada' : 'Operativa', style: TextStyle(color: isBloqueada ? Colors.red : Colors.green)),
                  trailing: Switch(
                    value: isBloqueada, // true implica que el switch de "Bloqueo" está activo
                    activeColor: Colors.red,
                    inactiveThumbColor: Colors.green,
                    inactiveTrackColor: Colors.green.shade200,
                    onChanged: (val) {
                      onToggle(mangueraId, !val); // pasamos el contrario porque el estado "val" será true si lo prenden.
                    },
                  ),
                );
              },
            ),
          )
        ],
      ),
    );
  }
}
