import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/services/api_consultas_service.dart';
import '../../../../core/providers/session_provider.dart';
import '../../../../core/widgets/teclado_tactil.dart';
import '../../../../core/theme/app_theme.dart';

/// Pagina principal de Turnos
/// Muestra turnos activos y permite iniciar/cerrar turno
class TurnosPage extends StatefulWidget {
  final bool autoIniciar;
  final bool autoCerrar;
  const TurnosPage({super.key, this.autoIniciar = false, this.autoCerrar = false});

  @override
  State<TurnosPage> createState() => _TurnosPageState();
}

class _TurnosPageState extends State<TurnosPage> {
  final ApiConsultasService _apiService = ApiConsultasService();
  List<Map<String, dynamic>> _turnosActivos = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarTurnos().then((_) {
      if (!mounted) return;
      if (widget.autoIniciar) {
        _abrirIniciarTurno();
      } else if (widget.autoCerrar) {
        _abrirCerrarTurno();
      }
    });
  }

  Future<void> _cargarTurnos() async {
    setState(() => _cargando = true);
    try {
      final turnos = await _apiService.getTurnosActivosApi();
      if (mounted) {
        setState(() {
          _turnosActivos = turnos;
          _cargando = false;
        });
      }
    } catch (e) {
      print('[TurnosPage] Error cargando turnos: $e');
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _abrirIniciarTurno() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _IniciarTurnoWizard(
          onTurnoIniciado: () {
            _cargarTurnos();
            final session = Provider.of<SessionProvider>(context, listen: false);
            session.refrescarTurnos();
          },
        ),
      ),
    );
  }

  void _abrirCerrarTurno() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _CerrarTurnoWizard(
          onTurnoCerrado: () {
            _cargarTurnos();
            final session = Provider.of<SessionProvider>(context, listen: false);
            session.refrescarTurnos();
          },
        ),
      ),
    );
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
              child: _cargando
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _cargarTurnos,
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        children: [
                          // ── Turno Actual section ──
                          _buildSectionTitle(
                            icon: Icons.person_rounded,
                            title: 'Turno Actual',
                            count: _turnosActivos.length,
                          ),
                          const SizedBox(height: 12),
                          if (_turnosActivos.isNotEmpty)
                            ..._turnosActivos.map((t) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _TurnoCard(turno: t),
                            ))
                          else
                            _buildEmptyState(),
                          const SizedBox(height: 24),
                          // ── Botones de acción ──
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _abrirIniciarTurno,
                                  icon: const Icon(Icons.play_arrow_rounded, size: 22),
                                  label: const Text('INICIAR TURNO', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green.shade600,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    elevation: 2,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _turnosActivos.isNotEmpty ? _abrirCerrarTurno : null,
                                  icon: const Icon(Icons.stop_rounded, size: 22),
                                  label: const Text('CERRAR TURNO', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.terpeRed,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    elevation: 2,
                                    disabledBackgroundColor: Colors.grey.shade300,
                                    disabledForegroundColor: Colors.grey.shade500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
            ),
          ],
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
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
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
            'Gestionar Turnos',
            style: TextStyle(color: Color(0xFF333333), fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.terpeRed.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.schedule_rounded, color: AppTheme.terpeRed, size: 24),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle({required IconData icon, required String title, required int count}) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.terpeRed, size: 22),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF333333)),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: count > 0 ? Colors.green.shade100 : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: count > 0 ? Colors.green.shade700 : Colors.grey.shade600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(Icons.person_off_rounded, size: 56, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(
            'Sin turnos activos',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade500, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            'Inicie un turno para comenzar a operar',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }
}

/// Card premium para mostrar un turno activo
class _TurnoCard extends StatelessWidget {
  final Map<String, dynamic> turno;

  const _TurnoCard({required this.turno});

