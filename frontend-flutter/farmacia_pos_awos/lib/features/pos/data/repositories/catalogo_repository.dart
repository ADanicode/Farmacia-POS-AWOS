import '../../../../core/network/app_endpoints.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/medicamento.dart';
import '../../domain/entities/medicamento_stock.dart';
import '../../domain/entities/pos_item.dart';

/// Repositorio de catálogo para consumo de medicamentos en FastAPI.
class CatalogoRepository {
  static const int _stockBatchSize = 20;

  /// URL base del endpoint de búsqueda del catálogo Python.
  static String get _catalogoEndpoint =>
      '${AppEndpoints.pythonApiV1}/catalogo/medicamentos';

  /// URL base para consultar lotes y stock por medicamento.
  static String get _almacenEndpoint => '${AppEndpoints.pythonApiV1}/almacen';

  /// Cliente HTTP compartido por toda la aplicación.
  final ApiClient _apiClient;

  /// Caché en memoria del catálogo activo.
  List<Medicamento>? _catalogoCache;

  /// Caché en memoria del stock por medicamento.
  final Map<int, MedicamentoStock> _stockCache = <int, MedicamentoStock>{};

  /// Constructor principal del repositorio de catálogo.
  CatalogoRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  /// Indica si el catálogo ya fue precargado en memoria.
  bool get tieneCatalogoEnMemoria => _catalogoCache != null;

  // PATRON: REPOSITORY - Abstrae el origen HTTP y entrega entidades de dominio.
  // CUMPLE HU-17: BUSQUEDA EN MOSTRADOR (ALTA VELOCIDAD) VIA CATALOGO CENTRAL.
  /// Obtiene medicamentos del catálogo, con filtro opcional por nombre.
  Future<List<Medicamento>> obtenerMedicamentos({String? nombre}) async {
    final Map<String, dynamic>? query =
        (nombre != null && nombre.trim().isNotEmpty)
        ? <String, dynamic>{'nombre': nombre.trim()}
        : null;

    final response = await _apiClient.get(
      _catalogoEndpoint,
      queryParameters: query,
    );

    final List<dynamic> data = response.data as List<dynamic>;
    return data
        .map(
          (dynamic item) => Medicamento.fromJson(item as Map<String, dynamic>),
        )
        .toList(growable: false);
  }

  /// Precarga catálogo completo y lo conserva en memoria para búsquedas locales.
  Future<List<Medicamento>> obtenerCatalogoCacheado({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _catalogoCache != null) {
      return _catalogoCache!;
    }

    final List<Medicamento> catalogo = await obtenerMedicamentos();
    _catalogoCache = catalogo;
    return catalogo;
  }

  /// Filtra el catálogo cacheado en memoria sin nuevas llamadas HTTP por query.
  Future<List<Medicamento>> buscarEnCache(
    String query, {
    bool forceRefresh = false,
  }) async {
    final List<Medicamento> catalogo = await obtenerCatalogoCacheado(
      forceRefresh: forceRefresh,
    );
    final String normalizedQuery = _normalize(query.trim());

    if (normalizedQuery.isEmpty) {
      return catalogo;
    }

    return catalogo
        .where((Medicamento medicamento) {
          final String nombre = _normalize(medicamento.nombre);
          final String codigo = _normalize(medicamento.codigoBarras);
          final String categoria = _normalize(medicamento.categoria);
          return nombre.contains(normalizedQuery) ||
              codigo.contains(normalizedQuery) ||
              categoria.contains(normalizedQuery);
        })
        .toList(growable: false);
  }

