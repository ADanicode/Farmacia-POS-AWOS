import 'package:equatable/equatable.dart';

/// Entidad de dominio para un medicamento disponible en catálogo.
class Medicamento extends Equatable {
  /// Identificador interno del medicamento.
  final int id;

  /// Nombre comercial para mostrar en UI.
  final String nombre;

  /// Código de barras del medicamento.
  final String codigoBarras;

  /// Precio unitario sin IVA.
  final double precio;

  /// Indica si requiere receta médica.
  final bool requiereReceta;

  /// Categoría del catálogo.
  final String categoria;

  /// Proveedor del catálogo.
  final String proveedor;

  /// Constructor principal de la entidad de medicamento.
  const Medicamento({
    required this.id,
    required this.nombre,
    required this.codigoBarras,
    required this.precio,
    required this.requiereReceta,
    required this.categoria,
    required this.proveedor,
  });

  /// Crea una entidad de dominio a partir del JSON de FastAPI.
  factory Medicamento.fromJson(Map<String, dynamic> json) {
    return Medicamento(
      id: (json['id'] as num?)?.toInt() ?? 0,
      nombre: (json['nombre'] as String?) ?? '',
      codigoBarras: (json['codigo_barras'] as String?) ?? '',
      precio: (json['precio'] as num?)?.toDouble() ?? 0,
      requiereReceta: (json['requiere_receta'] as bool?) ?? false,
      categoria: (json['categoria'] as String?) ?? 'Sin categoría',
      proveedor: (json['proveedor'] as String?) ?? 'Sin proveedor',
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
