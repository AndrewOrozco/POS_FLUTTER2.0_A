import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/widgets/supervisor_authorization_dialog.dart';
import '../../../../core/services/api_consultas_service.dart';

class VentaManualView extends StatefulWidget {
  const VentaManualView({Key? key}) : super(key: key);

  @override
  State<VentaManualView> createState() => _VentaManualViewState();
}

class _VentaManualViewState extends State<VentaManualView> {
  final _facturaController = TextEditingController();
  final _valorController = TextEditingController();
  final _apiService = ApiConsultasService();
  
  // Selectors State
  String _selectedCara = '1';
  String _selectedManguera = '1';
  String _selectedProducto = 'CARGANDO...';
  int _selectedProductoId = 0;

  // Catálogo de Base de Datos
  bool _isLoading = true;
  Map<String, dynamic> _catalogoCaras = {};

  // State variables for calculated fields
  double _precioGalon = 0.0;
  double _volumen = 0.0;

  @override
  void initState() {
    super.initState();
    _cargarCatalogo();
  }

  Future<void> _cargarCatalogo() async {
    setState(() => _isLoading = true);
    final data = await _apiService.getPreciosMangueras();
    if (mounted) {
      setState(() {
        if (data['exito'] == true && data['caras'] != null) {
          _catalogoCaras = Map<String, dynamic>.from(data['caras']);
          if (_catalogoCaras.isNotEmpty) {
            _selectedCara = _catalogoCaras.keys.first;
            _actualizarManguerasPorCara(_selectedCara);
          }
        } else {
          _selectedProducto = 'ERROR CARGANDO DATOS';
        }
        _isLoading = false;
      });
    }
  }

  void _actualizarManguerasPorCara(String caraStr) {
    if (_catalogoCaras.containsKey(caraStr)) {
      var manguerasList = _catalogoCaras[caraStr]['mangueras'] as List<dynamic>;
      if (manguerasList.isNotEmpty) {
        var primeraManugera = manguerasList.first;
        _selectedManguera = primeraManugera['manguera'].toString();
        _actualizarProductoYPrecio(primeraManugera);
      }
    }
  }

  void _actualizarProductoYPrecio(Map<String, dynamic> mangueraInfo) {
    setState(() {
      _selectedProducto = mangueraInfo['producto_desc'].toString();
      _selectedProductoId = int.tryParse(mangueraInfo['producto_id'].toString()) ?? 0;
      _precioGalon = double.tryParse(mangueraInfo['precio'].toString()) ?? 0.0;
      _calcularVolumen(); // Recalcular con el nuevo precio
    });
  }

