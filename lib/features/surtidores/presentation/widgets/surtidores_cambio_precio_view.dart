import 'package:flutter/material.dart';
import '../../../../core/services/api_consultas_service.dart';
import '../../../../core/widgets/teclado_tactil.dart';

class SurtidoresCambioPrecioView extends StatefulWidget {
  const SurtidoresCambioPrecioView({Key? key}) : super(key: key);

  @override
  State<SurtidoresCambioPrecioView> createState() => _SurtidoresCambioPrecioViewState();
}

class _SurtidoresCambioPrecioViewState extends State<SurtidoresCambioPrecioView> {
  final ApiConsultasService _apiService = ApiConsultasService();
  bool _isLoading = true;
  bool _isSaving = false;
  
  List<Map<String, dynamic>> _mangueras = [];
  
  Map<String, dynamic>? _mangueraSeleccionada;
  final TextEditingController _precioController = TextEditingController();

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

  Future<void> _aplicarCambioPrecio() async {
    if (_mangueraSeleccionada == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Seleccione una manguera')));
      return;
    }
    
    int nuevoPrecio = int.tryParse(_precioController.text) ?? 0;
    if (nuevoPrecio <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ingrese un precio válido'), backgroundColor: Colors.red));
      return;
    }
    
    setState(() => _isSaving = true);
    
    int surtidor = _mangueraSeleccionada!['surtidor'] ?? 0;
    int cara = _mangueraSeleccionada!['cara'] ?? 0;
    int manguera = _mangueraSeleccionada!['manguera'] ?? 0;

    final res = await _apiService.aplicarCambioPrecioSurtidor(
      surtidor: surtidor,
      cara: cara,
      manguera: manguera,
      nuevoPrecio: nuevoPrecio,
    );

    setState(() => _isSaving = false);

    if (res['exito'] == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Comando de cambio de precio enviado con éxito'), backgroundColor: Colors.green)
        );
        _precioController.clear();
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
                'Ajuste de Precios por Manguera',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF333333)),
              ),
              SizedBox(height: 4),
              Text(
                'Seleccione manguera y asigne el nuevo valor por galón.',
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
                        onTap: () {
                          setState(() => _mangueraSeleccionada = m);
                          // En la vida real aquí podríamos jalar el precio actual y ponerlo en el form
                        },
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
                              Icon(Icons.price_change, color: isSelected ? Colors.white : Colors.grey.shade700, size: 32),
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
              
              // Columna Derecha: Input de Precio y Teclado Táctil
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
                      const SizedBox(height: 20),
                      
                      // Input del Nuevo Precio
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                        decoration: BoxDecoration(
                          color: const Color(0xFFBA0C2F),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Text('NUEVO PRECIO \$', 
                              style: TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.bold)
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextField(
                                controller: _precioController,
                                textAlign: TextAlign.right,
                                readOnly: true,
                                style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                  hintText: '0',
                                  hintStyle: TextStyle(color: Colors.white54)
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
                            controller: _precioController,
                            soloNumeros: true,
                            onAceptar: _aplicarCambioPrecio,
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Boton Guardar
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _aplicarCambioPrecio,
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 60),
                            backgroundColor: const Color(0xFFBA0C2F),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _isSaving 
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text('ENVIAR COMANDO', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
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
}
