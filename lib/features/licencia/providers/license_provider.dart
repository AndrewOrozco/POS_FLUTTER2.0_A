import 'package:flutter/material.dart';
import '../../../core/services/api_consultas_service.dart';

/// Estado de la licencia del equipo.
/// Value Object — inmutable (SOLID SRP).
class LicenseStatus {
  final bool licenciado;
  final String? fingerprint;
  final String mensaje;

  const LicenseStatus({
    required this.licenciado,
    required this.mensaje,
    this.fingerprint,
  });

  factory LicenseStatus.noLicenciado(String fingerprint) => LicenseStatus(
        licenciado: false,
        mensaje: 'Equipo no autorizado',
        fingerprint: fingerprint,
      );

  factory LicenseStatus.error() => const LicenseStatus(
        licenciado: false,
        mensaje: 'Error verificando licencia',
      );
}

/// Provider de licencias — Open/Closed: extensible sin modificar la validación.
/// SRP: solo gestiona el estado de la licencia.
class LicenseProvider extends ChangeNotifier {
  final ApiConsultasService _api = ApiConsultasService();

  LicenseStatus _status = const LicenseStatus(
    licenciado: false,
    mensaje: 'Verificando...',
  );

  bool _cargando = true;
  bool _activando = false;
  bool _restaurando = false;
  String? _errorActivacion;
  String? _exitoActivacion;

  LicenseStatus get status => _status;
  bool get isLicensed => _status.licenciado;
  bool get cargando => _cargando;
  bool get activando => _activando;
  bool get restaurando => _restaurando;
  String? get errorActivacion => _errorActivacion;
  String? get exitoActivacion => _exitoActivacion;

  /// Verifica el estado de la licencia al arrancar la app.
  Future<void> checkLicense() async {
    _cargando = true;
    notifyListeners();
    try {
      final result = await _api.getLicenciaStatus();
      _status = LicenseStatus(
        licenciado: result['licenciado'] == true,
        mensaje: result['mensaje'] ?? '',
        fingerprint: result['fingerprint']?.toString(),
      );
    } catch (e) {
      _status = LicenseStatus.error();
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  /// Activa la licencia con el código ingresado.
  Future<bool> activate(String code) async {
    _activando = true;
    _errorActivacion = null;
    _exitoActivacion = null;
    notifyListeners();

    try {
      final result = await _api.activarLicencia(code);
      if (result['exito'] == true) {
        _exitoActivacion = result['mensaje'] ?? 'Licencia activada';
        await checkLicense();
        return true;
      } else {
        _errorActivacion = result['mensaje'] ?? 'Código inválido';
        return false;
      }
    } catch (e) {
      _errorActivacion = 'Error de conexión: $e';
      return false;
    } finally {
      _activando = false;
      notifyListeners();
    }
  }

  /// Restaura el equipo a estado no licenciado (para re-activar o probar).
  Future<void> restaurarLicencia() async {
    _restaurando = true;
    _errorActivacion = null;
    _exitoActivacion = null;
    notifyListeners();
    try {
      await _api.restaurarLicencia();
      await checkLicense(); // Refrescar estado
    } catch (e) {
      _errorActivacion = 'Error al restaurar: $e';
    } finally {
      _restaurando = false;
      notifyListeners();
    }
  }
}
