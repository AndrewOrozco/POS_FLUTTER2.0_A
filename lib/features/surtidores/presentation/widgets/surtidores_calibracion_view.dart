import 'package:flutter/material.dart';
import '../../../../core/services/api_consultas_service.dart';
import '../../../../core/widgets/teclado_tactil.dart';

class SurtidoresCalibracionesView extends StatefulWidget {
  const SurtidoresCalibracionesView({Key? key}) : super(key: key);

  @override
  State<SurtidoresCalibracionesView> createState() => _SurtidoresCalibracionesViewState();
}

class _SurtidoresCalibracionesViewState extends State<SurtidoresCalibracionesView> {
  final ApiConsultasService _apiService = ApiConsultasService();
  bool _isLoading = true;
  bool _isSaving = false;
  
  List<Map<String, dynamic>> _mangueras = [];
  
  Map<String, dynamic>? _mangueraSeleccionada;
  final TextEditingController _cantidadController = TextEditingController();
  bool _fijarPorValor = true;

  @override
  void initState() {
    super.initState();
    _cargarMangueras();
  }

  Future<void> _cargarMangueras() async {
    setState(() => _isLoading = true);
    final res = await _apiService.obtenerManguerasSurtidores();
    
    if (res['exito'] == true) {
      setState(() {
        _mangueras = List<Map<String, dynamic>>.from(res['data'] ?? []);
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar mangueras: ${res['mensaje']}'), backgroundColor: Colors.red)
        );
      }
    }
  }

  Future<void> _registrarCalibracion() async {
    if (_mangueraSeleccionada == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Seleccione una manguera')));
      return;
    }
    
    int cantidad = int.tryParse(_cantidadController.text) ?? 0;
    if (cantidad <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ingrese una cantidad válida'), backgroundColor: Colors.red));
      return;
    }
    
    setState(() => _isSaving = true);
    
    int surtidor = _mangueraSeleccionada!['surtidor'] ?? 0;
    int cara = _mangueraSeleccionada!['cara'] ?? 0;
    int manguera = _mangueraSeleccionada!['manguera'] ?? 0;
    
    int monto = _fijarPorValor ? cantidad : 0;
    int volumen = _fijarPorValor ? 0 : cantidad;

    final res = await _apiService.crearAutorizacionEspecialSurtidor(
      surtidor: surtidor,
      cara: cara,
      manguera: manguera,
      tipoVenta: 2, // 2 = Calibracion
      monto: monto,
      volumen: volumen,
    );

    setState(() => _isSaving = false);

    if (res['exito'] == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Calibración registrada con éxito (Levante la manguera y presione inicio)'), backgroundColor: Colors.green)
        );
        _cantidadController.clear();
        setState(() => _mangueraSeleccionada = null);
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${res['mensaje']}'), backgroundColor: Colors.red)
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cabecera top
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Registrar Calibración',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF333333)),
              ),
              SizedBox(height: 4),
              Text(
                'Seleccione manguera y defina el tope de la prueba.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ],
          ),
        ),
        
        Expanded(
          child: Row(
            children: [
              // Columna Izquierda: Surtidores y Caras
              Expanded(
                flex: 3,
                child: Container(
                  margin: const EdgeInsets.only(left: 24, bottom: 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 1.2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: _mangueras.length,
                    itemBuilder: (context, index) {
                      final m = _mangueras[index];
                      final mId = m['manguera'];
                      final isSelected = _mangueraSeleccionada?['manguera'] == mId;
                      
                      return InkWell(
                        onTap: () => setState(() => _mangueraSeleccionada = m),
                        borderRadius: BorderRadius.circular(12),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFFBA0C2F) : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? const Color(0xFFBA0C2F) : Colors.grey.shade300,
                              width: 2,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.local_gas_station, color: isSelected ? Colors.white : Colors.grey.shade700, size: 32),
                              const SizedBox(height: 8),
                              Text('S${m['surtidor']} - C${m['cara']} - Mg${m['manguera']}', 
                                style: TextStyle(
                                  fontWeight: FontWeight.bold, 
                                  color: isSelected ? Colors.white : Colors.black87
                                )
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              
              const SizedBox(width: 24),
              
              // Columna Derecha: Teclado numérico y confirmación
              Expanded(
                flex: 2,
                child: Container(
                  margin: const EdgeInsets.only(right: 24, bottom: 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: Column(
                    children: [
                      // Toggle Valor/Volumen
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildToggleButton(
                                title: 'VALOR',
                                isSelected: _fijarPorValor,
                                onTap: () => setState(() {
                                  _fijarPorValor = true;
                                  _cantidadController.clear();
                                }),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildToggleButton(
                                title: 'VOLUMEN',
                                isSelected: !_fijarPorValor,
                                onTap: () => setState(() {
                                  _fijarPorValor = false;
                                  _cantidadController.clear();
                                }),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Input
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                        decoration: BoxDecoration(
                          color: const Color(0xFFBA0C2F),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Text(_fijarPorValor ? 'VALOR \$' : 'VOLUMEN:', 
                              style: const TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.bold)
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextField(
                                controller: _cantidadController,
                                textAlign: TextAlign.right,
                                readOnly: true,
                                style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Teclado Numérico
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: TecladoTactil(
                            controller: _cantidadController,
                            soloNumeros: true,
                            onAceptar: _registrarCalibracion,
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Boton Guardar (fallback a onAceptar del teclado)
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _registrarCalibracion,
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 60),
                            backgroundColor: const Color(0xFFBA0C2F),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _isSaving 
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text('CALIBRAR MEDIDOR', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildToggleButton({required String title, required bool isSelected, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 50,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFBA0C2F) : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? const Color(0xFFBA0C2F) : Colors.grey.shade300, width: 2),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }
}
