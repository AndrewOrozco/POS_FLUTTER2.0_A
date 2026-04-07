import 'package:flutter/material.dart';
import '../../../../core/services/api_consultas_service.dart';
import '../../../../core/theme/app_theme.dart';

/// Sincronización manual del POS.
/// Diseño: Grid de cards cuadradas con ícono centrado grande.
class SincronizacionPage extends StatefulWidget {
  const SincronizacionPage({super.key});

  @override
  State<SincronizacionPage> createState() => _SincronizacionPageState();
}

class _SincronizacionPageState extends State<SincronizacionPage> {
  final ApiConsultasService _api = ApiConsultasService();

  bool _sincronizando = false;
  Map<String, dynamic>? _resultado;
  String? _error;

  final List<_Modulo> _modulos = [
    _Modulo('Personas',       'personas',     Icons.people_rounded,               1),
    _Modulo('Empresas',       'empresas',     Icons.business_rounded,             2),
    _Modulo('Categorías',     'categorias',   Icons.account_tree_rounded,         5),
    _Modulo('Productos',      'productos',    Icons.shopping_bag_rounded,         3),
    _Modulo('Medios de Pago', 'medios_pago',  Icons.payment_rounded,             6),
    _Modulo('Surtidores',     'surtidores',   Icons.local_gas_station_rounded,    15),
    _Modulo('Consecutivos',   'consecutivos', Icons.format_list_numbered_rounded, 4),
    _Modulo('Parámetros',     'parametros',   Icons.tune_rounded,                 10),
    _Modulo('Dispositivos',   'dispositivos', Icons.devices_other_rounded,        12),
    _Modulo('Inventario',     'inventario',   Icons.warehouse_rounded,            7),
    _Modulo('Bodegas',        'bodegas',      Icons.store_rounded,                8),
    _Modulo('Kardex',         'kardex',       Icons.receipt_long_rounded,         13),
    _Modulo('Datáfonos',      'datafonos',    Icons.credit_score_rounded,         17),
  ];

  bool _seleccionarTodos = true;

  @override
  void initState() {
    super.initState();
    for (var m in _modulos) {
      m.seleccionado = true;
    }
  }

  Future<void> _ejecutarSincronizacion() async {
    final seleccionados = _modulos.where((m) => m.seleccionado).toList();
    if (seleccionados.isEmpty) return;

    setState(() {
      _sincronizando = true;
      _resultado = null;
      _error = null;
      for (var m in _modulos) {
        m.estado = null;
      }
    });

    try {
      Map<String, dynamic> data;

      if (seleccionados.length == _modulos.length) {
        data = await _api.ejecutarSincronizacion('total');
      } else if (seleccionados.length == 1) {
        data = await _api.ejecutarSincronizacion(
          seleccionados.first.codigo,
          tipoNotificacion: seleccionados.first.tipoNotificacion,
        );
      } else {
        int exitosos = 0;
        int fallidos = 0;
        List<Map<String, dynamic>> resultados = [];

        for (var mod in seleccionados) {
          final res = await _api.ejecutarSincronizacion(
            mod.codigo,
            tipoNotificacion: mod.tipoNotificacion,
          );
          if (res['success'] == true && res['resultados'] != null) {
            for (var r in (res['resultados'] as List)) {
              resultados.add(Map<String, dynamic>.from(r));
              if (r['estado'] == 'OK') { exitosos++; } else { fallidos++; }
            }
          } else {
            resultados.add({
              'modulo': mod.nombre,
              'estado': 'ERROR',
              'detalle': res['error'] ?? 'Error desconocido',
            });
            fallidos++;
          }
        }
        data = {
          'success': true,
          'tipo': 'parcial',
          'total_modulos': seleccionados.length,
          'exitosos': exitosos,
          'fallidos': fallidos,
          'resultados': resultados,
        };
      }

      // Update module states
      if (data['resultados'] != null) {
        for (var r in (data['resultados'] as List)) {
          final mod = _modulos.where((m) =>
            m.nombre.toLowerCase() == (r['modulo'] ?? '').toString().toLowerCase() ||
            m.codigo.toLowerCase() == (r['modulo'] ?? '').toString().toLowerCase()
          ).firstOrNull;
          if (mod != null) {
            mod.estado = r['estado'] == 'OK' ? true : false;
            mod.detalle = r['detalle']?.toString();
          }
        }
      }

      setState(() {
        _sincronizando = false;
        _resultado = data;
      });
    } catch (e) {
      setState(() {
        _sincronizando = false;
        _error = e.toString();
      });
    }
  }

