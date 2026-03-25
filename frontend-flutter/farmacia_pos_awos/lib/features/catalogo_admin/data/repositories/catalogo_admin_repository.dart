import '../../../../core/network/app_endpoints.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/categoria_catalogo.dart';
import '../../domain/entities/medicamento_catalogo.dart';
import '../../domain/entities/proveedor_catalogo.dart';

/// Repositorio de administración del catálogo de medicamentos.
///
/// Conecta con el microservicio Python (puerto 8000) para las operaciones
/// de gestión de catálogo: medicamentos, categorías y proveedores.
/// Cumple HU-06 a HU-11.
class CatalogoAdminRepository {
  static String get _base => '${AppEndpoints.pythonApiV1}/catalogo';

  /// Cliente HTTP compartido de la aplicación.
  final ApiClient _apiClient;

  /// Constructor principal del repositorio.
  const CatalogoAdminRepository({required ApiClient apiClient})
    : _apiClient = apiClient;

  /// Retorna la lista completa de medicamentos activos del catálogo.
  Future<List<MedicamentoCatalogo>> getMedicamentos() async {
    final response = await _apiClient.get(
      '$_base/medicamentos',
      requiresAuth: false,
    );
    final List<dynamic> list = response.data as List<dynamic>;
    return list
        .map(
          (dynamic e) =>
              MedicamentoCatalogo.fromJson(e as Map<String, dynamic>),
        )
        .toList(growable: false);
  }

  /// Retorna la lista de categorías terapéuticas activas.
  Future<List<CategoriaCatalogo>> getCategorias() async {
    final response = await _apiClient.get(
      '$_base/categorias',
      requiresAuth: false,
    );
    final List<dynamic> list = response.data as List<dynamic>;
    return list
        .map(
          (dynamic e) => CategoriaCatalogo.fromJson(e as Map<String, dynamic>),
        )
        .toList(growable: false);
  }

  /// Retorna la lista de proveedores/laboratorios activos.
  Future<List<ProveedorCatalogo>> getProveedores() async {
    final response = await _apiClient.get(
      '$_base/proveedores',
      requiresAuth: false,
    );
    final List<dynamic> list = response.data as List<dynamic>;
    return list
        .map(
          (dynamic e) => ProveedorCatalogo.fromJson(e as Map<String, dynamic>),
        )
        .toList(growable: false);
  }

  /// Registra un nuevo medicamento en el catálogo (HU-07, HU-08).
  Future<void> crearMedicamento({
    required String nombre,
    required String codigoBarras,
    required double precio,
    required bool requiereReceta,
    required int categoriaId,
    required int proveedorId,
  }) async {
    await _apiClient.post(
      '$_base/medicamentos',
      requiresAuth: false,
      data: <String, dynamic>{
        'nombre': nombre,
        'codigo_barras': codigoBarras,
        'precio': precio,
        'requiere_receta': requiereReceta,
        'categoria_id': categoriaId,
        'proveedor_id': proveedorId,
      },
    );
  }

  /// Registra una nueva categoría terapéutica (HU-06).
  Future<void> crearCategoria(String nombre) async {
    await _apiClient.post(
      '$_base/categorias',
      requiresAuth: false,
      data: <String, dynamic>{'nombre': nombre},
    );
  }

  /// Registra un nuevo proveedor o laboratorio (HU-06).
  Future<void> crearProveedor(String nombre, {String? contacto}) async {
    await _apiClient.post(
      '$_base/proveedores',
      requiresAuth: false,
      data: <String, dynamic>{
        'nombre': nombre,
        if (contacto != null && contacto.isNotEmpty) 'contacto': contacto,
      },
    );
  }

  /// Aplica baja lógica a un medicamento (HU-11).
  Future<void> darDeBaja(int medicamentoId) async {
    await _apiClient.patch(
      '$_base/medicamentos/$medicamentoId/baja',
      requiresAuth: false,
    );
  }
}
