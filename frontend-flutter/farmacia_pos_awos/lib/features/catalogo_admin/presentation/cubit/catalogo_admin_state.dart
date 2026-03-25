import 'package:equatable/equatable.dart';

import '../../domain/entities/categoria_catalogo.dart';
import '../../domain/entities/medicamento_catalogo.dart';
import '../../domain/entities/proveedor_catalogo.dart';

/// Estados posibles del panel de administración de catálogo.
enum CatalogoAdminStatus {
  /// Estado inicial antes de cargar cualquier dato.
  initial,

  /// Cargando datos del servidor.
  loading,

  /// Datos cargados exitosamente.
  loaded,

  /// Guardando un nuevo registro.
  saving,

  /// Ocurrió un error al cargar o guardar.
  error,
}

/// Estado inmutable del [CatalogoAdminCubit].
class CatalogoAdminState extends Equatable {
  /// Estado actual del panel.
  final CatalogoAdminStatus status;

  /// Lista de medicamentos en el catálogo.
  final List<MedicamentoCatalogo> medicamentos;

  /// Lista de categorías terapéuticas disponibles.
  final List<CategoriaCatalogo> categorias;

  /// Lista de proveedores/laboratorios disponibles.
  final List<ProveedorCatalogo> proveedores;

  /// Mensaje de error cuando status == [CatalogoAdminStatus.error].
  final String? errorMessage;

  /// Constructor principal del estado.
  const CatalogoAdminState({
    required this.status,
    required this.medicamentos,
    required this.categorias,
    required this.proveedores,
    this.errorMessage,
  });

  /// Estado inicial vacío antes de la primera carga.
  factory CatalogoAdminState.initial() {
    return const CatalogoAdminState(
      status: CatalogoAdminStatus.initial,
      medicamentos: <MedicamentoCatalogo>[],
      categorias: <CategoriaCatalogo>[],
      proveedores: <ProveedorCatalogo>[],
    );
  }

  /// Crea una copia del estado con cambios parciales.
  CatalogoAdminState copyWith({
    CatalogoAdminStatus? status,
    List<MedicamentoCatalogo>? medicamentos,
    List<CategoriaCatalogo>? categorias,
    List<ProveedorCatalogo>? proveedores,
    String? errorMessage,
    bool clearError = false,
  }) {
    return CatalogoAdminState(
      status: status ?? this.status,
      medicamentos: medicamentos ?? this.medicamentos,
      categorias: categorias ?? this.categorias,
      proveedores: proveedores ?? this.proveedores,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => <Object?>[
    status,
    medicamentos,
    categorias,
    proveedores,
    errorMessage,
  ];
}
