/// Modelo de datos de la EDS (Estación de Servicio)
/// Viene del endpoint GET /configuracion/eds del backend FastAPI
class EdsInfo {
  final int id;
  final String nombre;
  final String razonSocial;
  final String nit;
  final String? direccion;
  final String? telefono;
  final String? correo;
  final String? codigo;

  const EdsInfo({
    required this.id,
    required this.nombre,
    required this.razonSocial,
    required this.nit,
    this.direccion,
    this.telefono,
    this.correo,
    this.codigo,
  });

  factory EdsInfo.fromJson(Map<String, dynamic> json) {
    return EdsInfo(
      id: json['id'] ?? 0,
      nombre: json['nombre'] ?? 'EDS TERPEL',
      razonSocial: json['razon_social'] ?? '',
      nit: json['nit'] ?? '',
      direccion: json['direccion'],
      telefono: json['telefono'],
      correo: json['correo'],
      codigo: json['codigo'],
    );
  }

  /// Fallback cuando el backend no está disponible
  static const EdsInfo fallback = EdsInfo(
    id: 0,
    nombre: 'EDS TERPEL',
    razonSocial: 'ESTACIÓN DE SERVICIO',
    nit: '--',
  );
}
