import 'package:flutter/material.dart';
import '../../../../core/services/api_consultas_service.dart';
import '../../../../core/widgets/teclado_tactil.dart';

class SurtidoresRecepcionCombustibleView extends StatefulWidget {
  const SurtidoresRecepcionCombustibleView({Key? key}) : super(key: key);

  @override
  State<SurtidoresRecepcionCombustibleView> createState() => _SurtidoresRecepcionCombustibleViewState();
}

class _SurtidoresRecepcionCombustibleViewState extends State<SurtidoresRecepcionCombustibleView> {
  final ApiConsultasService _apiService = ApiConsultasService();
  
  int _currentStep = 0;
  bool _isLoading = false;

  // Controladores Paso 1
  final TextEditingController _deliveryController = TextEditingController();
  final TextEditingController _placaController = TextEditingController();
  
  Map<String, dynamic>? _remisionActiva;
  List<dynamic> _productosRemision = [];
  
  // Controladores Paso 2
  List<dynamic> _tanquesDisponibles = [];
  Map<String, dynamic>? _tanqueSeleccionado;
  
  // Variables Modo Manual (Fallback Offline)
  bool _modoManual = false;
  bool _mostrarBotonManual = false;
  List<dynamic> _productosGlobales = [];
  Map<String, dynamic>? _productoSeleccionado;
  
  // Controladores Paso 3 / Recepción
  final TextEditingController _cantidadRecibirController = TextEditingController();
  final TextEditingController _alturaInicialController = TextEditingController();
  final TextEditingController _volumenInicialController = TextEditingController();
  final TextEditingController _aguaInicialController = TextEditingController();
  final TextEditingController _alturaFinalController = TextEditingController();
  final TextEditingController _volumenFinalController = TextEditingController();
  final TextEditingController _aguaFinalController = TextEditingController();

  // Teclado Integrado (Foco Dinámico)
  TextEditingController? _activeController;
  final ScrollController _scrollController = ScrollController();

  // Bandeja de Entrada (Vista Inicial)
  bool _mostrarListaPendientes = true;
  List<dynamic> _recepcionesPendientes = [];

  @override
  void initState() {
    super.initState();
    _cargarPendientes();
  }

  Future<void> _cargarPendientes() async {
    setState(() => _isLoading = true);
    final res = await _apiService.getRecepcionesPendientes();
    setState(() {
      _isLoading = false;
      if (res['exito'] == true) {
        _recepcionesPendientes = res['data'] ?? [];
      } else {
        _recepcionesPendientes = [];
      }
    });
  }
  
  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _setActiveController(TextEditingController ctrl) {
    if (_activeController == _alturaInicialController && ctrl != _alturaInicialController) {
      _calcularAforo(_alturaInicialController.text, _volumenInicialController);
    }
    if (_activeController == _alturaFinalController && ctrl != _alturaFinalController) {
      _calcularAforo(_alturaFinalController.text, _volumenFinalController);
    }
    setState(() {
      _activeController = ctrl;
    });
  }

  void _cerrarTeclado() {
    if (_activeController == _alturaInicialController) {
      _calcularAforo(_alturaInicialController.text, _volumenInicialController);
    }
    if (_activeController == _alturaFinalController) {
      _calcularAforo(_alturaFinalController.text, _volumenFinalController);
    }
    setState(() {
      _activeController = null;
    });
  }

