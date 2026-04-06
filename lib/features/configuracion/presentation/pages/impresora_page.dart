import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../core/services/api_consultas_service.dart';
import '../../../../core/theme/app_theme.dart';

/// Página de configuración de impresora.
/// Permite input manual de IP, escaneo de red, y prueba de conexión.
class ImpresoraPage extends StatefulWidget {
  const ImpresoraPage({super.key});

  @override
  State<ImpresoraPage> createState() => _ImpresoraPageState();
}

class _ImpresoraPageState extends State<ImpresoraPage> {
  final ApiConsultasService _api = ApiConsultasService();
  final TextEditingController _ipController = TextEditingController();

  String? _ipActual;
  bool _cargando = true;
  bool _guardando = false;

  // Escaneo de red
  bool _escaneando = false;
  double _progresoEscaneo = 0;
  String _mensajeEscaneo = '';
  List<String> _impresorasEncontradas = [];
  String? _ipLocal;
  String? _subred;

  // Prueba de conexión
  bool _probando = false;
  String? _resultadoPrueba;
  bool? _pruebaExitosa;

  @override
  void initState() {
    super.initState();
    _cargarIpActual();
    _detectarRedLocal();
  }

  @override
  void dispose() {
    _ipController.dispose();
    super.dispose();
  }

  Future<void> _cargarIpActual() async {
    final ip = await _api.getIpImpresora();
    if (mounted) {
      setState(() {
        _ipActual = ip;
        _ipController.text = ip ?? '';
        _cargando = false;
      });
    }
  }

