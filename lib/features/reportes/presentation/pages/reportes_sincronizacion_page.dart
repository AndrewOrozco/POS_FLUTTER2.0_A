import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/services/api_consultas_service.dart';
import '../../../../core/theme/app_theme.dart';

/// Dashboard de Auditoría de Sincronización.
/// Muestra estadísticas, historial expandible, y visor JSON interactivo.
class ReportesSincronizacionPage extends StatefulWidget {
  const ReportesSincronizacionPage({super.key});

  @override
  State<ReportesSincronizacionPage> createState() => _ReportesSincronizacionPageState();
}

class _ReportesSincronizacionPageState extends State<ReportesSincronizacionPage> {
  final ApiConsultasService _api = ApiConsultasService();
  List<Map<String, dynamic>> _historial = [];
  bool _cargando = true;
  int? _expandedIndex;
  int? _selectedModuloIndex; // Para mostrar JSON de un módulo específico

  @override
  void initState() {
    super.initState();
    _cargarHistorial();
  }

  Future<void> _cargarHistorial() async {
    setState(() => _cargando = true);
    final data = await _api.getHistorialSincronizacion();
    if (mounted) {
      setState(() {
        _historial = data;
        _cargando = false;
      });
    }
  }

  // ═══════════════════════════════════════════
  // STATS calculadas
  // ═══════════════════════════════════════════
  int get _totalSyncs => _historial.length;
  int get _totalExitosos => _historial.fold(0, (sum, h) => sum + ((h['exitosos'] ?? 0) as int));
  int get _totalFallidos => _historial.fold(0, (sum, h) => sum + ((h['fallidos'] ?? 0) as int));
  String get _ultimaSync {
    if (_historial.isEmpty) return 'N/A';
    return _formatearFecha(_historial.first['fecha'] ?? '');
  }
  double get _tasaExito {
    final total = _totalExitosos + _totalFallidos;
    if (total == 0) return 0;
    return (_totalExitosos / total) * 100;
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
                  : _historial.isEmpty
                      ? _buildEmpty()
                      : RefreshIndicator(
                          onRefresh: _cargarHistorial,
                          child: ListView(
                            padding: const EdgeInsets.all(16),
                            children: [
                              // ── Dashboard Stats ──
                              _buildDashboardStats(),
                              const SizedBox(height: 20),
                              // ── Título historial ──
                              Row(
                                children: [
                                  const Text(
                                    'Historial de Sincronizaciones',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF333333)),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '$_totalSyncs registros',
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              // ── Lista ──
                              ...List.generate(_historial.length, (i) => _buildHistorialItem(i)),
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
  //  DASHBOARD STATS
  // ══════════════════════════════════════════════════

  Widget _buildDashboardStats() {
    return Column(
      children: [
        // Primera fila: 3 cards
        Row(
          children: [
            Expanded(child: _buildStatCard(
              'Sincronizaciones',
              '$_totalSyncs',
              Icons.sync_rounded,
              const Color(0xFF5C6BC0),
            )),
            const SizedBox(width: 10),
            Expanded(child: _buildStatCard(
              'Tasa de Éxito',
              '${_tasaExito.toStringAsFixed(1)}%',
              Icons.trending_up_rounded,
              _tasaExito >= 80 ? Colors.green.shade600 : Colors.orange.shade600,
            )),
            const SizedBox(width: 10),
            Expanded(child: _buildStatCard(
              'Última Sync',
              _ultimaSync,
              Icons.access_time_rounded,
              const Color(0xFF00897B),
              smallText: true,
            )),
          ],
        ),
        const SizedBox(height: 10),
        // Segunda fila: 2 cards
        Row(
          children: [
            Expanded(child: _buildStatCard(
              'Módulos OK',
              '$_totalExitosos',
              Icons.check_circle_rounded,
              Colors.green.shade600,
            )),
            const SizedBox(width: 10),
            Expanded(child: _buildStatCard(
              'Módulos Fallidos',
              '$_totalFallidos',
              Icons.error_rounded,
              Colors.red.shade600,
            )),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color, {bool smallText = false}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: smallText ? 13 : 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
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
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
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
            'Auditoría de Sincronización',
            style: TextStyle(color: Color(0xFF333333), fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          IconButton(
            onPressed: _cargarHistorial,
            icon: Icon(Icons.refresh_rounded, color: AppTheme.terpeRed),
            tooltip: 'Refrescar',
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════
  //  EMPTY STATE
  // ══════════════════════════════════════════════════

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.sync_disabled_rounded, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text('No hay registros de sincronización',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey.shade500)),
          const SizedBox(height: 6),
          Text('Ejecuta una sincronización desde Configuración',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════
  //  HISTORIAL ITEM
  // ══════════════════════════════════════════════════

  Widget _buildHistorialItem(int index) {
    final item = _historial[index];
    final tipo = item['tipo'] ?? '';
    final exitosos = item['exitosos'] ?? 0;
    final fallidos = item['fallidos'] ?? 0;
    final duracion = item['duracion_ms'] ?? 0;
    final fecha = item['fecha'] ?? '';
    final isExpanded = _expandedIndex == index;

    List<dynamic> resultados = _parseResultados(item['resultados']);
    final esExitosa = fallidos == 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: esExitosa ? Colors.green.shade200 : Colors.orange.shade200,
          width: 1,
        ),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          // ── Header del registro ──
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            onTap: () {
              setState(() {
                _expandedIndex = isExpanded ? null : index;
                _selectedModuloIndex = null;
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  // Ícono de estado
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: esExitosa ? Colors.green.shade50 : Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      esExitosa ? Icons.check_circle_rounded : Icons.warning_rounded,
                      color: esExitosa ? Colors.green.shade600 : Colors.orange.shade600,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Título y fecha
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tipo == 'total' ? 'Sincronización Total' : 'Sync: ${tipo.toUpperCase()}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        Text(
                          _formatearFecha(fecha),
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  ),
                  // Stats badges
                  _buildMiniStat('✅', exitosos, Colors.green),
                  const SizedBox(width: 6),
                  _buildMiniStat('❌', fallidos, Colors.red),
                  const SizedBox(width: 6),
                  Text('${duracion}ms', style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
                  const SizedBox(width: 4),
                  Icon(
                    isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                    color: Colors.grey.shade400,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          // ── Expandido: módulos ──
          if (isExpanded && resultados.isNotEmpty) ...[
            Divider(height: 1, color: Colors.grey.shade200),
            // Grid de módulos
            Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(resultados.length, (mi) {
                  final r = resultados[mi];
                  final esOk = r['estado'] == 'OK';
                  final isSelectedMod = _selectedModuloIndex == mi;

                  return GestureDetector(
                    onTap: () {
                      setState(() => _selectedModuloIndex = isSelectedMod ? null : mi);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelectedMod
                            ? (esOk ? Colors.green.shade100 : Colors.red.shade100)
                            : (esOk ? Colors.green.shade50 : Colors.red.shade50),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelectedMod
                              ? (esOk ? Colors.green.shade400 : Colors.red.shade400)
                              : (esOk ? Colors.green.shade200 : Colors.red.shade200),
                          width: isSelectedMod ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            esOk ? Icons.check_circle_rounded : Icons.cancel_rounded,
                            color: esOk ? Colors.green.shade600 : Colors.red.shade600,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            r['modulo'] ?? '',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: esOk ? Colors.green.shade800 : Colors.red.shade800,
                            ),
                          ),
                          if (r['duracion_ms'] != null) ...[
                            const SizedBox(width: 4),
                            Text(
                              '${r['duracion_ms']}ms',
                              style: TextStyle(fontSize: 9, color: Colors.grey.shade500),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),

            // ── Panel de detalle del módulo seleccionado ──
            if (_selectedModuloIndex != null && _selectedModuloIndex! < resultados.length)
              _buildModuloDetail(resultados[_selectedModuloIndex!]),
          ],
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════
  //  PANEL DE DETALLE DEL MÓDULO
  // ══════════════════════════════════════════════════

  Widget _buildModuloDetail(Map<String, dynamic> modulo) {
    final esOk = modulo['estado'] == 'OK';
    final detalle = modulo['detalle']?.toString() ?? '';
    final respuestaApi = modulo['respuesta_api'];
    final consultaApi = modulo['consulta_api'];
    final jsonResultado = _formatJson(respuestaApi);
    final jsonConsulta = _formatJson(consultaApi);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: esOk ? Colors.green.shade700 : Colors.red.shade700,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Icon(esOk ? Icons.check_circle_rounded : Icons.error_rounded, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(modulo['modulo'] ?? '',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                ),
                if (modulo['duracion_ms'] != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('${modulo['duracion_ms']}ms',
                        style: const TextStyle(color: Colors.white, fontSize: 10)),
                  ),
              ],
            ),
          ),

          // ── Detalle texto ──
          if (detalle.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: Text(detalle,
                  style: TextStyle(
                    fontSize: 12,
                    color: esOk ? const Color(0xFF98C379) : const Color(0xFFE06C75),
                    fontWeight: FontWeight.w500,
                  )),
            ),

          // ── SECCIÓN: Resultado de Sync ──
          if (respuestaApi != null) ...[
            _buildJsonSection(
              titulo: '📋 Resultado',
              jsonStr: jsonResultado,
              color: const Color(0xFF61AFEF),
            ),
          ],

          // ── SECCIÓN: Consulta API (datos crudos del backoffice) ──
          if (consultaApi != null) ...[
            _buildJsonSection(
              titulo: '🔍 Consulta API — Datos del Backoffice',
              jsonStr: jsonConsulta,
              color: const Color(0xFFE5C07B),
              maxHeight: 400,
            ),
          ],

          const SizedBox(height: 4),
        ],
      ),
    );
  }

  /// Sección de JSON con título, botón copiar, y syntax highlighting.
  /// Para JSONs grandes, trunca y renderiza de forma asíncrona.
  Widget _buildJsonSection({
    required String titulo,
    required String jsonStr,
    required Color color,
    double maxHeight = 250,
  }) {
    // Truncar el JSON visible si es muy largo (para no bloquear la UI)
    const maxChars = 3000;
    final esTruncado = jsonStr.length > maxChars;
    final jsonVisible = esTruncado
        ? '${jsonStr.substring(0, maxChars)}\n\n  ... (truncado — ${jsonStr.length} caracteres total, use copiar para ver completo)'
        : jsonStr;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Text(titulo,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
                    if (esTruncado) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${(jsonStr.length / 1024).toStringAsFixed(1)}KB',
                          style: const TextStyle(fontSize: 9, color: Colors.orange),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              InkWell(
                onTap: () {
                  // Copiar el JSON COMPLETO (no truncado)
                  Clipboard.setData(ClipboardData(text: jsonStr));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$titulo copiado (${jsonStr.length} chars)'), duration: const Duration(seconds: 2)),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.copy_rounded, color: Color(0xFF888888), size: 13),
                ),
              ),
            ],
          ),
        ),
        Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF282C34),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF3E4451)),
          ),
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: FutureBuilder<TextSpan>(
            future: Future.delayed(const Duration(milliseconds: 50), () => _buildJsonHighlight(jsonVisible)),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF61AFEF))),
                        SizedBox(width: 8),
                        Text('Renderizando JSON...', style: TextStyle(color: Color(0xFF888888), fontSize: 11)),
                      ],
                    ),
                  ),
                );
              }
              return SingleChildScrollView(
                child: SelectableText.rich(
                  snapshot.data!,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11, height: 1.5),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════
  //  JSON SYNTAX HIGHLIGHTING
  // ══════════════════════════════════════════════════

  TextSpan _buildJsonHighlight(String json) {
    final spans = <TextSpan>[];
    final lines = json.split('\n');

    for (var line in lines) {
      // Color keys
      final keyMatch = RegExp(r'"([^"]+)"(?=\s*:)');
      final stringMatch = RegExp(r':\s*"([^"]*)"');
      final numberMatch = RegExp(r':\s*(\d+\.?\d*)');
      final boolMatch = RegExp(r':\s*(true|false|null)');

      int lastEnd = 0;
      final allMatches = <_JsonToken>[];

      for (final m in keyMatch.allMatches(line)) {
        allMatches.add(_JsonToken(m.start, m.end, 'key'));
      }
      for (final m in stringMatch.allMatches(line)) {
        final valueStart = line.indexOf('"', m.start + line.substring(m.start).indexOf(':') + 1);
        if (valueStart >= 0) {
          allMatches.add(_JsonToken(valueStart, m.end, 'string'));
        }
      }
      for (final m in numberMatch.allMatches(line)) {
        allMatches.add(_JsonToken(m.start + line.substring(m.start).indexOf(m.group(1)!), m.end, 'number'));
      }
      for (final m in boolMatch.allMatches(line)) {
        allMatches.add(_JsonToken(m.start + line.substring(m.start).indexOf(m.group(1)!), m.end, 'bool'));
      }

      allMatches.sort((a, b) => a.start.compareTo(b.start));

      for (final token in allMatches) {
        if (token.start > lastEnd) {
          spans.add(TextSpan(
            text: line.substring(lastEnd, token.start),
            style: const TextStyle(color: Color(0xFFABB2BF)),
          ));
        }
        Color color;
        switch (token.type) {
          case 'key':
            color = const Color(0xFF61AFEF); // Azul
            break;
          case 'string':
            color = const Color(0xFF98C379); // Verde
            break;
          case 'number':
            color = const Color(0xFFD19A66); // Naranja
            break;
          case 'bool':
            color = const Color(0xFFC678DD); // Púrpura
            break;
          default:
            color = const Color(0xFFABB2BF);
        }
        spans.add(TextSpan(
          text: line.substring(token.start, token.end),
          style: TextStyle(color: color),
        ));
        lastEnd = token.end;
      }

      if (lastEnd < line.length) {
        spans.add(TextSpan(
          text: line.substring(lastEnd),
          style: const TextStyle(color: Color(0xFFABB2BF)),
        ));
      }
      spans.add(const TextSpan(text: '\n'));
    }

    return TextSpan(children: spans);
  }

  // ══════════════════════════════════════════════════
  //  HELPERS
  // ══════════════════════════════════════════════════

  Widget _buildMiniStat(String emoji, int value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text('$emoji $value', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
    );
  }

  List<dynamic> _parseResultados(dynamic resultados) {
    if (resultados == null) return [];
    if (resultados is String) {
      try { return json.decode(resultados); } catch (_) { return []; }
    }
    if (resultados is List) return resultados;
    return [];
  }

  String _formatearFecha(String fecha) {
    try {
      final dt = DateTime.parse(fecha);
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
    } catch (_) {
      return fecha;
    }
  }

  String _formatJson(dynamic data) {
    try {
      if (data is String) {
        final parsed = json.decode(data);
        return const JsonEncoder.withIndent('  ').convert(parsed);
      }
      return const JsonEncoder.withIndent('  ').convert(data);
    } catch (_) {
      return data?.toString() ?? 'null';
    }
  }
}

class _JsonToken {
  final int start;
  final int end;
  final String type;
  _JsonToken(this.start, this.end, this.type);
}