  void _abrirSelectorList(String titulo, List<String> opciones, Function(String) onSelect) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text('Seleccione $titulo', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          const Divider(),
          Expanded(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: opciones.length,
              itemBuilder: (ctx, i) => ListTile(
                title: Center(child: Text(opciones[i], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                onTap: () {
                  onSelect(opciones[i]);
                  Navigator.pop(ctx);
                },
              ),
            ),
          )
        ],
      )
    );
  }

  void _cambiarCara() {
    if (_catalogoCaras.isEmpty) return;
    _abrirSelectorList('Cara', _catalogoCaras.keys.toList(), (selec) {
      setState(() {
        _selectedCara = selec;
        _actualizarManguerasPorCara(_selectedCara);
      });
    });
  }

  void _cambiarManguera() {
    if (!_catalogoCaras.containsKey(_selectedCara)) return;
    var manguerasList = _catalogoCaras[_selectedCara]['mangueras'] as List<dynamic>;
    var opciones = manguerasList.map((e) => e['manguera'].toString()).toList();
    
    _abrirSelectorList('Manguera', opciones, (selec) {
      var mInfo = manguerasList.firstWhere((element) => element['manguera'].toString() == selec);
      setState(() {
        _selectedManguera = selec;
        _actualizarProductoYPrecio(mInfo);
      });
    });
  }

  @override
  void dispose() {
    _facturaController.dispose();
    _valorController.dispose();
    super.dispose();
  }

  void _onNumpadPress(String value) {
    setState(() {
      if (_valorController.text.length < 10) {
        _valorController.text += value;
        _calcularVolumen();
      }
    });
  }

  void _onNumpadDelete() {
    setState(() {
      if (_valorController.text.isNotEmpty) {
        _valorController.text = _valorController.text.substring(0, _valorController.text.length - 1);
        _calcularVolumen();
      }
    });
  }
  
  void _calcularVolumen() {
    if (_valorController.text.isEmpty) {
      _volumen = 0.0;
      return;
    }
    double valor = double.tryParse(_valorController.text) ?? 0.0;
    _volumen = valor / _precioGalon;
  }

  Future<void> _guardarContingencia() async {
    if (_facturaController.text.isEmpty || _valorController.text.isEmpty || _precioGalon == 0.0 || _volumen == 0.0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Compruebe consecutivo, catálogo (precios) y valor.'), backgroundColor: Colors.orange),
      );
      return;
    }

    final autorizado = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => SupervisorAuthorizationDialog(
        onAuthorize: (username, password) async {
          await Future.delayed(const Duration(seconds: 1)); // Simula red
          return username == 'admin' && password == '1234';
        },
      ),
    );

    if (autorizado == true) {
      if (mounted) {
        // Enviar POST a Backend
        final dateNow = DateTime.now();
        final res = await _apiService.registrarVentaManual(
          consecutivo: _facturaController.text,
          cara: int.parse(_selectedCara),
          manguera: int.parse(_selectedManguera),
          productoId: _selectedProductoId,
          fecha: DateFormat('yyyy-MM-dd').format(dateNow),
          hora: DateFormat('HH:mm:ss').format(dateNow),
          precioGalon: _precioGalon,
          volumenGalones: _volumen,
          valorTotal: double.tryParse(_valorController.text) ?? 0.0,
          promotorId: 1, // Placeholder
          supervisorId: 999, // Placeholder desde el auth
        );

        if (res['exito'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res['mensaje'] ?? 'Guardado exitosamente'), backgroundColor: Colors.green),
          );
          setState(() {
            _facturaController.clear();
            _valorController.clear();
            _volumen = 0.0;
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error guardando: ${res['mensaje']}'), backgroundColor: Colors.red),
          );
        }
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
          // Header Moderno
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFBA0C2F), Color(0xFF8A001A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFFBA0C2F).withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 4))
                  ]
                ),
                child: const Icon(Icons.receipt_long, size: 28, color: Colors.white),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Venta de Contingencia', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF1A1A1A), letterSpacing: -0.5)),
                    Text('Registro manual de tirillas off-system', style: TextStyle(fontSize: 14, color: Colors.grey)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // PANEL IZQUIERDO: FORMULARIO PREMIUM
                Expanded(
                  flex: 55,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 24, offset: const Offset(0, 12))
                      ]
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildFacturaInput(),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(flex: 3, child: _isLoading ? const Center(child: CircularProgressIndicator()) : _buildSelectorTile('CARA', _selectedCara, Icons.local_gas_station, _cambiarCara)),
                              const SizedBox(width: 12),
                              Expanded(flex: 3, child: _isLoading ? const SizedBox.shrink() : _buildSelectorTile('MANGUERA', _selectedManguera, Icons.looks_one, _cambiarManguera)),
                              const SizedBox(width: 12),
                              Expanded(flex: 5, child: _isLoading ? const SizedBox.shrink() : _buildSelectorTile('PRODUCTO', _selectedProducto, Icons.water_drop, () {})),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(flex: 3, child: _buildReadOnlyTile('FECHA', DateFormat('yyyy-MM-dd').format(DateTime.now()), Icons.calendar_today)),
                              const SizedBox(width: 12),
                              Expanded(flex: 3, child: _buildReadOnlyTile('HORA', DateFormat('HH:mm').format(DateTime.now()), Icons.access_time)),
                              const SizedBox(width: 12),
                              Expanded(flex: 5, child: _isLoading 
                                ? const Center(child: CircularProgressIndicator()) 
                                : _buildReadOnlyTile('PRECIO / GALÓN', '\$ ${_precioGalon.toStringAsFixed(0)}', Icons.monetization_on, highlight: true)),
                            ],
                          ),
                          const SizedBox(height: 20),
                          // FOOTER CON CÁLCULO
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const FittedBox(fit: BoxFit.scaleDown, child: Text('VOLUMEN (GALONES)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 14))),
                                      const SizedBox(height: 4),
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          _volumen.toStringAsFixed(3),
                                          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Color(0xFF1A1A1A), letterSpacing: -1),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      const FittedBox(fit: BoxFit.scaleDown, child: Text('VALOR A COBRAR', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFBA0C2F), fontSize: 14))),
                                      const SizedBox(height: 4),
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          '\$ ${_valorController.text.isEmpty ? "0" : _valorController.text}',
                                          style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Color(0xFFBA0C2F), letterSpacing: -1),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(width: 20),
                
                // PANEL DERECHO: TECLADO NUMÉRICO MODERNO
                Expanded(
                  flex: 45,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E), // Dark modern theme
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 10))]
                    ),
                    child: Column(
                      children: [
                        Expanded(child: Row(children: [ _buildDarkNumpadBtn('1'), _buildDarkNumpadBtn('2'), _buildDarkNumpadBtn('3') ])),
                        Expanded(child: Row(children: [ _buildDarkNumpadBtn('4'), _buildDarkNumpadBtn('5'), _buildDarkNumpadBtn('6') ])),
                        Expanded(child: Row(children: [ _buildDarkNumpadBtn('7'), _buildDarkNumpadBtn('8'), _buildDarkNumpadBtn('9') ])),
                        Expanded(child: Row(
                          children: [ 
                            _buildDarkActionBtn('B', 'BORRAR', const Color(0xFFFF9800), _onNumpadDelete), 
                            _buildDarkNumpadBtn('0'), 
                            _buildDarkActionBtn('A', 'ACEPTAR', const Color(0xFF4CAF50), _guardarContingencia),
                          ]
                        )),
                      ],
                    ),
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildFacturaInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('NÚMERO DE FACTURA', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12, letterSpacing: 1)),
        const SizedBox(height: 8),
        TextField(
          controller: _facturaController,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A), letterSpacing: 2),
          decoration: InputDecoration(
            hintText: '000000',
            hintStyle: TextStyle(color: Colors.grey.shade400),
            filled: true,
            fillColor: Colors.grey.shade50,
            prefixIcon: const Icon(Icons.tag, color: Color(0xFFBA0C2F), size: 24),
            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade200, width: 2), borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0xFFBA0C2F), width: 2), borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectorTile(String label, String value, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey.shade200, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade500, fontSize: 11)))),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF1A1A1A))))),
                const Icon(Icons.arrow_drop_down, color: Color(0xFFBA0C2F), size: 16),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReadOnlyTile(String label, String value, IconData icon, {bool highlight = false}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: highlight ? const Color(0xFFBA0C2F).withOpacity(0.05) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: highlight ? const Color(0xFFBA0C2F).withOpacity(0.3) : Colors.transparent),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: highlight ? const Color(0xFFBA0C2F) : Colors.grey.shade500),
              const SizedBox(width: 4),
              Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: highlight ? const Color(0xFFBA0C2F) : Colors.grey.shade500, fontSize: 11)))),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: highlight ? const Color(0xFFBA0C2F) : const Color(0xFF1A1A1A)))),
        ],
      ),
    );
  }

  Widget _buildDarkNumpadBtn(String num) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(6.0),
        child: InkWell(
          onTap: () => _onNumpadPress(num),
          borderRadius: BorderRadius.circular(16),
          highlightColor: Colors.white10,
          splashColor: Colors.white24,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF2C2C2C),
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 5, offset: Offset(0, 4))]
            ),
            child: Center(child: Text(num, style: const TextStyle(fontSize: 36, fontWeight: FontWeight.normal, color: Colors.white))),
          ),
        ),
      ),
    );
  }

  Widget _buildDarkActionBtn(String letter, String subtitle, Color color, VoidCallback onTap) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(6.0),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [color.withOpacity(0.8), color],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 5))],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(letter, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                Text(subtitle, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white70, letterSpacing: 1)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
