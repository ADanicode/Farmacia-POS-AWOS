import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/repositories/catalogo_admin_repository.dart';
import '../../domain/entities/categoria_catalogo.dart';
import '../../domain/entities/medicamento_catalogo.dart';
import '../../domain/entities/proveedor_catalogo.dart';
import 'catalogo_admin_state.dart';

/// Cubit para la gestión del estado del panel de administración de catálogo.
///
/// Orquesta la carga paralela de medicamentos, categorías y proveedores,
/// y las operaciones de creación y baja lógica.
class CatalogoAdminCubit extends Cubit<CatalogoAdminState> {
  final CatalogoAdminRepository _repository;

  /// Constructor con inyección del repositorio.
  CatalogoAdminCubit({required CatalogoAdminRepository repository})
    : _repository = repository,
      super(CatalogoAdminState.initial());

  /// Carga en paralelo medicamentos, categorías y proveedores desde el servidor.
  Future<void> cargarTodo() async {
    emit(state.copyWith(status: CatalogoAdminStatus.loading, clearError: true));
    try {
      final (
        List<MedicamentoCatalogo> medicamentos,
        List<CategoriaCatalogo> categorias,
        List<ProveedorCatalogo> proveedores,
      ) = await (
        _repository.getMedicamentos(),
        _repository.getCategorias(),
        _repository.getProveedores(),
      ).wait;

      emit(
        state.copyWith(
          status: CatalogoAdminStatus.loaded,
          medicamentos: medicamentos,
          categorias: categorias,
          proveedores: proveedores,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: CatalogoAdminStatus.error,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  /// Registra un nuevo medicamento y recarga el catálogo completo.
  Future<void> crearMedicamento({
    required String nombre,
    required String codigoBarras,
    required double precio,
    required bool requiereReceta,
    required int categoriaId,
    required int proveedorId,
  }) async {
    emit(state.copyWith(status: CatalogoAdminStatus.saving, clearError: true));
    try {
      await _repository.crearMedicamento(
        nombre: nombre,
        codigoBarras: codigoBarras,
        precio: precio,
        requiereReceta: requiereReceta,
        categoriaId: categoriaId,
        proveedorId: proveedorId,
      );
      await cargarTodo();
    } catch (e) {
      emit(
        state.copyWith(
          status: CatalogoAdminStatus.error,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  /// Registra una nueva categoría terapéutica y recarga el catálogo.
  Future<void> crearCategoria(String nombre) async {
    emit(state.copyWith(status: CatalogoAdminStatus.saving, clearError: true));
    try {
      await _repository.crearCategoria(nombre);
      await cargarTodo();
    } catch (e) {
      emit(
        state.copyWith(
          status: CatalogoAdminStatus.error,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  /// Registra un nuevo proveedor/laboratorio y recarga el catálogo.
  Future<void> crearProveedor(String nombre, {String? contacto}) async {
    emit(state.copyWith(status: CatalogoAdminStatus.saving, clearError: true));
    try {
      await _repository.crearProveedor(nombre, contacto: contacto);
      await cargarTodo();
    } catch (e) {
      emit(
        state.copyWith(
          status: CatalogoAdminStatus.error,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  /// Aplica baja lógica a un medicamento y recarga el catálogo.
  Future<void> darDeBajaMedicamento(int id) async {
    emit(state.copyWith(status: CatalogoAdminStatus.saving, clearError: true));
    try {
      await _repository.darDeBaja(id);
      await cargarTodo();
    } catch (e) {
      emit(
        state.copyWith(
          status: CatalogoAdminStatus.error,
          errorMessage: e.toString(),
        ),
      );
    }
  }
}
