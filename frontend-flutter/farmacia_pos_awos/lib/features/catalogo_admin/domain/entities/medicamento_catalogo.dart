import 'package:equatable/equatable.dart';

/// Entidad de medicamento para el panel de administración de catálogo.
///
/// Mapea la respuesta del endpoint [GET /api/v1/catalogo/medicamentos]
/// del microservicio Python.
class MedicamentoCatalogo extends Equatable {
  /// Identificador único de la base de datos.
  final int id;

  /// Nombre comercial del medicamento.
  final String nombre;

  /// Código de barras único del medicamento.
  final String codigoBarras;

  /// Precio de venta al público.
  final double precio;

  /// Si el medicamento requiere receta médica (HU-08).
  final bool requiereReceta;

  /// Nombre de la categoría terapéutica asignada.
  final String? categoria;

  /// Nombre del proveedor/laboratorio asignado.
  final String? proveedor;

  /// Constructor principal de la entidad.
  const MedicamentoCatalogo({
    required this.id,
    required this.nombre,
    required this.codigoBarras,
    required this.precio,
    required this.requiereReceta,
    this.categoria,
    this.proveedor,
  });

  /// Crea una instancia desde el JSON del backend.
  factory MedicamentoCatalogo.fromJson(Map<String, dynamic> json) {
    return MedicamentoCatalogo(
      id: (json['id'] as num).toInt(),
      nombre: json['nombre'] as String,
      codigoBarras: json['codigo_barras'] as String,
      precio: (json['precio'] as num).toDouble(),
      requiereReceta: json['requiere_receta'] as bool,
      categoria: json['categoria'] as String?,
      proveedor: json['proveedor'] as String?,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    id,
    nombre,
    codigoBarras,
    precio,
    requiereReceta,
    categoria,
    proveedor,
  ];
}