  Future<void> _validarRemision() async {
    if (_deliveryController.text.isEmpty || _placaController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ingrese Delivery y Placa')));
      return;
    }
    
    _cerrarTeclado();
    setState(() => _isLoading = true);
    
    // 1. Validar Delivery
    final res = await _apiService.validarRemisionSAP(delivery: _deliveryController.text);
    if (res['exito'] == true) {
      _remisionActiva = res['data']['remision'];
      _productosRemision = res['data']['productos'];
      
      // 2. Obtener Tanques asignados
      final resTanques = await _apiService.obtenerTanquesRemision(delivery: _deliveryController.text);
      if (resTanques['exito'] == true) {
        if (mounted) {
          setState(() {
            _tanquesDisponibles = resTanques['data'] ?? [];
            _currentStep = 1; // Avanzar al paso 2
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _isLoading = false;
          _mostrarBotonManual = true;
        });
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error validando tanques: ${resTanques['mensaje']}'), backgroundColor: Colors.red));
      }
    } else {
      setState(() {
        _isLoading = false;
        _mostrarBotonManual = true;
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['mensaje'] ?? 'Remisión no válida'), backgroundColor: Colors.red));
    }
  }

  Future<void> _iniciarModoManual() async {
    _cerrarTeclado();
    setState(() => _isLoading = true);

    final resCatalogos = await _apiService.getTanquesYProductosManual();
    setState(() => _isLoading = false);

    if (resCatalogos['exito'] == true) {
      if (mounted) {
        setState(() {
          _modoManual = true;
          _tanquesDisponibles = resCatalogos['data']['tanques'] ?? [];
          _productosGlobales = resCatalogos['data']['productos'] ?? [];
          _currentStep = 1; // Avanzar al paso 2
          _mostrarBotonManual = false;
        });
      }
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error obteniendo catálogos: ${resCatalogos['mensaje']}'), backgroundColor: Colors.red));
    }
  }