  void _toggleSeleccionarTodos(bool value) {
    setState(() {
      _seleccionarTodos = value;
      for (var m in _modulos) {
        m.seleccionado = value;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final seleccionados = _modulos.where((m) => m.seleccionado).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // ── Seleccionar todos ──
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 22, height: 22,
                            child: Checkbox(
                              value: _seleccionarTodos,
                              onChanged: (v) => _toggleSeleccionarTodos(v ?? false),
                              activeColor: AppTheme.terpeRed,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'Seleccionar todos',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.terpeRed.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '$seleccionados / ${_modulos.length}',
                              style: TextStyle(
                                color: AppTheme.terpeRed,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── Grid de cards cuadradas ──
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 5,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 0.95,
                      ),
                      itemCount: _modulos.length,
                      itemBuilder: (context, i) => _buildModuloCard(_modulos[i]),
                    ),

                    const SizedBox(height: 20),

                    // ── Botón ──
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: (_sincronizando || seleccionados == 0)
                            ? null
                            : _ejecutarSincronizacion,
                        icon: _sincronizando
                            ? const SizedBox(
                                width: 22, height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.sync_rounded, size: 24),
                        label: Text(
                          _sincronizando
                              ? 'SINCRONIZANDO...'
                              : seleccionados == _modulos.length
                                  ? 'SINCRONIZAR TODO'
                                  : 'SINCRONIZAR ($seleccionados)',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            letterSpacing: 0.5,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.terpeRed,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: seleccionados > 0 ? 3 : 0,
                          disabledBackgroundColor: Colors.grey.shade300,
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── Resultados ──
                    if (_resultado != null) _buildResultados(),
                    if (_error != null) _buildError(),
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
  //  WIDGETS
  // ══════════════════════════════════════════════════

  Widget _buildHeader(BuildContext context) {
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
          const Text('Sincronización',
              style: TextStyle(color: Color(0xFF333333), fontSize: 20, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  /// Card cuadrada estilo mockup: checkbox+título arriba, ícono grande centrado, label abajo
  Widget _buildModuloCard(_Modulo mod) {
    final isSelected = mod.seleccionado;

    // Colores según estado
    Color borderColor = isSelected ? AppTheme.terpeRed.withValues(alpha: 0.3) : Colors.grey.shade200;
    Color bgColor = Colors.white;
    Color iconColor = isSelected ? AppTheme.terpeRed : Colors.grey.shade400;
    Widget? statusBadge;

    if (mod.estado == true) {
      borderColor = Colors.green.shade300;
      bgColor = Colors.green.shade50;
      statusBadge = Positioned(
        top: 6, right: 6,
        child: Icon(Icons.check_circle_rounded, color: Colors.green.shade600, size: 18),
      );
    } else if (mod.estado == false) {
      borderColor = Colors.red.shade300;
      bgColor = Colors.red.shade50;
      statusBadge = Positioned(
        top: 6, right: 6,
        child: Tooltip(
          message: mod.detalle ?? 'Error',
          child: Icon(Icons.error_rounded, color: Colors.red.shade600, size: 18),
        ),
      );
    } else if (_sincronizando && isSelected) {
      statusBadge = const Positioned(
        top: 8, right: 8,
        child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    return GestureDetector(
      onTap: _sincronizando
          ? null
          : () {
              setState(() {
                mod.seleccionado = !mod.seleccionado;
                _seleccionarTodos = _modulos.every((m) => m.seleccionado);
              });
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: isSelected ? 1.5 : 1),
          boxShadow: isSelected
              ? [BoxShadow(color: AppTheme.terpeRed.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))]
              : [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 1))],
        ),
        child: Stack(
          children: [
            // Contenido principal
            Column(
              children: [
                // ── Checkbox + título arriba ──
                Padding(
                  padding: const EdgeInsets.only(left: 8, top: 8, right: 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 20, height: 20,
                        child: Checkbox(
                          value: isSelected,
                          onChanged: _sincronizando
                              ? null
                              : (v) {
                                  setState(() {
                                    mod.seleccionado = v ?? false;
                                    _seleccionarTodos = _modulos.every((m) => m.seleccionado);
                                  });
                                },
                          activeColor: AppTheme.terpeRed,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          mod.nombre,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isSelected ? const Color(0xFF1A1A1A) : Colors.grey.shade500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Ícono grande centrado ──
                Expanded(
                  child: Center(
                    child: Icon(
                      mod.icono,
                      size: 42,
                      color: iconColor,
                    ),
                  ),
                ),

                // ── Label abajo ──
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    mod.nombre,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? const Color(0xFF333333) : Colors.grey.shade400,
                    ),
                  ),
                ),
              ],
            ),

            // Badge de estado
            if (statusBadge != null) statusBadge,
          ],
        ),
      ),
    );
  }

  Widget _buildResultados() {
    final data = _resultado!;
    final exitosos = data['exitosos'] ?? 0;
    final fallidos = data['fallidos'] ?? 0;
    final duracion = data['duracion_ms'] ?? 0;
    final resultados = (data['resultados'] as List?) ?? [];

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: fallidos > 0 ? Colors.orange.shade600 : Colors.green.shade600,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Icon(
                  fallidos > 0 ? Icons.warning_rounded : Icons.check_circle_rounded,
                  color: Colors.white, size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    fallidos > 0 ? 'SINCRONIZACIÓN PARCIAL' : 'SINCRONIZACIÓN EXITOSA',
                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
                Text('${duracion}ms', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _buildStatChip('Exitosos', exitosos, Colors.green),
                const SizedBox(width: 12),
                _buildStatChip('Fallidos', fallidos, Colors.red),
                const SizedBox(width: 12),
                _buildStatChip('Total', resultados.length, Colors.blue),
              ],
            ),
          ),
          ...resultados.map((r) {
            final esOk = r['estado'] == 'OK';
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
              ),
              child: Row(
                children: [
                  Icon(
                    esOk ? Icons.check_circle_rounded : Icons.cancel_rounded,
                    color: esOk ? Colors.green : Colors.red,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r['modulo'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        if (r['detalle'] != null)
                          Text(r['detalle'], style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  if (r['duracion_ms'] != null)
                    Text('${r['duracion_ms']}ms', style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                ],
              ),
            );
          }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade300),
      ),
      child: Row(
        children: [
          Icon(Icons.error_rounded, color: Colors.red.shade600),
          const SizedBox(width: 10),
          Expanded(
            child: Text(_error!, style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, int value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text('$value', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
            Text(label, style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.8))),
          ],
        ),
      ),
    );
  }
}

class _Modulo {
  final String nombre;
  final String codigo;
  final IconData icono;
  final int tipoNotificacion;
  bool seleccionado;
  bool? estado;
  String? detalle;

  _Modulo(this.nombre, this.codigo, this.icono, this.tipoNotificacion, {
    this.seleccionado = false,
    this.estado,
    this.detalle,
  });
}