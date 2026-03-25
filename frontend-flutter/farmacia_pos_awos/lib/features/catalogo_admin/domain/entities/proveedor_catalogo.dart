import 'package:equatable/equatable.dart';

/// Entidad de proveedor/laboratorio para el panel de administración.
///
/// Mapea la respuesta del endpoint [GET /api/v1/catalogo/proveedores]
/// del microservicio Python.
class ProveedorCatalogo extends Equatable {
  /// Identificador único de la base de datos.
  final int id;

  /// Nombre del proveedor o laboratorio farmacéutico.
  final String nombre;

  /// Información de contacto del proveedor (opcional).
  final String? contacto;

  /// Constructor principal de la entidad.
  const ProveedorCatalogo({
    required this.id,
    required this.nombre,
    this.contacto,
  });

  /// Crea una instancia desde el JSON del backend.
  factory ProveedorCatalogo.fromJson(Map<String, dynamic> json) {
    return ProveedorCatalogo(
      id: (json['id'] as num).toInt(),
      nombre: json['nombre'] as String,
      contacto: json['contacto'] as String?,
    );
  }

  @override
  List<Object?> get props => <Object?>[id, nombre, contacto];
}
