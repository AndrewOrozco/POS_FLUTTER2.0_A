import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/services/api_consultas_service.dart';
import '../../../../core/widgets/teclado_tactil.dart';
import '../../../../core/widgets/top_notification.dart';
import '../../../status_pump/presentation/providers/status_pump_provider.dart';

/// Pre-Autorización de Venta — Dos Modos:
///   GLP:              Manguera(GLP) → Placa(verificar) → Km → GUARDAR
///   CLIENTES PROPIOS: Manguera(noGLP) → iButton → Km → GUARDAR
class PlacaPage extends StatefulWidget {
  const PlacaPage({super.key});
  @override
  State<PlacaPage> createState() => _PlacaPageState();
}

enum _Modo { ninguno, glp, clientesPropios }

class _PlacaPageState extends State<PlacaPage> {
  final _api = ApiConsultasService();
  final _placaCtrl = TextEditingController();
  final _kmCtrl = TextEditingController();

  _Modo _modo = _Modo.ninguno;
  List<Map<String, dynamic>> _mangueras = [];
  Map<String, dynamic>? _mangueraSeleccionada;
  bool _cargando = false;
  bool _guardando = false;
  int _paso = 0; // 0=manguera, 1=placa/ibutton, 2=km
  String? _campoActivo;
  // Mensajes ahora se muestran con TopNotification (Steam-style)
  bool _caraOcupada = false;

  // iButton
  bool _esperandoChip = false;
  Timer? _pollingTimer;
  Map<String, dynamic>? _clienteData;
  String? _nombreCliente;
  String? _saldoCliente;

  // SICOM GLP
  bool _validandoSicom = false;
  String? _sicomMarca;
  String? _sicomCapacidad;
  bool _sicomValidado = false;

  @override
  void initState() {
    super.initState();
    // Actualizar UI en tiempo real cuando el teclado táctil escribe
    _placaCtrl.addListener(_onTextChanged);
    _kmCtrl.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _placaCtrl.removeListener(_onTextChanged);
    _kmCtrl.removeListener(_onTextChanged);
    _placaCtrl.dispose();
    _kmCtrl.dispose();
    _pollingTimer?.cancel();
    super.dispose();
  }

  // ═══════ LÓGICA ═══════

  Future<void> _cargarMangueras(String tipo) async {
    setState(() => _cargando = true);
    try {
      final m = await _api.getManguerasPlaca(tipo: tipo);
      setState(() { _mangueras = m; _cargando = false; });
    } catch (e) {
      setState(() { _cargando = false; _mostrarError('Error cargando mangueras: $e'); });
    }
  }

  void _seleccionarManguera(Map<String, dynamic> m) async {
    setState(() {
      _mangueraSeleccionada = m;
      _caraOcupada = false;
      _paso = 1;
      _campoActivo = _modo == _Modo.glp ? 'placa' : null;
    });

    // Para GLP verificar si cara ya tiene pre-auth
    if (_modo == _Modo.glp) {
      final r = await _api.verificarCaraUsada(m['cara'] as int);
      if (mounted && r['tiene_preautorizacion'] == true) {
        setState(() { _caraOcupada = true; });
        if (mounted) {
          TopNotification.show(context, message: 'Cara ${m['cara']} ya tiene Pre-Autorización activa', type: NotificationType.warning);
        }
      }
    }

    // Para Clientes Propios → iniciar lectura chip automática
    if (_modo == _Modo.clientesPropios) {
      _iniciarEsperaChip();
    }
  }

  void _elegirModo(_Modo modo) {
    setState(() {
      _modo = modo;
      _paso = 0;
      _mangueraSeleccionada = null;
      _placaCtrl.clear();
      _kmCtrl.clear();
      _campoActivo = null;
      _clienteData = null;
      _nombreCliente = null;
      _saldoCliente = null;
      _esperandoChip = false;
    });
    _pollingTimer?.cancel();
    _cargarMangueras(modo == _Modo.glp ? 'glp' : 'normal');
  }

  void _volverAModos() {
    _pollingTimer?.cancel();
    setState(() {
      _modo = _Modo.ninguno;
      _paso = 0;
      _esperandoChip = false;
      _campoActivo = null;
    });
  }

