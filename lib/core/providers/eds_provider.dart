import 'package:flutter/foundation.dart';
import '../models/eds_info.dart';
import '../services/api_consultas_service.dart';

/// Provider que mantiene la información de la EDS cargada desde el backend.
///
/// Se inicializa en [App] y queda disponible en todo el árbol de widgets.
///
/// Uso:
/// ```dart
/// final eds = context.watch<EdsProvider>();
/// Text(eds.nombre);  // "EDS LA JUANA"
/// Text(eds.nit);     // "900123456-1"
/// ```
class EdsProvider extends ChangeNotifier {
  EdsInfo _info = EdsInfo.fallback;
  bool _cargando = true;
  String? _error;

  EdsInfo get info => _info;
  bool get cargando => _cargando;
  String? get error => _error;

  /// Nombre de la estación (para mostrar en header, tickets, etc.)
  String get nombre => _info.nombre;
  String get nit => _info.nit;
  String get razonSocial => _info.razonSocial;
  String get codigo => _info.codigo ?? '';


  Future<void> cargar() async {
    _cargando = true;
    _error = null;
    notifyListeners();

    try {
      final service = ApiConsultasService();
      final data = await service.getConfiguracionEds();

      if (data != null) {
        _info = EdsInfo.fromJson(data);
        debugPrint('[EdsProvider] EDS cargada: ${_info.nombre} NIT:${_info.nit}');
      } else {
        _error = 'Sin respuesta del backend';
        debugPrint('[EdsProvider] No se pudo cargar EDS, usando fallback');
      }
    } catch (e) {
      _error = e.toString();
      debugPrint('[EdsProvider] Error cargando EDS: $e');
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }
}
