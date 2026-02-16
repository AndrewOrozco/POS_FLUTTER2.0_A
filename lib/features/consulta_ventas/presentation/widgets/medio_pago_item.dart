import '../../../../core/services/api_consultas_service.dart';

/// Item de medio de pago para la lista de pagos mixtos.
/// Usado tanto por el wizard de asignar datos como por el diálogo de medio de pago.
class MedioPagoItemConsulta {
  final MedioPagoConsulta medio;
  final double valor;
  final String voucher;
  
  MedioPagoItemConsulta({
    required this.medio,
    required this.valor,
    this.voucher = '',
  });
}
