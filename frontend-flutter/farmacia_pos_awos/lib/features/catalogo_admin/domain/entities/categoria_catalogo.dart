import 'package:equatable/equatable.dart';

/// Entidad de categoría terapéutica para el panel de administración.
///
/// Mapea la respuesta del endpoint [GET /api/v1/catalogo/categorias]
/// del microservicio Python.
class CategoriaCatalogo extends Equatable {
  /// Identificador único de la base de datos.
  final int id;

  /// Nombre de la categoría terapéutica.
  final String nombre;

  /// Constructor principal de la entidad.
  const CategoriaCatalogo({required this.id, required this.nombre});

  /// Crea una instancia desde el JSON del backend.
  factory CategoriaCatalogo.fromJson(Map<String, dynamic> json) {
    return CategoriaCatalogo(
      id: (json['id'] as num).toInt(),
      nombre: json['nombre'] as String,
    );
  }

  @override
  List<Object?> get props => <Object?>[id, nombre];
}
