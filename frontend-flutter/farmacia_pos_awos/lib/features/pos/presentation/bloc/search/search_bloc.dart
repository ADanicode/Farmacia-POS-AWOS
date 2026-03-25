import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:stream_transform/stream_transform.dart';

import '../../../data/repositories/catalogo_repository.dart';
import '../../../domain/entities/medicamento.dart';
import '../../../domain/entities/medicamento_stock.dart';
import 'search_event.dart';
import 'search_state.dart';

/// BLoC de búsqueda de medicamentos para el módulo POS.
class SearchBloc extends Bloc<SearchEvent, SearchState> {
  static const int _initialStockHydrationLimit = 60;

  /// Repositorio para consultar catálogo remoto.
  final CatalogoRepository _catalogoRepository;

  /// Constructor principal del SearchBloc.
  SearchBloc({required CatalogoRepository catalogoRepository})
    : _catalogoRepository = catalogoRepository,
      super(SearchState.initial()) {
    // PATRON: DEBOUNCE - Evita ráfagas de llamadas HTTP al tipear.
    // CUMPLE HU-17: BUSQUEDA EN MOSTRADOR (ALTA VELOCIDAD).
    on<SearchQueryChanged>(
      _onQueryChanged,
      transformer: _debounce(const Duration(milliseconds: 300)),
    );
    on<SearchCatalogSyncRequested>(_onCatalogSyncRequested);
    on<SearchStockDiscountApplied>(_onStockDiscountApplied);

    // Precarga del catálogo al iniciar para eliminar roundtrip por tecla.
    _catalogoRepository.obtenerCatalogoCacheado();
  }

  /// Crea un transformador debounce para eventos de texto de búsqueda.
  EventTransformer<T> _debounce<T>(Duration duration) {
    return (Stream<T> events, EventMapper<T> mapper) {
      return events.debounce(duration).asyncExpand(mapper);
    };
  }

  /// Maneja el cambio de query y filtra catálogo local cacheado.
  Future<void> _onQueryChanged(
    SearchQueryChanged event,
    Emitter<SearchState> emit,
  ) async {
    await _cargarResultados(
      emit,
      query: event.query,
      showLoading: !_catalogoRepository.tieneCatalogoEnMemoria,
    );
  }

  /// Sincroniza silenciosamente catálogo y stock visible sin bloquear la UI.
  Future<void> _onCatalogSyncRequested(
    SearchCatalogSyncRequested event,
    Emitter<SearchState> emit,
  ) async {
    await _cargarResultados(
      emit,
      query: state.query,
      forceRefresh: event.forceRefresh,
      showLoading: false,
    );
  }

  /// Aplica un descuento optimista de stock directamente sobre la caché local.
  Future<void> _onStockDiscountApplied(
    SearchStockDiscountApplied event,
    Emitter<SearchState> emit,
  ) async {
    _catalogoRepository.descontarStockLocal(event.vendidos);
    emit(
      state.copyWith(
        stockPorMedicamento: _catalogoRepository.obtenerStockDesdeCache(
          state.resultados,
        ),
      ),
    );
  }

  Future<void> _cargarResultados(
    Emitter<SearchState> emit, {
    required String query,
    bool forceRefresh = false,
    bool showLoading = false,
  }) async {
    if (showLoading) {
      emit(
        state.copyWith(
          status: SearchStatus.loading,
          query: query,
          errorMessage: null,
        ),
      );
    }

    try {
      final List<Medicamento> resultados = await _catalogoRepository
          .buscarEnCache(query, forceRefresh: forceRefresh);
      final bool esCargaInicial = query.trim().isEmpty;
      final List<Medicamento> medicamentosParaStock = esCargaInicial
          ? resultados.take(_initialStockHydrationLimit).toList(growable: false)
          : resultados;

      final Map<int, MedicamentoStock> stockPorMedicamento =
          await _catalogoRepository.obtenerStockParaMedicamentos(
            medicamentosParaStock,
            forceRefresh: forceRefresh,
          );

      emit(
        state.copyWith(
          status: SearchStatus.success,
          query: query,
          resultados: resultados,
          stockPorMedicamento: stockPorMedicamento,
          errorMessage: null,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: SearchStatus.failure,
          query: query,
          resultados: const <Medicamento>[],
          stockPorMedicamento: <int, MedicamentoStock>{},
          errorMessage: e.toString(),
        ),
      );
    }
  }
}
