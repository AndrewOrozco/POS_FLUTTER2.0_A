/// Fase de una venta en el Status Pump NEW
/// Representa el ciclo de vida reactivo en pantalla
enum StatusPumpFase {
  /// Surtidor entregando combustible activamente (monto y volumen subiendo)
  despacho,

  /// Venta terminada físicamente; ventana de gracia con temporizador (60s / 10s)
  /// para asociar cliente, factura electrónica o medio de pago.
  finDespacho,

  /// Surtidor en espera / inactivo
  idle,
}
