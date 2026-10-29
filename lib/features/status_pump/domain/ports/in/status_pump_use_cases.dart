import '../../entities/surtidor_estado.dart';

/// Caso de uso para enfocar una cara en la interfaz.
class SeleccionarCaraUseCase {
  int? execute({
    required int? caraActual,
    required int nuevaCara,
    required Map<int, SurtidorEstado> surtidores,
  }) {
    if (caraActual != nuevaCara) {
      return nuevaCara;
    }
    return caraActual;
  }
}

/// Caso de uso para confirmar la inserción de una venta por LazoExpress en BD.
class ConfirmarVentaLazoUseCase {
  SurtidorEstado execute({
    required SurtidorEstado surtidor,
    int? movimientoId,
    DateTime? nuevoDeadline,
  }) {
    return surtidor.copyWith(
      ventaInsertadaEnBd: true,
      gestionaVenta: true,
      idMovimiento: movimientoId ?? (surtidor.idMovimiento > 0 ? surtidor.idMovimiento : null),
      deadlineFin: nuevoDeadline ?? surtidor.deadlineFin,
    );
  }
}

/// Caso de uso para marcar una venta como gestionada.
class MarcarVentaGestionadaUseCase {
  SurtidorEstado execute({
    required SurtidorEstado surtidor,
    DateTime? nuevoDeadline,
  }) {
    return surtidor.copyWith(
      gestionaVenta: true,
      deadlineFin: nuevoDeadline ?? surtidor.deadlineFin,
    );
  }
}