  Future<void> _calcularAforo(String textura, TextEditingController volumenCtrl) async {
    if (textura.isEmpty || _tanqueSeleccionado == null) return;
    
    final double? altura = double.tryParse(textura);
    if (altura == null) return;
    
    setState(() => _isLoading = true);
    final int tanqueId = _tanqueSeleccionado!['id'] is int ? _tanqueSeleccionado!['id'] : int.tryParse(_tanqueSeleccionado!['id'].toString()) ?? 0;
    
    final res = await _apiService.getAforoTanque(tanqueId, altura);
    setState(() {
      _isLoading = false;
      if (res['exito'] == true) {
        volumenCtrl.text = res['volumen'].toString();
      } else {
        volumenCtrl.text = "0.0";
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['mensaje'] ?? 'No se pudo calcular el volumen'), duration: const Duration(seconds: 1)));
        }
      }
    });
  }

  Future<void> _registrarEntrada() async {
    if (_alturaInicialController.text.isEmpty || _alturaFinalController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Faltan medidas por completar')));
      return;
    }

    _cerrarTeclado();
    setState(() => _isLoading = true);

    final payload = {
      'delivery': _modoManual ? 'MANUAL' : _remisionActiva!['delivery'],
      'placa': _modoManual ? _placaController.text : _placaController.text, // Puede ser opcional en modo manual
      'tanque_id': _tanqueSeleccionado!['id'],
      'producto_id': _modoManual && _productoSeleccionado != null ? _productoSeleccionado!['id'] : _tanqueSeleccionado!['producto_id'],
      'altura_inicial': _alturaInicialController.text,
      'volumen_inicial': _volumenInicialController.text,
      'agua_inicial': _aguaInicialController.text,
      'altura_final': _alturaFinalController.text,
      'volumen_final': _volumenFinalController.text,
      'agua_final': _aguaFinalController.text,
      'cantidad_reportada': _cantidadRecibirController.text.isNotEmpty ? _cantidadRecibirController.text : '0',
    };

    final res = await _apiService.registrarReceptorCombustible(datos: payload);
    setState(() => _isLoading = false);

    if (res['exito'] == true) {
      if (mounted) {
        showDialog(context: context, barrierDismissible: false, builder: (_) => AlertDialog(
          title: const Text('Completado'),
          content: Text(_modoManual ? 'Descargue Offline ingresado localmente con éxito.' : 'Recepción de combustible ejecutada con éxito. Listo para cuadre.'),
          actions: [
            TextButton(onPressed: () {
              Navigator.pop(context);
              _resetearTodo();
            }, child: const Text('FINALIZAR'))
          ],
        ));
      }
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error guardando: ${res['mensaje']}'), backgroundColor: Colors.red));
    }
  }

  void _resetearTodo() {
    setState(() {
      _currentStep = 0;
      _remisionActiva = null;
      _tanquesDisponibles.clear();
      _tanqueSeleccionado = null;
      _deliveryController.clear();
      _placaController.clear();
      _alturaInicialController.clear();
      _volumenInicialController.clear();
      _aguaInicialController.clear();
      _alturaFinalController.clear();
      _volumenFinalController.clear();
      _aguaFinalController.clear();
      _cantidadRecibirController.clear();
      _activeController = null;
      _modoManual = false;
      _mostrarBotonManual = false;
      _productosGlobales.clear();
      _productoSeleccionado = null;
      _mostrarListaPendientes = true;
    });
    _cargarPendientes();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Recepción de Combustible', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF333333))),
                  SizedBox(height: 4),
                  Text('Asistente digital de descarga (Reemplaza los modales legacy)', style: TextStyle(fontSize: 16, color: Colors.grey)),
                ],
              ),
              if (_remisionActiva != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    children: [
                      const Icon(Icons.info, color: Colors.blue),
                      const SizedBox(width: 8),
                      Text('Remisión: ${_remisionActiva!['delivery']} - ${_remisionActiva!['status']}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                      const SizedBox(width: 16),
                      TextButton(onPressed: _resetearTodo, child: const Text('CANCELAR', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
                    ],
                  ),
                )
            ],
          ),
        ),
        
        _mostrarListaPendientes ? _buildListaPendientes() : _buildStepper(),
        
        // TECLADO DESLIZABLE DOCKED A LA BASE
        AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          curve: Curves.fastOutSlowIn,
          height: _activeController != null ? 360 : 0,
          margin: const EdgeInsets.symmetric(horizontal: 24),
          decoration: const BoxDecoration(
            color: Color(0xFF2D2D2D),
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, -4))],
          ),
          child: _activeController != null 
            ? Column(
                children: [
                  Center(
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      width: 50,
                      height: 4,
                      decoration: BoxDecoration(color: Colors.white30, borderRadius: BorderRadius.circular(4)),
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const NeverScrollableScrollPhysics(),
                      child: Padding(
                        padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                        child: TecladoTactil(
                          controller: _activeController!,
                          soloNumeros: _currentStep > 0, // En paso 0 alfa para Placa, luego numérico
                          height: 310,
                          onAceptar: () {
                          if (_currentStep == 0) {
                            if (_deliveryController.text.isNotEmpty && _placaController.text.isEmpty) {
                              _setActiveController(_placaController);
                            } else if (_deliveryController.text.isNotEmpty && _placaController.text.isNotEmpty) {
                              _cerrarTeclado();
                              _validarRemision();
                            } else {
                              _cerrarTeclado();
                            }
                          } else if (_currentStep == 1) {
                             if (_activeController == _cantidadRecibirController) {
                               _cerrarTeclado();
                             } else {
                               _cerrarTeclado();
                             }
                          } else if (_currentStep == 2) {
                             if (_activeController == _alturaInicialController) {
                               _setActiveController(_aguaInicialController);
                             } else if (_activeController == _aguaInicialController) {
                               _setActiveController(_alturaFinalController);
                             } else if (_activeController == _alturaFinalController) {
                               _setActiveController(_aguaFinalController);
                             } else if (_activeController == _aguaFinalController) {
                               _cerrarTeclado();
                               if (_alturaFinalController.text.isNotEmpty) {
                                 _registrarEntrada();
                               }
                             } else {
                               _cerrarTeclado();
                             }
                          } else {
                            _cerrarTeclado();
                          }
                        },
                      ),
                    ),
                  ),
                  ),
                ],
              )
            : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildListaPendientes() {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(left: 24, right: 24, bottom: 24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('...EN PROCESO', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFFBA0C2F))),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : _recepcionesPendientes.isEmpty
                    ? const Center(child: Text('No hay recepciones en proceso.', style: TextStyle(fontSize: 18, color: Colors.grey)))
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SingleChildScrollView(
                          child: DataTable(
                            headingRowColor: MaterialStateProperty.all(const Color(0xFFBA0C2F)),
                            headingTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            columns: const [
                              DataColumn(label: Text('ITEM')),
                              DataColumn(label: Text('PLACA')),
                              DataColumn(label: Text('DOCUMENTO')),
                              DataColumn(label: Text('TANQUE')),
                              DataColumn(label: Text('PRODUCTO')),
                              DataColumn(label: Text('ESTADO')),
                            ],
                            rows: _recepcionesPendientes.map((r) {
                              return DataRow(cells: [
                                DataCell(Text(r['id'].toString())),
                                DataCell(Text(r['placa'] ?? '')),
                                DataCell(Text(r['documento'] ?? '')),
                                DataCell(Text(r['tanque_desc'] ?? '')),
                                DataCell(Text(r['producto_desc'] ?? '')),
                                DataCell(Text(r['estado'] ?? 'PENDIENTE', style: const TextStyle(fontWeight: FontWeight.bold))),
                              ]);
                            }).toList(),
                          ),
                        ),
                      ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.bottomRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                         _mostrarListaPendientes = false;
                      });
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFBA0C2F), minimumSize: const Size(150, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    child: const Text('NUEVA', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildStepper() {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(left: 24, right: 24, bottom: 24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Stepper(
          physics: const ClampingScrollPhysics(),
          currentStep: _currentStep,
          controlsBuilder: (context, details) => const SizedBox.shrink(),
          steps: [
            // PASO 1: REMISION
            Step(
              isActive: _currentStep >= 0,
              title: const Text('Documentos SAP', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              content: Column(
                children: [
                  _buildInput('NRO DE ORDEN (DELIVERY)', _deliveryController),
                  const SizedBox(height: 12),
                  _buildInput('PLACA DE TRANSPORTE', _placaController),
                  const SizedBox(height: 20),
                  if (_currentStep == 0) ...[
                    ElevatedButton(
                      onPressed: _isLoading ? null : _validarRemision,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFBA0C2F),
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('VALIDAR', style: TextStyle(color: Colors.white, fontSize: 18)),
                    ),
                    if (_mostrarBotonManual) ...[
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _isLoading ? null : _iniciarModoManual,
                        icon: const Icon(Icons.warning_amber, color: Colors.orange),
                        label: const Text('FORZAR ENTRADA MANUAL (MODO OFFLINE)', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.orange, width: 2),
                          minimumSize: const Size(double.infinity, 50),
                        ),
                      )
                    ]
                  ]
                ],
              )
            ),
            
            // PASO 2: SELECCION DE TANQUE (Y PRODUCTO SI ES MANUAL)
            Step(
              isActive: _currentStep >= 1,
              title: const Text('Asignación Física', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              content: _modoManual 
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('SELECCIONE EL PRODUCTO:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<Map<String, dynamic>>(
                        decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                        hint: const Text('Seleccionar Producto'),
                        value: _productoSeleccionado,
                        items: _productosGlobales.map<DropdownMenuItem<Map<String, dynamic>>>((p) {
                          return DropdownMenuItem(value: p as Map<String, dynamic>, child: Text(p['descripcion']));
                        }).toList(),
                        onChanged: (val) => setState(() => _productoSeleccionado = val),
                      ),
                      const SizedBox(height: 16),
                      const Text('SELECCIONE EL TANQUE PISTA:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<Map<String, dynamic>>(
                        decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                        hint: const Text('Seleccionar Tanque'),
                        value: _tanqueSeleccionado,
                        items: _tanquesDisponibles.map<DropdownMenuItem<Map<String, dynamic>>>((t) {
                          return DropdownMenuItem(value: t as Map<String, dynamic>, child: Text('${t['numero']} - ${t['bodega']}'));
                        }).toList(),
                        onChanged: (val) => setState(() => _tanqueSeleccionado = val),
                      ),
                      const SizedBox(height: 16),
                      const Text('CANTIDAD A RECIBIR:', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFBA0C2F)), textAlign: TextAlign.center),
                      const SizedBox(height: 8),
                      Center(
                        child: SizedBox(
                          width: 250,
                          child: InkWell(
                            onTap: () => _setActiveController(_cantidadRecibirController),
                            child: IgnorePointer(
                              child: TextField(
                                controller: _cantidadRecibirController,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
                                textAlign: TextAlign.center,
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFBA0C2F))),
                                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                                  filled: true,
                                  fillColor: _activeController == _cantidadRecibirController ? Colors.yellow.shade50 : Colors.grey.shade50,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (_currentStep == 1)
                        ElevatedButton(
                          onPressed: _isLoading ? null : () {
                            // Lógica de validación manual
                            setState(() => _currentStep = 2);
                            Future.delayed(const Duration(milliseconds: 300), () => _setActiveController(_alturaInicialController));
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFBA0C2F),
                            minimumSize: const Size(double.infinity, 50),
                          ),
                          child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('CONTINUAR', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        )
                    ],
                  )
                : Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: _tanquesDisponibles.map((t) {
                      final isSelected = _tanqueSeleccionado == t;
                      return InkWell(
                        onTap: () {
                          setState(() {
                            _tanqueSeleccionado = t;
                            _currentStep = 2;
                          });
                          Future.delayed(const Duration(milliseconds: 300), () => _setActiveController(_alturaInicialController));
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 140,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFFBA0C2F) : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isSelected ? const Color(0xFFBA0C2F) : Colors.grey.shade300, width: 2)
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.inventory_2, color: isSelected ? Colors.white : Colors.grey.shade700, size: 36),
                              const SizedBox(height: 8),
                              Text('TANQUE ${t['numero']}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isSelected ? Colors.white : Colors.black)),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  )
            ),
            
            // PASO 3: MEDICION Y CIERRE
            Step(
              isActive: _currentStep >= 2,
              state: _currentStep == 2 ? StepState.editing : StepState.indexed,
              title: const Text('Medición Final y Registro', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              content: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: _buildInput('Altura Inc.', _alturaInicialController)),
                      const SizedBox(width: 4),
                      Expanded(child: _buildInput('Volumen(\$)', _volumenInicialController, enabled: false)),
                      const SizedBox(width: 4),
                      Expanded(child: _buildInput('Agua Inc.', _aguaInicialController)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _buildInput('Altura Fin.', _alturaFinalController)),
                      const SizedBox(width: 4),
                      Expanded(child: _buildInput('Volumen(\$)', _volumenFinalController, enabled: false)),
                      const SizedBox(width: 4),
                      Expanded(child: _buildInput('Agua Fin.', _aguaFinalController)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (_currentStep == 2)
                    ElevatedButton(
                      onPressed: _isLoading ? null : _registrarEntrada,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFBA0C2F),
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('GUARDAR RECEPCIÓN', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    )
                ],
              )
            )
          ],
        ),
      ),
    );
  }

  Widget _buildInput(String label, TextEditingController ctrl, {bool enabled = true}) {
    final bool isActive = _activeController == ctrl && enabled;
    return GestureDetector(
      onTap: enabled ? () => _setActiveController(ctrl) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: !enabled ? Colors.grey.shade300 : (isActive ? Colors.yellow.shade50 : Colors.grey.shade50),
          border: Border.all(color: isActive ? Colors.orange : Colors.grey.shade400, width: isActive ? 2 : 1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: !enabled ? Colors.red.shade900 : (isActive ? Colors.orange.shade800 : Colors.red.shade900))),
            IgnorePointer(
              child: TextField(
                controller: ctrl,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: !enabled ? Colors.black54 : Colors.black),
                decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
