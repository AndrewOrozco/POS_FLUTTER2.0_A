import 'package:flutter/material.dart';
import '../../../../core/services/api_consultas_service.dart';
import '../../../../core/widgets/teclado_tactil.dart';

/// Diálogo de fidelización (Club Terpel / Vive Terpel).
/// Permite buscar un cliente por cédula y acumular puntos en una venta.
///
/// Uso:
/// ```dart
/// final resultado = await mostrarFidelizarDialog(context, movimientoId: 123);
/// if (resultado == true) { /* fidelizado exitosamente */ }
/// ```
Future<bool?> mostrarFidelizarDialog(
  BuildContext context, {
  required int movimientoId,
  String? ventaInfo,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _FidelizarDialog(
      movimientoId: movimientoId,
      ventaInfo: ventaInfo,
    ),
  );
}

class _FidelizarDialog extends StatefulWidget {
  final int movimientoId;
  final String? ventaInfo;

  const _FidelizarDialog({
    required this.movimientoId,
    this.ventaInfo,
  });

  @override
  State<_FidelizarDialog> createState() => _FidelizarDialogState();
}

class _FidelizarDialogState extends State<_FidelizarDialog> {
  final ApiConsultasService _apiService = ApiConsultasService();
  final TextEditingController _cedulaController = TextEditingController();

  // Tipos de documento
  static const _tiposDoc = [
    {'id': 1, 'nombre': 'CÉDULA'},
    {'id': 2, 'nombre': 'CÉDULA EXTRANJERA'},
    {'id': 3, 'nombre': 'PASAPORTE'},
  ];
  int _tipoDocSeleccionado = 1;

  // Estados del flujo
  _FidelizarEstado _estado = _FidelizarEstado.ingresandoCedula;
  String? _error;
  String? _clienteNombre;
  bool _procesando = false;

  @override
  void initState() {
    super.initState();
    // Escuchar cambios del teclado táctil para actualizar el campo en tiempo real
    _cedulaController.addListener(_onTextoChanged);
  }

  void _onTextoChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _buscarCliente() async {
    final cedula = _cedulaController.text.trim();
    if (cedula.isEmpty) {
      setState(() => _error = 'Ingrese número de identificación');
      return;
    }

    setState(() {
      _procesando = true;
      _error = null;
    });

    final resultado = await _apiService.validarClienteFidelizacion(
      numeroIdentificacion: cedula,
      codigoTipoIdentificacion: _tipoDocSeleccionado,
    );

    if (!mounted) return;

    if (resultado['exito'] == true) {
      final cliente = resultado['cliente'];
      setState(() {
        _clienteNombre = cliente['nombre'] ?? 'Cliente encontrado';
        _estado = _FidelizarEstado.confirmarAcumulacion;
        _procesando = false;
      });
    } else {
      setState(() {
        _error = resultado['mensaje'] ?? 'Cliente no encontrado';
        _procesando = false;
      });
    }
  }

  Future<void> _acumularPuntos() async {
    setState(() {
      _procesando = true;
      _error = null;
    });

    final resultado = await _apiService.acumularPuntosFidelizacion(
      movimientoId: widget.movimientoId,
      numeroIdentificacion: _cedulaController.text.trim(),
      codigoTipoIdentificacion: _tipoDocSeleccionado,
    );

    if (!mounted) return;

    if (resultado['exito'] == true) {
      setState(() {
        _estado = _FidelizarEstado.exitoso;
        _procesando = false;
      });
      // Cerrar con éxito después de 2 segundos
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) Navigator.of(context).pop(true);
    } else {
      setState(() {
        _error = resultado['mensaje'] ?? 'Error al acumular puntos';
        _procesando = false;
      });
    }
  }

  @override
  void dispose() {
    _cedulaController.removeListener(_onTextoChanged);
    _cedulaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: Container(
        width: 800,
        constraints: const BoxConstraints(maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            Flexible(
              child: _estado == _FidelizarEstado.exitoso
                  ? _buildExito()
                  : _buildContenido(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade700, Colors.green.shade600],
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.favorite_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'FIDELIZACIÓN - VIVE TERPEL',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (widget.ventaInfo != null)
                  Text(
                    widget.ventaInfo!,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: _procesando ? null : () => Navigator.of(context).pop(false),
            icon: const Icon(Icons.close_rounded, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildExito() {
    return Padding(
      padding: const EdgeInsets.all(48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check_circle_rounded, size: 72, color: Colors.green.shade600),
          ),
          const SizedBox(height: 24),
          const Text(
            'PUNTOS ACUMULADOS',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF333333)),
          ),
          const SizedBox(height: 8),
          Text(
            _clienteNombre ?? '',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 4),
          Text(
            'Cédula: ${_cedulaController.text}',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildContenido() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Lado izquierdo: formulario
        Expanded(
          flex: 3,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tipo de documento
                const Text(
                  'TIPO DE DOCUMENTO',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF666666)),
                ),
                const SizedBox(height: 8),
                Row(
                  children: _tiposDoc.map((tipo) {
                    final seleccionado = _tipoDocSeleccionado == tipo['id'];
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Material(
                          color: seleccionado ? Colors.green.shade600 : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(10),
                          child: InkWell(
                            onTap: _procesando
                                ? null
                                : () => setState(() => _tipoDocSeleccionado = tipo['id'] as int),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Text(
                                tipo['nombre'] as String,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: seleccionado ? Colors.white : Colors.grey.shade700,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),

                // Campo de identificación
                const Text(
                  'NÚMERO DE IDENTIFICACIÓN',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF666666)),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.green.shade300, width: 2),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.badge_rounded, color: Colors.green.shade600, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _cedulaController.text.isEmpty ? 'Ingrese número...' : _cedulaController.text,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: _cedulaController.text.isEmpty
                                ? Colors.grey.shade400
                                : const Color(0xFF333333),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Estado: confirmación de cliente encontrado
                if (_estado == _FidelizarEstado.confirmarAcumulacion) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.green.shade300),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(Icons.person_rounded, color: Colors.green.shade700, size: 28),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('CLIENTE ENCONTRADO',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF666666))),
                                  Text(
                                    _clienteNombre ?? '',
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green.shade800),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _procesando ? null : _acumularPuntos,
                            icon: _procesando
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.star_rounded, size: 24),
                            label: Text(
                              _procesando ? 'ACUMULANDO...' : 'ACUMULAR PUNTOS',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade700,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  // Botón consultar
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _procesando ? null : _buscarCliente,
                      icon: _procesando
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.search_rounded, size: 24),
                      label: Text(
                        _procesando ? 'CONSULTANDO...' : 'CONSULTAR CLIENTE',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],

                // Error
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _error!,
                            style: TextStyle(color: Colors.red.shade800, fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        // Lado derecho: teclado numérico
        Container(
          width: 300,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: const BorderRadius.only(
              bottomRight: Radius.circular(24),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: TecladoTactil(
              controller: _cedulaController,
              soloNumeros: true,
            ),
          ),
        ),
      ],
    );
  }
}

enum _FidelizarEstado {
  ingresandoCedula,
  confirmarAcumulacion,
  exitoso,
}
