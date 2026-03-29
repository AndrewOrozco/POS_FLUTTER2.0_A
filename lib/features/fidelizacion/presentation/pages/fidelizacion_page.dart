import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/services/api_consultas_service.dart';
import '../../../../core/widgets/teclado_tactil.dart';

/// Página principal del módulo Fidelización (Vive Terpel).
/// Diseño moderno con 5 opciones del menú Java.
class FidelizacionPage extends StatefulWidget {
  const FidelizacionPage({super.key});

  @override
  State<FidelizacionPage> createState() => _FidelizacionPageState();
}

class _FidelizacionPageState extends State<FidelizacionPage>
    with TickerProviderStateMixin {
  final ApiConsultasService _api = ApiConsultasService();

  // Animaciones de entrada para las tarjetas
  late final AnimationController _staggerController;
  late final List<Animation<double>> _cardAnimations;

  // Estado del panel activo (null = ninguno abierto)
  int? _panelActivo;

  // ── Consulta de Cliente ──
  final TextEditingController _cedulaCtrl = TextEditingController();
  bool _buscandoCliente = false;
  Map<String, dynamic>? _clienteEncontrado;
  String? _errorCliente;

  // ── Acumulación ──
  bool _cargandoVentas = false;
  List<Map<String, dynamic>> _ventasPendientes = [];
  bool _acumulando = false;
  String? _acumulacionMsg;
  bool? _acumulacionOk;

  // ── Timer auto-expiración (3 minutos) ──
  static const _expireMinutes = 3;
  Timer? _expireTimer;

  // ── Fidelizaciones Retenidas ──
  bool _cargandoRetenidas = false;
  List<Map<String, dynamic>> _retenidasList = [];

  // ── Validación Bono ──
  final TextEditingController _bonoCodigoCtrl = TextEditingController();
  final TextEditingController _bonoValorCtrl = TextEditingController();
  bool _validandoBono = false;
  Map<String, dynamic>? _bonoResultado;

  @override
  void initState() {
    super.initState();
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _cardAnimations = List.generate(5, (i) {
      final start = i * 0.12;
      final end = start + 0.4;
      return CurvedAnimation(
        parent: _staggerController,
        curve: Interval(start.clamp(0.0, 1.0), end.clamp(0.0, 1.0),
            curve: Curves.easeOutBack),
      );
    });

    _staggerController.forward();
  }

  @override
  void dispose() {
    _expireTimer?.cancel();
    _staggerController.dispose();
    _cedulaCtrl.dispose();
    _bonoCodigoCtrl.dispose();
    _bonoValorCtrl.dispose();
    super.dispose();
  }

  // ── Formato de moneda (sin dependencia intl) ──
  String _formatCurrency(dynamic value) {
    final num parsed = (value is num) ? value : (num.tryParse(value.toString()) ?? 0);
    final intVal = parsed.round();
    final str = intVal.abs().toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buffer.write('.');
      buffer.write(str[i]);
    }
    return '\$${intVal < 0 ? '-' : ''}${buffer.toString()}';
  }

  // ═══════════════════════════════════════════════════════════
  //  ACCIONES
  // ═══════════════════════════════════════════════════════════


  void _abrirPanel(int index) {
    setState(() {
      _panelActivo = _panelActivo == index ? null : index;
      // Reset state when switching panels
      _clienteEncontrado = null;
      _errorCliente = null;
      _acumulacionMsg = null;
      _acumulacionOk = null;
    });

    if (index == 1 && _panelActivo == 1) {
      _cargarVentasPendientes();
    }
    if (index == 4 && _panelActivo == 4) {
      _cargarRetenidas();
    }
  }

  // ── Cargar fidelizaciones retenidas ──
  Future<void> _cargarRetenidas() async {
    setState(() => _cargandoRetenidas = true);
    try {
      final result = await _api.obtenerFidelizacionesRetenidas();
      if (!mounted) return;
      setState(() {
        _cargandoRetenidas = false;
        _retenidasList = List<Map<String, dynamic>>.from(result['retenidas'] ?? []);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargandoRetenidas = false;
        _retenidasList = [];
      });
    }
  }

  // ── Validar bono ──
  Future<void> _validarBono() async {
    final codigo = _bonoCodigoCtrl.text.trim();
    final valorStr = _bonoValorCtrl.text.trim();
    if (codigo.isEmpty) return;

    setState(() {
      _validandoBono = true;
      _bonoResultado = null;
    });

    try {
      final valor = int.tryParse(valorStr) ?? 0;
      final result = await _api.validarBono(codigoBono: codigo, valorBono: valor);
      if (!mounted) return;
      setState(() {
        _validandoBono = false;
        _bonoResultado = result;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _validandoBono = false;
        _bonoResultado = {'exito': false, 'mensaje': 'Error: $e'};
      });
    }
  }

  Future<void> _buscarCliente() async {
    final cedula = _cedulaCtrl.text.trim();
    if (cedula.isEmpty) return;

    setState(() {
      _buscandoCliente = true;
      _clienteEncontrado = null;
      _errorCliente = null;
    });

    try {
      final result = await _api.validarClienteFidelizacion(
        numeroIdentificacion: cedula,
      );
      if (!mounted) return;
      setState(() {
        _buscandoCliente = false;
        if (result['exito'] == true) {
          _clienteEncontrado = result['cliente'] as Map<String, dynamic>?;
        } else {
          _errorCliente =
              result['mensaje']?.toString() ?? 'Cliente no encontrado';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _buscandoCliente = false;
        _errorCliente = 'Error: $e';
      });
    }
  }

  Future<void> _cargarVentasPendientes() async {
    setState(() => _cargandoVentas = true);
    try {
      final result = await _api.obtenerVentasPendientesFidelizacion();
      if (!mounted) return;
      setState(() {
        _cargandoVentas = false;
        _ventasPendientes =
            List<Map<String, dynamic>>.from(result['ventas'] ?? []);
        _filtrarVentasExpiradas();
      });
      _iniciarTimerExpire();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargandoVentas = false;
        _ventasPendientes = [];
      });
    }
  }

  /// Inicia un timer periódico (cada 10s) que filtra ventas expiradas (>3 min)
  void _iniciarTimerExpire() {
    _expireTimer?.cancel();
    _expireTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!mounted) { _expireTimer?.cancel(); return; }
      _filtrarVentasExpiradas();
    });
  }

  /// Filtra ventas cuya fecha es mayor a [_expireMinutes] minutos
  void _filtrarVentasExpiradas() {
    final ahora = DateTime.now();
    final antes = _ventasPendientes.length;
    _ventasPendientes.removeWhere((venta) {
      final fechaStr = venta['fecha']?.toString() ?? '';
      if (fechaStr.isEmpty) return false;
      try {
        final fechaVenta = DateTime.parse(fechaStr);
        return ahora.difference(fechaVenta).inMinutes >= _expireMinutes;
      } catch (_) {
        return false; // si no se parsea, no expirar
      }
    });
    if (_ventasPendientes.length != antes && mounted) {
      setState(() {});
    }
  }

  Future<void> _acumularPuntos(Map<String, dynamic> venta) async {
    // Primero necesita buscar cédula
    final cedula = await _mostrarDialogoCedula();
    if (cedula == null || cedula.isEmpty) return;

    setState(() {
      _acumulando = true;
      _acumulacionMsg = null;
      _acumulacionOk = null;
    });

    try {
      final movId = venta['id'] ?? venta['movimiento_id'] ?? 0;
      final result =
          await _api.acumularPuntosFidelizacion(
            movimientoId: movId as int,
            numeroIdentificacion: cedula,
          );
      if (!mounted) return;
      setState(() {
        _acumulando = false;
        _acumulacionOk = result['exito'] == true;
        _acumulacionMsg =
            result['mensaje']?.toString() ?? 'Operación completada';
        if (_acumulacionOk == true) {
          _cargarVentasPendientes();
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _acumulando = false;
        _acumulacionOk = false;
        _acumulacionMsg = 'Error: $e';
      });
    }
  }

  Future<String?> _mostrarDialogoCedula() async {
    final ctrl = TextEditingController();
    String tipoDoc = 'CC';
    return showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFFFFB300), Color(0xFFFF8F00)]),
                  borderRadius: BorderRadius.circular(10),
                ),
                child:
                    const Icon(Icons.person_search, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              const Text('Identificación del Cliente',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            ],
          ),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Selector tipo documento
                Row(
                  children: [
                    _buildTipoDocChip(
                      label: 'Cédula (CC)',
                      selected: tipoDoc == 'CC',
                      onTap: () => setDialogState(() => tipoDoc = 'CC'),
                    ),
                    const SizedBox(width: 10),
                    _buildTipoDocChip(
                      label: 'Cédula Extranjería (CE)',
                      selected: tipoDoc == 'CE',
                      onTap: () => setDialogState(() => tipoDoc = 'CE'),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Campo de texto
                TextField(
                  controller: ctrl,
                  keyboardType: TextInputType.number,
                  readOnly: true,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, letterSpacing: 1),
                  decoration: InputDecoration(
                    hintText: 'Número de identificación',
                    hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 15),
                    prefixIcon:
                        const Icon(Icons.badge, color: Color(0xFFFF8F00), size: 26),
                    filled: true,
                    fillColor: const Color(0xFFFFF8E1),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                ),
                const SizedBox(height: 12),
                // Teclado numérico
                TecladoTactil(
                  controller: ctrl,
                  soloNumeros: true,
                  height: 240,
                  onAceptar: () {
                    if (ctrl.text.trim().isNotEmpty) {
                      Navigator.pop(ctx, ctrl.text.trim());
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancelar',
                  style: TextStyle(color: Colors.grey.shade600)),
            ),
            ElevatedButton.icon(
              onPressed: () {
                if (ctrl.text.trim().isNotEmpty) {
                  Navigator.pop(ctx, ctrl.text.trim());
                }
              },
              icon: const Icon(Icons.search_rounded, size: 20),
              label: const Text('BUSCAR', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF8F00),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTipoDocChip({required String label, required bool selected, required VoidCallback onTap}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFFF8F00) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? const Color(0xFFFF8F00) : Colors.grey.shade300,
              width: 1.5,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : Colors.grey.shade600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F3EE),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: Row(
              children: [
                // Panel izquierdo: menú de tarjetas
                SizedBox(
                  width: 420,
                  child: _buildMenuCards(),
                ),
                // Panel derecho: contenido activo
                Expanded(
                  child: _buildActivePanel(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Hero Header ──
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFCC0000), Color(0xFFB20000), Color(0xFF8B0000)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
              color: Color(0x40000000), blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            // Botón volver
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded,
                  color: Colors.white, size: 26),
              onPressed: () => Navigator.pop(context),
              tooltip: 'Volver',
            ),
            const SizedBox(width: 8),
            // Logo / ícono
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white24),
              ),
              child: const Icon(Icons.loyalty_rounded,
                  color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            // Título
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'FIDELIZACIÓN',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
                Text(
                  'Vive Terpel — Programa de Lealtad',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.75),
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
            const Spacer(),
            // Badge decorativo
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFB300),
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                      color: Color(0x40000000),
                      blurRadius: 6,
                      offset: Offset(0, 2)),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star_rounded, color: Colors.white, size: 18),
                  SizedBox(width: 6),
                  Text(
                    'VIVE TERPEL',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Menú lateral con 5 tarjetas animadas ──
  Widget _buildMenuCards() {
    final items = [
      _MenuOption(
        index: 0,
        icon: Icons.person_search_rounded,
        title: 'Consulta de Cliente',
        subtitle: 'Buscar cliente por cédula',
        color: const Color(0xFF1976D2),
        gradient: const [Color(0xFF1976D2), Color(0xFF0D47A1)],
        disponible: true,
      ),
      _MenuOption(
        index: 1,
        icon: Icons.add_circle_rounded,
        title: 'Acumulación',
        subtitle: 'Acumular puntos en ventas',
        color: const Color(0xFF388E3C),
        gradient: const [Color(0xFF43A047), Color(0xFF2E7D32)],
        disponible: true,
      ),
      _MenuOption(
        index: 2,
        icon: Icons.redeem_rounded,
        title: 'Redención',
        subtitle: 'Redimir puntos acumulados',
        color: const Color(0xFFE65100),
        gradient: const [Color(0xFFFF6D00), Color(0xFFE65100)],
        disponible: true,
      ),
      _MenuOption(
        index: 3,
        icon: Icons.confirmation_num_rounded,
        title: 'Validación Bono',
        subtitle: 'Validar bonos y vouchers',
        color: const Color(0xFF7B1FA2),
        gradient: const [Color(0xFF9C27B0), Color(0xFF6A1B9A)],
        disponible: true,
      ),
      _MenuOption(
        index: 4,
        icon: Icons.pending_actions_rounded,
        title: 'Fidelizaciones\nRetenidas',
        subtitle: 'Gestionar acumulaciones pendientes',
        color: const Color(0xFF546E7A),
        gradient: const [Color(0xFF607D8B), Color(0xFF37474F)],
        disponible: true,
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(4, 0)),
        ],
      ),
      child: Column(
        children: [
          // Mini-header del menú
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              children: [
                Icon(Icons.menu_rounded,
                    color: Colors.grey.shade600, size: 20),
                const SizedBox(width: 8),
                Text(
                  'OPCIONES',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade600,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Cards
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              itemCount: items.length,
              itemBuilder: (ctx, i) {
                final item = items[i];
                return AnimatedBuilder(
                  animation: _cardAnimations[i],
                  builder: (ctx, child) {
                    final value = _cardAnimations[i].value;
                    return Transform.translate(
                      offset: Offset(-30 * (1 - value), 0),
                      child: Opacity(opacity: value.clamp(0.0, 1.0), child: child),
                    );
                  },
                  child: _buildMenuCard(item),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuCard(_MenuOption item) {
    final isActive = _panelActivo == item.index;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: item.disponible ? () => _abrirPanel(item.index) : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: isActive
                  ? LinearGradient(colors: item.gradient)
                  : null,
              color: isActive ? null : const Color(0xFFF8F9FA),
              border: Border.all(
                color: isActive
                    ? Colors.transparent
                    : item.disponible
                        ? Colors.grey.shade200
                        : Colors.grey.shade100,
                width: 1.5,
              ),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: item.color.withOpacity(0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                // Número
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: isActive
                        ? Colors.white.withOpacity(0.2)
                        : item.disponible
                            ? item.color.withOpacity(0.1)
                            : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      '${item.index + 1}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: isActive
                            ? Colors.white
                            : item.disponible
                                ? item.color
                                : Colors.grey.shade400,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                // Ícono
                Icon(
                  item.icon,
                  size: 26,
                  color: isActive
                      ? Colors.white
                      : item.disponible
                          ? item.color
                          : Colors.grey.shade400,
                ),
                const SizedBox(width: 12),
                // Texto
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isActive
                              ? Colors.white
                              : item.disponible
                                  ? Colors.black87
                                  : Colors.grey.shade500,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.subtitle,
                        style: TextStyle(
                          fontSize: 11,
                          color: isActive
                              ? Colors.white70
                              : Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
                // Badge
                if (!item.disponible)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'PRONTO',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade500,
                        letterSpacing: 0.5,
                      ),
                    ),
                  )
                else
                  Icon(
                    isActive
                        ? Icons.keyboard_arrow_right_rounded
                        : Icons.chevron_right_rounded,
                    color: isActive ? Colors.white70 : Colors.grey.shade400,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Panel derecho: contenido activo ──
  Widget _buildActivePanel() {
    if (_panelActivo == null) {
      return _buildWelcomePanel();
    }
    switch (_panelActivo) {
      case 0:
        return _buildConsultaCliente();
      case 1:
        return _buildAcumulacion();
      case 2:
        return _buildRedencion();
      case 3:
        return _buildValidacionBono();
      case 4:
        return _buildRetenidasPanel();
      default:
        return _buildWelcomePanel();
    }
  }

  // ── Welcome / Default Panel ──
  Widget _buildWelcomePanel() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Ícono grande animado
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFFFFE082), Color(0xFFFFB300)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFB300).withOpacity(0.3),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: const Icon(Icons.loyalty_rounded,
                size: 64, color: Colors.white),
          ),
          const SizedBox(height: 28),
          const Text(
            'Vive Terpel',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: Color(0xFFCC0000),
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Seleccione una opción del menú\npara gestionar la fidelización',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey.shade500,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),
          // Stats decorativos
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildStatBubble(Icons.people_rounded, 'Clientes',
                  const Color(0xFF1976D2)),
              const SizedBox(width: 16),
              _buildStatBubble(Icons.star_rounded, 'Puntos',
                  const Color(0xFFFF8F00)),
              const SizedBox(width: 16),
              _buildStatBubble(Icons.card_giftcard_rounded, 'Premios',
                  const Color(0xFF388E3C)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatBubble(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w600, fontSize: 14)),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  PANEL 1: CONSULTA DE CLIENTE
  // ═══════════════════════════════════════════════════════════

  Widget _buildConsultaCliente() {
    return Container(
      margin: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Título del panel
          _buildPanelHeader(
            icon: Icons.person_search_rounded,
            title: 'Consulta de Cliente',
            color: const Color(0xFF1976D2),
          ),
          const SizedBox(height: 20),
          // Campo de búsqueda
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10),
                    ],
                  ),
                  child: TextField(
                    controller: _cedulaCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: 'Ingrese cédula del cliente...',
                      hintStyle: TextStyle(color: Colors.grey.shade400),
                      prefixIcon: const Icon(Icons.badge_rounded,
                          color: Color(0xFF1976D2)),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16),
                    ),
                    onSubmitted: (_) => _buscarCliente(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: _buscandoCliente ? null : _buscarCliente,
                  icon: _buscandoCliente
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.search_rounded),
                  label: const Text('BUSCAR',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1976D2),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Teclado numérico
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.04), blurRadius: 8),
              ],
            ),
            child: TecladoTactil(controller: _cedulaCtrl, soloNumeros: true),
          ),
          const SizedBox(height: 20),
          // Resultado
          Expanded(child: _buildResultadoCliente()),
        ],
      ),
    );
  }

  Widget _buildResultadoCliente() {
    if (_buscandoCliente) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Color(0xFF1976D2)),
            const SizedBox(height: 16),
            Text('Buscando cliente...', style: TextStyle(color: Colors.grey.shade500)),
          ],
        ),
      );
    }

    if (_errorCliente != null) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.red.shade100),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.person_off_rounded,
                  size: 56, color: Colors.red.shade300),
              const SizedBox(height: 12),
              Text(
                'Cliente no encontrado',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade700),
              ),
              const SizedBox(height: 6),
              Text(
                _errorCliente!,
                style: TextStyle(color: Colors.red.shade400),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (_clienteEncontrado != null) {
      return _buildClienteCard();
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.person_search_rounded,
              size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(
            'Ingrese la cédula y presione BUSCAR',
            style:
                TextStyle(color: Colors.grey.shade400, fontSize: 15),
          ),
        ],
      ),
    );
  }

  Widget _buildClienteCard() {
    final nombre = _clienteEncontrado!['nombre'] ?? 'Sin nombre';
    final cedula =
        _clienteEncontrado!['numero_identificacion'] ?? '';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE3F2FD), Color(0xFFBBDEFB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF90CAF9)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1976D2).withOpacity(0.1),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              // Avatar
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1976D2), Color(0xFF0D47A1)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1976D2).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(Icons.person_rounded,
                    color: Colors.white, size: 36),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4CAF50),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('REGISTRADO',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700)),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFB300),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.star, color: Colors.white, size: 12),
                              SizedBox(width: 3),
                              Text('VIVE TERPEL',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      nombre,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0D47A1),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'C.C. $cedula',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              // Check icon
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded,
                    color: Color(0xFF4CAF50), size: 32),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  PANEL 2: ACUMULACIÓN
  // ═══════════════════════════════════════════════════════════

  Widget _buildAcumulacion() {
    return Container(
      margin: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPanelHeader(
            icon: Icons.add_circle_rounded,
            title: 'Acumulación de Puntos',
            color: const Color(0xFF388E3C),
          ),
          const SizedBox(height: 16),
          // Mensaje de acumulación
          if (_acumulacionMsg != null)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _acumulacionOk == true
                    ? Colors.green.shade50
                    : Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _acumulacionOk == true
                      ? Colors.green.shade200
                      : Colors.red.shade200,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _acumulacionOk == true
                        ? Icons.check_circle
                        : Icons.error_outline,
                    color: _acumulacionOk == true
                        ? Colors.green.shade600
                        : Colors.red.shade600,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _acumulacionMsg!,
                      style: TextStyle(
                        color: _acumulacionOk == true
                            ? Colors.green.shade700
                            : Colors.red.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          // Refresh button
          Row(
            children: [
              Text(
                'Ventas sin fidelizar',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _cargarVentasPendientes,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Actualizar'),
                style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF388E3C)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Lista de ventas
          Expanded(
            child: _cargandoVentas
                ? const Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFF388E3C)))
                : _ventasPendientes.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.receipt_long_rounded,
                                size: 56, color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            Text(
                              'No hay ventas pendientes de fidelizar',
                              style: TextStyle(
                                  color: Colors.grey.shade400,
                                  fontSize: 15),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Las ventas del turno actual aparecerán aquí',
                              style: TextStyle(
                                  color: Colors.grey.shade400,
                                  fontSize: 12),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: _ventasPendientes.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 8),
                        itemBuilder: (ctx, i) =>
                            _buildVentaCard(_ventasPendientes[i]),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildVentaCard(Map<String, dynamic> venta) {
    final consecutivo = venta['consecutivo']?.toString() ?? '—';
    final prefijo = venta['prefijo']?.toString() ?? '';
    final totalRaw = venta['venta_total'] ?? venta['total'] ?? 0;
    final fecha = venta['fecha']?.toString() ?? '';
    final producto = venta['producto']?.toString() ?? '';
    final promotor = venta['promotor']?.toString() ?? '';
    final cara = venta['cara']?.toString() ?? '';
    final cantidad = venta['cantidad']?.toString() ?? '';
    final placa = venta['placa']?.toString() ?? '';

    // Calcular tiempo restante antes de expirar
    int secsRestante = _expireMinutes * 60;
    if (fecha.isNotEmpty) {
      try {
        final fechaVenta = DateTime.parse(fecha);
        final elapsed = DateTime.now().difference(fechaVenta).inSeconds;
        secsRestante = (_expireMinutes * 60) - elapsed;
        if (secsRestante < 0) secsRestante = 0;
      } catch (_) {}
    }
    final minsR = secsRestante ~/ 60;
    final secsR = secsRestante % 60;
    final tiempoStr = '$minsR:${secsR.toString().padLeft(2, '0')}';
    final Color tiempoColor = secsRestante < 30
        ? Colors.red
        : secsRestante < 60
            ? Colors.orange.shade700
            : const Color(0xFF388E3C);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03), blurRadius: 6),
        ],
      ),
      child: Row(
        children: [
          // Ícono de recibo
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.local_gas_station_rounded,
                    color: Color(0xFF388E3C), size: 22),
                if (cara.isNotEmpty)
                  Text(cara, style: const TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w700,
                    color: Color(0xFF388E3C),
                  )),
              ],
            ),
          ),
          const SizedBox(width: 14),
          // Info principal
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$prefijo-$consecutivo',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                if (producto.isNotEmpty)
                  Text(
                    producto,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF455A64)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(Icons.access_time_rounded, size: 12, color: Colors.grey.shade400),
                    const SizedBox(width: 4),
                    Text(
                      fecha,
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade500),
                    ),
                    if (promotor.isNotEmpty) ...[
                      const SizedBox(width: 10),
                      Icon(Icons.person_rounded, size: 12, color: Colors.grey.shade400),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          promotor,
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
                if (cantidad.isNotEmpty || placa.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                      children: [
                        if (cantidad.isNotEmpty) ...[
                          Icon(Icons.speed_rounded, size: 12, color: Colors.grey.shade400),
                          const SizedBox(width: 3),
                          Text(cantidad, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                        ],
                        if (placa.isNotEmpty) ...[
                          const SizedBox(width: 10),
                          Icon(Icons.directions_car_rounded, size: 12, color: Colors.grey.shade400),
                          const SizedBox(width: 3),
                          Text(placa, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Monto formateado
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatCurrency(totalRaw),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF388E3C),
                ),
              ),
              const SizedBox(height: 6),
              // Botón acumular
              ElevatedButton.icon(
                onPressed: _acumulando ? null : () => _acumularPuntos(venta),
                icon: _acumulando
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.star_rounded, size: 16),
                label: const Text('ACUMULAR',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF388E3C),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
              const SizedBox(height: 4),
              // Countdown badge
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.timer_outlined, size: 13, color: tiempoColor),
                  const SizedBox(width: 3),
                  Text(
                    tiempoStr,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: tiempoColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  PANEL 3: REDENCIÓN (NO DISPONIBLE)
  // ═══════════════════════════════════════════════════════════

  Widget _buildRedencion() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(40),
        margin: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 20,
                offset: const Offset(0, 6)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFE65100).withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.redeem_rounded,
                  size: 56, color: Color(0xFFE65100)),
            ),
            const SizedBox(height: 24),
            const Text(
              'Redención de Puntos',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Color(0xFFE65100),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFE65100).withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 18, color: Color(0xFFE65100)),
                  SizedBox(width: 8),
                  Text(
                    'NO DISPONIBLE',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFE65100),
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'La redención de puntos Vive Terpel\naún no está habilitada en este equipo.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  PANEL 4: VALIDACIÓN BONO
  // ═══════════════════════════════════════════════════════════

  Widget _buildValidacionBono() {
    return Container(
      margin: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPanelHeader(
            icon: Icons.confirmation_num_rounded,
            title: 'Validación de Bono',
            color: const Color(0xFF7B1FA2),
          ),
          const SizedBox(height: 20),
          // Resultado
          if (_bonoResultado != null)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _bonoResultado!['valido'] == true
                    ? Colors.green.shade50
                    : Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _bonoResultado!['valido'] == true
                      ? Colors.green.shade200
                      : Colors.red.shade200,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _bonoResultado!['valido'] == true
                        ? Icons.check_circle
                        : Icons.error_outline,
                    color: _bonoResultado!['valido'] == true
                        ? Colors.green.shade600
                        : Colors.red.shade600,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _bonoResultado!['mensaje']?.toString() ?? '',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: _bonoResultado!['valido'] == true
                                ? Colors.green.shade700
                                : Colors.red.shade700,
                          ),
                        ),
                        if (_bonoResultado!['monto'] != null)
                          Text(
                            'Monto: \$${_bonoResultado!['monto']}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Colors.green.shade800,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          // Formulario
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.03), blurRadius: 8),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Código del Bono',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    )),
                const SizedBox(height: 8),
                TextField(
                  controller: _bonoCodigoCtrl,
                  decoration: InputDecoration(
                    hintText: 'Ingrese el código del bono (mín. 6 dígitos)',
                    prefixIcon: const Icon(Icons.qr_code_rounded,
                        color: Color(0xFF7B1FA2)),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: Color(0xFF7B1FA2), width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Valor del Bono',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    )),
                const SizedBox(height: 8),
                TextField(
                  controller: _bonoValorCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: 'Valor en pesos (opcional)',
                    prefixIcon: const Icon(Icons.attach_money_rounded,
                        color: Color(0xFF7B1FA2)),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: Color(0xFF7B1FA2), width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _validandoBono ? null : _validarBono,
                    icon: _validandoBono
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.verified_rounded),
                    label: Text(
                      _validandoBono ? 'VALIDANDO...' : 'VALIDAR BONO',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7B1FA2),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  PANEL 5: FIDELIZACIONES RETENIDAS
  // ═══════════════════════════════════════════════════════════

  Widget _buildRetenidasPanel() {
    return Container(
      margin: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPanelHeader(
            icon: Icons.pending_actions_rounded,
            title: 'Fidelizaciones Retenidas',
            color: const Color(0xFF546E7A),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                'Acumulaciones pendientes de envío',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _cargarRetenidas,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Actualizar'),
                style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF546E7A)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _cargandoRetenidas
                ? const Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFF546E7A)))
                : _retenidasList.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle_outline_rounded,
                                size: 56, color: Colors.green.shade300),
                            const SizedBox(height: 12),
                            Text(
                              'No hay fidelizaciones retenidas',
                              style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Todas las acumulaciones fueron enviadas',
                              style: TextStyle(
                                  color: Colors.grey.shade400,
                                  fontSize: 12),
                            ),
                          ],
                        ),
                      )
                    : Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: SingleChildScrollView(
                            child: DataTable(
                              headingRowColor: WidgetStateProperty.all(
                                  const Color(0xFF546E7A)),
                              headingTextStyle: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                              dataRowMinHeight: 40,
                              dataRowMaxHeight: 48,
                              columnSpacing: 20,
                              columns: const [
                                DataColumn(label: Text('NRO')),
                                DataColumn(label: Text('FECHA')),
                                DataColumn(label: Text('NEGOCIO')),
                                DataColumn(label: Text('CANTIDAD')),
                                DataColumn(
                                    label: Text('VALOR'), numeric: true),
                              ],
                              rows: _retenidasList.map((item) {
                                final total = item['total'] ?? 0;
                                return DataRow(cells: [
                                  DataCell(Text(
                                    '${item['id'] ?? '—'}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600),
                                  )),
                                  DataCell(Text(
                                    _formatFechaRetenida(
                                        item['fecha']?.toString() ?? ''),
                                    style: const TextStyle(fontSize: 12),
                                  )),
                                  DataCell(Text(
                                    item['negocio']?.toString() ?? '',
                                    style: const TextStyle(fontSize: 12),
                                  )),
                                  DataCell(Text(
                                    item['cantidad']?.toString() ?? '',
                                  )),
                                  DataCell(Text(
                                    _formatCurrency(total),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF388E3C),
                                    ),
                                  )),
                                ]);
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  String _formatFechaRetenida(String fecha) {
    if (fecha.isEmpty) return '';
    try {
      final dt = DateTime.parse(fecha);
      final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      return '${dt.day}-${dt.month.toString().padLeft(2, '0')} '
          '$h:${dt.minute.toString().padLeft(2, '0')} $ampm';
    } catch (_) {
      return fecha;
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  WIDGETS COMPARTIDOS
  // ═══════════════════════════════════════════════════════════

  Widget _buildPanelHeader({
    required IconData icon,
    required String title,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: 14),
        Text(
          title,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }
}

// ── Data class para opciones del menú ──
class _MenuOption {
  final int index;
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final List<Color> gradient;
  final bool disponible;

  const _MenuOption({
    required this.index,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.gradient,
    required this.disponible,
  });
}
