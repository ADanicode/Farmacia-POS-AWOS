import '../../../../core/network/app_endpoints.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/lote_riesgo.dart';

/// Repositorio de almacén para HU-12, HU-13 y HU-15.
class AlmacenRepository {
  /// Endpoint de ingreso de lotes.
  static String get _lotesEndpoint =>
      '${AppEndpoints.pythonApiV1}/almacen/lotes';

  /// Endpoint de monitor de caducidades.
  static String get _riesgoEndpoint =>
      '${AppEndpoints.pythonApiV1}/almacen/lotes/proximos-caducar';

  /// Cliente HTTP compartido.
  final ApiClient _apiClient;

  /// Constructor principal del repositorio de almacén.
  const AlmacenRepository({required ApiClient apiClient})
    : _apiClient = apiClient;

  /// Registra un lote nuevo en inventario.
  Future<void> registrarLote({
    required int medicamentoId,
    required String numeroLote,
    required String fechaCaducidad,
    required int stockActual,
  }) async {
    await _apiClient.post(
      _lotesEndpoint,
      requiresAuth: false,
      data: <String, dynamic>{
        'medicamento_id': medicamentoId,
        'numero_lote': numeroLote,
        'fecha_caducidad': fechaCaducidad,
        'stock_actual': stockActual,
      },
    );
  }

  /// Obtiene lotes próximos a caducar para el dashboard de riesgos.
  Future<List<LoteRiesgo>> obtenerLotesProximosCaducar() async {
    final response = await _apiClient.get(_riesgoEndpoint, requiresAuth: false);
    final Map<String, dynamic> body = response.data as Map<String, dynamic>;
    final List<dynamic> lotes =
        (body['lotes'] as List<dynamic>?) ?? <dynamic>[];

    return lotes
        .map(
          (dynamic item) => LoteRiesgo.fromJson(item as Map<String, dynamic>),
        )
        .toList(growable: false);
  }
}