  /// Obtiene stock para una lista de medicamentos usando caché con refresh opcional.
  Future<Map<int, MedicamentoStock>> obtenerStockParaMedicamentos(
    List<Medicamento> medicamentos, {
    bool forceRefresh = false,
  }) async {
    final Map<int, MedicamentoStock> resultado = <int, MedicamentoStock>{};

    final List<Medicamento> pendientes = <Medicamento>[];
    for (final Medicamento medicamento in medicamentos) {
      final MedicamentoStock? cached = _stockCache[medicamento.id];
      if (!forceRefresh && cached != null) {
        resultado[medicamento.id] = cached;
      } else {
        pendientes.add(medicamento);
      }
    }

    for (int i = 0; i < pendientes.length; i += _stockBatchSize) {
      final int end = (i + _stockBatchSize) > pendientes.length
          ? pendientes.length
          : (i + _stockBatchSize);
      final List<Medicamento> lote = pendientes.sublist(i, end);

      final List<_StockLookupResult> loteResuelto = await Future.wait(
        lote.map((_resolverStockMedicamento)),
      );

      for (final _StockLookupResult item in loteResuelto) {
        if (item.stock != null) {
          _stockCache[item.medicamentoId] = item.stock!;
          resultado[item.medicamentoId] = item.stock!;
          continue;
        }

        final MedicamentoStock? cached = _stockCache[item.medicamentoId];
        if (cached != null) {
          resultado[item.medicamentoId] = cached;
        }
      }
    }

    return resultado;
  }

  Future<_StockLookupResult> _resolverStockMedicamento(
    Medicamento medicamento,
  ) async {
    try {
      final MedicamentoStock stock = await obtenerStockMedicamento(
        medicamento.id,
      );
      return _StockLookupResult(medicamentoId: medicamento.id, stock: stock);
    } catch (_) {
      return _StockLookupResult(medicamentoId: medicamento.id, stock: null);
    }
  }

  /// Retorna stock local disponible desde caché para los medicamentos visibles.
  Map<int, MedicamentoStock> obtenerStockDesdeCache(
    List<Medicamento> medicamentos,
  ) {
    final Map<int, MedicamentoStock> resultado = <int, MedicamentoStock>{};
    for (final Medicamento medicamento in medicamentos) {
      final MedicamentoStock? cached = _stockCache[medicamento.id];
      if (cached != null) {
        resultado[medicamento.id] = cached;
      }
    }
    return resultado;
  }

  /// Descuenta stock local en RAM sin bloquear UI tras una venta exitosa.
  void descontarStockLocal(List<PosItem> vendidos) {
    for (final PosItem item in vendidos) {
      final MedicamentoStock? cached = _stockCache[item.medicamento.id];
      if (cached == null) {
        continue;
      }

      final int nuevoStock = (cached.stockTotal - item.cantidad).clamp(
        0,
        1 << 31,
      );
      _stockCache[item.medicamento.id] = MedicamentoStock(
        medicamentoId: cached.medicamentoId,
        stockTotal: nuevoStock,
        lotePrincipal: cached.lotePrincipal,
      );
    }
  }

  String _normalize(String value) {
    final String lower = value.toLowerCase();
    return lower
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('ñ', 'n');
  }

  // CUMPLE HU-14: CONSULTA DE EXISTENCIAS POR LOTE PARA VISIBILIDAD DE STOCK.
  /// Obtiene stock total y lote FEFO sugerido de un medicamento.
  Future<MedicamentoStock> obtenerStockMedicamento(int medicamentoId) async {
    final response = await _apiClient.get(
      '$_almacenEndpoint/medicamentos/$medicamentoId/lotes',
      requiresAuth: false,
    );

    final Map<String, dynamic> data = response.data as Map<String, dynamic>;
    final List<dynamic> lotes =
        (data['lotes'] as List<dynamic>?) ?? <dynamic>[];

    String? lotePrincipal;
    if (lotes.isNotEmpty) {
      final Map<String, dynamic> primerLote =
          lotes.first as Map<String, dynamic>;
      lotePrincipal = primerLote['numero_lote'] as String?;
    }

    return MedicamentoStock(
      medicamentoId: medicamentoId,
      stockTotal: (data['stock_total'] as num?)?.toInt() ?? 0,
      lotePrincipal: lotePrincipal,
    );
  }
}

class _StockLookupResult {
  final int medicamentoId;
  final MedicamentoStock? stock;

  const _StockLookupResult({required this.medicamentoId, required this.stock});
}