  // ─── iButton polling ───
  void _iniciarEsperaChip() async {
    await _api.consumirNotificacionIButton();
    setState(() {
      _esperandoChip = true;
      _clienteData = null;
      _nombreCliente = null;
      _saldoCliente = null;
      _placaCtrl.clear();
    });
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (!mounted || !_esperandoChip) { _pollingTimer?.cancel(); return; }
      final r = await _api.getUltimaNotificacionIButton();
      if (r['data'] != null && r['exito'] == true) {
        _pollingTimer?.cancel();
        await _api.consumirNotificacionIButton();
        _procesarIButton(r);
      } else if (r['exito'] == false && r['mensaje'] != null) {
        _pollingTimer?.cancel();
        await _api.consumirNotificacionIButton();
        setState(() { _esperandoChip = false; });
        if (mounted) {
          TopNotification.show(context, message: r['mensaje'], type: NotificationType.error);
        }
      }
    });
  }

  void _procesarIButton(Map<String, dynamic> result) {
    final data = result['data'] as Map<String, dynamic>;
    setState(() {
      _esperandoChip = false;
      _clienteData = data;
      _nombreCliente = data['nombreCliente'] ?? '';
      _saldoCliente = '${data['saldo'] ?? 0}';
      final placa = data['placaVehiculo'] ?? '';
      if (placa.toString().isNotEmpty) _placaCtrl.text = placa.toString();
      // Filtrar mangueras por familias autorizadas
      final familias = data['familias'] as List<dynamic>? ?? [];
      if (familias.isNotEmpty) {
        final ids = familias.map((f) => f['identificador_familia_abajo']).whereType<int>().toSet();
        _mangueras = _mangueras.where((m) => ids.contains(m['familia_id'])).toList();
      }
      _paso = 2; // pasar a km
      _campoActivo = 'km';
    });
    if (mounted) {
      TopNotification.show(context,
        message: result['mensaje'] ?? 'Cliente autorizado',
        subtitle: 'Placa: ${(result['data'] as Map?)?['placaVehiculo'] ?? ''}',
        type: NotificationType.success,
      );
    }
  }

  void _cancelarEsperaChip() {
    _pollingTimer?.cancel();
    setState(() { _esperandoChip = false; _paso = 0; });
  }

  // ─── GLP: verificar placa ───
  void _verificarPlacaGlp() async {
    if (_placaCtrl.text.trim().isEmpty) { _mostrarError('Ingrese placa'); return; }
    // Validar placa en SICOM antes de pasar al km
    setState(() { _validandoSicom = true; });
    final r = await _api.validarPlacaSicom(_placaCtrl.text.trim());
    if (!mounted) return;
    setState(() { _validandoSicom = false; });

    if (r['exito'] == true) {
      // SICOM OK — guardar marca/capacidad y avanzar al km
      setState(() {
        _sicomMarca = r['marca'] as String? ?? '';
        _sicomCapacidad = r['capacidad']?.toString() ?? '';
        _sicomValidado = true;
        _paso = 2;
        _campoActivo = 'km';
      });
      TopNotification.show(context,
        message: 'Vehículo autorizado — ${_sicomMarca ?? ""}',
        type: NotificationType.success);
    } else {
      // SICOM rechazó o no disponible
      setState(() { _sicomValidado = false; });
      TopNotification.show(context,
        message: r['mensaje'] ?? 'Error al validar placa en SICOM',
        type: NotificationType.error);
    }
  }

  // ─── Guardar ───
  Future<void> _guardar() async {
    if (_mangueraSeleccionada == null) { _mostrarError('Seleccione manguera'); return; }
    if (_placaCtrl.text.trim().isEmpty) { _mostrarError('Ingrese placa'); return; }
    if (_kmCtrl.text.trim().isEmpty) { _mostrarError('Ingrese kilometraje'); return; }
    setState(() { _guardando = true; });
    final r = await _api.preAutorizarPlaca(
      surtidor: _mangueraSeleccionada!['surtidor'] as int,
      cara: _mangueraSeleccionada!['cara'] as int,
      manguera: _mangueraSeleccionada!['manguera'] as int,
      grado: _mangueraSeleccionada!['grado'] as int,
      placa: _placaCtrl.text.trim(),
      odometro: _kmCtrl.text.trim(),
      // ── Clientes Propios (iButton): pasar datos del cliente ──
      saldo: _clienteData != null
          ? double.tryParse('${_clienteData!['saldo'] ?? 0}')
          : null,
      tipoCupo: _clienteData?['tipoCupo'] as String?,
      documentoCliente: _clienteData?['documentoIdentificacionCliente'] as String?,
      nombreCliente: _clienteData?['nombreCliente'] as String?,
      medioAutorizacion: _clienteData != null ? 'ibutton' : null,
      serialDispositivo: _clienteData?['placaVehiculo'] as String?,
      productoPrecio: _mangueraSeleccionada!['producto_precio'] != null
          ? double.tryParse('${_mangueraSeleccionada!['producto_precio']}')
          : null,
    );
    setState(() => _guardando = false);
    if (r['exito'] == true) {
      // Pre-asignar placa al StatusPump (misma lógica que Rumbo)
      if (mounted) {
        final cara = _mangueraSeleccionada!['cara'] as int;
        final placa = _placaCtrl.text.trim().toUpperCase();
        context.read<StatusPumpProvider>().asignarPlacaRumbo(
          cara, placa, clienteNombre: _nombreCliente,
        );
        TopNotification.show(context, message: r['mensaje'] ?? 'Pre-autorización creada', type: NotificationType.success);
      }
      Future.delayed(const Duration(seconds: 2), () { if (mounted) Navigator.pop(context); });
    } else {
      if (mounted) {
        TopNotification.show(context, message: r['mensaje'] ?? 'Error al guardar', type: NotificationType.error);
      }
    }
  }

  void _mostrarError(String msg) {
    if (mounted) {
      TopNotification.show(context, message: msg, type: NotificationType.error);
    }
  }

  Color _colorProducto(String f) {
    final u = f.toUpperCase();
    if (u.contains('CORRIENTE')) return const Color(0xFFD32F2F);
    if (u.contains('EXTRA')) return const Color(0xFF1565C0);
    if (u.contains('DIESEL') || u.contains('ACPM') || u.contains('BIOAC')) return const Color(0xFFF9A825);
    if (u.contains('GLP')) return const Color(0xFF7B1FA2);
    if (u.contains('UREA')) return const Color(0xFF00838F);
    return const Color(0xFFBA0C2F);
  }

  // ═══════ BUILD ═══════

  @override
  Widget build(BuildContext context) {
    // Pantalla esperando chip (fullscreen)
    if (_esperandoChip) return _buildEsperandoChip();
    // Selección de modo
    if (_modo == _Modo.ninguno) return _buildSelectorModo();
    // Flujo normal
    return _buildFlujo();
  }

  // ──── SELECTOR DE MODO ────
  Widget _buildSelectorModo() {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: Column(children: [
        _buildHeaderSimple('PRE-AUTORIZACIÓN DE VENTA', showBack: true),
        Expanded(child: Center(child: Padding(
          padding: const EdgeInsets.all(40),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _buildModoCard(
              icon: Icons.local_gas_station,
              titulo: 'GLP',
              subtitulo: 'Gas Licuado de Petróleo',
              color: const Color(0xFF7B1FA2),
              onTap: () => _elegirModo(_Modo.glp),
            ),
            const SizedBox(width: 32),
            _buildModoCard(
              icon: Icons.nfc,
              titulo: 'CLIENTES PROPIOS',
              subtitulo: 'Lectura chip iButton',
              color: const Color(0xFF1565C0),
              onTap: () => _elegirModo(_Modo.clientesPropios),
            ),
          ]),
        ))),
      ]),
    );
  }

  Widget _buildModoCard({required IconData icon, required String titulo, required String subtitulo, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 260, height: 260,
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.12), blurRadius: 20, offset: const Offset(0, 6))],
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.1)),
            child: Icon(icon, size: 40, color: color),
          ),
          const SizedBox(height: 20),
          Text(titulo, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color, letterSpacing: 1)),
          const SizedBox(height: 8),
          Text(subtitulo, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
        ]),
      ),
    );
  }

  // ──── FLUJO PRINCIPAL ────
  Widget _buildFlujo() {
    final pasos = _modo == _Modo.glp
        ? ['Seleccione Manguera', 'Ingrese Placa', 'Ingrese Kilometraje']
        : ['Seleccione Manguera', 'Lectura iButton', 'Ingrese Kilometraje'];

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: Column(children: [
        _buildHeaderConModo(),
        _buildStepper(pasos),
        Expanded(child: _cargando
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFBA0C2F)))
          : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(flex: 7, child: _buildContenidoPaso()),
              Expanded(flex: 3, child: _buildPanelDerecho()),
            ]),
        ),
        if (_campoActivo != null)
          TecladoTactil(
            controller: _campoActivo == 'placa' ? _placaCtrl : _kmCtrl,
            soloNumeros: _campoActivo == 'km',
            onAceptar: () {
              if (_campoActivo == 'placa') { _verificarPlacaGlp(); }
              else if (_campoActivo == 'km') { setState(() => _campoActivo = null); }
            },
          ),
        _buildBotonesInferiores(),
      ]),
    );
  }

  // ──── HEADER ────
  Widget _buildHeaderSimple(String titulo, {bool showBack = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFFBA0C2F), Color(0xFF8B0A25)])),
      child: SafeArea(bottom: false, child: Row(children: [
        if (showBack) InkWell(
          onTap: () => Navigator.pop(context),
          child: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.arrow_back, color: Colors.white, size: 22)),
        ),
        if (showBack) const SizedBox(width: 14),
        Text(titulo, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1)),
      ])),
    );
  }

  Widget _buildHeaderConModo() {
    final esGlp = _modo == _Modo.glp;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFFBA0C2F), Color(0xFF8B0A25)])),
      child: SafeArea(bottom: false, child: Row(children: [
        InkWell(
          onTap: _volverAModos,
          child: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.arrow_back, color: Colors.white, size: 22)),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('PRE-AUTORIZACIÓN', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          if (_nombreCliente != null) Text(_nombreCliente!, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white54)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(esGlp ? Icons.local_gas_station : Icons.nfc, color: Colors.white, size: 16),
            const SizedBox(width: 6),
            Text(esGlp ? 'GLP' : 'CLIENTES PROPIOS', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
          ]),
        ),
      ])),
    );
  }

  // ──── STEPPER ────
  Widget _buildStepper(List<String> pasos) {
    return Container(
      color: Colors.white, padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
      child: Row(children: [
        for (int i = 0; i < pasos.length; i++) ...[
          if (i > 0) Container(width: 20, height: 1, margin: const EdgeInsets.symmetric(horizontal: 4), color: Colors.grey.shade300),
          Expanded(child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 26, height: 26,
              decoration: BoxDecoration(
                color: _paso == i ? const Color(0xFFBA0C2F) : _paso > i ? const Color(0xFF4CAF50) : const Color(0xFFE0E0E0),
                shape: BoxShape.circle,
              ),
              child: Center(child: _paso > i
                ? const Icon(Icons.check, color: Colors.white, size: 16)
                : Text('${i + 1}', style: TextStyle(color: _paso == i ? Colors.white : Colors.grey, fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ),
            const SizedBox(width: 6),
            Flexible(child: Text(pasos[i], overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, fontWeight: _paso == i ? FontWeight.bold : FontWeight.normal, color: _paso == i ? const Color(0xFF333333) : Colors.grey))),
          ])),
        ],
      ]),
    );
  }

  // ──── CONTENIDO POR PASO ────
  Widget _buildContenidoPaso() {
    if (_paso == 0) return _buildPasoMangueras();
    if (_paso == 1) return _modo == _Modo.glp ? _buildPasoPlacaGlp() : _buildPasoIButton();
    return _buildPasoKm();
  }

  Widget _buildPasoMangueras() {
    final agrupado = <int, List<Map<String, dynamic>>>{};
    for (final m in _mangueras) { agrupado.putIfAbsent(m['cara'] as int, () => []).add(m); }

    if (agrupado.isEmpty && !_cargando) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.local_gas_station_outlined, size: 64, color: Colors.grey.shade300),
        const SizedBox(height: 12),
        Text('No hay mangueras disponibles', style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
        const SizedBox(height: 16),
        OutlinedButton.icon(onPressed: () => _cargarMangueras(_modo == _Modo.glp ? 'glp' : 'normal'), icon: const Icon(Icons.refresh), label: const Text('Actualizar')),
      ]));
    }

    return Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text('Paso 1  Seleccione Manguera', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey.shade700))),
      Expanded(child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.6),
        itemCount: agrupado.keys.length,
        itemBuilder: (ctx, i) {
          final cara = agrupado.keys.elementAt(i);
          final ms = agrupado[cara]!;
          final m0 = ms.first;
          final fam = (m0['familia_descripcion'] ?? '') as String;
          final color = _colorProducto(fam);
          final bloqueado = m0['bloqueado'] == true;
          final sel = _mangueraSeleccionada?['cara'] == cara;
          return GestureDetector(
            onTap: bloqueado ? null : () => _seleccionarManguera(m0),
            child: Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
                border: Border.all(color: sel ? color : bloqueado ? Colors.red.shade200 : Colors.grey.shade300, width: sel ? 2.5 : 1),
                boxShadow: [BoxShadow(color: sel ? color.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.04), blurRadius: sel ? 8 : 4, offset: const Offset(0, 2))]),
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(width: 32, height: 32, decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                    child: Icon(Icons.local_gas_station, color: color, size: 20)),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Cara $cara  $fam', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: bloqueado ? Colors.grey : const Color(0xFF333333))),
                    Text(m0['producto_descripcion'] ?? '', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                  ])),
                ]),
                const Spacer(),
                Row(children: [
                  for (final m in ms) ...[
                    Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(6)),
                      child: Text('Manguera ${m['manguera']}', style: const TextStyle(fontSize: 11, color: Colors.black54))),
                    const SizedBox(width: 6),
                  ],
                  const Spacer(),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: !bloqueado ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE), borderRadius: BorderRadius.circular(20)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(!bloqueado ? Icons.check_circle : Icons.cancel, size: 14, color: !bloqueado ? const Color(0xFF4CAF50) : const Color(0xFFE53935)),
                      const SizedBox(width: 4),
                      Text(!bloqueado ? 'Disponible' : 'No Disponible', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: !bloqueado ? const Color(0xFF4CAF50) : const Color(0xFFE53935))),
                    ])),
                ]),
              ]),
            ),
          );
        },
      )),
    ]));
  }

  // GLP Paso 2: Ingresar placa
  Widget _buildPasoPlacaGlp() {
    return Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Paso 2  Ingrese Placa', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey.shade700)),
      const SizedBox(height: 20),
      GestureDetector(
        onTap: () => setState(() => _campoActivo = 'placa'),
        child: Container(
          width: double.infinity, padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _campoActivo == 'placa' ? const Color(0xFFBA0C2F) : Colors.grey.shade300, width: _campoActivo == 'placa' ? 2.5 : 1)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.directions_car, size: 20, color: Color(0xFFBA0C2F)),
              const SizedBox(width: 8),
              Text('PLACA DEL VEHÍCULO', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
            ]),
            const SizedBox(height: 12),
            Text(_placaCtrl.text.isEmpty ? 'ABC123' : _placaCtrl.text,
              style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, letterSpacing: 4, color: _placaCtrl.text.isEmpty ? Colors.grey.shade300 : Colors.black87)),
          ]),
        ),
      ),
      const SizedBox(height: 16),
      // ── Botón VALIDAR SICOM ──
      SizedBox(width: double.infinity, child: ElevatedButton.icon(
        onPressed: _validandoSicom || _placaCtrl.text.trim().isEmpty ? null : _verificarPlacaGlp,
        icon: _validandoSicom
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.verified_user, size: 20),
        label: Text(_validandoSicom ? 'VALIDANDO...' : 'VALIDAR SICOM GLP',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey.shade400,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 2),
      )),
      // ── Info SICOM (marca/capacidad) ──
      if (_sicomValidado && _sicomMarca != null) ...[
        const SizedBox(height: 12),
        Container(
          width: double.infinity, padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF4CAF50))),
          child: Row(children: [
            const Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 22),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_sicomMarca ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              if (_sicomCapacidad != null && _sicomCapacidad!.isNotEmpty)
                Text('Capacidad máx: ${_sicomCapacidad}LT', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
            ])),
          ]),
        ),
      ],
    ]));
  }

  // Clientes Propios Paso 2: esperando chip (inline, no fullscreen)
  Widget _buildPasoIButton() {
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.nfc, size: 70, color: Color(0xFF1565C0)),
      const SizedBox(height: 16),
      const Text('PRESENTE CHIP IBUTTON', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1565C0), letterSpacing: 2)),
      const SizedBox(height: 8),
      Text('Esperando lectura...', style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
      const SizedBox(height: 16),
      const SizedBox(width: 36, height: 36, child: CircularProgressIndicator(strokeWidth: 3, color: Color(0xFF1565C0))),
      const SizedBox(height: 20),
      OutlinedButton(onPressed: _cancelarEsperaChip, child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
    ]));
  }

  // Paso 3: Kilometraje
  Widget _buildPasoKm() {
    return Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(_modo == _Modo.glp ? 'Paso 3  Ingrese Kilometraje' : 'Paso 3  Ingrese Kilometraje',
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey.shade700)),
      const SizedBox(height: 20),
      GestureDetector(
        onTap: () => setState(() => _campoActivo = 'km'),
        child: Container(
          width: double.infinity, padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _campoActivo == 'km' ? const Color(0xFFBA0C2F) : Colors.grey.shade300, width: _campoActivo == 'km' ? 2.5 : 1)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.speed, size: 20, color: Color(0xFFBA0C2F)),
              const SizedBox(width: 8),
              Text('KILOMETRAJE', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
            ]),
            const SizedBox(height: 12),
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(_kmCtrl.text.isEmpty ? '000000' : _kmCtrl.text,
                style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, letterSpacing: 4, color: _kmCtrl.text.isEmpty ? Colors.grey.shade300 : Colors.black87)),
              const SizedBox(width: 8),
              Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('km', style: TextStyle(fontSize: 18, color: Colors.grey.shade500, fontWeight: FontWeight.w500))),
            ]),
          ]),
        ),
      ),
    ]));
  }

  // ──── PANEL DERECHO ────
  Widget _buildPanelDerecho() {
    final tieneCliente = _modo == _Modo.clientesPropios && _clienteData != null;
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 12, 12, 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6)]),
      child: Column(children: [
        // Header del panel
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: tieneCliente ? const Color(0xFF1565C0) : const Color(0xFFF5F5F5),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
          ),
          child: Row(children: [
            Icon(tieneCliente ? Icons.verified_user : Icons.receipt_long,
              size: 20, color: tieneCliente ? Colors.white : Colors.grey.shade600),
            const SizedBox(width: 8),
            Expanded(child: Text(
              tieneCliente ? 'CLIENTE AUTORIZADO' : 'RESUMEN',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold,
                color: tieneCliente ? Colors.white : Colors.grey.shade700, letterSpacing: 0.5),
            )),
          ]),
        ),
        // Contenido scrollable
        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Info cliente propio — card destacado
            if (tieneCliente) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFE3F2FD), Color(0xFFBBDEFB)]),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(
                      width: 36, height: 36,
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF1565C0)),
                      child: const Icon(Icons.person, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_nombreCliente ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0D47A1))),
                      Text('Doc: ${_clienteData!['documentoCliente'] ?? ''}', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                    ])),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: _miniCard('Saldo', '\$ $_saldoCliente', const Color(0xFF2E7D32), Icons.account_balance_wallet)),
                    const SizedBox(width: 8),
                    Expanded(child: _miniCard('Tipo', _clienteData!['tipoCupo'] ?? 'L', const Color(0xFF5C6BC0), Icons.credit_card)),
                  ]),
                ]),
              ),
              const SizedBox(height: 12),
            ],

            // Manguera
            _resumenItem(Icons.local_gas_station, 'Manguera',
              _mangueraSeleccionada != null
                ? 'C${_mangueraSeleccionada!['cara']}M${_mangueraSeleccionada!['manguera']}'
                : 'No seleccionada',
              _mangueraSeleccionada != null ? _mangueraSeleccionada!['familia_descripcion'] ?? '' : '',
              _mangueraSeleccionada != null ? _colorProducto(_mangueraSeleccionada!['familia_descripcion'] ?? '') : Colors.grey),
            const SizedBox(height: 8),

            // Placa
            _resumenItem(Icons.directions_car, 'Placa',
              _placaCtrl.text.isEmpty ? 'No ingresada' : _placaCtrl.text.toUpperCase(),
              '', _placaCtrl.text.isNotEmpty ? const Color(0xFF333333) : Colors.grey),
            const SizedBox(height: 8),

            // Kilometraje
            _resumenItem(Icons.speed, 'Kilometraje',
              _kmCtrl.text.isEmpty ? '---' : '${_kmCtrl.text} km',
              '', _kmCtrl.text.isNotEmpty ? const Color(0xFF333333) : Colors.grey),

            if (_caraOcupada) ...[
              const SizedBox(height: 12),
              Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(8)),
                child: const Row(children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 18),
                  SizedBox(width: 8),
                  Expanded(child: Text('Cara ya tiene pre-autorización', style: TextStyle(fontSize: 12, color: Colors.orange))),
                ])),
            ],

            // Releer chip
            if (tieneCliente) ...[
              const SizedBox(height: 14),
              SizedBox(width: double.infinity, child: OutlinedButton.icon(
                onPressed: _iniciarEsperaChip,
                icon: const Icon(Icons.nfc, size: 16),
                label: const Text('RELEER CHIP', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF1565C0), side: const BorderSide(color: Color(0xFF1565C0)),
                  padding: const EdgeInsets.symmetric(vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              )),
            ],
          ]),
        )),
      ]),
    );
  }

  Widget _miniCard(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
        ]),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color),
          overflow: TextOverflow.ellipsis),
      ]),
    );
  }

  Widget _resumenItem(IconData icon, String label, String valor, String sub, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: const Color(0xFFFAFAFA), borderRadius: BorderRadius.circular(8)),
      child: Row(children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
          Text(valor, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
          if (sub.isNotEmpty) Text(sub, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
        ])),
      ]),
    );
  }

  // ──── BOTONES INFERIORES ────
  Widget _buildBotonesInferiores() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.grey.shade200))),
      child: Row(children: [
        Expanded(child: OutlinedButton.icon(
          onPressed: _volverAModos,
          icon: const Icon(Icons.close, size: 18),
          label: const Text('CANCELAR', style: TextStyle(fontWeight: FontWeight.bold)),
          style: OutlinedButton.styleFrom(foregroundColor: Colors.grey.shade700, side: BorderSide(color: Colors.grey.shade400),
            padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        )),
        const SizedBox(width: 16),
        Expanded(flex: 2, child: ElevatedButton.icon(
          onPressed: _guardando ? null : _guardar,
          icon: _guardando ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save, size: 20),
          label: Text(_guardando ? 'GUARDANDO...' : 'GUARDAR PRE-AUTORIZACIÓN', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32), foregroundColor: Colors.white, disabledBackgroundColor: Colors.grey.shade400,
            padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 2),
        )),
      ]),
    );
  }

  // ──── PANTALLA ESPERA CHIP FULLSCREEN ────
  Widget _buildEsperandoChip() {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(children: [
        _buildHeaderSimple('CLIENTE PROPIO — iButton', showBack: false),
        Expanded(child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 140, height: 140,
            decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white,
              boxShadow: [BoxShadow(color: const Color(0xFF1565C0).withValues(alpha: 0.15), blurRadius: 30, spreadRadius: 5)]),
            child: const Icon(Icons.nfc, size: 70, color: Color(0xFF1565C0)),
          ),
          const SizedBox(height: 32),
          const Text('PRESENTE CHIP IBUTTON', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1565C0), letterSpacing: 2)),
          const SizedBox(height: 12),
          Text('Esperando lectura del dispositivo...', style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
          const SizedBox(height: 24),
          const SizedBox(width: 40, height: 40, child: CircularProgressIndicator(strokeWidth: 3, color: Color(0xFF1565C0))),
        ]))),
        Container(width: double.infinity, padding: const EdgeInsets.all(16),
          child: OutlinedButton.icon(
            onPressed: _cancelarEsperaChip,
            icon: const Icon(Icons.close),
            label: const Text('CANCELAR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.grey.shade700, side: BorderSide(color: Colors.grey.shade400),
              padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          ),
        ),
      ]),
    );
  }
}