  Future<void> _detectarRedLocal() async {
    try {
      final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          final ip = addr.address;
          if (!ip.startsWith('127.') && !ip.startsWith('169.254')) {
            final parts = ip.split('.');
            if (mounted) {
              setState(() {
                _ipLocal = ip;
                _subred = '${parts[0]}.${parts[1]}.${parts[2]}';
              });
            }
            return;
          }
        }
      }
    } catch (e) {
      debugPrint('Error detectando red: $e');
    }
  }

  Future<void> _escanearRed() async {
    if (_subred == null) return;

    setState(() {
      _escaneando = true;
      _progresoEscaneo = 0;
      _impresorasEncontradas = [];
      _mensajeEscaneo = 'Probando localhost...';
    });

    const port = 9100; // Puerto estándar impresoras térmicas
    const batchSize = 30; // IPs en paralelo
    final encontradas = <String>[];

    // 1. Primero probar localhost
    if (await _probarPuerto('127.0.0.1', port)) {
      encontradas.add('127.0.0.1');
      if (mounted) setState(() => _impresorasEncontradas = List.from(encontradas));
    }

    // 2. Escanear el rango de la subred
    for (int start = 1; start < 255; start += batchSize) {
      final end = (start + batchSize).clamp(0, 255);
      final futures = <Future>[];

      for (int i = start; i < end; i++) {
        final ip = '$_subred.$i';
        // No re-escanear localhost ni nuestra propia IP
        if (ip == '127.0.0.1' || ip == _ipLocal) continue;
        futures.add(_probarPuerto(ip, port).then((ok) {
          if (ok) {
            encontradas.add(ip);
            if (mounted) setState(() => _impresorasEncontradas = List.from(encontradas));
          }
        }));
      }

      await Future.wait(futures);
      if (mounted) {
        setState(() {
          _progresoEscaneo = end / 254;
          _mensajeEscaneo = 'Escaneando $_subred.$start-$end ...';
        });
      }
    }

    if (mounted) {
      setState(() {
        _escaneando = false;
        _progresoEscaneo = 1;
        _mensajeEscaneo = encontradas.isEmpty
            ? 'No se encontraron impresoras en la red'
            : '${encontradas.length} impresora(s) encontrada(s)';
      });
    }
  }

  Future<bool> _probarPuerto(String ip, int port) async {
    try {
      final socket = await Socket.connect(ip, port, timeout: const Duration(milliseconds: 500));
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _probarConexion(String ip) async {
    setState(() {
      _probando = true;
      _resultadoPrueba = null;
      _pruebaExitosa = null;
    });

    final ok = await _probarPuerto(ip, 9100);
    if (mounted) {
      setState(() {
        _probando = false;
        _pruebaExitosa = ok;
        _resultadoPrueba = ok
            ? '✅ Conexión exitosa — Impresora respondió en $ip:9100'
            : '❌ Sin respuesta — Verifique que la impresora esté encendida y en la misma red';
      });
    }
  }

  Future<void> _guardarIp() async {
    final ip = _ipController.text.trim();
    if (ip.isEmpty) return;

    setState(() => _guardando = true);
    final ok = await _api.guardarIpImpresora(ip);
    if (mounted) {
      setState(() {
        _guardando = false;
        if (ok) _ipActual = ip;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? 'IP guardada correctamente: $ip' : 'Error al guardar la IP'),
          backgroundColor: ok ? Colors.green : Colors.red,
        ),
      );
    }
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
              child: _cargando
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        _buildIpActualCard(),
                        const SizedBox(height: 16),
                        _buildInputManualCard(),
                        const SizedBox(height: 16),
                        _buildEscaneoCard(),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════
  //  HEADER
  // ══════════════════════════════════════════════

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
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
          const Icon(Icons.print_rounded, color: Color(0xFFCC0000), size: 28),
          const SizedBox(width: 10),
          const Text(
            'Configuración de Impresora',
            style: TextStyle(color: Color(0xFF333333), fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════
  //  CARD: IP ACTUAL
  // ══════════════════════════════════════════════

  Widget _buildIpActualCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: (_ipActual != null ? Colors.green : Colors.grey).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _ipActual != null ? Icons.print_rounded : Icons.print_disabled_rounded,
                  color: _ipActual != null ? Colors.green.shade600 : Colors.grey,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('IP Actual', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 2),
                    Text(
                      _ipActual ?? 'No configurada',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: _ipActual != null ? const Color(0xFF333333) : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              // Botón probar conexión
              if (_ipActual != null)
                _probando
                    ? const SizedBox(
                        width: 24, height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : ElevatedButton.icon(
                        onPressed: () => _probarConexion(_ipActual!),
                        icon: const Icon(Icons.wifi_find_rounded, size: 16),
                        label: const Text('Probar'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.terpeRed,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
            ],
          ),

          // Resultado de prueba
          if (_resultadoPrueba != null)
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (_pruebaExitosa == true ? Colors.green : Colors.red).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: (_pruebaExitosa == true ? Colors.green : Colors.red).withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _pruebaExitosa == true ? Icons.check_circle_rounded : Icons.cancel_rounded,
                    color: _pruebaExitosa == true ? Colors.green : Colors.red,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _resultadoPrueba!,
                      style: TextStyle(
                        fontSize: 12,
                        color: _pruebaExitosa == true ? Colors.green.shade800 : Colors.red.shade800,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Info de red local
          if (_ipLocal != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                '📡 Tu IP local: $_ipLocal   •   Segmento: $_subred.x',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════
  //  CARD: INPUT MANUAL
  // ══════════════════════════════════════════════

  Widget _buildInputManualCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Configurar IP Manualmente',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF333333))),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ipController,
                  decoration: InputDecoration(
                    labelText: 'IP de la Impresora',
                    hintText: '172.31.99.168',
                    prefixIcon: const Icon(Icons.print_rounded),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: AppTheme.terpeRed, width: 2),
                    ),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              // Botón probar esta IP
              IconButton(
                onPressed: _ipController.text.trim().isEmpty
                    ? null
                    : () => _probarConexion(_ipController.text.trim()),
                icon: const Icon(Icons.wifi_find_rounded),
                tooltip: 'Probar conexión',
                style: IconButton.styleFrom(
                  backgroundColor: Colors.blue.shade50,
                  foregroundColor: Colors.blue.shade700,
                ),
              ),
              const SizedBox(width: 8),
              // Botón guardar
              ElevatedButton.icon(
                onPressed: _guardando ? null : _guardarIp,
                icon: _guardando
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_rounded, size: 18),
                label: const Text('Guardar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.terpeRed,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════
  //  CARD: ESCANEO DE RED
  // ══════════════════════════════════════════════

  Widget _buildEscaneoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Buscar Impresoras en la Red',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF333333))),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _escaneando ? null : _escanearRed,
                icon: _escaneando
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.search_rounded, size: 18),
                label: Text(_escaneando ? 'Escaneando...' : 'Escanear Red'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5C6BC0),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),

          if (_subred != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Escanea el rango $_subred.1–254 en puerto 9100 (impresoras térmicas)',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ),

          // Barra de progreso
          if (_escaneando || _progresoEscaneo > 0)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: _escaneando ? _progresoEscaneo : 1,
                      minHeight: 6,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation(
                        _escaneando ? const Color(0xFF5C6BC0) : Colors.green.shade500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _mensajeEscaneo,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),

          // Impresoras encontradas
          if (_impresorasEncontradas.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _impresorasEncontradas.map((ip) {
                  final esActual = ip == _ipActual;
                  return InkWell(
                    onTap: () {
                      setState(() => _ipController.text = ip);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: esActual ? Colors.green.shade50 : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: esActual ? Colors.green.shade400 : AppTheme.terpeRed.withValues(alpha: 0.3),
                          width: esActual ? 2 : 1,
                        ),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.print_rounded,
                            color: esActual ? Colors.green.shade600 : AppTheme.terpeRed,
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                ip,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: esActual ? Colors.green.shade700 : const Color(0xFF333333),
                                ),
                              ),
                              Text(
                                esActual ? 'Configurada actualmente' : 'Puerto 9100 abierto',
                                style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                              ),
                            ],
                          ),
                          if (esActual) ...[
                            const SizedBox(width: 8),
                            Icon(Icons.check_circle_rounded, color: Colors.green.shade600, size: 18),
                          ],
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

          // Si no se encontraron y ya terminó
          if (!_escaneando && _progresoEscaneo >= 1 && _impresorasEncontradas.isEmpty)
            Container(
              margin: const EdgeInsets.only(top: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_rounded, color: Colors.orange.shade700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('No se encontraron impresoras',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange.shade800)),
                        const SizedBox(height: 2),
                        Text(
                          'Verifique que la impresora esté encendida, conectada a la misma red, y que el puerto 9100 esté habilitado.',
                          style: TextStyle(fontSize: 11, color: Colors.orange.shade700),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}