// import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../../core/services/api_consultas_service.dart';
import '../../../../core/theme/app_theme.dart';

/// Gestión de dispositivos del sistema.
/// Replica: Java DispositivosBean + GetDispositivosInfoUseCase
/// Dropdowns reales: TIPO (IBUTTON/RFID), INTERFAZ (SERIAL/TCP), CONECTOR (COM1-8)
class DispositivosPage extends StatefulWidget {
  const DispositivosPage({super.key});

  @override
  State<DispositivosPage> createState() => _DispositivosPageState();
}

class _DispositivosPageState extends State<DispositivosPage> {
  final ApiConsultasService _apiService = ApiConsultasService();
  List<Map<String, dynamic>> _dispositivos = [];
  bool _cargando = true;

  // Opciones de dropdowns (tomadas de la UI Java)
  static const List<String> _tiposOptions = ['IBUTTON', 'RFID'];
  static const List<String> _interfazOptions = ['SERIAL', 'TCP'];
  static const List<String> _conectorOptions = [
    'COM1', 'COM2', 'COM3', 'COM4',
    'COM5', 'COM6', 'COM7', 'COM8',
  ];
  static const List<String> _pOptions = ['P1', 'P2', 'P3', 'P4'];
  static const List<String> _cOptions = ['C1', 'C2'];

  @override
  void initState() {
    super.initState();
    _cargarDispositivos();
  }

