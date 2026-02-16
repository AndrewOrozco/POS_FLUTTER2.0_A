import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/services/api_consultas_service.dart';
import '../../../../core/providers/session_provider.dart';
import '../../../../core/widgets/teclado_tactil.dart';

/// Pagina principal de Turnos
/// Muestra turnos activos y permite iniciar/cerrar turno
class TurnosPage extends StatefulWidget {
  const TurnosPage({super.key});

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
    _cargarTurnos();
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
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.red.shade700, Colors.red.shade900],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _buildTitle(),
                      const Divider(height: 1),
                      _buildBotones(),
                      const Divider(height: 1),
                      Expanded(child: _buildListaTurnos()),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Material(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: () => Navigator.of(context).pop(),
              borderRadius: BorderRadius.circular(12),
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Icon(Icons.arrow_back_rounded, color: Colors.white, size: 28),
              ),
            ),
          ),
          const SizedBox(width: 16),
          const Text(
            'Gestionar Turnos',
            style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.schedule_rounded, color: Colors.red.shade700, size: 40),
          ),
        ],
      ),
    );
  }

  Widget _buildTitle() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 32),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.people_alt_rounded, color: Colors.red.shade700, size: 32),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Turnos Activos',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF333333)),
              ),
              Text(
                '${_turnosActivos.length} promotor(es) en turno',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBotones() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _abrirIniciarTurno,
              icon: const Icon(Icons.play_arrow_rounded, size: 28),
              label: const Text('INICIAR TURNO', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 4,
              ),
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _turnosActivos.isNotEmpty ? _abrirCerrarTurno : null,
              icon: const Icon(Icons.stop_rounded, size: 28),
              label: const Text('CERRAR TURNO', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 4,
                disabledBackgroundColor: Colors.grey.shade300,
                disabledForegroundColor: Colors.grey.shade500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListaTurnos() {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_turnosActivos.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_off_rounded, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'Sin turnos activos',
              style: TextStyle(fontSize: 18, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Text(
              'Inicie un turno para comenzar a operar',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _cargarTurnos,
      child: ListView.separated(
        padding: const EdgeInsets.all(24),
        itemCount: _turnosActivos.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final turno = _turnosActivos[index];
          return _TurnoCard(turno: turno);
        },
      ),
    );
  }
}

/// Card para mostrar un turno activo
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.person_rounded, color: Colors.green.shade700, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nombre,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF333333)),
                ),
                const SizedBox(height: 4),
                Text(
                  'ID: $identificacion',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
                Text(
                  'Inicio: $fechaInicio',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.shade600,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('ACTIVO', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 8),
              Text(
                'Saldo: \$$saldo',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.green.shade700),
              ),
            ],
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
    _verificarEstadoInicial();
  }

  @override
  void dispose() {
    _rfidPolling = false;
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
      );

      if (!mounted || !_rfidPolling) return;

      if (lectura != null) {
        print('[TurnoWizard] RFID detectado: $lectura');
        // serial = promotorIdentificador (cedula), promotor_id = personas.id en BD
        final cedula = lectura['serial']?.toString() ?? '';
        final nombre = lectura['promotor_nombre']?.toString() ?? '';

        if (cedula.isNotEmpty) {
          // Validar promotor por cedula
          final result = await _apiService.validarPromotor(cedula);
          if (!mounted) return;

          if (result['exito'] == true) {
            final promotor = result['promotor'] as Map<String, dynamic>;
            setState(() {
              _usuarioController.text = promotor['identificacion']?.toString() ?? cedula;
              _passwordController.text = promotor['pin']?.toString() ?? '';
              if (_saldoController.text.isEmpty) _saldoController.text = '0';
              _rfidDetectado = true;
              _rfidNombre = promotor['nombre']?.toString() ?? nombre;
              _loginError = null;
            });

            // Si estamos en paso surtidores, avanzar al login
            if (_pasoActual == 0 && _necesitaSurtidores && _puedeContinuarSurtidores) {
              setState(() => _pasoActual = 1);
            } else if (_pasoActual == 0 && !_necesitaSurtidores) {
              setState(() => _pasoActual = 1);
            }

            // Auto-submit si ya estamos en login
            if (_pasoActual == 1) {
              await Future.delayed(const Duration(milliseconds: 500));
              if (mounted) _iniciarTurno();
            }
            return;
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Turno iniciado para ${promotor['nombre']}'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
      Navigator.of(context).pop();
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
              colors: [Colors.red.shade700, Colors.red.shade900],
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
            colors: [Colors.red.shade700, Colors.red.shade900],
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
                    color: Colors.white,
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
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.red.shade50,
          child: Row(
            children: [
              Icon(Icons.local_gas_station_rounded, color: Colors.red.shade700, size: 24),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Seleccione los surtidores para leer totalizadores',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF333333)),
                ),
              ),
            ],
          ),
        ),
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
                        childAspectRatio: 1.6,
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
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton.icon(
                onPressed: _puedeContinuarSurtidores
                    ? () => setState(() => _pasoActual = 1)
                    : null,
                icon: const Icon(Icons.arrow_forward_rounded),
                label: const Text('CONTINUAR', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
        // Zona inferior: teclado numerico
        Container(
          decoration: BoxDecoration(
            color: Colors.red.shade700,
            border: Border(top: BorderSide(color: Colors.red.shade800, width: 2)),
          ),
          child: SizedBox(
            height: 220,
            child: TecladoTactil(
              controller: _controllerActivo,
              soloNumeros: true,
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
              color: activo ? Colors.red.shade700 : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: activo ? Colors.red.shade50 : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: activo ? Colors.red.shade400 : Colors.grey.shade300,
                width: activo ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(icon, size: 20, color: activo ? Colors.red.shade700 : Colors.grey.shade500),
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
          color: Colors.red.shade700,
          child: const Text(
            'TURNOS ACTIVOS',
            style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ),
        // Header de tabla
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.red.shade50,
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Text('PROMOTOR', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red.shade700)),
              ),
              Expanded(
                flex: 2,
                child: Text('IDENTIFICACION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red.shade700)),
              ),
              Expanded(
                flex: 3,
                child: Text('F. INICIO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red.shade700)),
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


/// Card para un surtidor en la seleccion
class _SurtidorCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    Color bgColor;
    Color borderColor;
    Widget trailing;

    if (!seleccionado) {
      bgColor = Colors.grey.shade50;
      borderColor = Colors.grey.shade300;
      trailing = const SizedBox();
    } else if (estado == 'cargando') {
      bgColor = Colors.blue.shade50;
      borderColor = Colors.blue.shade300;
      trailing = const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2));
    } else if (estado == 'ok') {
      bgColor = Colors.green.shade50;
      borderColor = Colors.green.shade400;
      trailing = Icon(Icons.check_circle_rounded, color: Colors.green.shade600, size: 24);
    } else {
      bgColor = Colors.red.shade50;
      borderColor = Colors.red.shade300;
      trailing = Icon(Icons.error_rounded, color: Colors.red.shade600, size: 24);
    }

    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: estado == 'cargando' ? null : onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: seleccionado ? 2 : 1),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(
                    Icons.local_gas_station_rounded,
                    color: seleccionado ? Colors.green.shade700 : Colors.grey.shade500,
                    size: 28,
                  ),
                  trailing,
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Surtidor $numero',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: seleccionado ? Colors.green.shade800 : Colors.grey.shade700,
                ),
              ),
            ],
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
      final lectura = await _apiService.getLecturaIdentificadorRumbo(cara: 1);
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
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.red.shade700, Colors.red.shade900],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: _mensajeExito != null
                      ? _buildExitoView()
                      : _buildFormularioCierre(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Material(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: () => Navigator.of(context).pop(),
              borderRadius: BorderRadius.circular(12),
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Icon(Icons.arrow_back_rounded, color: Colors.white, size: 28),
              ),
            ),
          ),
          const SizedBox(width: 16),
          const Text(
            'CIERRE DE JORNADA',
            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          // Indicador de totalizadores
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: _leyendoTotalizadores
                  ? Colors.orange.shade100
                  : Colors.green.shade100,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_leyendoTotalizadores)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Icon(Icons.check_circle, color: Colors.green.shade700, size: 18),
                const SizedBox(width: 8),
                Text(
                  _estadoTotalizadores,
                  style: TextStyle(
                    fontSize: 12,
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
    return Row(
      children: [
        // Lado izquierdo: formulario login + tabla turnos
        Expanded(
          flex: 3,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Titulo
                Row(
                  children: [
                    Icon(Icons.lock_outline_rounded, color: Colors.red.shade700, size: 28),
                    const SizedBox(width: 12),
                    const Text(
                      'Ingrese sus credenciales',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF333333)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Ingrese su identificación y contraseña, o use RFID',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 20),

                // Campo USUARIO
                _buildCampoTexto(
                  label: 'USUARIO (Identificación)',
                  controller: _usuarioController,
                  activo: _campoActivo == 0,
                  onTap: () => setState(() => _campoActivo = 0),
                  icono: Icons.person_rounded,
                ),
                const SizedBox(height: 14),

                // Campo CONTRASEÑA
                _buildCampoTexto(
                  label: 'CONTRASEÑA (PIN)',
                  controller: _passwordController,
                  activo: _campoActivo == 1,
                  onTap: () => setState(() => _campoActivo = 1),
                  icono: Icons.lock_rounded,
                  obscure: true,
                ),
                const SizedBox(height: 20),

                // Botón CERRAR TURNO
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _cerrando || _leyendoTotalizadores ? null : () => _cerrarTurno(),
                    icon: _cerrando
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.stop_rounded, size: 24),
                    label: Text(
                      _cerrando ? 'CERRANDO...' : 'CERRAR TURNO',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      disabledBackgroundColor: Colors.grey.shade400,
                    ),
                  ),
                ),

                // Error
                if (_loginError != null) ...[
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
                            _loginError!,
                            style: TextStyle(color: Colors.red.shade800, fontWeight: FontWeight.w600, fontSize: 13),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // RFID Status
                if (_rfidMensaje.isNotEmpty) ...[
                  const SizedBox(height: 12),
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
                          size: 20,
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
                ],

                const SizedBox(height: 24),

                // Tabla de turnos activos
                const Text(
                  'PROMOTORES EN TURNO',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF555555)),
                ),
                const SizedBox(height: 8),
                _buildTablaTurnos(),
              ],
            ),
          ),
        ),

        // Lado derecho: teclado numérico
        Container(
          width: 350,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(24),
              bottomRight: Radius.circular(24),
            ),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  _campoActivo == 0 ? 'USUARIO' : 'CONTRASEÑA',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: TecladoTactil(
                    controller: _campoActivo == 0
                        ? _usuarioController
                        : _passwordController,
                    soloNumeros: true,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
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

  Widget _buildTablaTurnos() {
    if (_cargando) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(20),
        child: CircularProgressIndicator(),
      ));
    }

    if (_turnosActivos.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Text('Sin turnos activos', style: TextStyle(color: Colors.grey)),
      );
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          // Encabezado
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(9),
                topRight: Radius.circular(9),
              ),
            ),
            child: const Row(
              children: [
                Expanded(flex: 3, child: Text('PROMOTOR', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text('IDENTIFICACIÓN', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text('F. INICIO', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
              ],
            ),
          ),
          // Filas
          ...List.generate(_turnosActivos.length, (i) {
            final turno = _turnosActivos[i];
            return InkWell(
              onTap: () {
                // Al hacer clic en una fila, auto-llenar el usuario
                setState(() {
                  _usuarioController.text = turno['promotor_identificacion']?.toString() ?? '';
                  _campoActivo = 1; // Mover al campo password
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: i.isEven ? Colors.white : Colors.grey.shade50,
                  border: Border(top: BorderSide(color: Colors.grey.shade200)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        turno['promotor_nombre'] ?? '',
                        style: const TextStyle(fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        turno['promotor_identificacion']?.toString() ?? '',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        _formatearFecha(turno['fecha_inicio']?.toString() ?? ''),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  String _formatearFecha(String fecha) {
    if (fecha.length >= 16) {
      return fecha.substring(0, 16);
    }
    return fecha;
  }
}
