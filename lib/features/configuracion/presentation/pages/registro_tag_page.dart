import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/services/api_consultas_service.dart';
import '../../../../core/theme/app_theme.dart';

/// Registro de Tag RFID a usuarios.
/// Replica: Java RegistroTagViewController
/// Layout: Tabla de usuarios registrados (arriba) + Panel de asignación (abajo)
class RegistroTagPage extends StatefulWidget {
  const RegistroTagPage({super.key});

  @override
  State<RegistroTagPage> createState() => _RegistroTagPageState();
}

class _RegistroTagPageState extends State<RegistroTagPage> {
  final ApiConsultasService _apiService = ApiConsultasService();

  List<Map<String, dynamic>> _usuarios = [];
  bool _cargando = true;
  Map<String, dynamic>? _usuarioSeleccionado;

  final TextEditingController _tagCtrl = TextEditingController();
  bool _guardando = false;
  String? _mensaje;
  bool _mensajeExito = false;

  // Polling RFID
  Timer? _rfidTimer;

  @override
  void initState() {
    super.initState();
    _cargarUsuarios();
    _iniciarPollingRfid();
  }

  @override
  void dispose() {
    _rfidTimer?.cancel();
    _tagCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarUsuarios() async {
    setState(() => _cargando = true);
    try {
      final result = await _apiService.getUsuariosTag();
      if (mounted) {
        setState(() {
          _usuarios = result;
          _cargando = false;
        });
      }
    } catch (e) {
      debugPrint('[RegistroTag] Error: $e');
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _iniciarPollingRfid() {
    _rfidTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      try {
        final lectura = await _apiService.getLecturaTag();
        if (lectura != null && lectura.isNotEmpty && mounted) {
          setState(() => _tagCtrl.text = lectura);
        }
      } catch (_) {}
    });
  }

  void _seleccionarUsuario(Map<String, dynamic>? usuario) {
    setState(() {
      _usuarioSeleccionado = usuario;
      _tagCtrl.text = usuario?['tag']?.toString() ?? '';
      _mensaje = null;
    });
  }

  Future<void> _guardarTag() async {
    if (_usuarioSeleccionado == null) {
      setState(() { _mensaje = 'Seleccione un usuario primero'; _mensajeExito = false; });
      return;
    }

    final tag = _tagCtrl.text.trim();
    if (tag.isEmpty) {
      setState(() { _mensaje = 'POR FAVOR ACERQUE EL TAG RFID'; _mensajeExito = false; });
      return;
    }

    setState(() => _guardando = true);

    try {
      final identificacion = _usuarioSeleccionado!['identificacion']?.toString() ?? '';
      final result = await _apiService.registrarTag(identificacion: identificacion, tag: tag);

      if (mounted) {
        setState(() {
          _guardando = false;
          if (result['success'] == true) {
            _mensaje = 'TAG RFID ASIGNADO CORRECTAMENTE';
            _mensajeExito = true;
            _cargarUsuarios();
          } else {
            _mensaje = result['message'] ?? 'Error al asignar tag';
            _mensajeExito = false;
          }
        });

        Future.delayed(const Duration(seconds: 4), () {
          if (mounted) setState(() => _mensaje = null);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _guardando = false;
          _mensaje = 'Error de conexión';
          _mensajeExito = false;
        });
      }
    }
  }

  void _limpiar() {
    setState(() {
      _usuarioSeleccionado = null;
      _tagCtrl.clear();
      _mensaje = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    // ════════════════════════════════════════
                    // TABLA DE USUARIOS REGISTRADOS
                    // ════════════════════════════════════════
                    Expanded(
                      flex: 5,
                      child: _buildTablaUsuarios(),
                    ),
                    const SizedBox(height: 16),
                    // ════════════════════════════════════════
                    // PANEL DE ASIGNACIÓN TAG
                    // ════════════════════════════════════════
                    _buildPanelAsignacion(),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════
  //  TABLA DE USUARIOS
  // ══════════════════════════════════════════════════

  Widget _buildTablaUsuarios() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Título sección
        Row(
          children: [
            Icon(Icons.people_alt_rounded, color: AppTheme.terpeRed, size: 20),
            const SizedBox(width: 8),
            const Text(
              'USUARIOS REGISTRADOS',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF333333), letterSpacing: 0.5),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.terpeRed.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_usuarios.length}',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.terpeRed),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Encabezado tabla
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.terpeRed,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: const Row(
            children: [
              Expanded(flex: 2, child: Text('IDENTIFICACIÓN', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
              Expanded(flex: 3, child: Text('NOMBRE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
              Expanded(flex: 2, child: Text('ESTADO', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
              Expanded(flex: 2, child: Text('MEDIO ASIGNADO', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
            ],
          ),
        ),

        // Filas
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: _cargando
                ? const Center(child: CircularProgressIndicator())
                : _usuarios.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.person_off_rounded, size: 48, color: Colors.grey.shade300),
                            const SizedBox(height: 8),
                            Text('Sin usuarios registrados', style: TextStyle(color: Colors.grey.shade400, fontSize: 14)),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: EdgeInsets.zero,
                        itemCount: _usuarios.length,
                        separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade100),
                        itemBuilder: (context, index) {
                          final u = _usuarios[index];
                          return _buildFilaUsuario(u, index);
                        },
                      ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilaUsuario(Map<String, dynamic> u, int index) {
    final identificacion = u['identificacion']?.toString() ?? '-';
    final nombre = u['nombre']?.toString() ?? '-';
    final estado = u['estado']?.toString().toUpperCase() ?? 'INACTIVO';
    final tag = u['tag']?.toString().trim() ?? '';
    final tieneTag = tag.isNotEmpty;
    final activo = estado == 'ACTIVO' || estado == 'A';

    // Highlight: sin tag = naranja/amarillo (como Java)
    final sinTagBg = !tieneTag ? const Color(0xFFFFF8E1) : null;

    return InkWell(
      onTap: () => _seleccionarUsuario(u),
      child: Container(
        color: sinTagBg ?? (index.isEven ? Colors.white : const Color(0xFFFAFBFC)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Text(
                identificacion,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                nombre.toUpperCase(),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              flex: 2,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: activo ? Colors.green.shade50 : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    activo ? 'ACTIVO' : 'INACTIVO',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: activo ? Colors.green.shade700 : Colors.red.shade600,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Center(
                child: tieneTag
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.nfc_rounded, size: 13, color: Colors.blue.shade600),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                tag,
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.blue.shade700),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      )
                    : Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Text(
                          'NO ASIGNADO',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.orange.shade800),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════
  //  PANEL DE ASIGNACIÓN TAG
  // ══════════════════════════════════════════════════

  Widget _buildPanelAsignacion() {
    final tagActual = _usuarioSeleccionado?['tag']?.toString().trim() ?? '';
    final tieneTagActual = tagActual.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: AppTheme.terpeRed,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: const Row(
              children: [
                Icon(Icons.nfc_rounded, color: Colors.white, size: 22),
                SizedBox(width: 10),
                Text(
                  'ASIGNAR TAG RFID',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                ),
              ],
            ),
          ),

          // Contenido
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Columna 1: Dropdown usuario ──
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SELECCIONAR USUARIO',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey.shade500, letterSpacing: 1),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F9FA),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: DropdownButtonFormField<String>(
                          initialValue: _usuarioSeleccionado?['identificacion']?.toString(),
                          isExpanded: true,
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            prefixIcon: Icon(Icons.person_rounded, color: AppTheme.terpeRed, size: 22),
                            hintText: 'Seleccione un usuario...',
                            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                          ),
                          items: _usuarios.map((u) {
                            final id = u['identificacion']?.toString() ?? '';
                            final nombre = u['nombre']?.toString() ?? '';
                            return DropdownMenuItem<String>(
                              value: id,
                              child: Text(
                                '$id — $nombre',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            final u = _usuarios.firstWhere(
                              (u) => u['identificacion']?.toString() == val,
                              orElse: () => {},
                            );
                            if (u.isNotEmpty) _seleccionarUsuario(u);
                          },
                        ),
                      ),

                      // Tag actual del usuario seleccionado
                      if (_usuarioSeleccionado != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: tieneTagActual ? Colors.blue.shade50 : Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: tieneTagActual ? Colors.blue.shade200 : Colors.orange.shade200,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                tieneTagActual ? Icons.nfc_rounded : Icons.warning_amber_rounded,
                                size: 16,
                                color: tieneTagActual ? Colors.blue.shade600 : Colors.orange.shade700,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                tieneTagActual ? 'Tag actual: $tagActual' : 'Sin tag asignado',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: tieneTagActual ? Colors.blue.shade700 : Colors.orange.shade800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(width: 24),

                // ── Columna 2: RFID + botones ──
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TAG RFID',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey.shade500, letterSpacing: 1),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          // Icon RFID animado
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: AppTheme.terpeRed.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.contactless_rounded, color: AppTheme.terpeRed, size: 26),
                          ),
                          const SizedBox(width: 12),
                          // Campo tag
                          Expanded(
                            child: TextField(
                              controller: _tagCtrl,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1),
                              decoration: InputDecoration(
                                hintText: 'Acerque el tag al lector...',
                                hintStyle: TextStyle(fontSize: 14, color: Colors.grey.shade400, fontWeight: FontWeight.normal),
                                filled: true,
                                fillColor: const Color(0xFFF8F9FA),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: AppTheme.terpeRed, width: 2),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 24),

                // ── Columna 3: Botones ──
                Column(
                  children: [
                    const SizedBox(height: 24),
                    // Botón Guardar
                    SizedBox(
                      width: 160,
                      height: 46,
                      child: ElevatedButton.icon(
                        onPressed: _guardando ? null : _guardarTag,
                        icon: _guardando
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.save_rounded, size: 20),
                        label: Text(
                          _guardando ? 'GUARDANDO...' : 'GUARDAR TAG',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.terpeRed,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                          disabledBackgroundColor: Colors.grey.shade400,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Botón Limpiar
                    SizedBox(
                      width: 160,
                      height: 46,
                      child: OutlinedButton.icon(
                        onPressed: _limpiar,
                        icon: Icon(Icons.clear_rounded, size: 18, color: Colors.grey.shade600),
                        label: Text(
                          'LIMPIAR',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey.shade600),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.grey.shade300),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Mensaje de estado
          if (_mensaje != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: _mensajeExito ? Colors.green.shade50 : Colors.red.shade50,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                border: Border(top: BorderSide(color: _mensajeExito ? Colors.green.shade200 : Colors.red.shade200)),
              ),
              child: Row(
                children: [
                  Icon(
                    _mensajeExito ? Icons.check_circle_rounded : Icons.error_rounded,
                    color: _mensajeExito ? Colors.green.shade600 : Colors.red.shade600,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _mensaje!,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: _mensajeExito ? Colors.green.shade700 : Colors.red.shade700,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════
  //  HEADER
  // ══════════════════════════════════════════════════

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
            'Registro Tag RFID',
            style: TextStyle(color: Color(0xFF333333), fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          IconButton(
            onPressed: _cargarUsuarios,
            icon: Icon(Icons.refresh_rounded, color: AppTheme.terpeRed),
            tooltip: 'Refrescar',
          ),
        ],
      ),
    );
  }
}