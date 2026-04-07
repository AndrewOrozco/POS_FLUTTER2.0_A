import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../core/constants/app_constants.dart';
import '../core/config/app_env.dart';
import '../core/providers/session_provider.dart';
import '../core/providers/eds_provider.dart';
import '../core/services/payment_websocket_service.dart';
import '../features/home/presentation/pages/home_page.dart';
import '../features/licencia/presentation/pages/license_page.dart';
import '../features/licencia/providers/license_provider.dart';
import '../features/status_pump/status_pump.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    PaymentWebSocketService().connect(
      host: AppEnv.hostPagos,
      port: AppEnv.portPagos,
    );

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => EdsProvider()..cargar()),
        ChangeNotifierProvider(create: (_) => SessionProvider()..inicializar()),
        ChangeNotifierProvider(
          create: (_) => StatusPumpProvider()..initialize(
            host: AppEnv.urlFlask,
            port: AppEnv.portFlask,
          ),
        ),
        // Verifica licencia al arrancar — SRP: solo este provider decide si el
        // equipo está autorizado. ISO 27001 A.9: acceso controlado desde el inicio.
        ChangeNotifierProvider(create: (_) => LicenseProvider()..checkLicense()),
      ],
      child: MaterialApp(
        title: AppConstants.appTitle,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.theme,
        home: const _LicenseGate(),
      ),
    );
  }
}

/// Puerta de licencia — decide qué pantalla mostrar al inicio.
///
/// • Si el equipo no tiene registro (tabla vacía) o autorizado='N' → [TerpelLicensePage]
/// • Si la licencia está activa → [HomePage]
///
/// Mentre carga muestra un splash minimalista para evitar flash de contenido.
class _LicenseGate extends StatelessWidget {
  const _LicenseGate();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LicenseProvider>();

    // Cargando — splash mínimo
    if (provider.cargando) {
      return const _SplashScreen();
    }

    // Sin licencia → pantalla de activación (sin botón volver)
    if (!provider.isLicensed) {
      return const TerpelLicensePage(fromSettings: false);
    }

    // Licenciado → app normal
    return const HomePage();
  }
}

/// Splash screen minimalista mientras se verifica la licencia.
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.terpelGrayDark,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.terpelMediumRed, AppTheme.terpeRed],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'TERPEL',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                  letterSpacing: 4,
                ),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppTheme.terpeRed.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Verificando licencia...',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.35),
                fontSize: 12,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