  Future<void> _cargarDispositivos() async {
    setState(() => _cargando = true);
    try {
      final result = await _apiService.getDispositivos();
      if (mounted) {
        setState(() {
          _dispositivos = result;
          _cargando = false;
        });
      }
    } catch (e) {
      debugPrint('[Dispositivos] Error: $e');
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            // ── Toolbar: Agregar ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Row(
                children: [
                  Icon(Icons.devices_other_rounded, color: AppTheme.terpeRed, size: 22),
                  const SizedBox(width: 8),
                  const Text(
                    'Dispositivos',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF333333)),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.terpeRed.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_dispositivos.length}',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.terpeRed),
                    ),
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: () => _mostrarDialogoDispositivo(context),
                    icon: const Icon(Icons.add_rounded, size: 20),
                    label: const Text('AGREGAR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.terpeRed,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                    ),
                  ),
                ],
              ),
            ),
            // ── Encabezado de tabla ──
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.terpeRed,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: const Row(
                children: [
                  SizedBox(width: 50, child: Text('ID', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                  Expanded(flex: 2, child: Text('TIPO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                  Expanded(flex: 2, child: Text('INTERFAZ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                  Expanded(flex: 2, child: Text('CONECTOR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                  SizedBox(width: 70, child: Text('ESTADO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                  SizedBox(width: 100, child: Text('ACCIONES', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                ],
              ),
            ),
            // ── Tabla ──
            Expanded(
              child: _cargando
                  ? const Center(child: CircularProgressIndicator())
                  : _dispositivos.isEmpty
                      ? _buildEmptyState()
                      : Container(
                          margin: const EdgeInsets.symmetric(horizontal: 24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: RefreshIndicator(
                            onRefresh: _cargarDispositivos,
                            child: ListView.separated(
                              padding: EdgeInsets.zero,
                              itemCount: _dispositivos.length,
                              separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade200),
                              itemBuilder: (context, index) {
                                final d = _dispositivos[index];
                                return _buildFilaDispositivo(d, index);
                              },
                            ),
                          ),
                        ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildFilaDispositivo(Map<String, dynamic> d, int index) {
    final tipo = d['tipos'] ?? '-';
    final interfaz = d['interfaz'] ?? '-';
    final conector = d['conector'] ?? '-';
    final estado = d['estado'] ?? 'I';
    final activo = estado == 'A';
    final id = d['id'] ?? 0;

    return Container(
      color: index.isEven ? Colors.white : const Color(0xFFFAFBFC),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 50,
            child: Text('$id', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
          Expanded(
            flex: 2,
            child: _chipTipo(tipo),
          ),
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Icon(
                  interfaz.toUpperCase() == 'SERIAL' ? Icons.cable_rounded : Icons.lan_rounded,
                  size: 16,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 4),
                Text(interfaz, style: const TextStyle(fontSize: 13)),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Icon(Icons.usb_rounded, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(conector, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          SizedBox(
            width: 70,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: activo ? Colors.green.shade50 : Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                activo ? 'Activo' : 'Inact.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: activo ? Colors.green.shade700 : Colors.red.shade600,
                ),
              ),
            ),
          ),
          SizedBox(
            width: 100,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _accionBtn(Icons.edit_rounded, Colors.blue.shade600, 'Editar', () => _mostrarDialogoDispositivo(context, dispositivo: d)),
                const SizedBox(width: 4),
                _accionBtn(Icons.delete_rounded, Colors.red.shade500, 'Eliminar', () => _confirmarEliminar(context, d)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chipTipo(String tipo) {
    final esRfid = tipo.toUpperCase() == 'RFID';
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: esRfid ? const Color(0xFFE3F2FD) : const Color(0xFFFFF3E0),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: esRfid ? Colors.blue.shade200 : Colors.orange.shade200),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                esRfid ? Icons.contactless_rounded : Icons.key_rounded,
                size: 14,
                color: esRfid ? Colors.blue.shade700 : Colors.orange.shade800,
              ),
              const SizedBox(width: 4),
              Text(
                tipo,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: esRfid ? Colors.blue.shade700 : Colors.orange.shade800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _accionBtn(IconData icon, Color color, String tooltip, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          InkWell(
            onTap: () => Navigator.of(context).pop(),
            borderRadius: BorderRadius.circular(8),
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Icon(Icons.arrow_back_rounded, color: Color(0xFF333333), size: 24),
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'Gestión de Dispositivos',
            style: TextStyle(color: Color(0xFF333333), fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          IconButton(
            onPressed: _cargarDispositivos,
            icon: Icon(Icons.refresh_rounded, color: AppTheme.terpeRed),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.devices_rounded, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text('Sin dispositivos configurados', style: TextStyle(fontSize: 16, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text('Agregue dispositivos usando el botón superior', style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
        ],
      ),
    );
  }

  /// Diálogo para crear/editar dispositivo con dropdowns reales
  Future<void> _mostrarDialogoDispositivo(BuildContext context, {Map<String, dynamic>? dispositivo}) async {
    final esEdicion = dispositivo != null;

    // Valores iniciales (Java: tipos, interfaz, conector + atributos JSON)
    String tipo = dispositivo?['tipos']?.toString().toUpperCase() ?? _tiposOptions.first;
    if (!_tiposOptions.contains(tipo)) tipo = _tiposOptions.first;

    String interfaz = dispositivo?['interfaz']?.toString().toUpperCase() ?? _interfazOptions.first;
    if (!_interfazOptions.contains(interfaz)) interfaz = _interfazOptions.first;

    String conector = dispositivo?['conector']?.toString().toUpperCase() ?? _conectorOptions.first;
    if (!_conectorOptions.contains(conector)) conector = _conectorOptions.first;

    String estado = dispositivo?['estado'] ?? 'A';

    // Campos extra de atributos (P = posición, C = cara)
    final Map<String, dynamic> atributos = dispositivo?['atributos'] is Map
        ? Map<String, dynamic>.from(dispositivo!['atributos'])
        : {};

    String puerto = atributos['puerto']?.toString().toUpperCase() ?? _pOptions.first;
    if (!_pOptions.contains(puerto)) puerto = _pOptions.first;

    String cara = atributos['cara']?.toString().toUpperCase() ?? _cOptions.first;
    if (!_cOptions.contains(cara)) cara = _cOptions.first;

    final ipCtrl = TextEditingController(text: atributos['ip']?.toString() ?? '');
    final puertoTcpCtrl = TextEditingController(text: atributos['puerto_tcp']?.toString() ?? '');

    final resultado = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final esTcp = interfaz == 'TCP';

            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              insetPadding: const EdgeInsets.symmetric(horizontal: 60, vertical: 40),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Header con fondo rojo ──
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                      decoration: BoxDecoration(
                        color: AppTheme.terpeRed,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            esEdicion ? Icons.edit_rounded : Icons.add_circle_outline_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            esEdicion ? 'Editar Dispositivo' : 'Nuevo Dispositivo',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          if (esEdicion) ...[
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'ID: ${dispositivo['id']}',
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // ── Contenido ──
                    Padding(
                      padding: const EdgeInsets.fromLTRB(28, 28, 28, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Sección: Configuración principal
                          Text(
                            'CONFIGURACIÓN PRINCIPAL',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.grey.shade500,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Fila 1: Tipo + Interfaz
                          Row(
                            children: [
                              Expanded(
                                child: _buildDropdown(
                                  label: 'Tipo',
                                  icon: Icons.category_rounded,
                                  value: tipo,
                                  items: _tiposOptions,
                                  onChanged: (v) => setDialogState(() => tipo = v!),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildDropdown(
                                  label: 'Interfaz',
                                  icon: Icons.settings_ethernet_rounded,
                                  value: interfaz,
                                  items: _interfazOptions,
                                  onChanged: (v) => setDialogState(() => interfaz = v!),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Fila 2: Conector + Estado
                          Row(
                            children: [
                              Expanded(
                                child: _buildDropdown(
                                  label: 'Conector',
                                  icon: Icons.usb_rounded,
                                  value: conector,
                                  items: _conectorOptions,
                                  onChanged: (v) => setDialogState(() => conector = v!),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildDropdown(
                                  label: 'Estado',
                                  icon: Icons.toggle_on_rounded,
                                  value: estado,
                                  items: const ['A', 'I'],
                                  itemLabels: const {'A': 'Activo', 'I': 'Inactivo'},
                                  onChanged: (v) => setDialogState(() => estado = v!),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),
                          Divider(color: Colors.grey.shade200, height: 1),
                          const SizedBox(height: 24),

                          // Sección: Parámetros
                          Text(
                            esTcp ? 'PARÁMETROS DE RED' : 'PARÁMETROS DEL DISPOSITIVO',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.grey.shade500,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 16),

                          if (esTcp)
                            Row(
                              children: [
                                Expanded(
                                  child: _buildInput('Dirección IP', ipCtrl, Icons.language_rounded, hint: '192.168.1.100'),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildInput('Puerto TCP', puertoTcpCtrl, Icons.numbers_rounded, hint: '9100'),
                                ),
                              ],
                            )
                          else
                            Row(
                              children: [
                                Expanded(
                                  child: _buildDropdown(
                                    label: 'P (Posición)',
                                    icon: Icons.pin_drop_rounded,
                                    value: puerto,
                                    items: _pOptions,
                                    onChanged: (v) => setDialogState(() => puerto = v!),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildDropdown(
                                    label: 'C (Cara)',
                                    icon: Icons.looks_one_rounded,
                                    value: cara,
                                    items: _cOptions,
                                    onChanged: (v) => setDialogState(() => cara = v!),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── Acciones ──
                    Container(
                      padding: const EdgeInsets.fromLTRB(28, 16, 28, 20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAFBFC),
                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                        border: Border(top: BorderSide(color: Colors.grey.shade200)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                            ),
                            child: Text(
                              'CANCELAR',
                              style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600, fontSize: 14),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: () async {
                              // Construir atributos JSON
                              final Map<String, dynamic> attrs = {};
                              if (esTcp) {
                                if (ipCtrl.text.trim().isNotEmpty) attrs['ip'] = ipCtrl.text.trim();
                                if (puertoTcpCtrl.text.trim().isNotEmpty) attrs['puerto_tcp'] = puertoTcpCtrl.text.trim();
                              } else {
                                attrs['puerto'] = puerto;
                                attrs['cara'] = cara;
                              }

                              bool ok;
                              if (esEdicion) {
                                ok = await _apiService.editarDispositivo(
                                  id: dispositivo['id'],
                                  tipos: tipo,
                                  conector: conector,
                                  interfaz: interfaz,
                                  estado: estado,
                                  atributos: attrs.isNotEmpty ? attrs : null,
                                );
                              } else {
                                ok = await _apiService.crearDispositivo(
                                  tipos: tipo,
                                  conector: conector,
                                  interfaz: interfaz,
                                  estado: estado,
                                  atributos: attrs.isNotEmpty ? attrs : null,
                                );
                              }

                              if (ctx.mounted) Navigator.pop(ctx, ok);
                            },
                            icon: Icon(esEdicion ? Icons.save_rounded : Icons.add_rounded, size: 20),
                            label: Text(
                              esEdicion ? 'GUARDAR' : 'CREAR',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.terpeRed,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (resultado == true) {
      _cargarDispositivos();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(esEdicion ? 'Dispositivo actualizado' : 'Dispositivo creado'),
            backgroundColor: Colors.green.shade600,
          ),
        );
      }
    }
  }

  /// Dropdown estilizado Terpel
  Widget _buildDropdown({
    required String label,
    required IconData icon,
    required String value,
    required List<String> items,
    Map<String, String>? itemLabels,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
          border: InputBorder.none,
          icon: Icon(icon, size: 20, color: AppTheme.terpeRed),
          contentPadding: EdgeInsets.zero,
        ),
        items: items.map((item) => DropdownMenuItem(
          value: item,
          child: Text(
            itemLabels?[item] ?? item,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        )).toList(),
        onChanged: onChanged,
      ),
    );
  }

  /// Campo de texto estilizado
  Widget _buildInput(String label, TextEditingController controller, IconData icon, {String? hint}) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
        prefixIcon: Icon(icon, size: 20, color: AppTheme.terpeRed),
        filled: true,
        fillColor: const Color(0xFFF8F9FA),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppTheme.terpeRed, width: 2)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  Future<void> _confirmarEliminar(BuildContext context, Map<String, dynamic> dispositivo) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange.shade600, size: 28),
            const SizedBox(width: 10),
            const Text('Confirmar Eliminación', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: RichText(
          text: TextSpan(
            style: const TextStyle(fontSize: 15, color: Color(0xFF333333)),
            children: [
              const TextSpan(text: '¿Eliminar el dispositivo '),
              TextSpan(text: '${dispositivo['tipos']}', style: const TextStyle(fontWeight: FontWeight.bold)),
              TextSpan(text: ' (${dispositivo['conector']})'),
              const TextSpan(text: '?'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('CANCELAR', style: TextStyle(color: Colors.grey.shade600)),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.delete_rounded, size: 18),
            label: const Text('ELIMINAR', style: TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );

    if (confirmado == true) {
      final ok = await _apiService.eliminarDispositivo(dispositivo['id']);
      if (ok) {
        _cargarDispositivos();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: const Text('Dispositivo eliminado'), backgroundColor: Colors.green.shade600),
          );
        }
      }
    }
  }
}