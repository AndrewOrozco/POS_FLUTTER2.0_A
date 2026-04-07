import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/teclado_tactil.dart';
import '../../providers/license_provider.dart';

/// Pantalla de activación de licencia — diseño premium Terpel.
/// Se muestra en el arranque si el equipo no está autorizado.
/// También se accede desde Configuración (fromSettings: true) para ver estado
/// y poder restaurar (resetear) la licencia del equipo.
class TerpelLicensePage extends StatefulWidget {
  /// Si true: viene desde Configuración → muestra botón "Restaurar POS"
  final bool fromSettings;
  const TerpelLicensePage({super.key, this.fromSettings = false});

  @override
  State<TerpelLicensePage> createState() => _TerpelLicensePageState();
}

class _TerpelLicensePageState extends State<TerpelLicensePage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _codeController = TextEditingController();
  late AnimationController _pulseCtrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _codeController.addListener(_onChanged);
    // Animación de pulso suave para el ícono de candado
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _codeController.removeListener(_onChanged);
    _codeController.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  /// Pega desde el portapapeles — filtra solo dígitos.
  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text == null) return;
    // Solo dígitos
    final soloDigitos = data!.text!.replaceAll(RegExp(r'[^0-9]'), '');
    if (soloDigitos.isEmpty) return;
    _codeController.text = soloDigitos;
    _codeController.selection = TextSelection.collapsed(offset: soloDigitos.length);
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => LicenseProvider()..checkLicense(),
      child: Consumer<LicenseProvider>(
        builder: (ctx, provider, _) => provider.isLicensed && provider.exitoActivacion != null
            ? _buildExitoTotal(provider.exitoActivacion!)
            : _buildMain(ctx, provider),
      ),
    );
  }

  // ── Pantalla principal ────────────────────────────────────────────────────
  Widget _buildMain(BuildContext ctx, LicenseProvider provider) {
    return Scaffold(
      backgroundColor: AppTheme.terpelGrayDark,
      body: Stack(
        children: [
          // Fondo con gradiente radial
          _buildBackground(),
          // Contenido
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(),
                Expanded(
                  child: Row(
                    children: [
                      // Columna izquierda — info e ícono
                      Expanded(flex: 5, child: _buildLeftPanel(provider)),
                      // Divisor
                      Container(
                        width: 1,
                        margin: const EdgeInsets.symmetric(vertical: 32),
                        color: Colors.white.withValues(alpha: 0.06),
                      ),
                      // Columna derecha — campo + teclado
                      Expanded(flex: 5, child: _buildRightPanel(ctx, provider)),
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

  // ── Fondo ─────────────────────────────────────────────────────────────────
  Widget _buildBackground() {
    return Stack(
      children: [
        // Gradiente base
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.terpelGrayDark,
                const Color(0xFF0D1F24),
                const Color(0xFF0A1015),
              ],
            ),
          ),
        ),
        // Círculo decorativo rojo top-right
        Positioned(
          top: -120,
          right: -80,
          child: Container(
            width: 400,
            height: 400,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppTheme.terpelMediumRed.withValues(alpha: 0.18),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        // Círculo decorativo gris bottom-left
        Positioned(
          bottom: -80,
          left: -60,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppTheme.terpelGray6.withValues(alpha: 0.4),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        // Grid lines decorativas
        CustomPaint(
          painter: _GridPainter(),
          child: const SizedBox.expand(),
        ),
      ],
    );
  }

  // ── Barra superior ────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Row(
        children: [
          // Botón volver (solo desde Configuración)
          if (widget.fromSettings) ...[
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: Icon(Icons.arrow_back_rounded, color: Colors.white.withValues(alpha: 0.7), size: 20),
              ),
            ),
            const SizedBox(width: 14),
          ],
          // Logo / marca Terpel
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.terpelMediumRed, AppTheme.terpeRed],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'TERPEL',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 16,
                letterSpacing: 3,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Text(
            'Sistema Punto de Venta',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 13,
              letterSpacing: 0.5,
            ),
          ),
          const Spacer(),
          // Badge de estado
          Consumer<LicenseProvider>(
            builder: (_, prov, __) {
              final activo = prov.isLicensed;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: activo
                      ? Colors.green.withValues(alpha: 0.08)
                      : Colors.orange.withValues(alpha: 0.08),
                  border: Border.all(
                    color: activo
                        ? Colors.green.withValues(alpha: 0.25)
                        : Colors.orange.withValues(alpha: 0.25),
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: activo ? Colors.greenAccent : Colors.orange,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      activo ? 'LICENCIA ACTIVA' : 'ACTIVACIÓN REQUERIDA',
                      style: TextStyle(
                        color: activo ? Colors.greenAccent : Colors.orange,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Panel izquierdo ───────────────────────────────────────────────────────
  Widget _buildLeftPanel(LicenseProvider provider) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(48, 32, 32, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ícono animado
          ScaleTransition(
            scale: _pulse,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.terpelMediumRed.withValues(alpha: 0.25),
                    Colors.transparent,
                  ],
                ),
                border: Border.all(
                  color: AppTheme.terpelMediumRed.withValues(alpha: 0.4),
                  width: 1.5,
                ),
              ),
              child: Icon(
                Icons.lock_outline_rounded,
                color: AppTheme.terpeRed,
                size: 44,
              ),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            provider.isLicensed ? 'Licencia\nActiva' : 'Activación\nde Licencia',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w800,
              height: 1.15,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            provider.isLicensed
                ? 'El equipo cuenta con una licencia válida para operar.\nPuede restaurar el POS si desea reconfigurarlo.'
                : 'Este equipo requiere una licencia activa\npara operar. Ingrese el código numérico\nproporcionado por la HO.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 14,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 32),
          // Tarjeta de fingerprint del equipo
          _buildFingerprintCard(provider),
          const SizedBox(height: 20),
          // Botón Restaurar POS (solo desde Configuración)
          if (widget.fromSettings)
            _buildRestaurarBtn(provider),
          const Spacer(),
          // Footer info
          Row(
            children: [
              Icon(Icons.shield_outlined, color: Colors.white.withValues(alpha: 0.2), size: 14),
              const SizedBox(width: 6),
              Text(
                'ISO 27001 — Acceso controlado',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.2),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Botón "Restaurar POS" — muestra diálogo de confirmación antes de resetear.
  Widget _buildRestaurarBtn(LicenseProvider provider) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: provider.restaurando
            ? null
            : () => _confirmarRestore(provider),
        icon: provider.restaurando
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange))
            : const Icon(Icons.restore_rounded, size: 18),
        label: Text(
          provider.restaurando ? 'RESTAURANDO...' : 'RESTAURAR POS',
          style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 13),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.orange,
          side: BorderSide(color: Colors.orange.withValues(alpha: 0.4)),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Future<void> _confirmarRestore(LicenseProvider provider) async {
    // ✅ Capturar ANTES de cualquier await — evita stale context en gaps async
    final nav = Navigator.of(context);
    final rootProvider = context.read<LicenseProvider>();

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A2A30),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
            SizedBox(width: 10),
            Text('Restaurar POS', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Esta acción restablecerá el estado "no licenciado" del equipo.\n\nTendrá que ingresar nuevamente el código de la HO para activarlo.\n\n¿Continuar?',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade800,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('SÍ, RESTAURAR', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmado == true && mounted) {
      await provider.restaurarLicencia();
      if (!mounted) return;
      // 1) Pop toda la pila → vuelve a _LicenseGate (primera ruta)
      nav.popUntil((route) => route.isFirst);
      // 2) Recheck en el ROOT provider → _LicenseGate detecta sin licencia
      //    y muestra TerpelLicensePage(fromSettings: false) automáticamente
      rootProvider.checkLicense();
    }
  }

  Widget _buildFingerprintCard(LicenseProvider provider) {
    final fp = provider.status.fingerprint ?? '—';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.computer_rounded, color: Colors.cyan.shade400, size: 16),
              const SizedBox(width: 8),
              Text(
                'IDENTIFICADOR DEL EQUIPO',
                style: TextStyle(
                  color: Colors.cyan.shade400,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.cyan.withValues(alpha: 0.15)),
            ),
            child: provider.cargando
                ? Row(children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.cyan.shade400,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text('Obteniendo...', style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 13)),
                  ])
                : Text(
                    fp,
                    style: TextStyle(
                      color: Colors.cyan.shade200,
                      fontFamily: 'monospace',
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
          ),
          const SizedBox(height: 8),
          Text(
            'Comparta este código con la HO para obtener su licencia.',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 11),
          ),
        ],
      ),
    );
  }

  // ── Panel derecho ─────────────────────────────────────────────────────────
  Widget _buildRightPanel(BuildContext ctx, LicenseProvider provider) {
    if (provider.isLicensed) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.greenAccent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 72),
            ),
            const SizedBox(height: 32),
            const Text(
              'EQUIPO AUTORIZADO',
              style: TextStyle(
                color: Colors.greenAccent,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'La licencia de este punto de venta se encuentra\nactiva, garantizando la integridad de las\ntransacciones según la HO.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 32, 48, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Título campo
          Text(
            'CÓDIGO DE LICENCIA',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 10),
          // Campo de código
          _buildCodeDisplay(),
          const SizedBox(height: 16),
          // Mensajes de error / éxito
          if (provider.errorActivacion != null) _buildMensaje(
            provider.errorActivacion!,
            isError: true,
          ),
          if (provider.exitoActivacion != null) _buildMensaje(
            provider.exitoActivacion!,
            isError: false,
          ),
          const SizedBox(height: 12),
          // Botón activar
          _buildActivarBtn(provider),
          const SizedBox(height: 16),
          // Teclado numérico
          Expanded(
            child: Center(
              child: TecladoTactil(
                controller: _codeController,
                soloNumeros: true,
                height: 220,
                colorTema: AppTheme.terpelMediumRed,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCodeDisplay() {
    final code = _codeController.text;
    final isEmpty = code.isEmpty;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: isEmpty
            ? Colors.white.withValues(alpha: 0.04)
            : AppTheme.terpelMediumRed.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isEmpty
              ? Colors.white.withValues(alpha: 0.1)
              : AppTheme.terpeRed.withValues(alpha: 0.5),
          width: isEmpty ? 1 : 2,
        ),
        boxShadow: isEmpty
            ? []
            : [
                BoxShadow(
                  color: AppTheme.terpeRed.withValues(alpha: 0.15),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
      ),
      child: Row(
        children: [
          Icon(
            Icons.key_rounded,
            color: isEmpty
                ? Colors.white.withValues(alpha: 0.2)
                : AppTheme.terpeRed.withValues(alpha: 0.8),
            size: 26,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              isEmpty ? 'Ingrese el código...' : code,
              style: TextStyle(
                color: isEmpty ? Colors.white.withValues(alpha: 0.2) : Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.bold,
                letterSpacing: isEmpty ? 0 : 4,
                fontFamily: isEmpty ? null : 'monospace',
              ),
            ),
          ),
          // Botón pegar (siempre visible)
          Tooltip(
            message: 'Pegar código (Ctrl+V)',
            child: GestureDetector(
              onTap: _pasteFromClipboard,
              child: Container(
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                ),
                child: Icon(
                  Icons.content_paste_rounded,
                  color: Colors.white.withValues(alpha: 0.5),
                  size: 18,
                ),
              ),
            ),
          ),
          // Botón borrar (solo si hay texto)
          if (!isEmpty)
            GestureDetector(
              onTap: () => _codeController.clear(),
              child: Icon(
                Icons.backspace_outlined,
                color: Colors.white.withValues(alpha: 0.3),
                size: 20,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMensaje(String texto, {required bool isError}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isError
            ? Colors.red.withValues(alpha: 0.08)
            : Colors.green.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isError
              ? Colors.red.withValues(alpha: 0.3)
              : Colors.green.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.check_circle_outline,
            color: isError ? Colors.redAccent : Colors.greenAccent,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              texto,
              style: TextStyle(
                color: isError ? Colors.redAccent : Colors.greenAccent,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivarBtn(LicenseProvider provider) {
    final canActivate = _codeController.text.trim().length >= 10 && !provider.activando;
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: canActivate ? () => provider.activate(_codeController.text.trim()) : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.terpelMediumRed,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.white.withValues(alpha: 0.06),
          disabledForegroundColor: Colors.white.withValues(alpha: 0.2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: canActivate ? 8 : 0,
          shadowColor: AppTheme.terpeRed.withValues(alpha: 0.4),
        ),
        child: provider.activando
            ? const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  ),
                  SizedBox(width: 12),
                  Text('VALIDANDO CON HO...', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                ],
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.verified_rounded, size: 20),
                  SizedBox(width: 10),
                  Text('ACTIVAR LICENCIA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1.5)),
                ],
              ),
      ),
    );
  }

  // ── Pantalla de éxito con countdown automático ─────────────────────────────────
  Widget _buildExitoTotal(String mensaje) {
    return _ExitoCountdownWidget(
      key: const ValueKey('exito_countdown'),
      mensaje: mensaje,
      onComplete: () {
        if (!mounted) return;
        if (widget.fromSettings) {
          // Viene de Configuración → volver con refresh
          Navigator.of(context).pop();
        } else {
          // Viene del gate de arranque → notificar al provider raíz
          // context aquí es el del State, ENCIMA del ChangeNotifierProvider local,
          // por lo que alcanza el LicenseProvider del App (el que _LicenseGate observa)
          context.read<LicenseProvider>().checkLicense();
        }
      },
    );
  }
}

// ── Pantalla de bienvenida premium ────────────────────────────────────────────────────────────
class _ExitoCountdownWidget extends StatefulWidget {
  final String mensaje;
  final VoidCallback onComplete;
  const _ExitoCountdownWidget({super.key, required this.mensaje, required this.onComplete});

  @override
  State<_ExitoCountdownWidget> createState() => _ExitoCountdownWidgetState();
}

class _ExitoCountdownWidgetState extends State<_ExitoCountdownWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeCtrl;
  int _messageIndex = 0;

  final List<String> _loadingMessages = [
    'Licencia activada con éxito',
    'Sincronizando configuración...',
    'Descargando maestros e inventarios...',
    'Preparando entorno de la estación...',
    'Aplicando políticas de seguridad...',
    '¡Todo listo!'
  ];

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeCtrl.forward();
    _startWelcomeSequence();
  }

  void _startWelcomeSequence() async {
    // Cicla a través de los mensajes, dándole unos 1500ms a cada uno.
    for (int i = 0; i < _loadingMessages.length; i++) {
      if (!mounted) return;
      setState(() {
        _messageIndex = i;
      });
      _fadeCtrl.forward(from: 0.0);
      
      // El último mensaje se muestra más corto antes de saltar
      final delay = i == _loadingMessages.length - 1 ? 800 : 1800;
      await Future.delayed(Duration(milliseconds: delay));
    }
    
    if (mounted) widget.onComplete();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.terpelGrayDark,
      body: Stack(
        children: [
          // Fondo oscuro premium
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.5,
                colors: [Color(0xFF152A32), Color(0xFF0A1015)],
              ),
            ),
          ),
          Center(
            child: FadeTransition(
              opacity: _fadeCtrl,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_messageIndex == 0 || _messageIndex == _loadingMessages.length - 1)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.greenAccent.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.greenAccent.withValues(alpha: 0.2),
                            blurRadius: 40,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.verified_rounded, color: Colors.greenAccent, size: 72),
                    )
                  else
                    SizedBox(
                      width: 80,
                      height: 80,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          const SizedBox(
                            width: 80,
                            height: 80,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white24,
                            ),
                          ),
                          SizedBox(
                            width: 60,
                            height: 60,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              color: AppTheme.terpeRed,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 48),
                  Text(
                    _loadingMessages[_messageIndex],
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_messageIndex > 0 && _messageIndex < _loadingMessages.length - 1)
                    Text(
                      'Por favor, no apague el equipo...',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 13,
                        letterSpacing: 0.5,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Pintor de grid decorativo ─────────────────────────────────────────────────
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.025)
      ..strokeWidth = 1;

    const spacing = 60.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => false;
}
