import 'package:flutter/material.dart';

/// Mapa oficial de colores de producto Terpel para StatusPump NEW
/// Cumple con las especificaciones visuales de la Guía Terpel
class CombustibleColor {
  static const Color corriente = Color(0xFFEC000F); // Rojo
  static const Color extra = Color(0xFF0070D5);     // Azul
  static const Color diesel = Color(0xFFFDB913);    // Amarillo / Bioacem
  static const Color glp = Color(0xFF0FAB0B);       // Verde
  static const Color gas = Color(0xFF0FAB0B);       // Verde

  // Estados visuales de la tarjeta y chips
  static const Color idleBg = Color(0xFF42535C);    // Gris azulado inactivo
  static const Color idleNum = Color(0xFFA0B0B8);   // Número atenuado
  static const Color cardBg = Color(0xFFFFFFFF);    // Fondo tarjeta blanca
  static const Color headerDark = Color(0xFF001333); // Fondo header superior
  static const Color labelManguera = Color(0xFF8B0000); // Guinda / Rojo títulos cajas

  // Badge y borde de FIN_DESPACHO
  static const Color finDespachoBg = Color(0xFFDCF5DC); // Verde muy claro
  static const Color finDespachoFg = Color(0xFF0B8A08); // Verde oscuro texto/borde
  static const Color finDespachoBorder = Color(0xFF0B8A08);

  // Botones de acción
  static const Color botonAccionBg = Color(0xFF7C0000); // Rojo vino corporativo
  static const Color botonDisabledBg = Color(0xFFDCE0E6); // Gris claro desactivado
  static const Color botonDisabledFg = Color(0xFF646E78); // Texto gris desactivado

  /// Obtiene el color correspondiente según el nombre del producto o familia
  static Color fromProducto(String producto) {
    if (producto.trim().isEmpty) return extra;
    final p = producto.trim().toLowerCase();
    if (p.contains('diesel') || p.contains('acpm') || p.contains('bioacem')) {
      return diesel;
    }
    if (p.contains('extra')) {
      return extra;
    }
    if (p.contains('glp') || (p.contains('gas') && !p.contains('gasolina'))) {
      return glp;
    }
    return corriente;
  }
}
