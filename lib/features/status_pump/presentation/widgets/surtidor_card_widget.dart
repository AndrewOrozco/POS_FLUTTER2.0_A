import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/surtidor_estado.dart';

/// Widget que muestra el estado de un surtidor individual
/// Similar al StatusPump de la UI Java
class SurtidorCardWidget extends StatelessWidget {
  final SurtidorEstado surtidor;
  final VoidCallback? onTap;
  final VoidCallback? onGestionarVenta;
  final VoidCallback? onMediosPago;
  /// Si true, la venta ya fue gestionada (datos guardados) y el botón se muestra deshabilitado con check.
  final bool ventaGestionada;

  const SurtidorCardWidget({
    super.key,
    required this.surtidor,
    this.onTap,
    this.onGestionarVenta,
    this.onMediosPago,
    this.ventaGestionada = false,
  });

  @override
  Widget build(BuildContext context) {
    final tienePlaca = surtidor.placa != null && surtidor.placa!.isNotEmpty;
    final tieneMedioEspecial = surtidor.medioPagoEspecial != null && surtidor.medioPagoEspecial!.isNotEmpty;
    final tieneExtra = tienePlaca || tieneMedioEspecial;
    return Container(
      width: 320,
      height: tieneExtra ? 385 : 340, // Más altura si tiene placa o medio especial asignado
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header con producto
          _buildHeader(),
          // Botones de acción
          _buildActionButtons(),
          // Información de venta
          Expanded(child: _buildVentaInfo()),
          // Manguera
          _buildMangueraInfo(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final productoColor = _getProductoColor();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: productoColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              surtidor.producto.isNotEmpty 
                  ? surtidor.producto 
                  : 'COMBUSTIBLE',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (surtidor.placa != null && surtidor.placa!.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                surtidor.placa!,
                style: TextStyle(
                  color: productoColor,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          else if (surtidor.medioPagoEspecial != null && surtidor.medioPagoEspecial!.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.phone_iphone, size: 14, color: productoColor),
                  const SizedBox(width: 4),
                  Text(
                    surtidor.medioPagoEspecial!,
                    style: TextStyle(
                      color: productoColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    final bool habilitarMediosPago = surtidor.authorizationIdentifier == null;
    final productoColor = _getProductoColor();
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: _ActionButton(
              icon: ventaGestionada ? Icons.check_circle : Icons.edit_document,
              label: ventaGestionada ? 'Datos\nguardados' : 'Gestionar\nventa',
              onTap: onGestionarVenta,
              enabled: !ventaGestionada,
              accentColor: ventaGestionada ? Colors.green : productoColor,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _ActionButton(
              icon: Icons.payments,
              label: 'Medios de\npago',
              onTap: habilitarMediosPago ? onMediosPago : null,
              enabled: habilitarMediosPago,
              accentColor: productoColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVentaInfo() {
    final productoColor = _getProductoColor();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: productoColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Icono manguera
          Container(
            width: 55,
            height: 70,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.local_gas_station,
              size: 40,
              color: productoColor,
            ),
          ),
          const SizedBox(width: 12),
          // Información de venta
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoRowCompact(
                  label: 'IMPORTE',
                  value: '\$ ${_formatNumber(surtidor.monto)}',
                ),
                const SizedBox(height: 4),
                _InfoRowCompact(
                  label: 'CANTIDAD',
                  value: '${surtidor.volumen.toStringAsFixed(3)} GL',
                ),
                const SizedBox(height: 4),
                _InfoRowCompact(
                  label: 'PRECIO',
                  value: '\$ ${_formatNumber(surtidor.precioUnidad)}',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMangueraInfo() {
    final productoColor = _getProductoColor();
    final tienePlaca = surtidor.placa != null && surtidor.placa!.isNotEmpty;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: productoColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    '${surtidor.manguera}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Cara ${surtidor.cara}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
              const Spacer(),
              // Estado indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: _getEstadoColor(),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  surtidor.estado.nombre,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          // Medio de pago especial (APP TERPEL) - badge morado
          if (!tienePlaca && surtidor.medioPagoEspecial != null && surtidor.medioPagoEspecial!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF6A1B9A).withAlpha(15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF6A1B9A).withAlpha(60)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.phone_iphone, size: 16, color: Color(0xFF6A1B9A)),
                  const SizedBox(width: 6),
                  Text(
                    surtidor.medioPagoEspecial!,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF6A1B9A),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6A1B9A),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.qr_code_2, size: 12, color: Colors.white),
                        SizedBox(width: 4),
                        Text(
                          'QR 90s',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          // Placa asignada (GOPASS o similar)
          if (tienePlaca) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF1565C0).withAlpha(15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF1565C0).withAlpha(60)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.directions_car, size: 16, color: Color(0xFF1565C0)),
                  const SizedBox(width: 6),
                  Text(
                    'PLACA ASIGNADA',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1565C0),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      surtidor.placa!,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getEstadoColor() {
    switch (surtidor.estado) {
      case EstadoSurtidor.idle:
        return Colors.grey;
      case EstadoSurtidor.authorizationInProgress:
        return Colors.orange;
      case EstadoSurtidor.fueling:
        return Colors.green;
      case EstadoSurtidor.terminatedPEOT:
      case EstadoSurtidor.terminatedFEOT:
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  /// Obtener color según el tipo de combustible/manguera
  Color _getProductoColor() {
    final producto = surtidor.producto.toUpperCase();
    
    // Corriente / Regular → Rojo
    if (producto.contains('CORRIENTE') || 
        producto.contains('REGULAR') ||
        producto.contains('OXIGENADA')) {
      return const Color(0xFFE53935); // Rojo
    }
    
    // Diesel / ACPM / Biodiesel → Amarillo/Naranja
    if (producto.contains('DIESEL') || 
        producto.contains('ACPM') ||
        producto.contains('BIODIESEL') ||
        producto.contains('BIOACEM') ||
        producto.contains('B10') ||
        producto.contains('B12')) {
      return const Color(0xFFFFA000); // Amarillo/Naranja
    }
    
    // Extra / Premium → Azul
    if (producto.contains('EXTRA') || 
        producto.contains('PREMIUM') ||
        producto.contains('SUPER')) {
      return const Color(0xFF1E88E5); // Azul
    }
    
    // Gas Natural / GNV → Verde
    if (producto.contains('GAS') || 
        producto.contains('GNV') ||
        producto.contains('NATURAL')) {
      return const Color(0xFF43A047); // Verde
    }
    
    // GLP → Morado
    if (producto.contains('GLP') || 
        producto.contains('PROPANO')) {
      return const Color(0xFF8E24AA); // Morado
    }
    
    // Por defecto → Rojo Terpel
    return AppTheme.terpeRed;
  }

  String _formatNumber(double number) {
    if (number >= 1000) {
      return number.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (Match m) => '${m[1]},',
      );
    }
    return number.toStringAsFixed(0);
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool enabled;
  final Color accentColor;

  const _ActionButton({
    required this.icon,
    required this.label,
    this.onTap,
    this.enabled = true,
    this.accentColor = Colors.red,
  });

  @override
  Widget build(BuildContext context) {
    final buttonColor = enabled ? accentColor : Colors.grey;
    return Material(
      color: enabled ? Colors.white : Colors.grey.shade200,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            border: Border.all(
              color: buttonColor,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 22,
                color: buttonColor,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: buttonColor,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const _InfoRow({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _InfoRowCompact extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRowCompact({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.85),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
