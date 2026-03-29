import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTheme {
  // ── Colores primarios Terpel ──
  static const Color terpeRed = Color(0xFFFF0B18);       // Rojo Terpel
  static const Color terpelSky = Color(0xFFF3FFFF);      // Cielo Terpel
  static const Color terpelYellow = Color(0xFFFFE500);    // Amarillo Terpel

  // ── Colores secundarios Terpel ──
  static const Color terpelDarkYellow = Color(0xFFFDB915); // Amarillo oscuro
  static const Color terpelMediumRed = Color(0xFFB20000);  // Rojo medio
  static const Color terpelDarkRed = Color(0xFF7C0000);    // Rojo oscuro

  // ── Grises Terpel ──
  static const Color lightGray = Color(0xFFEDF9F9);       // Gris 1
  static const Color mediumGray = Color(0xFFC9D6D7);      // Gris 2
  static const Color darkGray = Color(0xFFECEFF1);        // Panel BG (funcional)
  static const Color terpelGray3 = Color(0xFFA9BBBD);     // Gris 3
  static const Color terpelGray4 = Color(0xFF638287);     // Gris 4
  static const Color terpelGray5 = Color(0xFF466468);     // Gris 5
  static const Color terpelGray6 = Color(0xFF1A3A42);     // Gris 6
  static const Color terpelGrayDark = Color(0xFF132023);  // Gris oscuro

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