  @override
  Widget build(BuildContext context) {
    final nombre = turno['promotor_nombre'] ?? 'Sin nombre';
    final identificacion = turno['promotor_identificacion'] ?? '';
    final fechaInicio = turno['fecha_inicio'] ?? '';
    final saldo = turno['saldo'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.green.shade200, width: 2),
            ),
            child: Icon(Icons.person_rounded, color: Colors.green.shade600, size: 28),
          ),
          const SizedBox(width: 14),
          // Name, ID, date
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nombre,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A)),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.badge_outlined, size: 14, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text(
                      'ID: $identificacion',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(Icons.schedule_outlined, size: 14, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text(
                      'Inicio: $fechaInicio',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // Saldo inline
                Row(
                  children: [
                    Icon(Icons.account_balance_wallet_outlined, size: 14, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text(
                      'Saldo: \$$saldo',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Active badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.green.shade300),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.green.shade600,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text('Activo', style: TextStyle(color: Colors.green.shade700, fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


// ============================================================
// WIZARD: INICIAR TURNO
// ============================================================
// Si ya hay turno activo (principal): va directo al login
// Si no hay turno activo: primero pide surtidores, luego login

class _IniciarTurnoWizard extends StatefulWidget {
  final VoidCallback onTurnoIniciado;

  const _IniciarTurnoWizard({required this.onTurnoIniciado});

  @override
  State<_IniciarTurnoWizard> createState() => _IniciarTurnoWizardState();
}

class _IniciarTurnoWizardState extends State<_IniciarTurnoWizard> {
  final ApiConsultasService _apiService = ApiConsultasService();

  // Flujo
  bool _necesitaSurtidores = true; // true si es primer turno (principal)
  bool _verificandoTurnos = true;
  int _pasoActual = 0; // 0: surtidores (si aplica), 1: login

  // Surtidores (solo paso principal)
  List<Map<String, dynamic>> _surtidoresDisponibles = [];
  final Set<int> _surtidoresSeleccionados = {};
  final Map<int, String> _surtidorEstado = {};
  final Map<int, List<dynamic>> _totalizadoresPorSurtidor = {};
  bool _cargandoSurtidores = true;

  // Login (USUARIO, CONTRASEÑA, SALDO)
  final TextEditingController _usuarioController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _saldoController = TextEditingController(text: '0');
  int _campoActivo = 0; // 0=usuario, 1=password, 2=saldo
  bool _iniciandoTurno = false;
  String? _loginError;

  // Turnos activos (para mostrar tabla como en Java)
  List<Map<String, dynamic>> _turnosActivos = [];

  // RFID background polling
  bool _rfidPolling = false;
  bool _rfidDetectado = false;
  String? _rfidNombre;

  @override
  void initState() {
    super.initState();
    _usuarioController.addListener(_onTextoChanged);
    _passwordController.addListener(_onTextoChanged);
    _saldoController.addListener(_onTextoChanged);
    _verificarEstadoInicial();
  }

  void _onTextoChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _rfidPolling = false;
    _usuarioController.removeListener(_onTextoChanged);
    _passwordController.removeListener(_onTextoChanged);
    _saldoController.removeListener(_onTextoChanged);
    _usuarioController.dispose();
    _passwordController.dispose();
    _saldoController.dispose();
    super.dispose();
  }

  Future<void> _verificarEstadoInicial() async {
    try {
      final turnos = await _apiService.getTurnosActivosApi();
      if (mounted) {
        setState(() {
          _turnosActivos = turnos;
          _necesitaSurtidores = turnos.isEmpty;
          _verificandoTurnos = false;
          if (_necesitaSurtidores) {
            _pasoActual = 0;
          } else {
            _pasoActual = 1; // Saltar surtidores
          }
        });
        if (_necesitaSurtidores) {
          _cargarSurtidores();
        }
        _iniciarPollingRfid();
      }
    } catch (e) {
      print('[TurnoWizard] Error verificando turnos: $e');
      if (mounted) {
        setState(() {
          _verificandoTurnos = false;
          _necesitaSurtidores = true;
          _pasoActual = 0;
        });
        _cargarSurtidores();
        _iniciarPollingRfid();
      }
    }
  }

  // ---- SURTIDORES ----

  Future<void> _cargarSurtidores() async {
    try {
      final surtidores = await _apiService.getSurtidoresEstacion();
      if (mounted) {
        setState(() {
          _surtidoresDisponibles = surtidores;
          _cargandoSurtidores = false;
        });
      }
    } catch (e) {
      print('[TurnoWizard] Error cargando surtidores: $e');
      if (mounted) setState(() => _cargandoSurtidores = false);
    }
  }

  Future<void> _toggleSurtidor(int surtidor, String host) async {
    if (_surtidoresSeleccionados.contains(surtidor)) {
      setState(() {
        _surtidoresSeleccionados.remove(surtidor);
        _surtidorEstado.remove(surtidor);
        _totalizadoresPorSurtidor.remove(surtidor);
      });
      return;
    }

    setState(() {
      _surtidoresSeleccionados.add(surtidor);
      _surtidorEstado[surtidor] = 'cargando';
    });

    final resultado = await _apiService.getTotalizadores(surtidor: surtidor, host: host);

    if (mounted) {
      setState(() {
        if (resultado['exito'] == true) {
          _surtidorEstado[surtidor] = 'ok';
          _totalizadoresPorSurtidor[surtidor] = resultado['data'] as List<dynamic>;
        } else {
          _surtidorEstado[surtidor] = 'error';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Surtidor $surtidor: ${resultado['mensaje'] ?? 'Error'}'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      });
    }
  }

  bool get _puedeContinuarSurtidores {
    return _surtidoresSeleccionados.isNotEmpty &&
        _surtidoresSeleccionados.every((s) => _surtidorEstado[s] == 'ok');
  }

  // ---- RFID BACKGROUND ----

  void _iniciarPollingRfid() {
    _rfidPolling = true;
    _hacerPollRfid();
  }

  Future<void> _hacerPollRfid() async {
    if (!_rfidPolling || !mounted) return;

    try {
      final lectura = await _apiService.getLecturaIdentificadorRumbo(
        cara: 1,
        segundosEspera: 25,
        tipo: 'turno',
      );

      if (!mounted || !_rfidPolling) return;

      if (lectura != null) {
        print('[TurnoWizard] RFID detectado: $lectura');
        // serial = RFID tag serial, promotor_id = personas.id en BD (resuelto por Core)
        final cedula = lectura['serial']?.toString() ?? '';
        final nombre = lectura['promotor_nombre']?.toString() ?? '';
        final promotorId = int.tryParse(lectura['promotor_id']?.toString() ?? '') ?? 0;

        if (cedula.isNotEmpty || promotorId > 0) {
          // Validar promotor: preferir por personas_id (más confiable desde RFID)
          final result = await _apiService.validarPromotor(cedula, personasId: promotorId);
          if (!mounted) return;

          print('[TurnoWizard] validarPromotor result: ${result['exito']} mensaje: ${result['mensaje'] ?? 'OK'}');

          if (result['exito'] == true) {
            final promotor = result['promotor'] as Map<String, dynamic>;
            print('[TurnoWizard] Promotor encontrado: nombre=${promotor['nombre']} ident=${promotor['identificacion']} pin=${promotor['pin']}');
            setState(() {
              _usuarioController.text = promotor['identificacion']?.toString() ?? cedula;
              _passwordController.text = promotor['pin']?.toString() ?? '';
              if (_saldoController.text.isEmpty) _saldoController.text = '0';
              _rfidDetectado = true;
              _rfidNombre = promotor['nombre']?.toString() ?? nombre;
              _loginError = null;
            });
            print('[TurnoWizard] Controllers: usuario=${_usuarioController.text} pwd=${_passwordController.text}');
            print('[TurnoWizard] Estado: pasoActual=$_pasoActual necesitaSurt=$_necesitaSurtidores puedeContinuar=$_puedeContinuarSurtidores');

            // Si estamos en paso surtidores, avanzar al login
            if (_pasoActual == 0 && _necesitaSurtidores && _puedeContinuarSurtidores) {
              print('[TurnoWizard] -> Avanzando a login (surtidores listos)');
              setState(() => _pasoActual = 1);
            } else if (_pasoActual == 0 && !_necesitaSurtidores) {
              print('[TurnoWizard] -> Avanzando a login (no necesita surtidores)');
              setState(() => _pasoActual = 1);
            }

            // Auto-submit si ya estamos en login
            if (_pasoActual == 1) {
              print('[TurnoWizard] -> AUTO-INIT: llamando _iniciarTurno()');
              await Future.delayed(const Duration(milliseconds: 500));
              if (mounted) _iniciarTurno();
              return; // Turno iniciado, no seguir polling
            }

            // Si aún estamos en paso 0 (surtidores no listos),
            // los datos del promotor quedan pre-llenados.
            // Continuar polling por si pasa otra lectura RFID.
            print('[TurnoWizard] RFID guardado pero pasoActual=$_pasoActual, esperando surtidores');
            if (_rfidPolling && mounted) {
              _hacerPollRfid();
            }
            return;
          } else {
            // Promotor no encontrado - mostrar error en UI
            print('[TurnoWizard] Promotor no encontrado: ${result['mensaje']}');
            setState(() {
              _rfidDetectado = false;
              _rfidNombre = null;
              _loginError = result['mensaje']?.toString() ?? 'Promotor no encontrado';
            });
          }
        }
      }

      // Reintentar polling
      if (_rfidPolling && mounted) {
        _hacerPollRfid();
      }
    } catch (e) {
      print('[TurnoWizard] Error RFID poll: $e');
      if (_rfidPolling && mounted) {
        Future.delayed(const Duration(seconds: 3), () => _hacerPollRfid());
      }
    }
  }

  // ---- LOGIN / INICIAR ----

  TextEditingController get _controllerActivo {
    switch (_campoActivo) {
      case 0: return _usuarioController;
      case 1: return _passwordController;
      case 2: return _saldoController;
      default: return _usuarioController;
    }
  }

  Future<void> _iniciarTurno() async {
    final usuario = _usuarioController.text.trim();
    final password = _passwordController.text.trim();
    final saldo = int.tryParse(_saldoController.text.trim()) ?? 0;

    if (usuario.isEmpty) {
      setState(() => _loginError = 'Ingrese el usuario (identificacion)');
      return;
    }

    setState(() {
      _iniciandoTurno = true;
      _loginError = null;
    });

    // Validar promotor con PIN
    final validacion = await _apiService.validarPromotor(usuario, pin: password);

    if (!mounted) return;

    if (validacion['exito'] != true) {
      setState(() {
        _iniciandoTurno = false;
        _loginError = validacion['mensaje'] ?? 'Promotor no encontrado';
      });
      return;
    }

    final promotor = validacion['promotor'] as Map<String, dynamic>;
    final personasId = promotor['id'] as int;

    // Consolidar totalizadores
    List<dynamic> todosLosTotal = [];
    for (final entry in _totalizadoresPorSurtidor.entries) {
      todosLosTotal.addAll(entry.value);
    }

    final resultado = await _apiService.iniciarTurno(
      personasId: personasId,
      saldo: saldo,
      surtidores: _surtidoresSeleccionados.toList(),
      totalizadores: todosLosTotal.isNotEmpty ? todosLosTotal : null,
      esPrincipal: _necesitaSurtidores,
    );

    if (!mounted) return;

    setState(() => _iniciandoTurno = false);

    if (resultado['exito'] == true) {
      _rfidPolling = false;
      widget.onTurnoIniciado();
      final nombre = promotor['nombre'] ?? 'Promotor';
      // Diálogo de éxito — NO se puede cerrar tocando ni con back
      await showDialog(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black38,
        builder: (ctx) {
          Future.delayed(const Duration(seconds: 2), () {
            if (ctx.mounted) Navigator.of(ctx).pop();
          });
          return PopScope(
            canPop: false,
            child: Center(
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: 320,
                  padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withOpacity(0.3),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.check_circle_rounded, color: Colors.green.shade600, size: 48),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        '¡Turno Iniciado!',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF2E7D32)),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        nombre,
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.grey.shade700),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'ID: ${promotor['identificacion'] ?? usuario}',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
      // Overlay de carga "Volviendo al inicio..."
      if (mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          barrierColor: Colors.black54,
          builder: (ctx) {
            Future.delayed(const Duration(milliseconds: 1200), () {
              if (ctx.mounted) Navigator.of(ctx).pop();
            });
            return PopScope(
              canPop: false,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                    const SizedBox(height: 16),
                    Text(
                      'Volviendo al inicio...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      }
      // Ir a home
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      setState(() {
        _loginError = resultado['mensaje'] ?? 'Error al iniciar turno';
      });
    }
  }

  // ---- BUILD ----

  @override
  Widget build(BuildContext context) {
    if (_verificandoTurnos) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [const Color(0xFF4A4A4A), const Color(0xFF333333)],
            ),
          ),
          child: const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Colors.white),
                SizedBox(height: 16),
                Text('Verificando turnos...', style: TextStyle(color: Colors.white, fontSize: 16)),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [const Color(0xFF4A4A4A), const Color(0xFF333333)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildWizardHeader(context),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F0F0),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: _pasoActual == 0 && _necesitaSurtidores
                        ? _buildPasoSurtidores()
                        : _buildPasoLogin(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWizardHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Material(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: () {
                _rfidPolling = false;
                Navigator.of(context).pop();
              },
              borderRadius: BorderRadius.circular(12),
              child: const Padding(
                padding: EdgeInsets.all(10),
                child: Icon(Icons.arrow_back_rounded, color: Colors.white, size: 26),
              ),
            ),
          ),
          const SizedBox(width: 16),
          const Text(
            'INICIAR TURNO',
            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          // Indicador RFID
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _rfidDetectado ? Colors.green.shade400 : Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.contactless_rounded,
                  color: _rfidDetectado ? Colors.white : Colors.white70,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  _rfidDetectado ? 'RFID OK' : 'RFID...',
                  style: TextStyle(
                    color: _rfidDetectado ? Colors.white : Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---- PASO SURTIDORES ----

  Widget _buildPasoSurtidores() {
    final int selCount = _surtidoresSeleccionados.length;
    return Column(
      children: [
        // ── Header con ícono, título, contador ──
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          color: Colors.red.shade50,
          child: Row(
            children: [
              // Ícono gasolina en contenedor rojo
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.local_gas_station_rounded, color: Colors.red.shade700, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Selecciona surtidores',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF333333)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      selCount == 0
                          ? 'Puedes elegir varios'
                          : '$selCount seleccionado${selCount > 1 ? 's' : ''}',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // ── Grid de surtidores ──
        Expanded(
          child: _cargandoSurtidores
              ? const Center(child: CircularProgressIndicator())
              : _surtidoresDisponibles.isEmpty
                  ? const Center(child: Text('No se encontraron surtidores'))
                  : GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 2.2,
                      ),
                      itemCount: _surtidoresDisponibles.length,
                      itemBuilder: (context, index) {
                        final surtidor = _surtidoresDisponibles[index];
                        final num = surtidor['surtidor'] as int;
                        final host = surtidor['host'] as String;
                        return _SurtidorCard(
                          numero: num,
                          seleccionado: _surtidoresSeleccionados.contains(num),
                          estado: _surtidorEstado[num],
                          onTap: () => _toggleSurtidor(num, host),
                        );
                      },
                    ),
        ),
        // ── Botón CONTINUAR con count ──
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton(
                onPressed: _puedeContinuarSurtidores
                    ? () => setState(() => _pasoActual = 1)
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      selCount > 0 ? 'CONTINUAR ($selCount)' : 'CONTINUAR',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_rounded, size: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---- PASO LOGIN (como Java: USUARIO, CONTRASEÑA, SALDO + tabla turnos + teclado) ----

  Widget _buildPasoLogin() {
    return Column(
      children: [
        // Zona superior: formulario izquierda + tabla turnos derecha
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Columna izquierda: campos de login
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Campos scrollables
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildCampoLogin(
                                label: 'USUARIO',
                                controller: _usuarioController,
                                indice: 0,
                                icon: Icons.person_rounded,
                              ),
                              const SizedBox(height: 12),
                              _buildCampoLogin(
                                label: 'CONTRASEÑA',
                                controller: _passwordController,
                                indice: 1,
                                icon: Icons.lock_rounded,
                                obscure: true,
                              ),
                              const SizedBox(height: 12),
                              _buildCampoLogin(
                                label: 'SALDO',
                                controller: _saldoController,
                                indice: 2,
                                icon: Icons.attach_money_rounded,
                              ),
                              if (_loginError != null) ...[
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.red.shade200),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.error_outline, color: Colors.red.shade600, size: 18),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _loginError!,
                                          style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              if (_rfidDetectado && _rfidNombre != null) ...[
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.green.shade200),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.contactless_rounded, color: Colors.green.shade600, size: 18),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'RFID: $_rfidNombre',
                                          style: TextStyle(color: Colors.green.shade700, fontSize: 12, fontWeight: FontWeight.w600),
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
                      const SizedBox(height: 8),
                      // Boton iniciar (siempre visible abajo)
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: ElevatedButton.icon(
                          onPressed: _iniciandoTurno ? null : _iniciarTurno,
                          icon: _iniciandoTurno
                              ? const SizedBox(
                                  width: 18, height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.play_arrow_rounded, size: 24),
                          label: Text(
                            _iniciandoTurno ? 'INICIANDO...' : 'INICIAR TURNO',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade600,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 3,
                          ),
                        ),
                      ),
                      if (_necesitaSurtidores) ...[
                        const SizedBox(height: 4),
                        Center(
                          child: TextButton.icon(
                            onPressed: () => setState(() => _pasoActual = 0),
                            icon: const Icon(Icons.arrow_back_rounded, size: 16),
                            label: const Text('Volver a surtidores', style: TextStyle(fontSize: 12)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // Separador
              Container(width: 1, color: Colors.grey.shade200),
              // Columna derecha: tabla turnos activos
              Expanded(
                flex: 4,
                child: _buildTablaTurnosActivos(),
              ),
            ],
          ),
        ),
        // Zona inferior: teclado numerico flotante
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Center(
            child: TecladoTactil(
              controller: _controllerActivo,
              soloNumeros: true,
              height: 210,
              colorTema: const Color(0xFFBA0C2F), // Rojo Terpel solo aquí
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCampoLogin({
    required String label,
    required TextEditingController controller,
    required int indice,
    required IconData icon,
    bool obscure = false,
  }) {
    final bool activo = _campoActivo == indice;
    return GestureDetector(
      onTap: () => setState(() => _campoActivo = indice),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: activo ? const Color(0xFFE65100) : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: activo ? const Color(0xFFFFF3E0) : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: activo ? const Color(0xFFFF8C00) : Colors.grey.shade300,
                width: activo ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(icon, size: 20, color: activo ? const Color(0xFFE65100) : Colors.grey.shade500),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    obscure && controller.text.isNotEmpty
                        ? '*' * controller.text.length
                        : controller.text.isEmpty ? '' : controller.text,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: controller.text.isEmpty ? Colors.grey.shade400 : const Color(0xFF333333),
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

  Widget _buildTablaTurnosActivos() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: const Color(0xFF424242),
          child: const Text(
            'TURNOS ACTIVOS',
            style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ),
        // Header de tabla
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.grey.shade100,
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Text('PROMOTOR', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
              ),
              Expanded(
                flex: 2,
                child: Text('IDENTIFICACION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
              ),
              Expanded(
                flex: 3,
                child: Text('F. INICIO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _turnosActivos.isEmpty
              ? Center(
                  child: Text(
                    'Sin turnos activos',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                  ),
                )
              : ListView.separated(
                  padding: EdgeInsets.zero,
                  itemCount: _turnosActivos.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final t = _turnosActivos[index];
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      color: index.isEven ? Colors.white : Colors.grey.shade50,
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Text(
                              t['promotor_nombre'] ?? '',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              t['promotor_identificacion']?.toString() ?? '',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Text(
                              t['fecha_inicio']?.toString() ?? '',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}


/// Card para un surtidor en la seleccion — diseño compacto tipo mockup
class _SurtidorCard extends StatefulWidget {
  final int numero;
  final bool seleccionado;
  final String? estado;
  final VoidCallback onTap;

  const _SurtidorCard({
    required this.numero,
    required this.seleccionado,
    required this.estado,
    required this.onTap,
  });

  @override
  State<_SurtidorCard> createState() => _SurtidorCardState();
}

class _SurtidorCardState extends State<_SurtidorCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool esCargando = widget.estado == 'cargando';
    final bool esOk = widget.estado == 'ok';
    final bool esError = widget.estado != null && !esOk && !esCargando;

    // Colores del badge numérico
    Color badgeBg;
    Color badgeText;
    if (widget.seleccionado) {
      badgeBg = esError ? Colors.red.shade600 : Colors.green.shade600;
      badgeText = Colors.white;
    } else {
      badgeBg = Colors.grey.shade300;
      badgeText = Colors.grey.shade700;
    }

    // Colores del borde y fondo
    Color borderColor = widget.seleccionado
        ? (esError ? Colors.red.shade400 : Colors.green.shade400)
        : Colors.grey.shade200;
    Color bgColor = widget.seleccionado
        ? (esError ? Colors.red.shade50 : Colors.green.shade50)
        : Colors.white;

    // Status info
    String statusText;
    Color statusDotColor;
    if (esCargando) {
      statusText = 'Cargando...';
      statusDotColor = Colors.blue.shade400;
    } else if (esOk) {
      statusText = 'Disponible';
      statusDotColor = Colors.green.shade500;
    } else if (esError) {
      statusText = 'Sin comunicación';
      statusDotColor = Colors.red.shade500;
    } else {
      statusText = 'Disponible';
      statusDotColor = Colors.green.shade500;
    }

    return ScaleTransition(
      scale: _scaleAnimation,
      child: GestureDetector(
        onTapDown: (_) => _scaleController.forward(),
        onTapUp: (_) {
          _scaleController.reverse();
          if (!esCargando) widget.onTap();
        },
        onTapCancel: () => _scaleController.reverse(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: borderColor,
              width: widget.seleccionado ? 2.0 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.seleccionado
                    ? borderColor.withOpacity(0.15)
                    : Colors.black.withOpacity(0.04),
                blurRadius: widget.seleccionado ? 8 : 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Fila superior: Badge número + Título + Check ──
                Row(
                  children: [
                    // Badge numérico
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: badgeBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          '${widget.numero}',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: badgeText,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Título
                    Expanded(
                      child: Text(
                        'Surtidor ${widget.numero}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade800,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Check badge (solo si seleccionado y OK)
                    if (widget.seleccionado && esOk)
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: Colors.green.shade500,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check_rounded, color: Colors.white, size: 16),
                      )
                    else if (esCargando)
                      SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.blue.shade500,
                        ),
                      ),
                  ],
                ),
                const Spacer(),
                // ── Fila inferior: ícono fuel + status dot + texto ──
                Row(
                  children: [
                    Icon(
                      Icons.local_gas_station_rounded,
                      size: 16,
                      color: widget.seleccionado ? Colors.grey.shade600 : Colors.grey.shade400,
                    ),
                    const SizedBox(width: 6),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: statusDotColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: esError ? Colors.red.shade600 : Colors.green.shade700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


// ============================================================
// WIZARD: CERRAR TURNO
// ============================================================
// Flujo basado en TurnosFinalizarViewController.java:
// 1. Leer totalizadores en background (8019)
// 2. Mostrar turnos activos + formulario de login
// 3. Validar promotor (manual o RFID)
// 4. Verificar que tenga turno activo
// 5. PUT /api/jornada/finalizar al 8010

class _CerrarTurnoWizard extends StatefulWidget {
  final VoidCallback onTurnoCerrado;

  const _CerrarTurnoWizard({required this.onTurnoCerrado});

  @override
  State<_CerrarTurnoWizard> createState() => _CerrarTurnoWizardState();
}

class _CerrarTurnoWizardState extends State<_CerrarTurnoWizard> {
  final ApiConsultasService _apiService = ApiConsultasService();

  // Login
  final TextEditingController _usuarioController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  int _campoActivo = 0; // 0=usuario, 1=password
  bool _cerrando = false;
  String? _loginError;
  String? _mensajeExito;

  // Turnos activos
  List<Map<String, dynamic>> _turnosActivos = [];
  bool _cargando = true;

  // Totalizadores
  List<dynamic> _totalizadoresFinales = [];
  bool _leyendoTotalizadores = true;
  String _estadoTotalizadores = 'CONSULTANDO LECTURAS...';

  // RFID polling
  Timer? _rfidTimer;
  bool _rfidDetectado = false;
  String _rfidMensaje = '';

  @override
  void initState() {
    super.initState();
    _inicializar();
  }

  Future<void> _inicializar() async {
    await Future.wait([
      _cargarTurnos(),
      _leerTotalizadores(),
    ]);
    _iniciarPollRfid();
  }

  Future<void> _cargarTurnos() async {
    try {
      final turnos = await _apiService.getTurnosActivosApi();
      if (mounted) {
        setState(() {
          _turnosActivos = turnos;
          _cargando = false;
        });
      }
    } catch (e) {
      print('[CerrarTurno] Error cargando turnos: $e');
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _leerTotalizadores() async {
    try {
      // Obtener surtidores de la estación
      final surtidores = await _apiService.getSurtidoresEstacion();

      if (surtidores.isEmpty) {
        if (mounted) {
          setState(() {
            _leyendoTotalizadores = false;
            _estadoTotalizadores = 'SIN SURTIDORES';
          });
        }
        return;
      }

      List<dynamic> todosTotalizadores = [];

      for (final s in surtidores) {
        final surtidorId = s['surtidor'] as int;
        final host = s['host'] as String;

        try {
          final totResult = await _apiService.getTotalizadores(
            surtidor: surtidorId,
            host: host,
          );
          if (totResult['exito'] == true) {
            final data = totResult['data'] as List<dynamic>? ?? [];
            todosTotalizadores.addAll(data);
          }
        } catch (e) {
          print('[CerrarTurno] Error totalizadores surtidor $surtidorId: $e');
        }
      }

      if (mounted) {
        setState(() {
          _totalizadoresFinales = todosTotalizadores;
          _leyendoTotalizadores = false;
          _estadoTotalizadores = 'LECTURAS OK (${todosTotalizadores.length} registros)';
        });
      }
    } catch (e) {
      print('[CerrarTurno] Error leyendo totalizadores: $e');
      if (mounted) {
        setState(() {
          _leyendoTotalizadores = false;
          _estadoTotalizadores = 'ERROR LEYENDO TOTALIZADORES';
        });
      }
    }
  }

  void _iniciarPollRfid() {
    _rfidTimer?.cancel();
    _rfidTimer = Timer.periodic(const Duration(seconds: 3), (_) => _hacerPollRfid());
  }

  Future<void> _hacerPollRfid() async {
    if (_cerrando || _mensajeExito != null) return;
    try {
      final lectura = await _apiService.getLecturaIdentificadorRumbo(cara: 1, tipo: 'turno');
      if (lectura != null && mounted) {
        _rfidTimer?.cancel();

        final cedula = lectura['serial']?.toString() ?? '';
        final pin = lectura['pin']?.toString() ?? '';

        setState(() {
          _rfidDetectado = true;
          _rfidMensaje = 'RFID detectado: $cedula';
        });

        // Validar promotor con la cedula del RFID
        final resultado = await _apiService.validarPromotor(cedula, pin: pin);
        if (resultado['exito'] == true && mounted) {
          final promotor = resultado['promotor'];
          setState(() {
            _usuarioController.text = promotor['identificacion']?.toString() ?? cedula;
            _passwordController.text = pin;
            _rfidMensaje = 'RFID: ${promotor['nombre']}';
          });
          // Auto-submit
          await _cerrarTurno(fromRFID: true);
        } else if (mounted) {
          setState(() {
            _rfidMensaje = 'RFID: ${resultado['mensaje'] ?? 'Error'}';
            _rfidDetectado = false;
          });
          _iniciarPollRfid();
        }
      }
    } catch (_) {}
  }

  Future<void> _cerrarTurno({bool fromRFID = false}) async {
    final user = _usuarioController.text.trim();
    final password = _passwordController.text.trim();

    if (user.isEmpty) {
      setState(() => _loginError = 'Ingrese identificación del promotor');
      return;
    }

    if (!fromRFID && password.isEmpty) {
      setState(() => _loginError = 'Ingrese contraseña');
      return;
    }

    setState(() {
      _cerrando = true;
      _loginError = null;
    });

    try {
      // Validar promotor
      final validacion = await _apiService.validarPromotor(
        user,
        pin: fromRFID ? null : password,
      );
      if (validacion['exito'] != true) {
        setState(() {
          _loginError = validacion['mensaje'] ?? 'ERROR EN CREDENCIALES';
          _cerrando = false;
        });
        return;
      }

      final promotor = validacion['promotor'];
      final personaId = promotor['id'] as int;

      // Verificar que tenga turno activo
      final turnoPromotor = _turnosActivos.firstWhere(
        (t) => t['personas_id'] == personaId,
        orElse: () => {},
      );

      if (turnoPromotor.isEmpty) {
        setState(() {
          _loginError = 'ESTE PROMOTOR NO HA INICIADO TURNO';
          _cerrando = false;
        });
        return;
      }

      // Determinar si es principal (el que inició primero)
      final esPrincipal = _turnosActivos.isNotEmpty &&
          _turnosActivos.last['personas_id'] == personaId;

      // Construir lista de personas a cerrar
      List<Map<String, dynamic>> personasCierre;
      if (esPrincipal) {
        // Principal cierra a todos
        personasCierre = _turnosActivos.map((t) => {
          'personas_id': t['personas_id'] as int,
          'identificadorJornada': t['jornada_id'] as int,
          'grupo_jornada': t['grupo_jornada'],
        }).toList();
      } else {
        // Solo cierra su turno
        personasCierre = [
          {
            'personas_id': personaId,
            'identificadorJornada': turnoPromotor['jornada_id'] as int,
            'grupo_jornada': turnoPromotor['grupo_jornada'],
          }
        ];
      }

      // Llamar al endpoint de cierre
      final resultado = await _apiService.finalizarTurno(
        personas: personasCierre,
        totalizadoresFinales: esPrincipal ? _totalizadoresFinales : null,
        esPrincipal: esPrincipal,
      );

      if (resultado['exito'] == true) {
        setState(() {
          _cerrando = false;
          _mensajeExito = resultado['mensaje'] ?? 'Turno cerrado correctamente';
        });
        widget.onTurnoCerrado();

        // Esperar un momento y volver al Home
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      } else {
        setState(() {
          _loginError = resultado['mensaje'] ?? 'Error cerrando turno';
          _cerrando = false;
        });
      }
    } catch (e) {
      setState(() {
        _loginError = 'Error: $e';
        _cerrando = false;
      });
    }
  }

  @override
  void dispose() {
    _rfidTimer?.cancel();
    _usuarioController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _mensajeExito != null
                  ? _buildExitoView()
                  : _buildFormularioCierre(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          InkWell(
            onTap: () => Navigator.of(context).pop(),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.terpeRed.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.arrow_back_rounded, color: AppTheme.terpeRed, size: 22),
            ),
          ),
          const SizedBox(width: 14),
          const Text(
            'Cierre de Jornada',
            style: TextStyle(color: Color(0xFF333333), fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          // Indicador de totalizadores
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: _leyendoTotalizadores
                  ? Colors.orange.shade50
                  : Colors.green.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _leyendoTotalizadores
                    ? Colors.orange.shade200
                    : Colors.green.shade200,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_leyendoTotalizadores)
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange.shade700),
                  )
                else
                  Icon(Icons.check_circle, color: Colors.green.shade600, size: 16),
                const SizedBox(width: 6),
                Text(
                  _estadoTotalizadores,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: _leyendoTotalizadores
                        ? Colors.orange.shade800
                        : Colors.green.shade800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExitoView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_rounded, color: Colors.green.shade600, size: 80),
          const SizedBox(height: 24),
          Text(
            _mensajeExito!,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF333333)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Regresando a Turnos...',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildFormularioCierre() {
    return Column(
      children: [
        // Contenido principal (scroll)
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Columna izquierda: alerta + turnos afectados
                Expanded(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Warning alert ──
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 28),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Cierre global de turnos',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.orange.shade900),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Se cerrarán todos los turnos activos.',
                                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                                  ),
                                  Text(
                                    'Esta acción no se puede deshacer.',
                                    style: TextStyle(fontSize: 13, color: AppTheme.terpeRed, fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ── Turnos activos count + list ──
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Turnos activos: ${_turnosActivos.length}',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF333333)),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Turnos afectados:',
                              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                            ),
                            const SizedBox(height: 8),
                            _buildTurnosAfectados(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                // Columna derecha: credenciales + botón
                Expanded(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Credenciales ──
                      Text(
                        'Ingrese credenciales administrativas',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                      ),
                      const SizedBox(height: 12),

                      // Row con campos lado a lado
                      Row(
                        children: [
                          Expanded(
                            child: _buildCampoTexto(
                              label: 'Usuario (ID o identificación)',
                              controller: _usuarioController,
                              activo: _campoActivo == 0,
                              onTap: () => setState(() => _campoActivo = 0),
                              icono: Icons.person_rounded,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildCampoTexto(
                              label: 'PIN',
                              controller: _passwordController,
                              activo: _campoActivo == 1,
                              onTap: () => setState(() => _campoActivo = 1),
                              icono: Icons.lock_rounded,
                              obscure: true,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // ── Error message ──
                      if (_loginError != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline, color: Colors.red.shade700, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _loginError!,
                                  style: TextStyle(color: Colors.red.shade800, fontWeight: FontWeight.w600, fontSize: 13),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // ── RFID Status ──
                      if (_rfidMensaje.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _rfidDetectado ? Colors.green.shade50 : Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _rfidDetectado ? Colors.green.shade200 : Colors.blue.shade200,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _rfidDetectado ? Icons.nfc_rounded : Icons.sensors_rounded,
                                color: _rfidDetectado ? Colors.green.shade700 : Colors.blue.shade700,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _rfidMensaje,
                                  style: TextStyle(
                                    color: _rfidDetectado ? Colors.green.shade800 : Colors.blue.shade800,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // ── Botón CERRAR TODOS ──
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _cerrando || _leyendoTotalizadores ? null : () => _cerrarTurno(),
                          icon: _cerrando
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.warning_amber_rounded, size: 22),
                          label: Text(
                            _cerrando ? 'CERRANDO...' : 'CERRAR TODOS LOS TURNOS ACTIVOS',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.terpeRed,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                            disabledBackgroundColor: Colors.grey.shade400,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        // Teclado numérico compacto abajo
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Center(
            child: TecladoTactil(
              controller: _campoActivo == 0
                  ? _usuarioController
                  : _passwordController,
              soloNumeros: true,
              height: 210,
              colorTema: const Color(0xFFBA0C2F),
            ),
          ),
        ),
      ],
    );
  }

  /// Build the 'Turnos afectados' cards
  Widget _buildTurnosAfectados() {
    if (_cargando) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(16),
        child: CircularProgressIndicator(),
      ));
    }

    if (_turnosActivos.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text('Sin turnos activos', style: TextStyle(color: Colors.grey.shade500)),
      );
    }

    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: _turnosActivos.map((turno) {
        final nombre = turno['promotor_nombre'] ?? 'Sin nombre';
        final fechaInicio = turno['fecha_inicio']?.toString() ?? '';
        final horaInicio = _formatearFecha(fechaInicio);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.green.shade200),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle, color: Colors.green.shade600, size: 16),
              const SizedBox(width: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nombre,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade800),
                  ),
                  Text(
                    'Inició: $horaInicio',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCampoTexto({
    required String label,
    required TextEditingController controller,
    required bool activo,
    required VoidCallback onTap,
    required IconData icono,
    bool obscure = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: activo ? Colors.red.shade50 : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: activo ? Colors.red.shade400 : Colors.grey.shade300,
            width: activo ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icono, color: activo ? Colors.red.shade600 : Colors.grey.shade500, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      color: activo ? Colors.red.shade700 : Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    obscure
                        ? '*' * controller.text.length
                        : (controller.text.isEmpty ? ' ' : controller.text),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: controller.text.isEmpty ? Colors.grey.shade400 : const Color(0xFF333333),
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

  // _buildTablaTurnos removed — replaced by _buildTurnosAfectados

  String _formatearFecha(String fecha) {
    if (fecha.length >= 16) {
      return fecha.substring(0, 16);
    }
    return fecha;
  }
}
