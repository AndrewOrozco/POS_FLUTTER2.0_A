import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTheme {
  static const Color terpeRed = Color(0xFFE31E24);
  static const Color lightGray = Color(0xFFF5F5F5);
  static const Color mediumGray = Color(0xFFcFD8DC);
  static const Color darkGray = Color(0xFFECEFF1);
  static const Color success = Color(0xFF4CAF50);

  static ThemeData get theme => ThemeData(
    useMaterial3: true,
    fontFamily: 'Arial',
    primaryColor: terpeRed,
    colorScheme: ColorScheme.fromSeed(
      seedColor: terpeRed,
      brightness: Brightness.light,
    ),
  );

  static void configureOrientation() {
    // Configurar orientación horizontal para POS
    WidgetsFlutterBinding.ensureInitialized();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }
}
