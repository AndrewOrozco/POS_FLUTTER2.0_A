import 'package:flutter/material.dart';
import '../../../../core/services/api_consultas_service.dart';
import '../../../../core/models/api_models.dart';

class GopassEstadoPagoPage extends StatefulWidget {
  const GopassEstadoPagoPage({super.key});

  @override
  State<GopassEstadoPagoPage> createState() => _GopassEstadoPagoPageState();
}

class _GopassEstadoPagoPageState extends State<GopassEstadoPagoPage>
    with SingleTickerProviderStateMixin {
  final ApiConsultasService _apiService = ApiConsultasService();

  List<TransaccionGopass> _transacciones = [];
  bool _isLoading = true;
  String? _error;
  int? _consultandoId;
  int? _imprimiendoId;
  int _filtroActual = 0; // 0=todos, 1=aceptados, 2=pendientes, 3=rechazados

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _filtroActual = _tabController.index);
      }
    });
    _cargarTransacciones();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<TransaccionGopass> get _transaccionesFiltradas {
    switch (_filtroActual) {
      case 1:
        return _transacciones.where((t) => t.esAceptado).toList();
      case 2:
        return _transacciones.where((t) => t.esPendiente).toList();
      case 3:
        return _transacciones.where((t) => t.esRechazado).toList();
      default:
        return _transacciones;
    }
  }

  int get _countAceptados => _transacciones.where((t) => t.esAceptado).length;
  int get _countPendientes => _transacciones.where((t) => t.esPendiente).length;
  int get _countRechazados => _transacciones.where((t) => t.esRechazado).length;

  Future<void> _cargarTransacciones() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final lista = await _apiService.obtenerTransaccionesGopass(dias: 30);
      setState(() {
        _transacciones = lista;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error cargando transacciones: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _consultarEstado(TransaccionGopass tx) async {
    if (tx.idTransaccionGopass == null || tx.idVentaTerpel == null) {
      _mostrarSnackBar('Datos insuficientes para consultar', esError: true);
      return;
    }
    setState(() => _consultandoId = tx.idMovimiento);
    try {
      final resultado = await _apiService.consultarEstadoGopass(
        idTransaccionGopass: tx.idTransaccionGopass!,
        idVentaTerpel: tx.idVentaTerpel!,
      );
      final exito = resultado['exito'] == true;
      final mensaje = resultado['mensaje']?.toString() ?? 'Sin respuesta';
      if (mounted) {
        _mostrarDialogoEstado(tx, mensaje, exito);
        _cargarTransacciones();
      }
    } catch (e) {
      _mostrarSnackBar('Error: $e', esError: true);
    } finally {
      if (mounted) setState(() => _consultandoId = null);
    }
  }

  Future<void> _imprimir(TransaccionGopass tx) async {
    if (tx.idMovimiento == null) {
      _mostrarSnackBar('Sin referencia de movimiento', esError: true);
      return;
    }
    setState(() => _imprimiendoId = tx.idMovimiento);
    try {
      final resultado = await _apiService.imprimirGopass(
        movimientoId: tx.idMovimiento!,
        reportType: 'FACTURA',
      );
      final exito = resultado['exito'] == true;
      final mensaje = resultado['mensaje']?.toString() ?? 'Sin respuesta';
      _mostrarSnackBar(mensaje, esError: !exito);
    } catch (e) {
      _mostrarSnackBar('Error al imprimir: $e', esError: true);
    } finally {
      if (mounted) setState(() => _imprimiendoId = null);
    }
  }

  void _mostrarDialogoEstado(TransaccionGopass tx, String mensaje, bool exito) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              exito ? Icons.check_circle : Icons.info_outline,
              color: exito ? Colors.green : Colors.orange,
              size: 28,
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text('Estado GoPass', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoRow('Placa', tx.placa),
            _infoRow('Referencia', tx.idMovimientoCompuesto ?? tx.idMovimiento?.toString() ?? '-'),
            const Divider(),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: exito ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                mensaje,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: exito ? Colors.green.shade800 : Colors.orange.shade800,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CERRAR')),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(width: 100, child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
        ],
      ),
    );
  }

  void _mostrarSnackBar(String msg, {bool esError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: esError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      body: Column(
        children: [
          _buildHeader(),
          if (!_isLoading && _error == null && _transacciones.isNotEmpty) _buildTabs(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  // ── HEADER con branding GoPass ──────────────────────────────
  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFB71C1C), Color(0xFFD32F2F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
          child: Column(
            children: [
              // Top bar
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.credit_card, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'GOPASS',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                          ),
                        ),
                        Text(
                          'Estado de Pagos',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.refresh, color: Colors.white),
                    onPressed: _isLoading ? null : _cargarTransacciones,
                    tooltip: 'Actualizar',
                  ),
                ],
              ),
              // Stats cards
              if (!_isLoading && _transacciones.isNotEmpty) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildStatCard('Total', _transacciones.length, const Color(0xFF263238), Colors.white),
                    const SizedBox(width: 8),
                    _buildStatCard('Aceptados', _countAceptados, const Color(0xFF1B5E20), const Color(0xFFE8F5E9)),
                    const SizedBox(width: 8),
                    _buildStatCard('Pendientes', _countPendientes, const Color(0xFFE65100), const Color(0xFFFFF3E0)),
                    const SizedBox(width: 8),
                    _buildStatCard('Rechazados', _countRechazados, const Color(0xFFB71C1C), const Color(0xFFFFEBEE)),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, int count, Color textColor, Color bgColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: TextStyle(
                color: textColor,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(color: textColor.withOpacity(0.85), fontSize: 11, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ── TABS de filtro ──────────────────────────────────────────
  Widget _buildTabs() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        labelColor: const Color(0xFFB71C1C),
        unselectedLabelColor: Colors.grey,
        indicatorColor: const Color(0xFFB71C1C),
        indicatorWeight: 3,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        tabs: [
          Tab(text: 'TODOS (${_transacciones.length})'),
          Tab(text: 'ACEPTADOS ($_countAceptados)'),
          Tab(text: 'PENDIENTES ($_countPendientes)'),
          Tab(text: 'RECHAZADOS ($_countRechazados)'),
        ],
      ),
    );
  }

  // ── BODY ────────────────────────────────────────────────────
  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFFB71C1C)),
            SizedBox(height: 16),
            Text('Cargando transacciones...', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cloud_off, size: 64, color: Colors.red.shade200),
              const SizedBox(height: 16),
              Text(_error!, style: const TextStyle(fontSize: 15), textAlign: TextAlign.center),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _cargarTransacciones,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFB71C1C),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_transacciones.isEmpty) return _buildEmpty();

    final filtradas = _transaccionesFiltradas;
    if (filtradas.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.filter_list_off, size: 56, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(
              'Sin transacciones en este filtro',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
      itemCount: filtradas.length,
      itemBuilder: (context, index) => _buildTransaccionCard(filtradas[index]),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.credit_card_off, size: 56, color: Colors.grey.shade400),
          ),
          const SizedBox(height: 20),
          Text(
            'Sin transacciones GoPass',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 8),
          Text(
            'No hay pagos GoPass en los últimos 30 días',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }

  // ── CARD de transacción ─────────────────────────────────────
  Widget _buildTransaccionCard(TransaccionGopass tx) {
    final Color accentColor;
    final IconData estadoIcon;
    final String estadoLabel;
    final Color estadoBg;

    if (tx.esAceptado) {
      accentColor = const Color(0xFF2E7D32);
      estadoIcon = Icons.check_circle_rounded;
      estadoLabel = 'ACEPTADO';
      estadoBg = const Color(0xFFE8F5E9);
    } else if (tx.esRechazado) {
      accentColor = const Color(0xFFC62828);
      estadoIcon = Icons.cancel_rounded;
      estadoLabel = 'RECHAZADO';
      estadoBg = const Color(0xFFFFEBEE);
    } else {
      accentColor = const Color(0xFFE65100);
      estadoIcon = Icons.schedule_rounded;
      estadoLabel = 'PENDIENTE';
      estadoBg = const Color(0xFFFFF3E0);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: accentColor.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Top color bar
          Container(
            height: 4,
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Row 1: Placa + Estado
                Row(
                  children: [
                    // Placa badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF263238),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.directions_car, color: Colors.white, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            tx.placa.isNotEmpty ? tx.placa : '---',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    // Estado badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: estadoBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: accentColor.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(estadoIcon, color: accentColor, size: 16),
                          const SizedBox(width: 5),
                          Text(
                            estadoLabel,
                            style: TextStyle(
                              color: accentColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Row 2: Detalles
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAFAFA),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      _detailItem(Icons.calendar_today_rounded, 'Fecha', _formatFecha(tx.fecha)),
                      Container(width: 1, height: 32, color: Colors.grey.shade300),
                      _detailItem(Icons.tag, 'Referencia', tx.idMovimientoCompuesto ?? tx.idMovimiento?.toString() ?? '-'),
                      if (tx.surtidor != null) ...[
                        Container(width: 1, height: 32, color: Colors.grey.shade300),
                        _detailItem(Icons.local_gas_station, 'Surtidor', '${tx.surtidor}'),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Row 3: Acciones
                Row(
                  children: [
                    if (tx.esAceptado)
                      Expanded(
                        child: _actionButton(
                          icon: Icons.print_rounded,
                          label: _imprimiendoId == tx.idMovimiento ? 'IMPRIMIENDO...' : 'IMPRIMIR FACTURA',
                          color: const Color(0xFFB71C1C),
                          loading: _imprimiendoId == tx.idMovimiento,
                          onTap: _imprimiendoId != null ? null : () => _imprimir(tx),
                        ),
                      ),
                    if (!tx.esAceptado)
                      Expanded(
                        child: _actionButton(
                          icon: Icons.manage_search_rounded,
                          label: _consultandoId == tx.idMovimiento ? 'CONSULTANDO...' : 'CONSULTAR ESTADO',
                          color: accentColor,
                          loading: _consultandoId == tx.idMovimiento,
                          onTap: _consultandoId != null ? null : () => _consultarEstado(tx),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailItem(IconData icon, String label, String value) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          children: [
            Icon(icon, size: 16, color: Colors.grey.shade500),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    bool loading = false,
    VoidCallback? onTap,
  }) {
    return Material(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (loading)
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: color),
                )
              else
                Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatFecha(String fecha) {
    if (fecha.isEmpty) return '-';
    try {
      // "2026-02-16 15:26:39.445682" → "16/02 15:26"
      final parts = fecha.split(' ');
      if (parts.length >= 2) {
        final dateParts = parts[0].split('-');
        final timeParts = parts[1].split(':');
        if (dateParts.length == 3 && timeParts.length >= 2) {
          return '${dateParts[2]}/${dateParts[1]} ${timeParts[0]}:${timeParts[1]}';
        }
      }
    } catch (_) {}
    return fecha.length > 16 ? fecha.substring(0, 16) : fecha;
  }
}
