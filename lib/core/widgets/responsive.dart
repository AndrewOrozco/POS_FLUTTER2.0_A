import 'package:flutter/material.dart';

/// Helper para responsividad en toda la app Terpel POS
class Responsive extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget desktop;

  const Responsive({
    super.key,
    required this.mobile,
    this.tablet,
    required this.desktop,
  });

  /// Breakpoint para teléfonos móviles (detecta vertical u horizontal en smartphones)
  static bool isMobile(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return size.shortestSide < 600 || size.width < 768;
  }

  /// Breakpoint para tablets o pantallas intermedias
  static bool isTablet(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return !isMobile(context) && size.width < 1024;
  }

  /// Breakpoint para desktop o pantallas amplias de POS
  static bool isDesktop(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return !isMobile(context) && size.width >= 1024;
  }

  static double screenWidth(BuildContext context) =>
      MediaQuery.of(context).size.width;

  static double screenHeight(BuildContext context) =>
      MediaQuery.of(context).size.height;

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    if (width >= 1024) {
      return desktop;
    } else if (width >= 768 && tablet != null) {
      return tablet!;
    } else {
      return mobile;
    }
  }
}
