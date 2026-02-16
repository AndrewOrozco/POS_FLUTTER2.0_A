import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../core/constants/app_constants.dart';
import '../core/providers/session_provider.dart';
import '../core/services/payment_websocket_service.dart';
import '../features/home/presentation/pages/home_page.dart';
import '../features/status_pump/status_pump.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    // Conectar al WebSocket del orquestador de pagos (puerto 5555)
    PaymentWebSocketService().connect(host: '127.0.0.1', port: 5555);

    return MultiProvider(
      providers: [
        // Provider para la sesión (EDS, promotores)
        ChangeNotifierProvider(
          create: (_) => SessionProvider()..inicializar(),
        ),
        // Provider para Status Pump (WebSocket Flask - surtidores)
        ChangeNotifierProvider(
          create: (_) => StatusPumpProvider()..initialize(
            host: 'http://127.0.0.1',
            port: 5000,
          ),
        ),
      ],
      child: MaterialApp(
        title: AppConstants.appTitle,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.theme,
        home: const HomePage(),
      ),
    );
  }
}
